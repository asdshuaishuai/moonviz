# moonviz-engine-sdk

> 🇨🇳 简体中文: [README.zh-CN.md](./README.zh-CN.md)

Node.js integration SDK for the [MoonViz](https://github.com/asdshuaishuai/moonviz) prototype design engine (pure [MoonBit](https://www.moonbitlang.com/)).

MoonViz treats one MoonBit literate source file — **`.mbt.md`** — as the single source of truth of a design project. Human canvas edits and Agent edits both commit back to that same source; every visual preview is rebuilt from it. This SDK is a **pure transport / orchestration layer**: it spawns the engine CLI, encodes commands, and parses newline-framed JSON. It never caches and never becomes a second source of truth.

## Install

```bash
npm install moonviz-engine-sdk
```

## Prerequisites

**Recommended (zero toolchain):** install the prebuilt platform binary alongside the SDK. The engine ships as a self-contained native executable (links only libc — no MoonBit toolchain, no engine sources):

```bash
npm install moonviz-engine-sdk moonviz-bin-darwin-arm64   # or -linux-x64 / -linux-arm64
```

The SDK auto-discovers the platform package (or honor `MOONVIZ_CLI_BIN=/path/to/moonviz-cli`). In this mode `new MoonViz()` works with no other setup.

**Fallback (`moon run` mode)** drives the engine through the MoonBit toolchain and requires:

| Requirement | How the SDK finds it | Override |
|---|---|---|
| MoonBit toolchain (`moon` executable) | `MOONVIZ_MOON` / `MOON` / `PATH` → `~/.moon/bin/moon` → `/opt/homebrew/bin/moon` | `new MoonViz({ moon: '/path/to/moon' })` |
| Engine directory (contains `cli/moon.pkg`) | `moonvizDir` option → `MOONVIZ_DIR` env → auto-discovery relative to the SDK package | `new MoonViz({ moonvizDir: '...' })` |

`ddp_codec` (DDP encrypt/decrypt only) is a separate Rust binary resolved via `MOONVIZ_DDP_HELPER` → `<moonviz>/ddp/target/{debug,release}/ddp_codec`; override with `DDP.encrypt(mbt, pwd, { codecPath: '...' })`. Build it once with:

```bash
cd moonviz/ddp && cargo build --release
```

## Quick start

```js
import { MoonViz, Project, DDP, build } from 'moonviz-engine-sdk';

const engine = new MoonViz({ moonvizDir: '/path/to/moonviz' });

// Low level: run a batch of commands in one stateful CLI session
const templates = await engine.run(['list-templates']);

// High level: Project builder — accumulate commands, execute once on export
const mbt = await build(engine, p => {
  p.template('login', 't_login', 390, 844);
  p.template('dashboard', 't_home', 390, 844);
  p.update('t_login', 'welcome_title', { text: 'Welcome back' });
  p.flow('t_login', 't_home', 'login_btn');
});  // → canonical .mbt.md text (HumanGate-validated)

// Render from source (AgentGate rebuild)
const view = await engine.render(mbt);   // { ok, entry, flows, artboards }

// Dual-gate operations
const h = await engine.applyHumanOp(mbt, op);   // human route, hard-blocks structural violations
const a = await engine.applyAgentOp(mbt, op);   // agent route, semantic validation

// DDP containers
const locked = await DDP.encrypt(mbt, 'password');   // → { bytes, mode: 'DDP1' }
const free   = await DDP.encrypt(mbt, '');           // → { bytes, mode: 'DDP2' }
const back   = await DDP.decrypt(free.bytes);        // → { mbt, mode: 'DDP2' }
```

## API

### `MoonViz` — engine session

| Member | Description |
|---|---|
| `new MoonViz({ moonvizDir?, moon?, target? })` | Create an engine client. Throws if the engine directory cannot be resolved. |
| `run(commands: string[]) → Promise<any[]>` | Spawn one stateful CLI session, feed commands, return all JSON lines. |
| `last(commands) → Promise<object>` | Same, returning the last JSON object. |
| `render(mbt) → Promise<RenderResult>` | Full rebuild: all artboards as SVG + flows + entry. |
| `validate(mbt) → Promise<ValidateResult>` | Validate without rendering. |
| `applyHumanOp(mbt, op)` / `applyAgentOp(mbt, op)` | One-shot dual-gate operations. |
| `apply(mbt, op, gate?)` | Apply + throw `EngineError` on `{ok:false}`. |
| `create(name, w?, h?)` | Create a blank artboard. |

### `Project` — stateful builder

`template / create / duplicate / deleteArtboard / update / move / flip / reorder / copy / flow / exportHuman` — each method appends one CLI command and returns `this`; `exportHuman()` executes the batch and returns the canonical `.mbt.md`.

### `Session` — stateful CLI session (mirrors the wasm session surface)

`open(engine, seedCommand?) / exec(cmd) / apply(op) / lint(ab) / critique(ab) / autoFix(ab) / constrain(ab, intent) / interactions(ab) / states(ab) / queryNodes(ab) / flows() / spec(ab) / protest(ab, script) / collabMerge(spec) / animationCss(id, preset) / history(...) / exportMbt() / close()` — `constrain` is the natural-language layout intent （居中 | 垂直排列 | 等宽 | 间距 N …, same semantics as the wasm `sessionConstrain`).

### `DDP` — container codec

`encrypt(mbt, password, { codecPath?, moonvizDir? })` and `decrypt(bytes, password?, options?)`. DDP1 = Argon2id + XChaCha20-Poly1305; DDP2 (empty password) = zstd + CRC32, no encryption.

### Utilities

- `findPrebuiltCli()` — locate the prebuilt engine binary (`MOONVIZ_CLI_BIN` or `moonviz-bin-<platform>` package); returns `null` in fallback mode.
- `defaultMoonvizDir()` — engine-directory auto-discovery relative to the SDK package.
- `encodeProps(props)` — object → CLI `k=v` fragments (strings JSON-quoted).
- `EngineError` — thrown by `apply()`; `.error` is the engine error code, `.detail` keeps the raw response.
- `build(engine, recipe)` — one-shot Project factory.

## Self test

```bash
cd moonviz && node sdk/node/test/selftest.mjs
# SDK selftest passed: template/update/flow/export/render/DDP1/DDP2 all OK
```

Covers the full chain: templates → operations → flows → dual-gate export → render → DDP1/DDP2 round-trips.

## License

MIT © MoonViz contributors
