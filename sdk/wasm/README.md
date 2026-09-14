# moonviz-engine-wasm

The [MoonViz](https://github.com/asdshuaishuai/moonviz) prototype design engine, compiled to **WebAssembly GC**. Render and validate `.mbt.md` visual documents entirely in the browser or in Node — no MoonBit toolchain, no subprocess, no server.

The engine treats one MoonBit literate source file — **`.mbt.md`** — as the single source of truth of a design project. This package embeds a prebuilt `wasm-gc` artifact (≈90 KB) and exposes its render/validate pipeline with plain-string ergonomics via [JS String Builtins](https://github.com/WebAssembly/js-string-builtin).

## Requirements

A host with **WasmGC + js-string builtins** support:

| Host | Minimum |
|---|---|
| Node.js | **22** (V8 with WasmGC shipping) |
| Chrome / Edge | 119+ |
| Firefox | 120+ |
| Safari | 18.2+ |

On Node 20 or older the module instantiation throws (`Unknown type code 0x50` / `invalid value type`) — upgrade, or use the process-based [`moonviz-engine-sdk`](https://www.npmjs.com/package/moonviz-engine-sdk) instead.

## Install

```bash
npm install moonviz-engine-wasm
```

## Quick start

### Node

```js
import { createEngine } from 'moonviz-engine-wasm';

const engine = await createEngine();

const view = engine.render(mbt);      // synchronous, in-process
// { ok: true, entry: 'a', flows: [...], artboards: [{ id, width, height, svg, nodes }] }

const check = engine.validate(mbt);
// { ok: true, entry: 'a', revision: 1, blockKinds: { mbt: 1, mbt_check: 0, ... } }

view.artboards[0].svg;                // ready-to-mount <svg> markup
```

### Browser

```js
import { createEngine } from 'moonviz-engine-wasm';
// serve dist/moonviz.wasm from your bundler's static assets
const engine = await createEngine(fetch('/assets/moonviz.wasm'));
document.querySelector('#stage').innerHTML = engine.render(mbt).artboards[0].svg;
```

## API

### `createEngine(source?) → Promise<Engine>`

- `source`: optional `Response`, `ArrayBuffer`, or `TypedArray` of the wasm bytes. Omit to read the bundled `dist/moonviz.wasm` (Node).

### `Engine`

| Method | Returns | Description |
|---|---|---|
| `version()` | `{ ok, engine, version }` | Engine build info. |
| `render(mbt)` | `{ ok, entry?, flows?, artboards?, error? }` | Full rebuild from source (AgentGate level). Each artboard carries `svg` markup and a `nodes` index. |
| `validate(mbt)` | `{ ok, entry?, revision?, blockKinds?, error? }` | Validate without rendering. |
| `raw` | wasm exports | Escape hatch for advanced use. |

Both entry points accept a complete `.mbt.md` document and return parsed objects. Malformed input returns `{ ok: false, error }` instead of throwing.

## Rebuilding the artifact

```bash
git clone https://github.com/asdshuaishuai/moonviz && cd moonviz
moon build --release --target wasm-gc wasm
cp _build/wasm-gc/release/build/wasm/wasm.wasm sdk/wasm/dist/moonviz.wasm
```

The boundary functions live in [`wasm/main.mbt`](https://github.com/asdshuaishuai/moonviz/blob/main/wasm/main.mbt) (`render_mbt` / `validate_mbt` / `version_info`); export list and `use-js-builtin-string` are configured in `wasm/moon.pkg`.

## When to use which SDK

| | `moonviz-engine-wasm` | `moonviz-engine-sdk` |
|---|---|---|
| Runtime deps | none (wasm in-process) | `moon` toolchain + engine dir + `ddp_codec` |
| Feature surface | render / validate | full CLI: sessions, edits, flows, dual-gate export, DDP codec |
| Latency | ~ms, synchronous | process spawn per batch |
| DDP encrypt/decrypt | ✗ (Rust codec, separate) | ✓ |

## License

MIT © MoonViz contributors
