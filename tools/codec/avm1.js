const Avm1 = (function() {
// Port of gfxforge/avm1.py — AVM1 (ActionScript 1/2) bytecode assembler.
// GFx 2.x runs AVM1: define functions the host can call, bind variables that
// text fields display, and fscommand back out to the host.
//
// The opcode set below is the one GFx 2.1.57 actually implements — taken from
// the action dispatch switch in the SDK's GFxPlayer/GFxAction.cpp, not from
// the general SWF spec. Two consequences worth knowing:
//   * 0x8F (try) hits the "Unsupported opcode" branch in that player, so this
//     assembler deliberately has no try/catch encoder. 0x2A (throw) exists but
//     is useless without it.
//   * ActionPush's double type has a non-obvious byte order — see doublele().

const { concatBytes, u8, u16le, i32le, cstr } = Swf._internal;

// -- opcodes with no payload (single-byte actions, < 0x80) -------------------
// Names follow the SDK's own comments in GFxAction.cpp's dispatch switch.

const NEXT_FRAME = u8(0x04);
const PREV_FRAME = u8(0x05);
const PLAY = u8(0x06);
const STOP = u8(0x07);
const TOGGLE_QUALITY = u8(0x08);
const STOP_SOUNDS = u8(0x09);
const ADD = u8(0x0a);           // legacy numeric add; ADD2 is the typed one
const SUBTRACT = u8(0x0b);
const MULTIPLY = u8(0x0c);
const DIVIDE = u8(0x0d);
const EQUALS = u8(0x0e);        // legacy; EQUALS2 is the typed one
const LESS = u8(0x0f);          // legacy; LESS2 is the typed one
const AND = u8(0x10);
const OR = u8(0x11);
const NOT = u8(0x12);
const STRING_EQUALS = u8(0x13);
const STRING_LENGTH = u8(0x14);
const STRING_EXTRACT = u8(0x15);
const POP = u8(0x17);
const TO_INTEGER = u8(0x18);
const GET_VARIABLE = u8(0x1c);
const SET_VARIABLE = u8(0x1d);
const SET_TARGET2 = u8(0x20);
const STRING_ADD = u8(0x21);
const GET_PROPERTY = u8(0x22);
const SET_PROPERTY = u8(0x23);
const CLONE_SPRITE = u8(0x24);
const REMOVE_SPRITE = u8(0x25);
const TRACE = u8(0x26);
const START_DRAG = u8(0x27);
const END_DRAG = u8(0x28);
const STRING_LESS = u8(0x29);
const THROW = u8(0x2a);         // present, but 0x8F (try) is not — see header
const CAST_OP = u8(0x2b);
const IMPLEMENTS_OP = u8(0x2c);
const RANDOM = u8(0x30);
const MB_STRING_LENGTH = u8(0x31);
const CHAR_TO_ASCII = u8(0x32);
const ASCII_TO_CHAR = u8(0x33);
const GET_TIMER = u8(0x34);
const MB_STRING_EXTRACT = u8(0x35);
const MB_CHAR_TO_ASCII = u8(0x36);
const MB_ASCII_TO_CHAR = u8(0x37);
const DELETE = u8(0x3a);
const DELETE2 = u8(0x3b);
const DEFINE_LOCAL = u8(0x3c);   // pop value, pop name -> declare in local frame
const CALL_FUNCTION = u8(0x3d);
const RETURN = u8(0x3e);
const MODULO = u8(0x3f);
const NEW_OBJECT = u8(0x40);
const DEFINE_LOCAL2 = u8(0x41);  // pop name -> declare undefined local
const INIT_ARRAY = u8(0x42);
const INIT_OBJECT = u8(0x43);
const TYPE_OF = u8(0x44);
const TARGET_PATH = u8(0x45);
const ENUMERATE = u8(0x46);
const ADD2 = u8(0x47);
const LESS2 = u8(0x48);
const EQUALS2 = u8(0x49);
const TO_NUMBER = u8(0x4a);
const TO_STRING = u8(0x4b);
const PUSH_DUPLICATE = u8(0x4c);
const STACK_SWAP = u8(0x4d);
const GET_MEMBER = u8(0x4e);
const SET_MEMBER = u8(0x4f);
const INCREMENT = u8(0x50);
const DECREMENT = u8(0x51);
const CALL_METHOD = u8(0x52);
const NEW_METHOD = u8(0x53);
const INSTANCE_OF = u8(0x54);
const ENUMERATE2 = u8(0x55);
const BIT_AND = u8(0x60);
const BIT_OR = u8(0x61);
const BIT_XOR = u8(0x62);
const BIT_LSHIFT = u8(0x63);
const BIT_RSHIFT = u8(0x64);
const BIT_URSHIFT = u8(0x65);
const STRICT_EQUALS = u8(0x66);
const GREATER = u8(0x67);
const STRING_GREATER = u8(0x68);
const EXTENDS = u8(0x69);
const END = u8(0x00);

// GetProperty/SetProperty take a numeric property index rather than a name.
// Order is fixed by the format; GFx resolves them in GFxAction.cpp's
// GASValue GetStandardMember path.
const PROPERTY = {
  _x: 0, _y: 1, _xscale: 2, _yscale: 3, _currentframe: 4, _totalframes: 5,
  _alpha: 6, _visible: 7, _width: 8, _height: 9, _rotation: 10, _target: 11,
  _framesloaded: 12, _name: 13, _droptarget: 14, _url: 15, _highquality: 16,
  _focusrect: 17, _soundbuftime: 18, _quality: 19, _xmouse: 20, _ymouse: 21,
};

// ActionPush's double type. NOT a plain little-endian float64: GFx reads the
// two 32-bit halves swapped —
//     memcpy(&u.Sub.Hi, &Buffer[3+i],     4);
//     memcpy(&u.Sub.Lo, &Buffer[3+i + 4], 4);
// (GFxAction.cpp, case 0x96, type 6; its own comment calls the layout
// "wacky format: 45670123"). So the high word goes on the wire first.
//
// Confirmed empirically against 15,512 type-6 pushes in the shipped Mercs 2
// movies: read word-swapped they decode to authoring values (0.25, 2.5, 12.5,
// 59.5); read as a plain LE double the same bytes decode to denormal garbage
// around 5.3e-315. 0.25 encodes to `00 00 d0 3f 00 00 00 00`, byte-identical
// to what the game's own files contain.
function doublele(v) {
  const le = new Uint8Array(8);
  new DataView(le.buffer).setFloat64(0, v, true);
  const out = new Uint8Array(8);
  out.set(le.subarray(4, 8), 0);  // high word first
  out.set(le.subarray(0, 4), 4);  // then low word
  return out;
}

function f32le(v) {
  const b = new Uint8Array(4);
  new DataView(b.buffer).setFloat32(0, v, true);
  return b;
}

// Wrappers so push() can emit the value types that aren't representable as
// plain JS values: register reads (type 4) and constant-pool refs (8/16).
function reg(n) { return { __push: 'register', n }; }
function constant(index) { return { __push: 'constant', index }; }
const NULL = { __push: 'null' };
const UNDEFINED = { __push: 'undefined' };
const FLOAT = (v) => ({ __push: 'float', v });

// ActionPush. Accepts string (type 0), boolean (5), whole-number (7, i32),
// non-whole number (6, f64), plus the wrapper types above: null (2),
// undefined (3), register (4), constant8/16 (8/9), float32 (1).
//
// JS has no separate int/float type, so — matching how gfxforge's own callers
// already decide (compiler.py normalises whole literals to Python `int` before
// pushing) — integral JS numbers encode as SWF INTEGER and non-integral ones
// as SWF DOUBLE.
function push(...values) {
  let body = new Uint8Array(0);
  for (const v of values) {
    if (typeof v === 'string') {
      body = concatBytes(body, u8(0x00), cstr(v));
    } else if (typeof v === 'boolean') {
      body = concatBytes(body, u8(0x05), u8(v ? 1 : 0));
    } else if (typeof v === 'number') {
      if (Number.isInteger(v)) {
        body = concatBytes(body, u8(0x07), i32le(v));
      } else {
        body = concatBytes(body, u8(0x06), doublele(v));
      }
    } else if (v && typeof v === 'object' && v.__push) {
      switch (v.__push) {
        case 'null': body = concatBytes(body, u8(0x02)); break;
        case 'undefined': body = concatBytes(body, u8(0x03)); break;
        case 'float': body = concatBytes(body, u8(0x01), f32le(v.v)); break;
        case 'register': body = concatBytes(body, u8(0x04), u8(v.n & 0xff)); break;
        case 'constant':
          body = v.index < 256
            ? concatBytes(body, u8(0x08), u8(v.index))
            : concatBytes(body, u8(0x09), u16le(v.index));
          break;
        default: throw new TypeError(`push: unsupported wrapper ${v.__push}`);
      }
    } else {
      throw new TypeError(`push: unsupported value ${JSON.stringify(v)}`);
    }
  }
  return concatBytes(u8(0x96), u16le(body.length), body);
}

// -- multi-byte actions (>= 0x80): [opcode][u16 length][body] ----------------

function action(opcode, body = new Uint8Array(0)) {
  return concatBytes(u8(opcode), u16le(body.length), body);
}

function gotoFrame(frame) {          // 0x81, zero-based frame index
  return action(0x81, u16le(frame));
}

function getUrl(url, target) {       // 0x83
  return action(0x83, concatBytes(cstr(url), cstr(target)));
}

// 0x87. Inside a DefineFunction2 the index selects one of that function's
// local registers; at top level only 0-3 (the global registers) are valid —
// GFx logs "register out of bounds" otherwise.
function storeRegister(index) {
  return action(0x87, u8(index & 0xff));
}

// 0x88 ConstantPool: u16 count then that many NUL-terminated strings. Entries
// are then referenced by push(constant(i)), which costs 2-3 bytes instead of
// re-emitting the whole string each time.
function constantPool(strings) {
  let body = u16le(strings.length);
  for (const s of strings) body = concatBytes(body, cstr(s));
  return action(0x88, body);
}

function waitForFrame(frame, skipCount) {   // 0x8a
  return action(0x8a, concatBytes(u16le(frame), u8(skipCount)));
}

function setTarget(name) {           // 0x8b
  return action(0x8b, cstr(name));
}

// 0x8c. Note GFx does NOT parse numbers out of this string — "4" is treated as
// a label named "4", not frame 4 (see the comment on case 0x8C in
// GFxAction.cpp). Use gotoFrame() for numeric targets.
function gotoLabel(label) {
  return action(0x8c, cstr(label));
}

function waitForFrame2(skipCount) {  // 0x8d
  return action(0x8d, u8(skipCount));
}

// 0x9f GotoFrame2: pops the frame (number or "path:label" string). Bit 0 of
// the flag byte selects play-on-arrival vs stop; bit 1 adds a u16 scene bias.
function gotoFrame2(play = false, sceneBias = null) {
  let flags = play ? 1 : 0;
  if (sceneBias !== null) flags |= 2;
  const body = sceneBias !== null
    ? concatBytes(u8(flags), u16le(sceneBias))
    : u8(flags);
  return action(0x9f, body);
}

function callFrame() {               // 0x9e
  return action(0x9e);
}

function withBlock(bodyBytes) {      // 0x94: [u16 code size] then the block
  return concatBytes(action(0x94, u16le(bodyBytes.length)), bodyBytes);
}

function getUrl2(flags = 0) {
  return concatBytes(u8(0x9a), u16le(1), u8(flags));
}

// ActionDefineFunction. A non-empty name defines the fn in the current scope
// (e.g. _root, so the host can call it by name); an empty name pushes the fn
// object on the stack. `body` bytes follow the header and are skipped at
// definition time (CodeSize).
function defineFunction(name, params, body) {
  let hdr = concatBytes(cstr(name), u16le(params.length));
  for (const p of params) hdr = concatBytes(hdr, cstr(p));
  hdr = concatBytes(hdr, u16le(body.length));
  return concatBytes(u8(0x9b), u16le(hdr.length), hdr, body);
}

// Flags controlling which implicit values GFx preloads into registers (and
// which it suppresses from the local frame) for a DefineFunction2 body.
// Values from GFxAction.cpp's Function2 flag handling.
const FN2 = {
  PRELOAD_THIS: 0x0001, SUPPRESS_THIS: 0x0002,
  PRELOAD_ARGUMENTS: 0x0004, SUPPRESS_ARGUMENTS: 0x0008,
  PRELOAD_SUPER: 0x0010, SUPPRESS_SUPER: 0x0020,
  PRELOAD_ROOT: 0x0040, PRELOAD_PARENT: 0x0080, PRELOAD_GLOBAL: 0x0100,
};

// ActionDefineFunction2 (0x8e). Same shape as DefineFunction plus a register
// budget and per-parameter register assignments, so a function body can read
// its arguments straight out of registers instead of by name.
//
// Header layout, per GFxAction.cpp case 0x8E:
//   name (cstring), nargs (u16), registerCount (u8), flags (u16),
//   then per arg: register (u8) + name (cstring), then codeSize (u16).
// A register of 0 means "not in a register, bind by name" — otherwise the
// argument is preloaded into that register and NOT added to the local frame.
//
// `params` accepts plain strings (register 0) or {name, register} objects.
function defineFunction2(name, params, body, { registerCount = null, flags = 0 } = {}) {
  const norm = params.map(p => (typeof p === 'string' ? { name: p, register: 0 } : p));
  const maxReg = norm.reduce((m, p) => Math.max(m, p.register || 0), 0);
  const regs = registerCount === null ? maxReg + 1 : registerCount;
  let hdr = concatBytes(cstr(name), u16le(norm.length), u8(regs), u16le(flags));
  for (const p of norm) hdr = concatBytes(hdr, u8(p.register || 0), cstr(p.name));
  hdr = concatBytes(hdr, u16le(body.length));
  return concatBytes(u8(0x8e), u16le(hdr.length), hdr, body);
}

// --- convenience expression/statement fragments -----------------------------

function v(name) {
  // Value of variable `name` (leaves it on the stack).
  return concatBytes(push(name), GET_VARIABLE);
}

function literal(value) {
  return push(value);
}

function root() {
  return concatBytes(push('_root'), GET_VARIABLE);
}

function getMember(obj, name) {
  return concatBytes(obj, push(name), GET_MEMBER);
}

function setMember(obj, name, value) {
  return concatBytes(obj, push(name), value, SET_MEMBER);
}

function setRoot(member, value) {
  return setMember(root(), member, value);
}

function fscommand(command, value) {
  return concatBytes(push('FSCommand:' + command), value, getUrl2(0));
}

// _root.<clip>.gotoAndStop(<frame>) and friends, as a ready-made fragment.
// `frame` may be a label string or a 1-based frame number, matching AS2.
function clipGoto(clipName, frame, play = false) {
  return concatBytes(
    push(frame),
    push(1),
    getMember(root(), clipName),
    push(play ? 'gotoAndPlay' : 'gotoAndStop'),
    CALL_METHOD,
    POP
  );
}

// trace(<expr>) — writes to the GFx log. Handy for debugging a movie in-engine
// with a log-enabled build; a no-op in the retail player.
function traceValue(valueBytes) {
  return concatBytes(valueBytes, TRACE);
}

class Script {
  constructor() {
    this._b = new Uint8Array(0);
  }

  set(name, value) {
    this._b = concatBytes(this._b, setRoot(name, push(value)));
    return this;
  }

  function(name, params, body) {
    this._b = concatBytes(this._b, defineFunction(name, params, body));
    return this;
  }

  raw(actionBytes) {
    this._b = concatBytes(this._b, actionBytes);
    return this;
  }

  body() {
    return this._b;
  }

  toAction() {
    return concatBytes(this._b, END);
  }
}

const api = {
  // original exports — unchanged names and values
  GET_VARIABLE, SET_VARIABLE, GET_MEMBER, SET_MEMBER, ADD2, SUBTRACT, MULTIPLY,
  DIVIDE, MODULO, LESS2, EQUALS2, GREATER, AND, OR, NOT, POP, RETURN,
  CALL_FUNCTION, CALL_METHOD, INIT_ARRAY, END,
  push, getUrl2, defineFunction, var: v, literal, root, getMember, setMember,
  setRoot, fscommand, Script,

  // timeline / playback
  NEXT_FRAME, PREV_FRAME, PLAY, STOP, TOGGLE_QUALITY, STOP_SOUNDS,
  gotoFrame, gotoLabel, gotoFrame2, callFrame, waitForFrame, waitForFrame2,

  // arithmetic, comparison, logic
  ADD, EQUALS, LESS, STRICT_EQUALS, TO_INTEGER, TO_NUMBER, TO_STRING,
  INCREMENT, DECREMENT, RANDOM, GET_TIMER,
  BIT_AND, BIT_OR, BIT_XOR, BIT_LSHIFT, BIT_RSHIFT, BIT_URSHIFT,

  // strings
  STRING_EQUALS, STRING_LENGTH, STRING_EXTRACT, STRING_ADD, STRING_LESS,
  STRING_GREATER, CHAR_TO_ASCII, ASCII_TO_CHAR,
  MB_STRING_LENGTH, MB_STRING_EXTRACT, MB_CHAR_TO_ASCII, MB_ASCII_TO_CHAR,

  // objects, scope, functions
  DEFINE_LOCAL, DEFINE_LOCAL2, NEW_OBJECT, NEW_METHOD, INIT_OBJECT, TYPE_OF,
  INSTANCE_OF, ENUMERATE, ENUMERATE2, DELETE, DELETE2, EXTENDS, CAST_OP,
  IMPLEMENTS_OP, THROW, TARGET_PATH, PUSH_DUPLICATE, STACK_SWAP,
  defineFunction2, FN2, storeRegister, constantPool, withBlock,
  setTarget, SET_TARGET2,

  // display objects
  GET_PROPERTY, SET_PROPERTY, PROPERTY, CLONE_SPRITE, REMOVE_SPRITE,
  START_DRAG, END_DRAG, TRACE,

  // push value wrappers + raw encoders
  reg, constant, NULL, UNDEFINED, FLOAT, action, getUrl,
  clipGoto, traceValue,
};

  return api;
})();
