# MoonViz 发展路线图

> 当前基线：**v0.2.0**（moonc ≥ 0.10.14 · tag engine-v0.1.11 已挂，GitHub Release / mooncakes 待发布） · `moon test` 全绿（默认目标 + native） · 组件目录 65×117 · 仓库 190+ commits · `moon test` 全绿（默认目标 + native） · 组件目录 65×117 · 仓库 170+ commits

## 0.1.9 · 组件规范（norms）——弱模型的"能用但不精致"三类根因

检测与修复共享同一判据（core/norms.mbt），定位是**指导与规范，不做硬门**——不改双门语义，存量文档不产生新视觉债：

- **按钮不卡文案**：操作组件（button/chip/tag/fab）文案必须与边缘留白——
  宽 ≥ 文案宽+24（左右各 12），高 ≥ 字号+20（chip 28 / tag 22 / fab 56 档位
  与 component_norm 下发档对齐；多行文案按行数计高）。
- **圆角档**：方正圆润族（button/chip/tag/select/search_bar/fab）归 8px 档，
  超出 高/2 收敛（胶囊 高/2）；avatar 正圆 radius 999。
- **全宽条/全宽行直角**：app_bar/tab_bar/list_item/divider 占满画板宽度时
  圆角归 0（圆角会顶出屏幕边缘）。
- **critique 第 9 维 `norms`**：偏差计数给分，建议自带换算好的尺寸——
  Agent 读到就能改，不必自己算。
- **auto_fix 规范预修**：`norm_fix_pass` 一键修复；只覆写真正变化的维度，
  `fill`/`hug` 尺寸策略不被圆角-only/高度-only 路径静默降级。
- **`list_components` norm 字段**：每条目携带一句话规范——Agent 选组件时
  即可见规范，不必等 critique 事后纠正。

## 0.2 方向 · 视觉语言升级——呼吸感 · 多彩感 · 生命感（对标 namethatui.com 的 UI 讲究）

namethatui.com 的气质是"每个 UI 细节都有名字、都有讲究"（Bento Grid / Toast / Scrim /
Status Dot / Hover Lift……90+ 词汇）。dev 线的深化目标与之对齐：生成的原型不止
"能用不出错"（norms 已兜底），还要**像精选 UI 一样有呼吸、有层次、有生命**。

### 诊断：平在哪（代码事实，非印象）

1. **渲染能力闲置**：渐变（`collect_gradients`）、三档阴影（shadow e1/e2/e3）、
   blur/blend/opacity/tracking 全部已支持，但生成模板一律 `shadow="none"`、
   `fill="#FFFFFF"`、纯色平铺——能力在 core，表达为零。
2. **色彩系统单薄**：palette 只有 主色+中性 两层；无 surface tint（带色相的浅底）、
   无辅助色角色（成功/警示/信息/高亮），整板一个强调色 → "简单、配色单一"的直接来源。
3. **间距无节奏**：gap 均匀密排（如 163px 统计卡 24px 等距），组内/组间/分区
   不分层，无留白率意识 → "挤、没有呼吸感"。
4. **层次靠运气**：字号/字重/透明度差异无规则，卡片之间无 elevation 差异，
   divider 直角与圆角混用。

### 三支柱（全部走生成层 + 规范层，不新增渲染原语）

**1. 呼吸感（Breathing）**——间距节奏与密度档
- 间距语言规则化：组内 gap ≤ 组间 gap ≤ 分区间距（建议 8/16/24 与 24/32/48 两档），
  容器内边距 ≥ 分区间距的一半；整板留白率（非内容面积占比）进 critique 第 10 维。
- 密度档进 design spec：`comfortable`（默认，呼吸优先）/`compact`（信息密度优先），
  影响模板 gap/padding 全链路取值。

**2. 多彩感（Colorfulness）**——色彩角色体系，不是满屏彩
- surface tint：中性底 → 主色低饱和浅底（如 primary-50 系），画板底/卡片底/高亮块
  分层带色；白色只做"浮起层"，不再做默认底。
