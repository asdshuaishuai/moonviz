# moonviz-engine-wasm

[MoonViz](https://github.com/asdshuaishuai/moonviz) 原型设计引擎编译为 **WebAssembly GC** 的产物。在浏览器或 Node 中完整渲染、校验 `.mbt.md` 视觉文档 —— 无需 MoonBit 工具链、无子进程、无服务器。

> 🇬🇧 English: [README.md](./README.md)

引擎把一份 MoonBit 文学化源文件 —— **`.mbt.md`** —— 作为设计项目的唯一事实源。本包内嵌预构建的 `wasm-gc` 产物（≈90 KB），经 [JS String Builtins](https://github.com/WebAssembly/js-string-builtin) 以纯字符串人机工学暴露渲染/校验管线。

## 环境要求

宿主需支持 **WasmGC + js-string builtins**：

| 宿主 | 最低版本 |
|---|---|
| Node.js | **22**（V8 正式携带 WasmGC） |
| Chrome / Edge | 119+ |
| Firefox | 120+ |
| Safari | 18.2+ |

Node 20 及更早版本实例化时会抛错（`Unknown type code 0x50` / `invalid value type`）——请升级，或改用基于子进程的 [`moonviz-engine-sdk`](https://www.npmjs.com/package/moonviz-engine-sdk)。

## 安装

```bash
npm install moonviz-engine-wasm
```

## 快速上手

### Node

```js
import { createEngine } from 'moonviz-engine-wasm';

const engine = await createEngine();

const view = engine.render(mbt);      // 同步、进程内
// { ok: true, entry: 'a', flows: [...], artboards: [{ id, width, height, svg, nodes }] }

const check = engine.validate(mbt);
// { ok: true, entry: 'a', revision: 1, blockKinds: { mbt: 1, mbt_check: 0, ... } }

view.artboards[0].svg;                // 可直接挂载的 <svg> 标记
```

### 浏览器

```js
import { createEngine } from 'moonviz-engine-wasm';
// 让 dist/moonviz.wasm 走打包器的静态资源
const engine = await createEngine(fetch('/assets/moonviz.wasm'));
document.querySelector('#stage').innerHTML = engine.render(mbt).artboards[0].svg;
```

## API

### `createEngine(source?) → Promise<Engine>`

- `source`：可选的 wasm 字节 `Response`、`ArrayBuffer` 或 `TypedArray`。缺省时（Node）读取内置的 `dist/moonviz.wasm`。

### `Engine`

| 方法 | 返回 | 说明 |
|---|---|---|
| `version()` | `{ ok, engine, version }` | 引擎构建信息。 |
| `render(mbt)` | `{ ok, entry?, flows?, artboards?, error? }` | 从源码全量重建（AgentGate 级）。每个画板带 `svg` 标记与 `nodes` 索引。 |
| `validate(mbt)` | `{ ok, entry?, revision?, blockKinds?, error? }` | 只校验不渲染。 |
| `sessionOpen(mbt)` / `sessionClose(h)` / `sessionCount()` | 句柄 / 布尔 / 整数 | 有状态会话生命周期。 |
| `sessionApply(h, op, gate?)` | `{ ok, mbt?, ... }` | 应用 mutating op；成功信封带 canonical `.mbt.md`，请保存供下次 `sessionOpen` 使用。 |
| `sessionConstrain(h, ab, intent)` | `{ ok, mbt?, ...moves }` | 自然语言布局意图（居中 \| 垂直排列 \| 等宽 \| 间距 N …）；成功信封带 canonical mbt。 |
| `sessionAutoFix(h, ab)` | `{ ok, fixes, detail, mbt? }` | 自动修复（违规严格下降才提交）；成功信封带 canonical mbt。 |
| `sessionGenerateResponsive(h, ab)` | `{ ok, variants, mbt? }` | 生成 `_tablet`/`_desktop` 变体；成功信封带 canonical mbt（含新画板）。 |
| `sessionTap(h, ab, x, y)` | `{ ok, changes, current, mbt? }` | 原型运行时 tap；⚡ `set_text`/`set_state` 会写穿会话文档，故信封带 canonical mbt。 |
| `sessionSave(h)` / `sessionOpenProjectJson(j)` | `{ ok, data }` / 句柄 | 项目 JSON 快照往返（跨进程持久化）。 |
| `raw` | wasm 导出 | 高级用法逃生门。 |

两个入口都接受完整 `.mbt.md` 文档并返回解析后的对象；畸形输入返回 `{ ok: false, error }` 而不是抛异常。

## 重建产物

```bash
git clone https://github.com/asdshuaishuai/moonviz && cd moonviz
moon build --release --target wasm-gc wasm
cp _build/wasm-gc/release/build/wasm/wasm.wasm sdk/wasm/dist/moonviz.wasm
```

边界函数在 [`wasm/main.mbt`](https://github.com/asdshuaishuai/moonviz/blob/main/wasm/main.mbt)（`render_mbt` / `validate_mbt` / `version_info`）；导出清单与 `use-js-builtin-string` 配置在 `wasm/moon.pkg`。

## 两个 SDK 怎么选

| | `moonviz-engine-wasm` | `moonviz-engine-sdk` |
|---|---|---|
| 运行时依赖 | 无（wasm 进程内） | `moon` 工具链 + 引擎目录 + `ddp_codec` |
| 能力面 | 渲染 / 校验 | 完整 CLI：会话、编辑、导航流、双门禁导出、DDP 编解码 |
| 延迟 | 毫秒级、同步 | 每批一次进程拉起 |
| DDP 加解密 | ✗（Rust 编解码器，独立） | ✓ |

## 许可

MIT © MoonViz contributors
