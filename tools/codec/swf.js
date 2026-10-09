const Swf = (function() {
// Port of gfxforge/swf.py — GFX/SWF tag encoders + container.
// Coordinates are accepted in PIXELS and converted to twips internally.

const { BitWriter, sbitsNeeded, encodeRect, px, IDENTITY_MATRIX } = Bitio;

// -- byte helpers -------------------------------------------------------

function concatBytes(...parts) {
  let len = 0;
  for (const p of parts) len += p.length;
  const out = new Uint8Array(len);
  let o = 0;
  for (const p of parts) {
    out.set(p, o);
    o += p.length;
  }
  return out;
}

function u8(...bytes) {
  return Uint8Array.from(bytes);
}

function u16le(v) {
  const b = new Uint8Array(2);
  new DataView(b.buffer).setUint16(0, v & 0xffff, true);
  return b;
}

function i32le(v) {
  const b = new Uint8Array(4);
  new DataView(b.buffer).setInt32(0, v | 0, true);
  return b;
}

function u32le(v) {
  const b = new Uint8Array(4);
  new DataView(b.buffer).setUint32(0, v >>> 0, true);
  return b;
}

// latin1 encode: SWF/GFX strings are single-byte (codepoints 0-255).
function latin1(str) {
  const out = new Uint8Array(str.length);
  for (let i = 0; i < str.length; i++) {
    const c = str.charCodeAt(i);
    if (c > 255) throw new Error(`latin1: character out of range: ${JSON.stringify(str[i])}`);
    out[i] = c;
  }
  return out;
}

function cstr(str) {
  return concatBytes(latin1(str), u8(0));
}

function tag(code, body) {
  // Frame a tag: short form if it fits in 6 bits, else the long form.
  if (body.length < 0x3f) {
    return concatBytes(u16le((code << 6) | body.length), body);
  }
  return concatBytes(u16le((code << 6) | 0x3f), u32le(body.length), body);
}

function rgba(c) {
  return u8(c[0], c[1], c[2], c.length > 3 ? c[3] : 255);
}

// --- movie preamble ----------------------------------------------------

function exporterInfo(name, version = 0x0207) {
  const nm = latin1(name);
  const b = concatBytes(u16le(version), u32le(0), u16le(0x000d), u8(0));
  return tag(1000, concatBytes(b, u8(nm.length), nm));
}

function fileAttributes() {
  return tag(69, u8(0, 0, 0, 0));
}

function setBackgroundColor(rgb) {
  return tag(9, u8(rgb[0], rgb[1], rgb[2]));
}

function importFont(url, fontId, exportName) {
  const b = concatBytes(
    cstr(url),
    u8(1, 0),
    u16le(1),
    u16le(fontId),
    cstr(exportName)
  );
  return tag(71, b);
}

// --- display objects -----------------------------------------------------

function defineShape3(shapeId, x1, y1, x2, y2, color) {
  const X1 = px(x1), Y1 = px(y1), X2 = px(x2), Y2 = px(y2);
  const w = X2 - X1, h = Y2 - Y1;
  let body = concatBytes(
    u16le(shapeId),
    encodeRect(X1, X2, Y1, Y2),
    u8(1), u8(0x00), rgba(color),
    u8(0)
  );
  const b = new BitWriter();
  b.ubits(1, 4).ubits(0, 4); // NumFillBits=1 NumLineBits=0
  b.ubits(0, 1).ubits(0, 1).ubits(0, 1).ubits(1, 1).ubits(0, 1).ubits(1, 1); // style change: fill1 + moveto
  const mb = sbitsNeeded(X1, Y1);
  b.ubits(mb, 5).sbits(X1, mb).sbits(Y1, mb).ubits(1, 1); // move to (X1,Y1); FillStyle1=1
  for (const [dx, dy] of [[w, 0], [0, h], [-w, 0], [0, -h]]) {
    const nb = sbitsNeeded(dx, dy);
    b.ubits(1, 1).ubits(1, 1).ubits(nb - 2, 4).ubits(1, 1).sbits(dx, nb).sbits(dy, nb);
  }
  b.ubits(0, 6); // end shape
  body = concatBytes(body, b.flush());
  return tag(32, body);
}

// -- extended shape encoder: rounded corners, strokes, gradients -------------
//
// Kept entirely separate from defineShape3 above (which stays byte-for-byte
// unchanged) since there's no independent reference implementation to check
// this against — see the project README's confidence notes. Structural
// validity is checked by verify.js; the geometry/matrix math below is
// reasoned from the SWF file format spec directly.

// A quadratic-bezier curved edge record. `from` is the pen's current
// position (needed to compute the control-point delta); the anchor delta is
// relative to the control point, not `from` — that's an SWF-spec quirk, not
// a typo.
function emitCurvedEdge(bw, fromX, fromY, controlX, controlY, anchorX, anchorY) {
  const cdx = controlX - fromX, cdy = controlY - fromY;
  const adx = anchorX - controlX, ady = anchorY - controlY;
  const nb = Math.max(2, sbitsNeeded(cdx, cdy, adx, ady));
  bw.ubits(1, 1).ubits(0, 1).ubits(nb - 2, 4).sbits(cdx, nb).sbits(cdy, nb).sbits(adx, nb).sbits(ady, nb);
}

function emitStraightEdge(bw, dx, dy) {
  const nb = Math.max(2, sbitsNeeded(dx, dy));
  bw.ubits(1, 1).ubits(1, 1).ubits(nb - 2, 4).ubits(1, 1).sbits(dx, nb).sbits(dy, nb);
}

// GRADIENT record: an 8-bit (SpreadMode|InterpolationMode|NumGradients)
// field, byte-aligned since 2+2+4 bits sums to exactly one byte, followed by
// NumGradients (Ratio:u8, Color:RGBA) pairs.
function encodeGradientRecord(stops) {
  const w = new BitWriter();
  w.ubits(0, 2).ubits(0, 2).ubits(stops.length, 4); // spread=pad, interp=normal RGB
  let body = w.flush();
  for (const s of stops) {
    body = concatBytes(body, u8(Math.round(s.ratio)), rgba(s.color));
  }
  return body;
}

// Matrix mapping gradient space (a ratio-0..255 ramp spanning twips -16384
// to +16384 around its own origin) onto the shape's actual bounding box, so
// ratio=0 lands at one edge and ratio=255 at the opposite edge:
//   horizontal: left (ratio 0) -> right (ratio 255)
//   vertical:   top (ratio 0) -> bottom (ratio 255)
//   radial:     centered, edge of the circle touches the shape's sides
// Derivation is in the surrounding project notes — this is the one part of
// the whole project without a reference implementation to check the matrix
// math against, so gradients are flagged lower-confidence in the README.
function gradientMatrix(x1, y1, x2, y2, type, direction) {
  const cx = (x1 + x2) / 2, cy = (y1 + y2) / 2;
  const sx = (x2 - x1) / 32768, sy = (y2 - y1) / 32768;
  if (type === 'radial' || direction !== 'vertical') {
    return Bitio.encodeMatrixFull({ scaleX: sx, scaleY: sy, translateX: cx, translateY: cy });
  }
  // vertical linear: swap axes so the gradient's ramp direction (local x)
  // maps to the shape's Y axis instead of its X axis.
  return Bitio.encodeMatrixFull({ scaleX: 0, scaleY: 0, rotateSkew0: sy, rotateSkew1: sx, translateX: cx, translateY: cy });
}

function encodeFillStyle(fill, x1, y1, x2, y2) {
  if (Array.isArray(fill)) return concatBytes(u8(0x00), rgba(fill)); // solid
  const typeByte = fill.type === 'radial' ? 0x12 : 0x10;
  const matrix = gradientMatrix(x1, y1, x2, y2, fill.type, fill.direction);
  return concatBytes(u8(typeByte), matrix, encodeGradientRecord(fill.stops));
}

// options: { fill: [r,g,b,a] | {type:'linear'|'radial', direction, stops},
//            radius: corner radius in px (0 = sharp corners),
//            stroke: {width, color} in px/rgba, or null }
function defineShapeEx(shapeId, x1, y1, x2, y2, options = {}) {
  const { fill = [255, 255, 255, 255], radius = 0, stroke = null } = options;
  const X1 = px(x1), Y1 = px(y1), X2 = px(x2), Y2 = px(y2);
  const w = X2 - X1, h = Y2 - Y1;
  const strokeW = stroke ? Math.max(0, px(stroke.width)) : 0;
  const numLineStyles = stroke ? 1 : 0;

  let body = concatBytes(u16le(shapeId), encodeRect(X1 - strokeW / 2, X2 + strokeW / 2, Y1 - strokeW / 2, Y2 + strokeW / 2));

  // FillStyleArray: exactly one fill style (solid or gradient).
  body = concatBytes(body, u8(1), encodeFillStyle(fill, X1, Y1, X2, Y2));
  // LineStyleArray
  body = concatBytes(body, u8(numLineStyles));
  if (stroke) body = concatBytes(body, u16le(strokeW), rgba(stroke.color));

  const numFillBits = 1;
  const numLineBits = numLineStyles ? 1 : 0;
  const bw = new BitWriter();
  bw.ubits(numFillBits, 4).ubits(numLineBits, 4);

  const r = Math.max(0, Math.min(px(radius), Math.abs(w) / 2, Math.abs(h) / 2));

  // Style-change record: select fill 1 (and line 1, if present), move to
  // the path's starting point.
  const startX = X1 + r, startY = Y1;
  bw.ubits(0, 1).ubits(0, 1).ubits(stroke ? 1 : 0, 1).ubits(1, 1).ubits(0, 1).ubits(1, 1);
  const mb = Math.max(1, sbitsNeeded(startX, startY));
  bw.ubits(mb, 5).sbits(startX, mb).sbits(startY, mb);
  bw.ubits(1, numFillBits); // fill style 1
  if (stroke) bw.ubits(1, numLineBits); // line style 1

  if (r <= 0) {
    // plain rectangle: 4 straight edges, same path defineShape3 draws.
    emitStraightEdge(bw, w, 0);
    emitStraightEdge(bw, 0, h);
    emitStraightEdge(bw, -w, 0);
    emitStraightEdge(bw, 0, -h);
  } else {
    // rounded rectangle: straight edge + quarter-round curve per corner,
    // clockwise from (X1+r, Y1). The curve's control point sits at the
    // sharp corner itself — a quadratic bezier can't trace a true circular
    // arc, but this is the standard, visually-good approximation.
    let cx = startX, cy = startY;
    const corner = (toX, toY, ctrlX, ctrlY, anchorX, anchorY) => {
      emitStraightEdge(bw, toX - cx, toY - cy);
      emitCurvedEdge(bw, toX, toY, ctrlX, ctrlY, anchorX, anchorY);
      cx = anchorX; cy = anchorY;
    };
    corner(X2 - r, Y1, X2, Y1, X2, Y1 + r);
    corner(X2, Y2 - r, X2, Y2, X2 - r, Y2);
    corner(X1 + r, Y2, X1, Y2, X1, Y2 - r);
    corner(X1, Y1 + r, X1, Y1, X1 + r, Y1);
  }

  bw.ubits(0, 6); // end shape
  body = concatBytes(body, bw.flush());
  return tag(32, body);
}

// DefineEditText flag bits, split across the two flag bytes that follow the
// bounds. The original encoder hard-coded these as 0x8d,0x11 — which is
// HasText|ReadOnly|HasTextColor|HasFont plus NoSelect|UseOutlines, i.e. a
// single-line read-only field and no way to ask for anything else.
const EDIT_FLAGS0 = {
  HAS_TEXT: 0x80, WORD_WRAP: 0x40, MULTILINE: 0x20, PASSWORD: 0x10,
  READ_ONLY: 0x08, HAS_TEXT_COLOR: 0x04, HAS_MAX_LENGTH: 0x02, HAS_FONT: 0x01,
};
const EDIT_FLAGS1 = {
  HAS_FONT_CLASS: 0x80, AUTO_SIZE: 0x40, HAS_LAYOUT: 0x20, NO_SELECT: 0x10,
  BORDER: 0x08, WAS_STATIC: 0x04, HTML: 0x02, USE_OUTLINES: 0x01,
};
const TEXT_ALIGN = { left: 0, right: 1, center: 2, justify: 3 };

// options:
//   multiline, wordWrap, html, border, password, selectable, autoSize (bools)
//   align: 'left'|'right'|'center'|'justify'
//   leftMargin/rightMargin/indent/leading: px (any of these forces a LAYOUT
//     record, which `align` also requires)
//   maxLength: number
//
// Defaults reproduce the original hard-coded flags exactly, so existing
// callers that pass no options get byte-identical output.
function defineEditText(charId, x1, y1, x2, y2, fontId, sizePx, text, color, varname = '', options = {}) {
  const {
    multiline = false, wordWrap = false, html = false, border = false,
    password = false, selectable = false, autoSize = false, readOnly = true,
    align = null, leftMargin = 0, rightMargin = 0, indent = 0, leading = 0,
    maxLength = null, useOutlines = true,
  } = options;

  const X1 = px(x1), Y1 = px(y1), X2 = px(x2), Y2 = px(y2);
  const needLayout = align !== null || leftMargin || rightMargin || indent || leading;

  let f0 = EDIT_FLAGS0.HAS_TEXT | EDIT_FLAGS0.HAS_TEXT_COLOR | EDIT_FLAGS0.HAS_FONT;
  if (wordWrap) f0 |= EDIT_FLAGS0.WORD_WRAP;
  if (multiline) f0 |= EDIT_FLAGS0.MULTILINE;
  if (password) f0 |= EDIT_FLAGS0.PASSWORD;
  if (readOnly) f0 |= EDIT_FLAGS0.READ_ONLY;
  if (maxLength !== null) f0 |= EDIT_FLAGS0.HAS_MAX_LENGTH;

  let f1 = 0;
  if (useOutlines) f1 |= EDIT_FLAGS1.USE_OUTLINES;
  if (!selectable) f1 |= EDIT_FLAGS1.NO_SELECT;
  if (border) f1 |= EDIT_FLAGS1.BORDER;
  if (html) f1 |= EDIT_FLAGS1.HTML;
  if (autoSize) f1 |= EDIT_FLAGS1.AUTO_SIZE;
  if (needLayout) f1 |= EDIT_FLAGS1.HAS_LAYOUT;

  // Field order is fixed: flags, [font id + height], [colour], [max length],
  // [layout], variable name, initial text.
  let body = concatBytes(u16le(charId), encodeRect(X1, X2, Y1, Y2), u8(f0, f1));
  body = concatBytes(body, u16le(fontId), u16le(px(sizePx)));
  body = concatBytes(body, rgba(color));
  if (maxLength !== null) body = concatBytes(body, u16le(maxLength));
  if (needLayout) {
    const a = align === null ? 0 : (TEXT_ALIGN[align] ?? 0);
    body = concatBytes(body, u8(a),
      u16le(px(leftMargin)), u16le(px(rightMargin)), u16le(px(indent)), u16le(px(leading)));
  }
  body = concatBytes(body, cstr(varname), cstr(text));
  return tag(37, body);
}

function placeObject(charId, depth, matrix = IDENTITY_MATRIX) {
  return tag(26, concatBytes(u8(0x06), u16le(depth), u16le(charId), matrix));
}

function placeNamed(charId, depth, name, matrix = IDENTITY_MATRIX) {
  return tag(26, concatBytes(u8(0x26), u16le(depth), u16le(charId), matrix, cstr(name)));
}

// -- CXFORMWITHALPHA ---------------------------------------------------------
//
// Field order per GFxStream::ReadCxformRgba: HasAddTerms(1), HasMultTerms(1),
// Nbits(4), then the multiply terms, then the add terms. Two details that are
// easy to get backwards: the *add* flag is the first bit even though the
// *mult* terms come first in the payload, and multiply factors are fixed-point
// over 256, not 255 — the SDK comment is explicit that "multiply factor 1.0
// has value 0x100, not 0xFF".
//
// mult: {r,g,b,a} as 0..1 multipliers (1 = unchanged)
// add:  {r,g,b,a} as -255..255 offsets (0 = unchanged)
function encodeCxform(mult = null, add = null) {
  const m = mult ? [mult.r ?? 1, mult.g ?? 1, mult.b ?? 1, mult.a ?? 1].map(v => Math.round(v * 256)) : null;
  const a = add ? [add.r ?? 0, add.g ?? 0, add.b ?? 0, add.a ?? 0].map(v => Math.round(v)) : null;
  const w = new BitWriter();
  const terms = [].concat(m || [], a || []);
  const nb = terms.length ? sbitsNeeded(...terms) : 1;
  w.ubits(a ? 1 : 0, 1).ubits(m ? 1 : 0, 1).ubits(nb, 4);
  if (m) for (const v of m) w.sbits(v, nb);
  if (a) for (const v of a) w.sbits(v, nb);
  return w.flush();
}

// Convenience: a colour transform that only changes alpha, which is what HUD
// work almost always wants (fading a panel in or out).
function alphaCxform(alpha01) {
  return encodeCxform({ r: 1, g: 1, b: 1, a: alpha01 }, null);
}

const PLACE = {
  HAS_CLIP_ACTIONS: 0x01, HAS_CHARACTER: 0x02, HAS_MATRIX: 0x04,
  HAS_COLOR_TRANSFORM: 0x08, HAS_RATIO: 0x10, HAS_NAME: 0x20,
  HAS_CLIP_DEPTH: 0x40, MOVE: 0x80,
};

// Full PlaceObject2. Field order is fixed by the format:
//   flags, depth, [charId], [matrix], [cxform], [ratio], [name], [clipDepth],
//   [clipActions]
//
// `move: true` modifies whatever already sits at `depth` instead of placing
// something new — that's how a timeline animates an existing object across
// frames rather than replacing it.
function placeObject2({
  charId = null, depth, matrix = null, name = null, cxform = null,
  ratio = null, clipDepth = null, clipActions = null, move = false,
} = {}) {
  let flags = 0;
  if (move) flags |= PLACE.MOVE;
  if (charId !== null) flags |= PLACE.HAS_CHARACTER;
  if (matrix !== null) flags |= PLACE.HAS_MATRIX;
  if (cxform !== null) flags |= PLACE.HAS_COLOR_TRANSFORM;
  if (ratio !== null) flags |= PLACE.HAS_RATIO;
  if (name !== null) flags |= PLACE.HAS_NAME;
  if (clipDepth !== null) flags |= PLACE.HAS_CLIP_DEPTH;
  if (clipActions !== null) flags |= PLACE.HAS_CLIP_ACTIONS;

  let body = concatBytes(u8(flags), u16le(depth));
  if (charId !== null) body = concatBytes(body, u16le(charId));
  if (matrix !== null) body = concatBytes(body, matrix);
  if (cxform !== null) body = concatBytes(body, cxform);
  if (ratio !== null) body = concatBytes(body, u16le(ratio));
  if (name !== null) body = concatBytes(body, cstr(name));
  if (clipDepth !== null) body = concatBytes(body, u16le(clipDepth));
  if (clipActions !== null) body = concatBytes(body, clipActions);
  return tag(26, body);
}

// -- clip event handlers ------------------------------------------------------
//
// The bits below are GFx's own GFxEventId::Event_* constants. GFxSwfEvent::Read
// assigns the wire flags straight into the event id (`Event = flags;`), so the
// SDK enum *is* the wire format rather than something mapped onto it.
//
// This is how the shipped game movies build interactive UI: a movieclip placed
// with onRelease/onRollOver handlers, rather than a DefineButton character.
// Across the 42 sampled movies DefineButton appears 4 times in total, in one
// file — clip handlers are the idiom the game actually uses.
const CLIP_EVENT = {
  load: 0x00001, enterFrame: 0x00002, unload: 0x00004,
  mouseMove: 0x00008, mouseDown: 0x00010, mouseUp: 0x00020,
  keyDown: 0x00040, keyUp: 0x00080, data: 0x00100, initialize: 0x00200,
  press: 0x00400, release: 0x00800, releaseOutside: 0x01000,
  rollOver: 0x02000, rollOut: 0x04000, dragOver: 0x08000, dragOut: 0x10000,
  keyPress: 0x20000, construct: 0x40000,
};

// CLIPACTIONS block for placeObject2({clipActions}).
//
// Layout per GFxPlayerImpl.cpp's PO2_HasActions branch:
//   reserved (u16 = 0)
//   allFlags (u32) — the OR of every handler's flags
//   per handler: flags (u32), length (u32), [keyCode u8 if keyPress], actions
//   terminator (u32 = 0)
//
// The u32 (rather than u16) widths apply because that branch selects them for
// movieVersion >= 6, and buildGfx writes version 8.
//
// handlers: [{ events: ['release', ...] | numeric mask, actions: Uint8Array,
//              keyCode?: number }]
function clipActions(handlers) {
  const masks = handlers.map(h => {
    if (typeof h.events === 'number') return h.events;
    return h.events.reduce((acc, name) => {
      if (!(name in CLIP_EVENT)) throw new Error(`unknown clip event ${JSON.stringify(name)}`);
      return acc | CLIP_EVENT[name];
    }, 0);
  });
  const all = masks.reduce((a, b) => a | b, 0);
  let body = concatBytes(u16le(0), u32le(all));
  handlers.forEach((h, i) => {
    const mask = masks[i];
    if (!mask) throw new Error('clip action handler has no events');
    // every handler's action list is self-terminated, so the End byte is part
    // of the measured length
    const actions = concatBytes(h.actions, u8(0));
    const withKey = (mask & CLIP_EVENT.keyPress)
      ? concatBytes(u8(h.keyCode & 0xff), actions)
      : actions;
    body = concatBytes(body, u32le(mask), u32le(withKey.length), withKey);
  });
  return concatBytes(body, u32le(0));
}

// -- timeline ----------------------------------------------------------------

// FrameLabel (43). GFx's GotoLabel does NOT parse numbers out of a label, so a
// label of "4" is a label named "4" and not frame 4 — worth knowing before
// naming frames numerically.
function frameLabel(name) {
  return tag(43, cstr(name));
}

// RemoveObject2 (28): clears whatever is at `depth`. Needed whenever content
// present on one frame is absent on the next — a placed object otherwise
// persists down the timeline until something removes it.
function removeObject2(depth) {
  return tag(28, u16le(depth));
}

// ExportAssets (56): gives characters public names so script can reach them
// with attachMovie()/loadMovie(). Used heavily by the shipped game movies
// (1,516 entries across 23 of the 42 sampled).
// entries: [{ id, name }]
function exportAssets(entries) {
  let body = u16le(entries.length);
  for (const e of entries) body = concatBytes(body, u16le(e.id), cstr(e.name));
  return tag(56, body);
}

// DoInitAction (59): actions that run once, when the sprite's character is
// first defined, rather than every time its frame is entered.
function doInitAction(spriteId, avm1Body) {
  return tag(59, concatBytes(u16le(spriteId), avm1Body));
}

// DefineScale9Grid (78): marks the 9-slice guides on an already-defined
// character, so corners keep their size while edges and centre stretch. Body
// is the character id followed by a RECT giving the inner rectangle, in twips.
function defineScale9Grid(charId, left, top, right, bottom) {
  return tag(78, concatBytes(
    u16le(charId),
    encodeRect(px(left), px(right), px(top), px(bottom))
  ));
}

const BTN_UP = 0x01, BTN_OVER = 0x02, BTN_DOWN = 0x04, BTN_HIT = 0x08;

function defineButton(buttonId, records, onRelease) {
  let body = u16le(buttonId);
  for (const [flags, char, depth, matrix] of records) {
    body = concatBytes(body, u8(flags), u16le(char), u16le(depth), matrix);
  }
  body = concatBytes(body, u8(0), onRelease, u8(0));
  return tag(7, body);
}

function defineSprite(spriteId, controlTags, frames = 1) {
  const body = concatBytes(u16le(spriteId), u16le(frames), controlTags);
  return tag(39, body);
}

function doAction(avm1Body) {
  return tag(12, avm1Body);
}

const SHOW_FRAME = tag(1, u8());
const END = tag(0, u8());

// --- container -----------------------------------------------------------

function buildGfx(stageW, stageH, fps, bodyTags, frameCount = 1) {
  let body = encodeRect(0, px(stageW), 0, px(stageH));
  body = concatBytes(body, u16le(Math.trunc(fps) << 8), u16le(Math.max(1, frameCount)), bodyTags);
  return concatBytes(latin1('GFX'), u8(8), u32le(8 + body.length), body);
}

const api = {
  tag, exporterInfo, fileAttributes, setBackgroundColor, importFont,
  defineShape3, defineShapeEx, defineEditText, placeObject, placeNamed,
  BTN_UP, BTN_OVER, BTN_DOWN, BTN_HIT, defineButton, defineSprite,
  doAction, SHOW_FRAME, END, buildGfx, IDENTITY_MATRIX,

  // timeline + structure
  placeObject2, PLACE, frameLabel, removeObject2, exportAssets, doInitAction,
  defineScale9Grid,

  // clip event handlers
  clipActions, CLIP_EVENT,

  // colour transforms
  encodeCxform, alphaCxform,

  // text flags
  EDIT_FLAGS0, EDIT_FLAGS1, TEXT_ALIGN,

  _internal: { concatBytes, u8, u16le, i32le, u32le, latin1, cstr },
};

  return api;
})();