- 多角色强调：accent（主操作）+ accent2（信息/图表）+ success/warning/info 语义色，
  图标、徽标、状态点、统计数字分角色上色；每板彩色面积占比有上限（rules 档），
  越界走 spec_violations。
- 底线不回退：#23 对比度硬标准照旧裁决——tint 底与浅色文字必须仍过 4.5:1。

**3. 生命感（Liveliness，视觉的）**——层次与 elevation 语言
- elevation 规则化：卡片 e1、浮层/弹层 e2、主角卡 e3；同级元素阴影一致，
  阴影滥用（全板 e3 / 文本节点带阴影）进 norms 检测。
- 渐变点睛：hero 区/统计块/主按钮允许线性渐变（复用既有 gradient 填充），
  其余区域保持纯色——渐变是强调，不是底色。
- 层级丰度：标题/副文/元数据三级（字号 20/14/12 + 字重 bold/normal/normal +
  透明度 1.0/0.9/0.6），配 #25 语义样例数据的丰度要求。
- 圆角语言搭配：大容器圆角 > 卡片圆角 > 控件圆角（如 20/12/8），divider 全宽直角
  不变；搭配错误（卡比容器圆）进 norms。

### Style Profiles——风格画像进 design spec

在 issue #24 spec 基础上扩可选键：`style: calm | vivid | editorial | playful`，
每个 profile = 一组确定参数（tint 深度 / accent 数量 / 阴影档 / 圆角比 / 密度）：

| profile | 参考气质 | tint | accent | 阴影 | 圆角 |
|---|---|---|---|---|---|
| calm（默认） | iOS HIG / 清爽 SaaS | 浅 | 1+语义 | e1 为主 | 12-16 |
| vivid | 多彩 Bento / 青春产品 | 中 | 2+语义 | e1-e2 | 16-20 |
| editorial | 杂志感 / 大留白 | 极浅 | 1 | 近无 | 4-8 |
| playful | 童趣 / 圆润 | 中高 | 2+ | e2 明显 | 20+ |

生成按 profile 取参，norms 按 profile 阈值裁决（复用 NormsProfile 单次解析），
白名单偏差随信封 `spec_violations` 上报——与既有 spec 闭环完全同构。

### 落点与顺序

**第一阶段已落地（dev，美学第一要素：Apple HIG / HarmonyOS）**：
- ✅ 美学主题预设 apple/apple_dark/harmony/harmony_dark——官方色板的 WCAG 校准
  翻译（逐档 ≥4.5:1 由测试锚定），三通道等价：意图美学词 / spec `style` 键 /
  `theme` 命令，暗色意图自动合流到暗色预设；
- ✅ 生命感：组件默认 elevation 三档（内容卡 e1 / 浮层 e2 / 模态 e3），阴影档
  提浓到可见档；按钮族文字默认居中；输入层中性底；
- ✅ 呼吸感：导出画布 = tinted background、卡面 = 白浮起（iOS 分组语义），
  画板根节点不再描幽灵虚线；仪表盘模板画出真实主色圆角柱状图；
