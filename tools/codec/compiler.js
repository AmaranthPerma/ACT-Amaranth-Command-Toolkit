const Compiler = (function() {
// Port + extension of gfxforge/compiler.py — an AS2-subset -> AVM1 compiler.
//
// Literals: number (decimal + hex), string, bool, null, undefined, array,
// object. Expressions: variables, `this`, obj.member, obj[key], calls f(a,b)
// and methods o.m(a), `new C(a)`, function expressions, ternary ?:, and the
// unary/binary operator set below. Statements: assignment (plain and
// compound), if/else, while, do/while, for(;;), for-in, switch/case/default,
// break, continue, var, function declarations, return, and fscommand("evt", x).
//
// Operators: unary - + ! ~ typeof delete; binary + - * / % < > <= >= == !=
// === !== && || & | ^ << >> >>> instanceof; prefix/postfix ++ --; compound
// assignment += -= *= /= %= &= |= ^= <<= >>= >>>=.
//
// Deliberately absent: try/catch/throw. GFx 2.1.57 routes opcode 0x8F (try)
// to its "Unsupported opcode" branch (GFxAction.cpp), so emitting it would
// produce a movie that logs an error and silently skips the handler. 0x2A
// (throw) exists but is useless on its own.
//
// Known limits: calls are by name or method (no calling an arbitrary
// expression result without going through a variable); `break` inside
// switch/for-in leaves the discriminant/enumeration on the AVM1 stack, which
// is harmless because the stack is per-action-buffer and reset at its end, but
// it is not a tidy unwind; parser/tokenizer errors include line/column, but
// errors raised during code generation (e.g. "break outside of a loop") do
// not, since that would require threading position info through every AST node
// rather than just tokens.

const avm1 = Avm1;
const NOT = avm1.NOT;

// --- Assembler: AVM1 code buffer with labels and backpatched branches -------
//
// Branch offsets in AVM1 are signed and measured from the byte *after* the
// 2-byte offset field, so we stash a fixup and resolve it in assemble().

const JUMP = 0x99; // ActionJump: always
const IF = 0x9d;   // ActionIf: pop bool, branch if true

class Assembler {
  constructor() {
    this.buf = [];       // array of byte values (numbers)
    this._labels = {};
    this._fixups = [];   // [offsetFieldPos, labelName]
  }

  emit(actionBytes) {
    for (const b of actionBytes) this.buf.push(b);
    return this;
  }

  label(name) {
    if (Object.prototype.hasOwnProperty.call(this._labels, name)) {
      throw new Error(`duplicate label ${JSON.stringify(name)}`);
    }
    this._labels[name] = this.buf.length;
    return this;
  }

  _branch(opcode, name) {
    this.buf.push(opcode, 2, 0);            // opcode + u16(2) little-endian
    this._fixups.push([this.buf.length, name]);
    this.buf.push(0, 0);                    // placeholder, patched in assemble()
    return this;
  }

  jump(name) {
    return this._branch(JUMP, name);
  }

  jumpIf(name) {
    return this._branch(IF, name);
  }

  jumpUnless(name) {
    this.emit(NOT);
    return this._branch(IF, name);
  }

  assemble() {
    const out = new Uint8Array(this.buf);
    const view = new DataView(out.buffer);
    for (const [pos, name] of this._fixups) {
      if (!Object.prototype.hasOwnProperty.call(this._labels, name)) {
        throw new Error(`undefined label ${JSON.stringify(name)}`);
      }
      view.setInt16(pos, this._labels[name] - (pos + 2), true);
    }
    return out;
  }
}

// --- lexer -------------------------------------------------------------------

const KEYWORDS = new Set(['if', 'else', 'while', 'for', 'break', 'continue',
  'function', 'return', 'var', 'true', 'false', 'null', 'undefined',
  'do', 'switch', 'case', 'default', 'new', 'delete', 'typeof', 'instanceof',
  'this', 'in']);

// Order mirrors the Python regex alternation: whitespace/comment, number,
// string, name, operator. First match wins at each position.
//
// Two ordering constraints inside the operator class: longer operators must
// precede their prefixes (">>>=" before ">>>" before ">>" before ">"; "===" before
// "=="; "&&" before "&"), and all compound-assignment forms must precede the
// single-char class so e.g. "+=" isn't split into "+" then "=".
//
// Comments cover both // to end-of-line and /* ... */ block form. The block
// form is non-greedy so two comments on one line don't merge into one.
const TOKEN_RE = /(\s+|\/\/[^\n]*|\/\*[\s\S]*?\*\/)|(0[xX][0-9a-fA-F]+|\d+\.\d+|\.\d+|\d+)|("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')|([A-Za-z_$][A-Za-z0-9_$]*)|(>>>=|>>>|>>=|<<=|===|!==|>>|<<|<=|>=|==|!=|&&|\|\||\+\+|--|\+=|-=|\*=|\/=|%=|&=|\|=|\^=|[-+*/%<>=!.,(){}\[\];?:&|^~])/y;

function unescape(s) {
  // Extends the Python original's four sequential replace passes with the
  // remaining C-style escapes AS2 accepts. Done as a single left-to-right scan
  // rather than chained replaces, because chained passes mis-handle sequences
  // that a previous pass just produced (the original's \\ pass running last
  // was a deliberate workaround for exactly that).
  //
  // \xNN and \uNNNN are accepted, but codepoints above 255 will be rejected
  // later by swf.js's latin1() — GFx strings here are single-byte.
  const q = s[0];
  const body = s.slice(1, -1);
  let out = '';
  for (let i = 0; i < body.length; i++) {
    const c = body[i];
    if (c !== '\\') { out += c; continue; }
    const n = body[++i];
    if (n === undefined) { out += '\\'; break; }
    switch (n) {
      case 'n': out += '\n'; break;
      case 't': out += '\t'; break;
      case 'r': out += '\r'; break;
      case 'b': out += '\b'; break;
      case 'f': out += '\f'; break;
      case '0': out += '\0'; break;
      case '\\': out += '\\'; break;
      case 'x': {
        const h = body.substr(i + 1, 2);
        if (/^[0-9a-fA-F]{2}$/.test(h)) { out += String.fromCharCode(parseInt(h, 16)); i += 2; }
        else out += 'x';
        break;
      }
      case 'u': {
        const h = body.substr(i + 1, 4);
        if (/^[0-9a-fA-F]{4}$/.test(h)) { out += String.fromCharCode(parseInt(h, 16)); i += 4; }
        else out += 'u';
        break;
      }
      default: out += n; break;   // covers \" \' and any unknown escape
    }
  }
  return out;
}

function parseNumber(text) {
  return /^0[xX]/.test(text) ? parseInt(text, 16) : parseFloat(text);
}

function tokenize(text) {
  const toks = [];
  let i = 0;
  let line = 1, col = 1;
  function advance(consumed) {
    for (let j = 0; j < consumed.length; j++) {
      if (consumed[j] === '\n') { line += 1; col = 1; } else { col += 1; }
    }
  }
  TOKEN_RE.lastIndex = 0;
  while (i < text.length) {
    TOKEN_RE.lastIndex = i;
    const m = TOKEN_RE.exec(text);
    if (!m || m.index !== i) {
      throw new SyntaxError(`Line ${line}, column ${col}: unrecognized text ${JSON.stringify(text.slice(i, i + 16))}`);
    }
    const startLine = line, startCol = col;
    const full = m[0];
    i = TOKEN_RE.lastIndex;
    const [, ws, num, str, name, op] = m;
    advance(full);
    if (ws !== undefined) continue;
    if (num !== undefined) {
      toks.push(['num', parseNumber(num), startLine, startCol]);
    } else if (str !== undefined) {
      toks.push(['str', unescape(str), startLine, startCol]);
    } else if (name !== undefined) {
      toks.push([KEYWORDS.has(name) ? 'kw' : 'name', name, startLine, startCol]);
    } else {
      toks.push(['op', op, startLine, startCol]);
    }
  }
  toks.push(['eof', '', line, col]);
  return toks;
}

// --- parser (recursive descent + precedence climbing) ------------------------

// Binding power, loosest first. Mirrors ECMAScript/AS2 precedence: the
// original table's levels are preserved in relative order, with the bitwise
// and shift levels slotted in between equality and the arithmetic levels
// where the language puts them. Ternary sits below everything here and is
// handled separately in expression(), since it is right-associative and
// three-part rather than a simple binary rung.
const PREC = {
  '||': 1, '&&': 2,
  '|': 3, '^': 4, '&': 5,
  '==': 6, '!=': 6, '===': 6, '!==': 6,
  '<': 7, '>': 7, '<=': 7, '>=': 7, 'instanceof': 7, 'in': 7,
  '<<': 8, '>>': 8, '>>>': 8,
  '+': 9, '-': 9,
  '*': 10, '/': 10, '%': 10,
};

const COMPOUND_OPS = {
  '+=': '+', '-=': '-', '*=': '*', '/=': '/', '%=': '%',
  '&=': '&', '|=': '|', '^=': '^', '<<=': '<<', '>>=': '>>', '>>>=': '>>>',
};

// An expression is "pure" if evaluating it twice is indistinguishable from
// evaluating it once — no calls, no ++/--, no assignment, no `new`. Used by
// compound assignment to decide whether it can simply re-emit the target's
// subexpressions or has to stash them in a register first.
function isPure(node) {
  if (!Array.isArray(node)) return true;
  switch (node[0]) {
    case 'num': case 'str': case 'bool': case 'null': case 'undef':
    case 'var': case 'this':
      return true;
    case 'member': return isPure(node[1]);
    case 'index': return isPure(node[1]) && isPure(node[2]);
    case 'unop': return node[1] !== 'delete' && isPure(node[2]);
    case 'binop': return isPure(node[2]) && isPure(node[3]);
    case 'logical': return isPure(node[2]) && isPure(node[3]);
    case 'ternary': return isPure(node[1]) && isPure(node[2]) && isPure(node[3]);
    case 'array': return node[1].every(isPure);
    case 'object': return node[1].every(p => isPure(p.value));
    default: return false;   // call, new, update, assign, function, ...
  }
}

class Parser {
  constructor(toks) {
    this.t = toks;
    this.i = 0;
  }

  _peek() { return this.t[this.i]; }
  _next() { const tok = this.t[this.i]; this.i += 1; return tok; }

  _at(kind, val) {
    const [k, v] = this.t[this.i];
    return k === kind && (val === undefined || v === val);
  }

  _eat(kind, val) {
    const [k, v, line, col] = this.t[this.i];
    if (k !== kind || (val !== undefined && v !== val)) {
      throw new SyntaxError(`Line ${line}, column ${col}: expected ${kind} ${JSON.stringify(val)}, got ${k} ${JSON.stringify(v)}`);
    }
    this.i += 1;
    return v;
  }

  program() {
    const out = [];
    while (!this._at('eof')) out.push(this.statement());
    return out;
  }

  block() {
    this._eat('op', '{');
    const out = [];
    while (!this._at('op', '}')) out.push(this.statement());
    this._eat('op', '}');
    return out;
  }

  // A statement body that may be either a braced block or a single statement,
  // so `if (x) doThing();` works without braces. Always returns a statement
  // array so callers can treat both forms identically.
  body() {
    if (this._at('op', '{')) return this.block();
    if (this._at('op', ';')) { this._next(); return []; }
    return [this.statement()];
  }

  statement() {
    let [k, v] = this._peek();
    if (k === 'op' && v === '{') return ['block', this.block()];
    if (k === 'op' && v === ';') { this._next(); return ['block', []]; }
    if (k === 'kw' && v === 'if') return this._if();
    if (k === 'kw' && v === 'while') {
      this._next(); this._eat('op', '(');
      const c = this.expression();
      this._eat('op', ')');
      return ['while', c, this.body()];
    }
    if (k === 'kw' && v === 'do') {
      this._next();
      const b = this.body();
      this._eat('kw', 'while'); this._eat('op', '(');
      const c = this.expression();
      this._eat('op', ')');
      if (this._at('op', ';')) this._next();
      return ['dowhile', c, b];
    }
    if (k === 'kw' && v === 'for') return this._for();
    if (k === 'kw' && v === 'switch') return this._switch();
    if (k === 'kw' && v === 'break') { this._next(); this._eat('op', ';'); return ['break']; }
    if (k === 'kw' && v === 'continue') { this._next(); this._eat('op', ';'); return ['continue']; }
    if (k === 'kw' && v === 'function') {
      this._next();
      const name = this._eat('name');
      return ['func', name, this._params(), this.block()];
    }
    if (k === 'kw' && v === 'return') {
      this._next();
      if (this._at('op', ';')) { this._next(); return ['return', null]; }
      const e = this.expression();
      this._eat('op', ';');
      return ['return', e];
    }
    if (k === 'kw' && v === 'var') return this._varDecl(true);
    // expression statement, assignment, or compound assignment
    const e = this.expression();
    const node = this._assignmentFrom(e);
    this._eat('op', ';');
    return node;
  }

  _params() {
    this._eat('op', '(');
    const params = [];
    if (!this._at('op', ')')) {
      params.push(this._eat('name'));
      while (this._at('op', ',')) { this._next(); params.push(this._eat('name')); }
    }
    this._eat('op', ')');
    return params;
  }

  // `var a = 1, b, c = 3;` — each declarator becomes its own node. A
  // declarator with no initializer still emits (DefineLocal2) so the name is
  // reserved in the local frame rather than silently resolving to _root.
  _varDecl(eatSemi) {
    this._eat('kw', 'var');
    const decls = [];
    for (;;) {
      const name = this._eat('name');
      if (this._at('op', '=')) {
        this._next();
        decls.push(['vardecl', name, this.expression()]);
      } else {
        decls.push(['vardecl', name, null]);
      }
      if (this._at('op', ',')) { this._next(); continue; }
      break;
    }
    if (eatSemi) this._eat('op', ';');
    return decls.length === 1 ? decls[0] : ['block', decls];
  }

  _switch() {
    this._eat('kw', 'switch'); this._eat('op', '(');
    const disc = this.expression();
    this._eat('op', ')'); this._eat('op', '{');
    const cases = [];   // {test: expr|null (default), body: [stmt]}
    while (!this._at('op', '}')) {
      let test = null;
      if (this._at('kw', 'default')) { this._next(); }
      else { this._eat('kw', 'case'); test = this.expression(); }
      this._eat('op', ':');
      const body = [];
      while (!this._at('op', '}') && !this._at('kw', 'case') && !this._at('kw', 'default')) {
        body.push(this.statement());
      }
      cases.push({ test, body });
    }
    this._eat('op', '}');
    return ['switch', disc, cases];
  }

  // Given an already-parsed expression `e`, checks for a following `=` or
  // compound-assignment operator and returns the right statement node —
  // otherwise just wraps `e` as an expression-statement. Shared by plain
  // statements and by for(...)'s init/update clauses (which don't have their
  // own trailing `;`/`)` to consume, so the caller handles that).
  // Given an already-parsed expression `e`, checks for a following `=` or
  // compound-assignment operator. Compound forms keep the operator and target
  // as-is rather than desugaring to ['assign', e, ['binop', op, e, rhs]] —
  // that desugaring duplicated the target node, so a target with side effects
  // (`a[next()] += 1`) evaluated them twice. Codegen expands it instead, where
  // it can arrange to evaluate the target exactly once.
  _assignmentFrom(e) {
    const [k, v] = this._peek();
    if (k === 'op' && v === '=') {
      this._next();
      const rhs = this.expression();
      return ['assign', e, rhs];
    }
    if (k === 'op' && Object.prototype.hasOwnProperty.call(COMPOUND_OPS, v)) {
      this._next();
      const rhs = this.expression();
      return ['compound', COMPOUND_OPS[v], e, rhs];
    }
    return ['expr', e];
  }

  _for() {
    this._eat('kw', 'for');
    this._eat('op', '(');

    // for (x in obj) / for (var x in obj) — detected by peeking past the
    // binding name for `in`, since up to that point it is identical to the
    // three-clause form's init.
    const isVar = this._at('kw', 'var');
    const save = this.i;
    if (isVar || this._at('name')) {
      if (isVar) this._next();
      if (this._at('name')) {
        const name = this._eat('name');
        if (this._at('kw', 'in')) {
          this._next();
          const obj = this.expression();
          this._eat('op', ')');
          return ['forin', name, isVar, obj, this.body()];
        }
      }
      this.i = save;   // not a for-in after all; re-parse as a normal for
    }

    let init = null;
    if (this._at('kw', 'var')) {
      init = this._varDecl(false);
    } else if (!this._at('op', ';')) {
      init = this._assignmentFrom(this.expression());
    }
    this._eat('op', ';');
    const cond = this._at('op', ';') ? ['bool', true] : this.expression();
    this._eat('op', ';');
    let update = null;
    if (!this._at('op', ')')) update = this._assignmentFrom(this.expression());
    this._eat('op', ')');
    const body = this.body();
    return ['for', init, cond, update, body];
  }

  _if() {
    this._eat('kw', 'if'); this._eat('op', '(');
    const c = this.expression();
    this._eat('op', ')');
    const then = this.body();
    let els = null;
    if (this._at('kw', 'else')) {
      this._next();
      els = this._at('kw', 'if') ? [this._if()] : this.body();
    }
    return ['if', c, then, els];
  }

  // Precedence climbing for the binary rungs, then a right-associative
  // ternary on top. `&&`/`||` become 'logical' rather than 'binop' because
  // they compile to branches, not to a single opcode.
  expression(minPrec = 1) {
    let left = this._unary();
    for (;;) {
      const [k, v] = this._peek();
      const isOp = (k === 'op' || (k === 'kw' && (v === 'instanceof' || v === 'in')));
      if (isOp && v in PREC && PREC[v] >= minPrec) {
        this._next();
        const right = this.expression(PREC[v] + 1);
        left = (v === '&&' || v === '||') ? ['logical', v, left, right] : ['binop', v, left, right];
      } else {
        break;
      }
    }
    if (minPrec <= 1 && this._at('op', '?')) {
      this._next();
      const thenE = this.expression();
      this._eat('op', ':');
      const elseE = this.expression();
      return ['ternary', left, thenE, elseE];
    }
    return left;
  }

  _unary() {
    const [k, v] = this._peek();
    if (k === 'op' && (v === '-' || v === '!' || v === '+' || v === '~')) {
      this._next();
      return ['unop', v, this._unary()];
    }
    if (k === 'kw' && (v === 'typeof' || v === 'delete')) {
      this._next();
      return ['unop', v, this._unary()];
    }
    if (k === 'op' && (v === '++' || v === '--')) {
      this._next();
      return ['update', v, this._unary(), true];   // prefix
    }
    if (k === 'kw' && v === 'new') {
      this._next();
      // `new A.B(x)` — the callee is a postfix chain, but the argument list
      // belongs to `new`, so parse the chain without letting it swallow a call.
      const callee = this._postfix(true);
      let args = [];
      if (this._at('op', '(')) args = this._args();
      return ['new', callee, args];
    }
    return this._postfix();
  }

  _args() {
    this._eat('op', '(');
    const args = [];
    if (!this._at('op', ')')) {
      args.push(this.expression());
      while (this._at('op', ',')) { this._next(); args.push(this.expression()); }
    }
    this._eat('op', ')');
    return args;
  }

  // `noCall` stops the chain before a `(` so `new Foo(1)` binds its argument
  // list to the `new` rather than parsing as `new (Foo(1))`.
  _postfix(noCall = false) {
    let e = this._primary();
    for (;;) {
      if (this._at('op', '.')) {
        this._next();
        // property names may be keywords (`clip.in`, `obj.default`), which the
        // lexer classifies as 'kw' — accept either token kind here
        const [tk, tv] = this._peek();
        if (tk === 'name' || tk === 'kw') { this._next(); e = ['member', e, tv]; }
        else e = ['member', e, this._eat('name')];
      } else if (!noCall && this._at('op', '(')) {
        e = ['call', e, this._args()];
      } else if (this._at('op', '[')) {
        this._next();
        const idx = this.expression();
        this._eat('op', ']');
        e = ['index', e, idx];
      } else if (this._at('op', '++') || this._at('op', '--')) {
        const [, op] = this._next();
        e = ['update', op, e, false];   // postfix
      } else {
        return e;
      }
    }
  }

  _primary() {
    const [k, v, line, col] = this._next();
    if (k === 'num') return ['num', v];
    if (k === 'str') return ['str', v];
    if (k === 'name') return ['var', v];
    if (k === 'kw') {
      if (v === 'true') return ['bool', true];
      if (v === 'false') return ['bool', false];
      if (v === 'null') return ['null'];
      if (v === 'undefined') return ['undef'];
      if (v === 'this') return ['this'];
      if (v === 'function') {   // function expression (anonymous or named)
        const name = this._at('name') ? this._eat('name') : '';
        return ['funcexpr', name, this._params(), this.block()];
      }
    }
    if (k === 'op' && v === '(') {
      const e = this.expression();
      this._eat('op', ')');
      return e;
    }
    if (k === 'op' && v === '[') {
      const elements = [];
      if (!this._at('op', ']')) {
        elements.push(this.expression());
        while (this._at('op', ',')) { this._next(); elements.push(this.expression()); }
      }
      this._eat('op', ']');
      return ['array', elements];
    }
    if (k === 'op' && v === '{') {   // object literal
      const props = [];
      if (!this._at('op', '}')) {
        for (;;) {
          const [pk, pv, pl, pc] = this._next();
          let key;
          if (pk === 'name' || pk === 'kw') key = pv;
          else if (pk === 'str') key = pv;
          else if (pk === 'num') key = String(pv);
          else throw new SyntaxError(`Line ${pl}, column ${pc}: bad object key ${pk} ${JSON.stringify(pv)}`);
          this._eat('op', ':');
          props.push({ key, value: this.expression() });
          if (this._at('op', ',')) { this._next(); if (this._at('op', '}')) break; continue; }
          break;
        }
      }
      this._eat('op', '}');
      return ['object', props];
    }
    throw new SyntaxError(`Line ${line}, column ${col}: unexpected ${k} ${JSON.stringify(v)}`);
  }
}

// --- code generator ----------------------------------------------------------

const BINOP = {
  '+': avm1.ADD2, '-': avm1.SUBTRACT, '*': avm1.MULTIPLY, '/': avm1.DIVIDE,
  '%': avm1.MODULO, '<': avm1.LESS2, '>': avm1.GREATER, '==': avm1.EQUALS2,
  '===': avm1.STRICT_EQUALS,
  '&': avm1.BIT_AND, '|': avm1.BIT_OR, '^': avm1.BIT_XOR,
  '<<': avm1.BIT_LSHIFT, '>>': avm1.BIT_RSHIFT, '>>>': avm1.BIT_URSHIFT,
  'instanceof': avm1.INSTANCE_OF,
};

// Zero-argument globals that lower to a single opcode instead of a real call.
const NULLARY_BUILTINS = { getTimer: avm1.GET_TIMER, targetPath: avm1.TARGET_PATH };

// One-argument globals that lower to a single opcode. `trace` writes to the
// GFx log (visible in a log-enabled build, inert in retail); `random` is AS1's
// integer random, distinct from Math.random().
const UNARY_BUILTINS = {
  trace: avm1.TRACE, random: avm1.RANDOM, ord: avm1.CHAR_TO_ASCII,
  chr: avm1.ASCII_TO_CHAR, int: avm1.TO_INTEGER,
  Number: avm1.TO_NUMBER, String: avm1.TO_STRING, length: avm1.STRING_LENGTH,
};

// Timeline verbs on the current target. `stop`/`play` take no arguments;
// gotoAndStop/gotoAndPlay take one and lower to GotoFrame2 so the argument can
// be a frame number or a label string, matching AS2.
const TIMELINE_BUILTINS = {
  play: () => avm1.PLAY, stop: () => avm1.STOP,
  nextFrame: () => avm1.NEXT_FRAME, prevFrame: () => avm1.PREV_FRAME,
  stopAllSounds: () => avm1.STOP_SOUNDS,
};
const NULL_LIT = Uint8Array.from([0x96, 0x01, 0x00, 0x02]);
const UNDEF_LIT = Uint8Array.from([0x96, 0x01, 0x00, 0x03]);

function concatArrays(...parts) {
  let len = 0;
  for (const p of parts) len += p.length;
  const out = new Uint8Array(len);
  let o = 0;
  for (const p of parts) { out.set(p, o); o += p.length; }
  return out;
}

class Gen {
  constructor() {
    this.asm = new Assembler();
    this._n = 0;
    this._loopStack = []; // [{continueLabel, breakLabel}], innermost last
    this._scratchDepth = 0; // nesting depth of register-using compound assigns
  }

  // Global registers 0-3 are the only ones addressable outside a
  // DefineFunction2 body (GFx logs "register out of bounds" past that), and
  // this compiler emits plain DefineFunction, so every context shares those
  // four. They're only ever live within a single statement's expansion, so
  // allocating by nesting depth is enough to keep concurrent uses apart.
  _scratchRegister() {
    if (this._scratchDepth >= 4) {
      throw new SyntaxError(
        'compound assignment nested too deeply on targets with side effects — '
        + 'only 4 AVM1 scratch registers exist; split the statement up');
    }
    return this._scratchDepth++;
  }
  _releaseScratch() { this._scratchDepth--; }

  _label(prefix) {
    this._n += 1;
    return `${prefix}${this._n}`;
  }

  emit(b) { this.asm.emit(b); }

  block(stmts) {
    for (const s of stmts) this.statement(s);
  }

  statement(node) {
    const t = node[0];
    if (t === 'assign') {
      this._assign(node[1], node[2]);
    } else if (t === 'compound') {
      this._compound(node[1], node[2], node[3]);
    } else if (t === 'vardecl') {
      this._varDecl(node[1], node[2]);
    } else if (t === 'block') {
      this.block(node[1]);
    } else if (t === 'if') {
      this._if(node[1], node[2], node[3]);
    } else if (t === 'while') {
      this._while(node[1], node[2]);
    } else if (t === 'dowhile') {
      this._doWhile(node[1], node[2]);
    } else if (t === 'for') {
      this._forLoop(node[1], node[2], node[3], node[4]);
    } else if (t === 'forin') {
      this._forIn(node[1], node[2], node[3], node[4]);
    } else if (t === 'switch') {
      this._switch(node[1], node[2]);
    } else if (t === 'break') {
      if (!this._loopStack.length) throw new SyntaxError('break used outside of a loop or switch');
      this.asm.jump(this._loopStack[this._loopStack.length - 1].breakLabel);
    } else if (t === 'continue') {
      // switch pushes a break-only frame, so `continue` inside a switch has to
      // skip past it to the enclosing loop, matching AS2.
      const loop = [...this._loopStack].reverse().find(f => f.continueLabel);
      if (!loop) throw new SyntaxError('continue used outside of a loop');
      this.asm.jump(loop.continueLabel);
    } else if (t === 'func') {
      this.emit(avm1.defineFunction(node[1], node[2], compileBody(node[3])));
    } else if (t === 'return') {
      if (node[1] !== null) this.expression(node[1]); else this.emit(UNDEF_LIT);
      this.emit(avm1.RETURN);
    } else if (t === 'expr') {
      // `x++;` as a statement discards its value, so generate the no-value
      // form rather than pushing a result and popping it back off.
      if (node[1][0] === 'update') { this._update(node[1], false); return; }
      const n = this.expression(node[1]);
      for (let i = 0; i < n; i++) this.emit(avm1.POP);
    } else {
      throw new SyntaxError(`bad statement ${JSON.stringify(t)}`);
    }
  }

  // `var x = e;` compiles to DefineLocal, not SetVariable. GFx makes that a
  // true function-local when it runs inside a function and falls back to
  // SetVariable for frame actions and event handlers all by itself
  // (GFxAction.cpp case 0x3C), so one encoding is correct in both contexts —
  // no need for the compiler to know which one it is emitting into.
  //
  // Previously this emitted SetVariable unconditionally, which meant every
  // `var` inside a function silently wrote a _root global.
  _varDecl(name, init) {
    this.emit(avm1.push(name));
    if (init === null) {
      this.emit(avm1.DEFINE_LOCAL2);
    } else {
      this.expression(init);
      this.emit(avm1.DEFINE_LOCAL);
    }
  }

  _assign(lval, rhs) {
    if (lval[0] === 'var') {
      this.emit(avm1.push(lval[1])); this.expression(rhs); this.emit(avm1.SET_VARIABLE);
    } else if (lval[0] === 'member') {
      this.expression(lval[1]); this.emit(avm1.push(lval[2]));
      this.expression(rhs); this.emit(avm1.SET_MEMBER);
    } else if (lval[0] === 'index') {
      this.expression(lval[1]); this.expression(lval[2]);
      this.expression(rhs); this.emit(avm1.SET_MEMBER);
    } else {
      throw new SyntaxError(`cannot assign to ${JSON.stringify(lval[0])}`);
    }
  }

  // `target op= rhs`, evaluating `target`'s subexpressions exactly once.
  //
  // The old desugaring to `target = target op rhs` duplicated the target AST,
  // so `a[next()] += 1` called next() twice and `f().x += 1` called f() twice.
  // AVM1 has PushDuplicate and StackSwap but no two-slot duplicate, so the
  // shapes below are what's reachable without a scratch register — and a
  // register is used only where nothing else will do.
  _compound(op, target, rhs) {
    const applyOp = () => this._emitBinaryOp(op);

    if (target[0] === 'var') {
      // Names are literals, so re-emitting the push costs nothing and has no
      // side effect.
      const name = target[1];
      this.emit(avm1.push(name));
      this.emit(avm1.push(name)); this.emit(avm1.GET_VARIABLE);
      this.expression(rhs);
      applyOp();
      this.emit(avm1.SET_VARIABLE);
      return;
    }

    if (target[0] === 'member') {
      // stack: obj -> obj obj -> obj old -> obj new -> obj prop new
      const prop = target[2];
      this.expression(target[1]);
      this.emit(avm1.PUSH_DUPLICATE);
      this.emit(avm1.push(prop));
      this.emit(avm1.GET_MEMBER);
      this.expression(rhs);
      applyOp();
      this.emit(avm1.push(prop));
      this.emit(avm1.STACK_SWAP);
      this.emit(avm1.SET_MEMBER);
      return;
    }

    if (target[0] === 'index') {
      const [, objNode, keyNode] = target;
      if (isPure(keyNode)) {
        // Re-emitting a pure key is free, and keeping it on the stack under
        // the object avoids needing a register at all.
        this.expression(objNode);
        this.emit(avm1.PUSH_DUPLICATE);
        this.expression(keyNode);
        this.emit(avm1.GET_MEMBER);
        this.expression(rhs);
        applyOp();
        this.expression(keyNode);
        this.emit(avm1.STACK_SWAP);
        this.emit(avm1.SET_MEMBER);
        return;
      }
      // Impure key: compute it once into a scratch register. StoreRegister
      // reads the top of stack without popping it (GFxAction.cpp case 0x87),
      // hence the explicit POP.
      const r = this._scratchRegister();
      try {
        this.expression(objNode);
        this.expression(keyNode);
        this.emit(avm1.storeRegister(r));
        this.emit(avm1.POP);
        this.emit(avm1.PUSH_DUPLICATE);
        this.emit(avm1.push(avm1.reg(r)));
        this.emit(avm1.GET_MEMBER);
        this.expression(rhs);
        applyOp();
        this.emit(avm1.push(avm1.reg(r)));
        this.emit(avm1.STACK_SWAP);
        this.emit(avm1.SET_MEMBER);
      } finally {
        this._releaseScratch();
      }
      return;
    }

    throw new SyntaxError(`cannot assign to ${JSON.stringify(target[0])}`);
  }

  // ++ / -- in either fixity. `wantValue` is false in statement position
  // (`i++;`), which lets the impure-target case work without needing to read
  // the target back a second time.
  _update(node, wantValue) {
    const [, op, target, isPrefix] = node;
    const delta = op === '++' ? avm1.INCREMENT : avm1.DECREMENT;

    if (target[0] === 'var') {
      const name = target[1];
      if (wantValue && !isPrefix) {
        this.emit(avm1.push(name)); this.emit(avm1.GET_VARIABLE);   // old value = result
      }
      this.emit(avm1.push(name));
      this.emit(avm1.push(name)); this.emit(avm1.GET_VARIABLE);
      this.emit(delta);
      this.emit(avm1.SET_VARIABLE);
      if (wantValue && isPrefix) {
        this.emit(avm1.push(name)); this.emit(avm1.GET_VARIABLE);   // new value = result
      }
      return wantValue ? 1 : 0;
    }

    // Non-variable targets reuse the compound-assignment expansion, which
    // already evaluates the target once. Producing a value on top of that
    // needs one extra read of the target, which is only sound if reading it
    // again has no side effect.
    if (wantValue && !isPure(target)) {
      throw new SyntaxError(
        `${op} on an expression with side effects can't also produce a value here — `
        + 'assign it to a variable first');
    }
    if (wantValue && !isPrefix) this.expression(target);            // old value
    this._compound(op === '++' ? '+' : '-', target, ['num', 1]);
    if (wantValue && isPrefix) this.expression(target);             // new value
    return wantValue ? 1 : 0;
  }

  _if(cond, then, els) {
    const end = this._label('endif');
    this.expression(cond);
    if (els) {
      const elsel = this._label('else');
      this.asm.jumpUnless(elsel);
      this.block(then);
      this.asm.jump(end);
      this.asm.label(elsel);
      this.block(els);
    } else {
      this.asm.jumpUnless(end);
      this.block(then);
    }
    this.asm.label(end);
  }

  _while(cond, body) {
    const top = this._label('while');
    const end = this._label('endwhile');
    this._loopStack.push({ continueLabel: top, breakLabel: end });
    this.asm.label(top);
    this.expression(cond);
    this.asm.jumpUnless(end);
    this.block(body);
    this.asm.jump(top);
    this.asm.label(end);
    this._loopStack.pop();
  }

  // do { body } while (cond) — body runs before the first test, and `continue`
  // goes to the test rather than back to the top.
  _doWhile(cond, body) {
    const top = this._label('do');
    const cont = this._label('docont');
    const end = this._label('enddo');
    this._loopStack.push({ continueLabel: cont, breakLabel: end });
    this.asm.label(top);
    this.block(body);
    this.asm.label(cont);
    this.expression(cond);
    this.asm.jumpIf(top);
    this.asm.label(end);
    this._loopStack.pop();
  }

  // for (name in obj) — Enumerate2 pops the object, pushes a null sentinel,
  // then pushes every member name on top of it (GFxAction.cpp case 0x55), so
  // the loop consumes names until it uncovers the null.
  //
  // A `break` out of this leaves the unconsumed names on the stack. That's
  // harmless — the AVM1 stack is per action buffer and discarded at its end —
  // but it is why this isn't a tidy unwind.
  _forIn(name, isVar, objNode, body) {
    const top = this._label('forin');
    const end = this._label('endforin');
    this.expression(objNode);
    this.emit(avm1.ENUMERATE2);
    this._loopStack.push({ continueLabel: top, breakLabel: end });
    this.asm.label(top);
    this.emit(avm1.PUSH_DUPLICATE);
    this.emit(NULL_LIT);
    this.emit(avm1.EQUALS2);
    this.asm.jumpIf(end);
    // bind the current name: stack has [.., nameStr], and SetVariable wants
    // [.., varName, value] — so push the target name and swap them into order
    this.emit(avm1.push(name));
    this.emit(avm1.STACK_SWAP);
    this.emit(isVar ? avm1.DEFINE_LOCAL : avm1.SET_VARIABLE);
    this.block(body);
    this.asm.jump(top);
    this.asm.label(end);
    this._loopStack.pop();
    this.emit(avm1.POP);   // discard the null sentinel
  }

  // switch — a chain of strict-equality tests against a duplicated
  // discriminant, then a per-case trampoline that pops the discriminant before
  // entering the body. Popping up front (rather than leaving it live across
  // the case bodies) is what lets `break` and `continue` inside a case behave
  // like they do anywhere else.
  _switch(disc, cases) {
    const end = this._label('endswitch');
    const bodyLabels = cases.map((_, i) => this._label(`case${i}body`));
    const testLabels = cases.map((_, i) => this._label(`case${i}match`));
    const defaultIdx = cases.findIndex(c => c.test === null);

    this.expression(disc);
    cases.forEach((c, i) => {
      if (c.test === null) return;               // default is not part of the chain
      this.emit(avm1.PUSH_DUPLICATE);
      this.expression(c.test);
      this.emit(avm1.STRICT_EQUALS);
      this.asm.jumpIf(testLabels[i]);
    });
    this.emit(avm1.POP);                          // no case matched
    this.asm.jump(defaultIdx >= 0 ? bodyLabels[defaultIdx] : end);

    cases.forEach((c, i) => {
      if (c.test === null) return;
      this.asm.label(testLabels[i]);
      this.emit(avm1.POP);                        // drop the discriminant
      this.asm.jump(bodyLabels[i]);
    });

    // Bodies run in source order so that fallthrough works.
    this._loopStack.push({ continueLabel: null, breakLabel: end });
    cases.forEach((c, i) => {
      this.asm.label(bodyLabels[i]);
      this.block(c.body);
    });
    this._loopStack.pop();
    this.asm.label(end);
  }

  // for(init; cond; update) { body } — continue must run `update` before
  // re-checking `cond` (unlike a plain while), so it gets its own label
  // sitting between body and update rather than reusing while's single
  // "top" label.
  _forLoop(init, cond, update, body) {
    if (init) this.statement(init);
    const top = this._label('for');
    const cont = this._label('forcont');
    const end = this._label('endfor');
    this._loopStack.push({ continueLabel: cont, breakLabel: end });
    this.asm.label(top);
    this.expression(cond);
    this.asm.jumpUnless(end);
    this.block(body);
    this.asm.label(cont);
    if (update) this.statement(update);
    this.asm.jump(top);
    this.asm.label(end);
    this._loopStack.pop();
  }

  // Emit code leaving the value on the stack; returns values pushed (0 or 1).
  expression(node) {
    const t = node[0];
    if (t === 'num') {
      const val = node[1];
      this.emit(avm1.push(val === Math.trunc(val) ? Math.trunc(val) : val));
      return 1;
    }
    if (t === 'str' || t === 'bool') { this.emit(avm1.push(node[1])); return 1; }
    if (t === 'null') { this.emit(NULL_LIT); return 1; }
    if (t === 'undef') { this.emit(UNDEF_LIT); return 1; }
    if (t === 'var') { this.emit(avm1.var(node[1])); return 1; }
    if (t === 'member') {
      this.expression(node[1]);
      this.emit(concatArrays(avm1.push(node[2]), avm1.GET_MEMBER));
      return 1;
    }
    if (t === 'index') {
      this.expression(node[1]); this.expression(node[2]); this.emit(avm1.GET_MEMBER);
      return 1;
    }
    if (t === 'this') { this.emit(avm1.var('this')); return 1; }
    if (t === 'unop') {
      const op = node[1];
      if (op === '-') {
        this.emit(avm1.push(0)); this.expression(node[2]); this.emit(avm1.SUBTRACT);
      } else if (op === '!') {
        this.expression(node[2]); this.emit(avm1.NOT);
      } else if (op === '+') {
        this.expression(node[2]); this.emit(avm1.TO_NUMBER);
      } else if (op === '~') {
        // AVM1 has no bitwise-NOT opcode; ~x is x ^ -1.
        this.expression(node[2]); this.emit(avm1.push(-1)); this.emit(avm1.BIT_XOR);
      } else if (op === 'typeof') {
        this.expression(node[2]); this.emit(avm1.TYPE_OF);
      } else if (op === 'delete') {
        return this._delete(node[2]);
      } else {
        throw new SyntaxError(`bad unary operator ${JSON.stringify(op)}`);
      }
      return 1;
    }
    if (t === 'binop') return this._binop(node[1], node[2], node[3]);
    if (t === 'logical') return this._logical(node[1], node[2], node[3]);
    if (t === 'ternary') return this._ternary(node[1], node[2], node[3]);
    if (t === 'update') return this._update(node, true);
    if (t === 'call') return this._call(node[1], node[2]);
    if (t === 'new') return this._new(node[1], node[2]);
    if (t === 'funcexpr') {
      // An empty name leaves the function object on the stack instead of
      // binding it — which is exactly what an expression position wants.
      this.emit(avm1.defineFunction(node[1], node[2], compileBody(node[3])));
      return 1;
    }
    if (t === 'array') {
      for (const el of node[1]) this.expression(el); // push elements in source order
      this.emit(avm1.push(node[1].length));
      this.emit(avm1.INIT_ARRAY);
      return 1;
    }
    if (t === 'object') {
      // InitObject pops {value, name} pairs after the count, so each property
      // goes on as name-then-value (GFxAction.cpp case 0x43).
      for (const p of node[1]) { this.emit(avm1.push(p.key)); this.expression(p.value); }
      this.emit(avm1.push(node[1].length));
      this.emit(avm1.INIT_OBJECT);
      return 1;
    }
    throw new SyntaxError(`bad expression ${JSON.stringify(t)}`);
  }

  _emitBinaryOp(op) {
    if (op in BINOP) {
      this.emit(BINOP[op]);
    } else if (op === '!=') {
      this.emit(concatArrays(avm1.EQUALS2, avm1.NOT));
    } else if (op === '!==') {
      this.emit(concatArrays(avm1.STRICT_EQUALS, avm1.NOT));
    } else if (op === '<=') {
      this.emit(concatArrays(avm1.GREATER, avm1.NOT));
    } else if (op === '>=') {
      this.emit(concatArrays(avm1.LESS2, avm1.NOT));
    } else {
      throw new SyntaxError(`bad operator ${JSON.stringify(op)}`);
    }
  }

  _binop(op, a, b) {
    this.expression(a); this.expression(b);
    this._emitBinaryOp(op);
    return 1;
  }

  // && and || short-circuit and yield the operand value, as in AS2 — not the
  // boolean-coercing And/Or opcodes this used to emit, which always evaluated
  // both sides. `a && b()` now really does skip the call when `a` is falsy.
  _logical(op, a, b) {
    const end = this._label(op === '&&' ? 'endand' : 'endor');
    this.expression(a);
    this.emit(avm1.PUSH_DUPLICATE);
    if (op === '&&') this.emit(avm1.NOT);   // bail out when the left side is falsy
    this.asm.jumpIf(end);
    this.emit(avm1.POP);                    // drop the left value, take the right
    this.expression(b);
    this.asm.label(end);
    return 1;
  }

  _ternary(cond, thenE, elseE) {
    const elseL = this._label('telse');
    const end = this._label('tend');
    this.expression(cond);
    this.asm.jumpUnless(elseL);
    this.expression(thenE);
    this.asm.jump(end);
    this.asm.label(elseL);
    this.expression(elseE);
    this.asm.label(end);
    return 1;
  }

  // `delete obj.p` needs the object and name (Delete); `delete x` takes just a
  // name and resolves it through scope (Delete2).
  _delete(target) {
    if (target[0] === 'member') {
      this.expression(target[1]); this.emit(avm1.push(target[2])); this.emit(avm1.DELETE);
    } else if (target[0] === 'index') {
      this.expression(target[1]); this.expression(target[2]); this.emit(avm1.DELETE);
    } else if (target[0] === 'var') {
      this.emit(avm1.push(target[1])); this.emit(avm1.DELETE2);
    } else {
      throw new SyntaxError('delete needs a variable or a property reference');
    }
    return 1;
  }

  // `new C(a, b)` — NewObject pops the class *name* then the arg count, and
  // resolves the name through scope (GFxAction.cpp case 0x40). A dotted
  // constructor (`new a.B()`) has no name to resolve, so it uses NewMethod,
  // which takes the object and the member name instead.
  _new(callee, args) {
    for (let i = args.length - 1; i >= 0; i--) this.expression(args[i]);
    this.emit(avm1.push(args.length));
    if (callee[0] === 'var') {
      this.emit(avm1.push(callee[1]));
      this.emit(avm1.NEW_OBJECT);
    } else if (callee[0] === 'member') {
      this.expression(callee[1]);
      this.emit(avm1.push(callee[2]));
      this.emit(avm1.NEW_METHOD);
    } else if (callee[0] === 'index') {
      this.expression(callee[1]);
      this.expression(callee[2]);
      this.emit(avm1.NEW_METHOD);
    } else {
      throw new SyntaxError('new needs a constructor name or a member reference');
    }
    return 1;
  }

  _call(callee, args) {
    // fscommand("evt", value) -> GetURL2 form (pushes nothing)
    if (callee[0] === 'var' && callee[1] === 'fscommand' && args.length && args[0][0] === 'str') {
      this.emit(avm1.push('FSCommand:' + args[0][1]));
      if (args.length > 1) this.expression(args[1]); else this.emit(avm1.push(''));
      this.emit(avm1.getUrl2(0));
      return 0;
    }

    // Globals that are single opcodes rather than real functions. Only taken
    // when the arity matches, so e.g. a user-defined two-argument `random` is
    // still compiled as an ordinary call.
    if (callee[0] === 'var') {
      const name = callee[1];
      if (args.length === 0 && Object.prototype.hasOwnProperty.call(TIMELINE_BUILTINS, name)) {
        this.emit(TIMELINE_BUILTINS[name]());
        return 0;   // timeline verbs leave nothing on the stack
      }
      if (args.length === 0 && Object.prototype.hasOwnProperty.call(NULLARY_BUILTINS, name)) {
        this.emit(NULLARY_BUILTINS[name]);
        return 1;
      }
      if (args.length === 1 && Object.prototype.hasOwnProperty.call(UNARY_BUILTINS, name)) {
        this.expression(args[0]);
        this.emit(UNARY_BUILTINS[name]);
        return name === 'trace' ? 0 : 1;   // trace consumes its argument
      }
      // gotoAndStop/gotoAndPlay on the current timeline. GotoFrame2 takes the
      // target off the stack, so a label string and a frame number both work
      // through the same encoding.
      if (args.length === 1 && (name === 'gotoAndStop' || name === 'gotoAndPlay')) {
        this.expression(args[0]);
        this.emit(avm1.gotoFrame2(name === 'gotoAndPlay'));
        return 0;
      }
    }
    if (callee[0] === 'member') { // method call: obj.m(args)
      for (let i = args.length - 1; i >= 0; i--) this.expression(args[i]);
      this.emit(avm1.push(args.length));
      this.expression(callee[1]);
      this.emit(avm1.push(callee[2]));
      this.emit(avm1.CALL_METHOD);
      return 1;
    }
    for (let i = args.length - 1; i >= 0; i--) this.expression(args[i]); // function call by name
    this.emit(avm1.push(args.length));
    if (callee[0] === 'var') {
      this.emit(avm1.push(callee[1]));
    } else {
      this.expression(callee);
    }
    this.emit(avm1.CALL_FUNCTION);
    return 1;
  }
}

function compileBody(stmts) {
  const g = new Gen();
  g.block(stmts);
  return g.asm.assemble();
}

// --- public API --------------------------------------------------------------

function compileSource(text) {
  return compileBody(new Parser(tokenize(text)).program());
}

function compileExpression(text) {
  const p = new Parser(tokenize(text));
  const node = p.expression();
  if (!p._at('eof')) throw new SyntaxError('trailing tokens after expression');
  const g = new Gen();
  g.expression(node);
  return g.asm.assemble();
}

const api = { Assembler, tokenize, Parser, compileSource, compileExpression };

  return api;
})();
