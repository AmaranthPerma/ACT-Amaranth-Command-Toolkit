const fs = require('fs');
const path = require('path');
const vm = require('vm');

const root = __dirname;
const context = { Uint8Array, DataView, ArrayBuffer, Math, Object, Map, Set,
  Array, Number, String, Boolean, Date, JSON, RegExp, Error, TypeError, SyntaxError };
vm.createContext(context);
for (const file of ['bitio.js', 'swf.js', 'avm1.js', 'compiler.js']) {
  const source = fs.readFileSync(path.join(root, 'codec', file), 'utf8');
  vm.runInContext(source, context, { filename: file });
}
vm.runInContext('globalThis.actCodec = { Compiler, Swf };', context);
const source = fs.readFileSync(path.join(root, 'act_runtime.as'), 'utf8');
const bytecode = context.actCodec.Compiler.compileSource(source);
const tag = Buffer.from(context.actCodec.Swf.tag(12, new Uint8Array([...bytecode, 0])));
fs.writeFileSync(path.join(root, 'act_action.tag'), tag);
console.log(`ACT UI action tag: ${tag.length} bytes`);
