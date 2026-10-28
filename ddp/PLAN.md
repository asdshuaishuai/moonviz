# DDP v2 多段容器 · 实施规划（PLAN.md）

> 依据：`ddp/FORMAT.md`（v2 容器规范，已定稿：`mbt.md` 真相源 + `design/ui.md` +
> `design/design.json`，PRD 明确不入容器）。本规划是其实现路线；**先规范、后实现、
> 再对齐修复**——每阶段先写测试锚，再写实现。

## 0. 范围

- **做**：lib.rs 段编解码、codec CLI、sdk/node 透传、ddpView 段浏览、CI 兼容矩阵
- **不做**：PRD 段（规范已排除）、派生物入容器（SVG/RenderPlan 纪律不变）、
  旧注释块机制的下线（过渡期保留，见 §4 过渡规则）

## 1. 阶段与验收

### P1 · `ddp/src/lib.rs` 段编解码（地基，先行）

- API：
  - `encrypt_sections(mbt: &str, sections: &[(String, Vec<u8>)], password: &str) -> DdpResult<Vec<u8>>`
  - `decrypt_sections(bytes, password) -> DdpResult<(String, Vec<(String, Vec<u8>)>)>`
  - v1 函数保留为薄包装（单 `mbt.md` 段），零行为变化
- 硬规则（FORMAT §3）：段名 ≤31B 且非空、重复段名拒绝、未知段跳过读、
  段 ≤8MiB / 总解压 ≤16MiB、DDP1 整表入 AEAD（AAD 覆盖明文头）、DDP2 逐段 CRC32
- 测试锚（先写）：
  1. v2 往返：DDP1/DDP2 × 0/1/N 附加段，逐字节还原
  2. v1 读 v2 → `ddp_version_unsupported`；v2 读 v1 → 隐式单 `mbt.md`
  3. 篡改任一字节 → 认证失败 / CRC 失败
  4. 段名重复、空名、超限 → 明确错误码
- **验收**：`cargo test` 全绿；现有 v1 测试零改动通过

### P2 · `ddp/src/bin/ddp_codec.rs` CLI

- 打包：`--section <name>=<path>`（可重复，如 `--section design/ui.md=ui.md`
  `--section design/design.json=design.json`）
- 解包：`--list` 列段名/大小/压缩标志；`--extract <name> [-o path]` 提取单段
- **验收**：examples/login-demo.ddp 解包列出 `mbt.md`；带段打包再解包逐段一致

### P3 · `sdk/node/src/ddp.js`

- `encryptDDP(mbt, password, { sections })` / 解密返回 `{ mbt, sections }`；
  不传 sections 时行为与现在完全一致
- selftest 追加 v2 往返用例
- **验收**：`node sdk/node/test/selftest.mjs` 全绿（Node ≥ 24）

### P4 · `ddpView` 段浏览

- v2 容器：段列表（名称/大小）；`design/ui.md`、`design/design.json` 提供预览；
  未知段显示「已跳过」提示而非报错
- **验收**：打开 P2 产物示例容器可见三段；v1 容器行为不回退

### P5 · CI 与发布

- Rust 测试入 CI（当前 ci.yml 只跑 moon 侧——ddp 的 cargo test 需显式加入，
  这是本规划发现的覆盖缺口）
- 兼容矩阵回归：v1 写 → v1/v2 读；v2 写 → v2 读；v2 写 → v1 读（预期明确失败）
- 发布随下一个引擎版本 tag 走 binaries 流程；ddpView 发版单独排期

## 2. 兼容矩阵

| 写入 \ 读取 | v1 读取器 | v2 读取器 |
|---|---|---|
| v1 容器 | ✅ 现状 | ✅ 隐式单 `mbt.md` 段 |
| v2 容器 | ⛔ `ddp_version_unsupported`（明确失败） | ✅ 全段 |

## 3. 客户端配合项（deepDesign，协调项非本仓实现）

1. 升级读取面：优先读段、段缺失回退 `deepdesign:design` 注释块（过渡期双写）
2. 保存时写入 `design/ui.md` 与 `design/design.json` 两段；PRD 不写
3. 重新 vendor 0.1.10 的 `engine-manifest.json` / `components.json`
  （现存的锚定 0.1.9，session/templates 口径过期）

## 4. 风险与缓解

| 风险 | 缓解 |
|---|---|
| Rust 工具链漂移（0.1.10 已经历一次） | P1 测试锚先行；CI 覆盖 cargo test 后由 CI 兜底 |
| 旧查看器读 v2 明确失败 | 升级顺序锁死：读取面先行，写入方后动；过渡期双写 |
| 段滥用（塞派生物/PRD） | 段名注册表收口 + 未知段跳过；规范明文排除 PRD |

## 5. 顺序与依赖

P1 → P2 → P3/P4（可并行）→ P5。P1 是唯一串行地基；P2 起每阶段可独立交付验收。
