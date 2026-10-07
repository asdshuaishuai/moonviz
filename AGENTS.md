# AGENTS.md — MoonViz 引擎仓库

MoonViz：纯 MoonBit 的 AI-Native 原型设计引擎。`.mbt.md` 是设计项目唯一事实源，
人类画布与 Agent 修改都回写同一份源码；每次预览从源码重建。纯 MoonBit（核心库 +
链 libc）；周边（Node SDK、DDP 加解密）按职能分别以薄 JS 层 / Rust 编解码器交付。

```
core/                引擎内核（组件目录、ops、令牌、谓词、门、渲染、agent_api 工具字典）
decl/                声明式 DSL：MBT 扫描 ⇄ 场景图 ⇄ .mbt.md 双向往返
wasm/                双 wasm 产物：wasm-gc（JS 宿主）+ classic 标准 MVP（wasmtime 等任意运行时）
cli/ mcp/            行协议 CLI + MCP Server（stdio，含 protest proto DSL）
site/                官网 + 文档 + playground（GitHub Pages 部署）
sdk/                 MoonBit SDK 门面包（mooncakes.io：moon add asdshuaishuai/moonviz
                     → @sdk.new/apply/validate/render_svg/canonical——宿主一站式内嵌）
npm/                 npm 分发（mcp / skill / moonviz-bin-*）；engine-sdk / engine-wasm 包源在 sdk/{node,wasm}
.github/workflows/   ci.yml（moonc 硬门 + native 全量测试 + 示例复现）· binaries.yml（全产物构建 + Release 归档）· pages.yml（官网部署）
docs/wasm-abi.md     classic ABI 契约（清单由脚本生成，勿手改）
```

## 元规则（最高优先级，覆盖一切局部习惯）

**每次同步构建产物时，文档、官网、全部产物与 playground 必须一起同步到同一版本基线。**
不存在"只推二进制"或"只改文档"的中间态——产物是基线的落地，文档与 playground 是基线的
声明面。任一侧落后，基线即视为未达成，不允许宣称"已发布"。

版本基线只有两处权威值，互相必须相等（CI smoke 以断言硬门校验，不一致直接 fail）：

- `core/version.mbt` 的 `ENGINE_VERSION`（wasm version_info / CLI banner / MCP serverInfo / artifact meta_version 的唯一来源）
- `.github/workflows/binaries.yml` 的 `MOONVIZ_VERSION`（全产物构建与资产命名基准）

`moon.mod.json` 的 version 随上述两处同步。文档中引用版本示例时用 `<ver>` 占位或动态表述，
**不要写死版本数字**（历史教训：写死示例是计数/版本漂移的头号来源）。

### 同步产物时的检查单（每项都过，缺一项即未完成）

1. **计数类**：组件/变体/工具/测试数改动时，同步清扫 `README.md`、`README.zh-CN.md`、
   `site/docs.html`(`52 工具`/`65×115` 这类)、`site/index.html`(stat 行)、`ROADMAP.md`、`SKILL.md`，
   以及测试断言（如 `core/agent_test.mbt` 的 catalog 数量测试）。
2. **playground**：`COMP_ZH` / `COMP_ICON` 随组件目录补全（JS 语法自校验：两表 key 数
   必须与 `builtin_components()` 一致）；界面方法表与 wasm 导出面对齐。
   `site/assets/`（wasm、tools/ops json）由 pages.yml CI 重建，**不要手编**。
3. **ABI 契约**：`scripts/check-wasm-abi.mjs` 的 `required` 清单以
   `wasm/moon.pkg` 的 classic exports 段为单一事实源生成后烘焙——导出面变动时
   先从 moon.pkg 重新生成再跑脚本，任何手改清单都会漂移（issue #8 一类）。
4. **全量构建**：本地不单独构建产物。流程是 `git push tag engine-v*` →
   `gh workflow run binaries.yml --ref engine-v*` → 等 4 平台 matrix + release 归档 job
   全绿 → 校验 Release 资产（4 平台 bin tarball + 双 wasm 版本化命名 + npm 镜像，按
   release id 直查）→ pages.yml 部署后线上实测（playground 目录计数 / docs 计数）。
5. **下游版本锚定**：deepDesign Studio 的 `scripts/sync-engine.mjs` 按 sha512 锚定引擎
   classic wasm；本次基线含修复但下游未升级时，在汇报中明确标出该缺口（引擎信封修复
   必须先消费侧升级才对宿主可见）。

## 分支策略

- `main` = 发布线（0.x 序列，Release 资产从 main 的 engine-v* tag 构建）
- `dev` = 0.x 主线开发分支（从 main 切出；issue 修复与新能力先进 dev，
  验证后合回 main 发布）
- `release/1.0` = 1.0 长期开发分支（**不发布、暂不并入 main**），
  分支特有能力的文档随分支走；多分支都成立的能力才双写

## 红线（不可回退）

- **classic wasm 保持标准 MVP、宿主中立、零 import**，不为任何宿主特殊编译；wasm-gc 走
  JS String Builtins。这是消费侧（wasmtime / Node / Rust）可复用的前提。
- **空集合 envelope 一律合法 JSON**：`detail`/`missing` 等键为空时必须输出 `[]`，裸 join
  是事故源（issue #10 一类）。新工具加 envelope 时同步写空集合路径的契约测试。
- 工具字典单一事实源在 `core/agent_api.mbt`（`list_tools_json()` / `list_ops_json()`），
  产物 `moonviz-tools.json` / `moonviz-ops.json` 由 CI 从 CLI 生成，改工具描述只改一处。
- `moon test` 全量绿是提交前提；组件目录扩充必须带"全变体放置 + 渲染"冒烟测试。

## MoonBit 原生包（mooncakes.io）

模块名固定为 `asdshuaishuai/moonviz`——**新建 moon 包时 import 必须用此前缀**
（`"asdshuaishuai/moonviz/core"` 等），改名需全仓同步并跑三目标验证。
发布：`moon login`（mooncakes.io 账号）→ `moon publish`，由仓库所有者执行；
版本取自 moon.mod.json，须与 `ENGINE_VERSION` 基线协调。
**已知坑与绕过**（2026-10-07 首次上架验证）：本地网络路径会掐断 mooncake 的
HTTP/2 上传（`receiver is gone`）。绕过 = 协议直发（FastAPI multipart）：
```
moon package    # 产出 _build/publish/<name>-<ver>.zip（尊重 .gitignore！）
curl -X POST https://mooncakes.io/api/v0/publish \
  -F "token=$(python3 -c "import json;print(json.load(open('$HOME/.moon/credentials.json'))['token'])")" \
  -F "file=@_build/publish/asdshuaishuai-moonviz-<ver>.zip;type=application/zip"
```
成功响应 `{"status":"ok"}`；语义化版本每次发布必须递增。
0.1.7 已于 2026-10-07 用此通道上架（[包页](https://mooncakes.io/asdshuaishuai/moonviz)），
「moon add → 编译 → 渲染」闭环实测通过。工具链底线
moonc ≥ 0.10.14，ci.yml 有版本硬门。

## 构建与测试

```bash
moon check                                              # 类型检查
moon test --target native                               # 全量测试（含 wasm 契约测试）
node scripts/check-wasm-abi.mjs                         # classic ABI 断言（本地）
moon build --release --target native cli mcp            # 仅本地验证用；产物发布走 CI
# 发布渠道以 GitHub Releases 为准（npm 仓库暂不入驻，
# scripts/publish-all.sh 仅在用户显式要求发 npm 时使用，浏览器 passkey）
```
