# moonviz-engine-sdk

[MoonViz](https://github.com/asdshuaishuai/moonviz) 原型设计引擎（纯 [MoonBit](https://www.moonbitlang.com/) 实现）的 Node.js 集成 SDK。

> 🇬🇧 English: [README.md](./README.md)

MoonViz 把一份 MoonBit 文学化源文件 —— **`.mbt.md`** —— 作为设计项目的唯一事实源：人类画布编辑与 Agent 编辑都回写到这同一份源码，每次预览都从源码重建。本 SDK 是**纯传输/编排层**：拉起引擎 CLI、编码命令、解析换行分帧的 JSON。它不做缓存，也绝不会成为第二个事实源。

## 安装

```bash
npm install moonviz-engine-sdk
```

## 前置条件

**推荐（零工具链）：** 随 SDK 一起安装平台预编译二进制。引擎以自包含原生可执行文件分发（仅链系统 libc —— 无需 MoonBit 工具链、无需引擎源码）：

```bash
npm install moonviz-engine-sdk moonviz-bin-darwin-arm64   # 或 -linux-x64 / -linux-arm64
```

SDK 会自动发现平台包（也支持 `MOONVIZ_CLI_BIN=/path/to/moonviz-cli` 显式指定）。此模式下 `new MoonViz()` 无需任何其它配置。

**回退（`moon run` 模式）** 通过 MoonBit 工具链驱动引擎，需要：

| 依赖 | SDK 的查找顺序 | 覆盖方式 |
|---|---|---|
| MoonBit 工具链（`moon` 可执行文件） | `MOONVIZ_MOON` / `MOON` / `PATH` → `~/.moon/bin/moon` → `/opt/homebrew/bin/moon` | `new MoonViz({ moon: '/path/to/moon' })` |
| 引擎目录（含 `cli/moon.pkg`） | `moonvizDir` 选项 → `MOONVIZ_DIR` 环境变量 → 相对 SDK 包自动发现 | `new MoonViz({ moonvizDir: '...' })` |

`ddp_codec`（仅 DDP 加解密需要）是独立的 Rust 二进制，解析顺序 `MOONVIZ_DDP_HELPER` → `<moonviz>/ddp/target/{debug,release}/ddp_codec`；可用 `DDP.encrypt(mbt, pwd, { codecPath: '...' })` 覆盖。构建一次：

```bash
cd moonviz/ddp && cargo build --release
```

## 快速上手

```js
import { MoonViz, Project, DDP, build } from 'moonviz-engine-sdk';

const engine = new MoonViz({ moonvizDir: '/path/to/moonviz' });

// 低层：在一个有状态 CLI 会话里执行一批命令
const templates = await engine.run(['list-templates']);

// 高层：Project 构建器 —— 累积命令，导出时一次执行
const mbt = await build(engine, p => {
  p.template('login', 't_login', 390, 844);
  p.template('dashboard', 't_home', 390, 844);
  p.update('t_login', 'welcome_title', { text: '欢迎回来' });
  p.flow('t_login', 't_home', 'login_btn');
});  // → canonical .mbt.md 文本（HumanGate 校验）

// 从源码渲染（AgentGate 重建）
const view = await engine.render(mbt);   // { ok, entry, flows, artboards }

// 双门禁操作
const h = await engine.applyHumanOp(mbt, op);   // 人类路线，结构违规硬拦
const a = await engine.applyAgentOp(mbt, op);   // Agent 路线，语义校验

// DDP 容器
const locked = await DDP.encrypt(mbt, 'password');   // → { bytes, mode: 'DDP1' }
const free   = await DDP.encrypt(mbt, '');           // → { bytes, mode: 'DDP2' }
const back   = await DDP.decrypt(free.bytes);        // → { mbt, mode: 'DDP2' }
```

## API

### `MoonViz` —— 引擎会话

| 成员 | 说明 |
|---|---|
| `new MoonViz({ moonvizDir?, moon?, target? })` | 创建引擎客户端；引擎目录无法解析时抛错。 |
| `run(commands: string[]) → Promise<any[]>` | 启动一个有状态 CLI 会话，喂入命令，返回全部 JSON 行。 |
| `last(commands) → Promise<object>` | 同上，只返回最后一个 JSON 对象。 |
| `render(mbt) → Promise<RenderResult>` | 全量重建：所有画板 SVG + 导航流 + entry。 |
| `validate(mbt) → Promise<ValidateResult>` | 只校验不渲染。 |
| `applyHumanOp(mbt, op)` / `applyAgentOp(mbt, op)` | 一次性双门禁操作。 |
| `apply(mbt, op, gate?)` | 应用操作，`{ok:false}` 时抛 `EngineError`。 |
| `create(name, w?, h?)` | 创建空白画板。 |

### `Project` —— 有状态构建器

`template / create / duplicate / deleteArtboard / update / move / flip / reorder / copy / flow / exportHuman` —— 每个方法追加一条 CLI 命令并返回 `this`；`exportHuman()` 执行整批并返回 canonical `.mbt.md`。

### `DDP` —— 容器编解码

`encrypt(mbt, password, { codecPath?, moonvizDir? })` 与 `decrypt(bytes, password?, options?)`。DDP1 = Argon2id + XChaCha20-Poly1305；DDP2（空密码）= zstd + CRC32，不加密。

### 工具函数

- `findPrebuiltCli()` —— 定位预编译引擎二进制（`MOONVIZ_CLI_BIN` 或 `moonviz-bin-<platform>` 包）；回退模式下返回 `null`。
- `defaultMoonvizDir()` —— 相对 SDK 包自动发现引擎目录。
- `encodeProps(props)` —— 对象 → CLI `k=v` 片段（字符串加 JSON 引号）。
- `EngineError` —— `apply()` 抛出；`.error` 为引擎错误码，`.detail` 保留原始响应。
- `build(engine, recipe)` —— 一次性 Project 工厂。

## 自检

```bash
cd moonviz && node sdk/node/test/selftest.mjs
# SDK selftest passed: template/update/flow/export/render/DDP1/DDP2 all OK
```

覆盖全链路：模板 → 操作 → 导航流 → 双门禁导出 → 渲染 → DDP1/DDP2 往返。

## 许可

MIT © MoonViz contributors
