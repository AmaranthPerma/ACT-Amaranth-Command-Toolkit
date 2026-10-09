const Verify = (function() {
// Port of gfxforge/verify.py — structural verification of an emitted .gfx.
// Walks the whole tag stream and the AVM1 inside every DoAction. Pure JS,
// no dependencies. (Only the uncompressed 'GFX'/'FWS' container is supported,
// since that's the only thing this tool's own Movie.build() ever produces;
// the Python original's zlib path for foreign CFX/CWS files is intentionally
// left out here — see the writeup for why.)

class VerifyError extends Error {}

function u16(bytes, off) {
  return bytes[off] | (bytes[off + 1] << 8);
}
function i16(bytes, off) {
  const v = u16(bytes, off);
  return v >= 0x8000 ? v - 0x10000 : v;
}
function u32(bytes, off) {
  return (bytes[off] | (bytes[off + 1] << 8) | (bytes[off + 2] << 16) | (bytes[off + 3] << 24)) >>> 0;
}

function walkAvm1(code, ctx, out) {
  let o = 0;
  while (o < code.length) {
    const op = code[o]; o += 1;
    if (op === 0x00) return; // End
    if (op < 0x80) continue; // single-byte action
    if (o + 2 > code.length) throw new VerifyError(`${ctx}: truncated action-length field`);
    const ln = u16(code, o); o += 2;
    if (o + ln > code.length) throw new VerifyError(`${ctx}: action 0x${op.toString(16).padStart(2, '0')} body overruns`);
    const pl = code.subarray(o, o + ln); o += ln;
    if (op === 0x9b) { // DefineFunction: header + body follows
      let name, q, nparams, codesize;
      try {
        const nul1 = pl.indexOf(0);
        name = String.fromCharCode(...pl.subarray(0, nul1)); // latin1: byte value == char code
        q = nul1 + 1;
        nparams = u16(pl, q); q += 2;
        for (let i = 0; i < nparams; i++) {
          q = pl.indexOf(0, q) + 1;
        }
        codesize = u16(pl, q);
      } catch (e) {
        throw new VerifyError(`${ctx}: malformed DefineFunction header`);
      }
      if (o + codesize > code.length) throw new VerifyError(`${ctx}: function ${JSON.stringify(name)} body overruns`);
      // an anonymous definition is a function *expression* — it has no name to
      // report, but its body still has to be walked
      if (name) out.push(name);
      walkAvm1(code.subarray(o, o + codesize), `${ctx}/${name || '<anonymous>'}`, out);
      o += codesize;
    } else if (op === 0x8e) { // DefineFunction2: same idea, richer header
      let name, q, nparams, codesize;
      try {
        const nul1 = pl.indexOf(0);
        name = String.fromCharCode(...pl.subarray(0, nul1));
        q = nul1 + 1;
        nparams = u16(pl, q); q += 2;
        q += 1;            // registerCount
        q += 2;            // flags
        for (let i = 0; i < nparams; i++) {
          q += 1;          // this parameter's register assignment
          q = pl.indexOf(0, q) + 1;
        }
        codesize = u16(pl, q);
      } catch (e) {
        throw new VerifyError(`${ctx}: malformed DefineFunction2 header`);
      }
      if (o + codesize > code.length) throw new VerifyError(`${ctx}: function ${JSON.stringify(name)} body overruns`);
      if (name) out.push(name);
      walkAvm1(code.subarray(o, o + codesize), `${ctx}/${name || '<anonymous>'}`, out);
      o += codesize;
    } else if (op === 0x94) { // With: [u16 code size] then the block, inline
      const size = u16(pl, 0);
      if (o + size > code.length) throw new VerifyError(`${ctx}: with-block overruns`);
      walkAvm1(code.subarray(o, o + size), `${ctx}/with`, out);
      o += size;
    } else if (op === 0x99 || op === 0x9d) { // Jump / If: target must stay in range
      const off = i16(pl, 0);
      const tgt = o + off;
      if (!(tgt >= 0 && tgt <= code.length)) {
        throw new VerifyError(`${ctx}: branch target ${tgt} outside [0,${code.length}]`);
      }
    }
  }
  // falling off the end (no End) is legal for a function body (implicit return)
}

function verifyGfx(data, require = null) {
  const magic = String.fromCharCode(data[0], data[1], data[2]);
  if (!['GFX', 'CFX', 'FWS', 'CWS'].includes(magic)) {
    throw new VerifyError(`bad magic ${JSON.stringify(magic)}`);
  }
  const filelen = u32(data, 4);
  let body;
  if (magic === 'CFX' || magic === 'CWS') {
    throw new VerifyError('compressed (CFX/CWS) verification is not supported client-side without a zlib helper');
  } else {
    if (filelen !== data.length) {
      throw new VerifyError(`FileLength ${filelen} != actual ${data.length}`);
    }
    body = data.subarray(8);
  }

  const nb = body[0] >> 3;
  let off = Math.floor((5 + 4 * nb + 7) / 8) + 4; // RECT + framerate + framecount
  const tags = [];
  const functions = [];
  let first = null;
  let ended = false;
  while (off + 2 <= body.length) {
    const rh = u16(body, off); off += 2;
    const code = rh >> 6;
    let ln = rh & 0x3f;
    if (ln === 0x3f) {
      if (off + 4 > body.length) throw new VerifyError('truncated long-tag length');
      ln = u32(body, off); off += 4;
    }
    if (off + ln > body.length) throw new VerifyError(`tag ${code} body overruns (${off + ln} > ${body.length})`);
    const tb = body.subarray(off, off + ln); off += ln;
    tags.push(code);
    if (first === null) first = code;
    if (code === 12) walkAvm1(tb, 'DoAction', functions);
    if (code === 0) { ended = true; break; }
  }

  if (first !== 1000) throw new VerifyError(`ExporterInfo (1000) is not the first tag (got ${first})`);
  if (!ended) throw new VerifyError('no End tag — stream truncated');

  const tagCounts = {};
  for (const t of tags) tagCounts[t] = (tagCounts[t] || 0) + 1;
  const summary = { bytes: data.length, tags: tagCounts, functions };
  if (require) {
    for (const fn of (require.functions || [])) {
      if (!functions.includes(fn)) throw new VerifyError(`required function ${JSON.stringify(fn)} not defined`);
    }
    for (const [tcode, n] of Object.entries(require.minTags || {})) {
      if ((tagCounts[tcode] || 0) < n) {
        throw new VerifyError(`expected >=${n} of tag ${tcode}, got ${tagCounts[tcode] || 0}`);
      }
    }
  }
  return summary;
}

function verifyMovie(movie, require = null) {
  return verifyGfx(movie.build(), require);
}

  // walkAvm1 is exposed so tests can check a bare action stream (not just a
  // whole movie) with a reader that was written from the format rather than by
  // inverting the assembler.
  return { VerifyError, verifyGfx, verifyMovie, _walkAvm1: walkAvm1 };
})();
