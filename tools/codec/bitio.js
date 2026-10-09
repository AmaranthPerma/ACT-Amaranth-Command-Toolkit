const Bitio = (function() {
// Port of gfxforge/_bitio.py — SWF bitfields, rects, matrices (twips).
// Format-level and game-agnostic. No dependencies.

const TWIPS = 20;

function px(value) {
  return Math.round(value * TWIPS);
}

class BitWriter {
  constructor() {
    this._acc = 0;
    this._nbits = 0;
    this._out = [];
  }

  ubits(value, nbits) {
    for (let i = nbits - 1; i >= 0; i--) {
      this._acc = (this._acc << 1) | ((value >>> i) & 1);
      this._nbits += 1;
      if (this._nbits === 8) {
        this._out.push(this._acc & 0xff);
        this._acc = 0;
        this._nbits = 0;
      }
    }
    return this;
  }

  sbits(value, nbits) {
    const mask = nbits >= 32 ? 0xffffffff : (1 << nbits) - 1;
    return this.ubits(value & mask, nbits);
  }

  flush() {
    if (this._nbits) {
      this._acc <<= (8 - this._nbits);
      this._out.push(this._acc & 0xff);
      this._acc = 0;
      this._nbits = 0;
    }
    return Uint8Array.from(this._out);
  }
}

function sbitsNeeded(...values) {
  let width = 1;
  for (const v of values) {
    const bits = v >= 0 ? bitLength(v) + 1 : bitLength(-v - 1) + 1;
    width = Math.max(width, bits, 1);
  }
  return width;
}

function bitLength(n) {
  // Python int.bit_length() for non-negative n: number of bits, 0 -> 0.
  return n === 0 ? 0 : n.toString(2).length;
}

function encodeRect(xmin, xmax, ymin, ymax) {
  const w = new BitWriter();
  const nb = sbitsNeeded(xmin, xmax, ymin, ymax);
  w.ubits(nb, 5);
  for (const v of [xmin, xmax, ymin, ymax]) {
    w.sbits(v, nb);
  }
  return w.flush();
}

function encodeMatrix(translateX = 0, translateY = 0, scale = null) {
  const w = new BitWriter();
  if (scale !== null) {
    const sx = Math.round(scale[0] * 65536);
    const sy = Math.round(scale[1] * 65536);
    const nb = sbitsNeeded(sx, sy);
    w.ubits(1, 1).ubits(nb, 5).sbits(sx, nb).sbits(sy, nb);
  } else {
    w.ubits(0, 1); // HasScale = 0
  }
  w.ubits(0, 1); // HasRotate = 0
  if (translateX || translateY) {
    const nb = sbitsNeeded(translateX, translateY);
    w.ubits(nb, 5).sbits(translateX, nb).sbits(translateY, nb);
  } else {
    w.ubits(0, 5); // NTranslateBits = 0
  }
  return w.flush();
}

const IDENTITY_MATRIX = encodeMatrix();

// General MATRIX encoder supporting scale + rotate/skew + translate, for
// gradient fill matrices (encodeMatrix() above only ever needs pure
// translate, so it hardcodes HasRotate=0 — this is a separate function
// rather than extending that one, so its existing byte-for-byte-verified
// output can never change). Always writes HasScale=1 and HasRotate=1
// explicitly (never omitted, even for identity values) — simpler and still
// fully spec-valid, just marginally less compact.
function encodeMatrixFull({ scaleX = 1, scaleY = 1, rotateSkew0 = 0, rotateSkew1 = 0, translateX = 0, translateY = 0 }) {
  const w = new BitWriter();
  const sx = Math.round(scaleX * 65536), sy = Math.round(scaleY * 65536);
  const sNb = sbitsNeeded(sx, sy);
  w.ubits(1, 1).ubits(sNb, 5).sbits(sx, sNb).sbits(sy, sNb);
  const r0 = Math.round(rotateSkew0 * 65536), r1 = Math.round(rotateSkew1 * 65536);
  const rNb = sbitsNeeded(r0, r1);
  w.ubits(1, 1).ubits(rNb, 5).sbits(r0, rNb).sbits(r1, rNb);
  const tx = Math.round(translateX), ty = Math.round(translateY);
  const tNb = sbitsNeeded(tx, ty);
  w.ubits(tNb, 5).sbits(tx, tNb).sbits(ty, tNb);
  return w.flush();
}

  return { TWIPS, px, BitWriter, sbitsNeeded, encodeRect, encodeMatrix, encodeMatrixFull, IDENTITY_MATRIX };
})();