- ✅ critique 第 10 维 `visual`（文字阴影 / 卡片融底 / 同心圆角，只报不修）；
- ✅ spec 第一权威（需求 → Agent 提取 → 引擎跟随）：palette 扩展键
  （secondary/info/warning/*Container），容器色从 spec 语义色对背景推导
  （不落引擎预设），spec 令牌先于模板实例化，调色板外字面色进 `spec_violations`；
  新色彩角色 info/success_container/warning_container/info_container 进全部
  预设（text_primary 压每只 ≥4.5）；list 分类 chips 容器色四色轮换（角色用色）；
  norms visual 容器可辨性扩到 tinted 全族（对比 < 1.10 且无阴影无描边）。
- ✅ 强制规范流程：`generate_from_doc` 从设计文档确定性提取 spec（缺关键项
  `design_doc_spec_gaps` 拒绝生成，来源 `spec_source:"design_doc"`）；
  `design_compliance` 四检（color/type/radius/motion）证明 UI 与交互完全遵从。
- ✅ 主题系统第三批：vivid/editorial/playful 风格画像为一等预设（13 套），
  spec `style` 三通道同权；动画 `Spring(k)` 过冲随刚度调制（k=1 兼容旧导出）。
- ✅ H5/CSS/JS：导出 chrome 全部令牌化为 CSS 变量（明暗随主题、theme-color、
  安全区呼吸边距、窄屏等比缩放）、Vibrancy 磨砂吸顶胶囊 tab、设备感画板（分层
  柔阴影 + hairline）、Hover Lift 仅给可交互节点、键盘 Enter/Space 可达、
  haptic 真振动（navigator.vibrate）。

**后续阶段**：
1. **tokens 层**（core/tokens.mbt）：surface tint / elevation 语义 / accent 角色命名
   入 token，vivid/editorial/playful profile 预设表收敛于此（单一事实源）。
2. **生成层**（core/generate.mbt + 组件默认样式）：其余模板按间距节奏与角色取色
   重构；栈卡内的多级文字层级需要先解决「normalize 收编进栈卡被重排」的坐标
   语义（当前以无布局 rect 面板绕行）。
3. **规范层**（core/norms.mbt，软路径）：留白率 / 彩积比两项量化指标。
4. **spec/DDP 层**：spec 新键向后兼容（缺省 = 保留当前主题），playground 加
   style 切换对比。

验收：同一 intent + 不同 profile 出稿，留白率/彩积比/elevation 分布可量化且显著
区分；对比度与双门禁零回退；playground 预览可切 profile 对比。

## 当前基线盘点

| 维度 | 现状 |
|---|---|
| 引擎内核 | 100% MoonBit，52 个核心模块、300+ 公开函数；不崩谓词 5 项 + 双门禁 |
| 工具面 | CLI 63 命令（cli_help 文档化口径）· MCP 57 工具（含 inputSchema 字典）· WASM 双产物 77/77 导出· Node SDK |
| 组件与模板 | 65 组件 × 118 变体 · 14 个整页模板（移动 + Web/桌面） |
| 分发 | npm 7 包 + GitHub Releases 全产物 10 项（4 平台 tarball + 双 wasm + npm 全家族） |
| 人类体验 | Playground 设计工作台（设计/预览双模式）+ deepDesign Studio 画布 |
| 质量治理 | 5 个下游 issue 全闭环；契约测试（wasm/contract_test.mbt）锁定回归 |

## 路线图

按 **能力平权 → 体验深化 → 生态扩展** 三层推进。优先级依据真实缺口测量，不预设时间表。

### P0 · 能力平权（核心模块 → 边界全通）

**1. 搁浅模块出井。** collab/history/animation/prototest 已于 0.1.x 补齐 CLI 命令 + MCP 工具边界（见文末附表）；**剩余真实缺口**是 wasm 会话面（仅 history 有 `session_history`，其余三者不可达）与最后的搁浅模块 `core/variants.mbt`（实测 CLI/MCP/WASM 均无调用）：

| 模块 | 能力 | 已达边界 | 剩余缺口 |
|---|---|---|---|
| `core/collab.mbt` | 多 Agent 操作变换（OT）、冲突检测、三方合并 | CLI · MCP | wasm 会话面 |
| `core/history.mbt` | 设计版本控制：时间旅行、分支、变更回放、undo/redo | CLI · MCP · WASM(`session_history`) | —— |
| `core/animation.mbt` | 属性动画：关键帧、缓动函数、时间线编排、CSS 导出 | CLI · MCP | wasm 会话面 |
| `core/prototest.mbt` | 原型测试：断言式验证导航/输入/渲染/违规 | CLI · MCP | wasm 会话面 |
| `core/variants.mbt` | fork/score/merge 变体探索 | ——（无任何外部调用，实测仅 core 内部与测试引用） | CLI + MCP + wasm 会话面（最后搁浅模块） |

交付：按既有模式补齐剩余缺口（collab/animation/prototest 的 wasm 会话面 + variants.mbt 全边界），文档同步，测试锚定。

**2. classic wasm 写路径。** Rust/wasmtime 宿主目前只能读（无参调用）。补齐 `session_*` 入参方向：在 wasm 边界导出字符串分配辅助（宿主写入线性内存 → 引擎构造 MoonBit String），打通 `render_mbt` / `apply_*_op` / `session_apply_*` 的双向调用。

**3. Node SDK 会话封装。** `moonviz-engine-sdk` 的 `MoonViz` 类目前走 CLI 通道；对齐 wasm SDK 的 session API 形态（open/apply/lint/…/count），让 Node 宿主与 WASM 宿主共享同一套调用心智。

### P1 · 体验深化
- **显式层叠语义（issue #17 延伸）**：部分相交的合法层叠（半透明遮罩、
  贴边装饰）目前 AgentGate 下无正道——全包含已由 0.1.5-fix 豁免，但
  「显式声明 A 压 B」需要节点级 layer 声明或 reorder 感知豁免；
  设计约束：声明走双门、序列化/decl 往返保持、不复活视觉债遮蔽。

**4. deepDesign Studio 全面接入新引擎。** 引擎能力面（57 工具/27 op/组件库/交互面板/主题令牌）与 Studio 画布对齐：画布撤销/重做（引擎 revision + journal 已就绪）、组件库拖放、交互面板、源码视图直读 `.mbt.md`。

**5. Playground 能力补全。** 动画系统接入（`animation.mbt` → 预览模式实时动效）；用户组件编译入口（MCP `component_compile` 已有，Playground 缺 UI）；原型测试面板（`protest.mbt` 断言可视化运行）。

**6. ddpView 只读查看器。** macOS 原生查看加密 DDP 文档并渲染交互原型（DDP1 加密 / DDP2 免密容器）。

### P2 · 生态扩展

**7. npm 0.2.0 发版。** 纳入 session API 全量 + issues #1–#5 修复 + 双语 README；win32-x64 包待 npm 风控解除后补发（GitHub Releases 渠道已可用，Windows 用户不受阻）。

**8. 在线 API 参考。** 官网已有工具字典（tools.json）与 op 字典（ops.json）；补参数级 API 参考与示例库（每个工具一个最小可运行用例）。

**9. 多 Agent 协作场景落地。** `collab.mbt` 的 OT/冲突解决接进 Studio：两个 Agent 会话同改一份 `.mbt.md`，冲突显式呈现而非静默覆盖。

**10. 性能基线进 CI。** `benchmark.mbt` 的输出（节点数/深度/Fill 密度/评分）纳入构建流水线，布局复杂度回归自动告警。

## 治理原则

- **每条路线以“数据模型已支持但边界不可达/体验未落地”为线索**——core 是资产，边界和体验是债务；
- **能力过界必须同源**：新能力一律从 core 单一事实源派生到各端，字典/测试/文档同步锚定；
- **不破坏既有契约**：`.mbt.md` 格式、双门禁语义、JSON 信封向前兼容，破坏性变更走显式 PR + 契约测试红绿评审。

---

## 附：当前搁浅模块清点（测量于 v0.1.1）

```
模块                公开函数    CLI            MCP                    WASM
core/collab.mbt     OT/冲突/合并  ✓(collab-merge) ✓(collab_merge)      ✗
core/history.mbt    版本控制       ✓(history×7)    ✓(history)           ✗
core/animation.mbt  动画/CSS导出   ✓(anim-css)     ✓(animation_css)     ✗
core/prototest.mbt  原型测试断言   ✓(protest)      ✓(protest)           ✗
core/runtime.mbt    交互运行时     ✓(tap)          ✗                    ✓(session_tap)
core/reasoning.mbt  自然语言约束   ✓(constrain)    ✗                    ✗
core/variants.mbt   变体探索       ✗               △(部分)              ✗
```

> 测量方法：`grep -c "<module>" {cli,mcp,wasm}/main.mbt`。P0-1 已消灭四个 ✗ 行；
> `core/variants.mbt`（fork/score/merge 变体探索）是剩余最后一个搁浅模块，列入下一轮。
