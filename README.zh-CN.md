# MoonViz — AI 时代的 Agent 驱动原型设计基础引擎

> 🇬🇧 English: [README.md](./README.md)

**`.mbt.md` 是唯一事实源，MoonBit 是统一计算内核。Agent 通过工具 API 发现组件、放置元素、检查质量、修复违规——全部走结构化文本协议。本仓库 100% MoonBit，零手写 JS/Node。**

```
┌─────────────────────────────────────────────────────────────┐
│  Agent (任意 LLM)                                            │
│  发现组件 → 创建画板 → 放置元素 → lint → 修复 → 导出         │
└──────────────┬────────▲─────────────────────────────────────┘
               │ Agent Tools API (11 tools, JSON in/out)
┌──────────────▼────────┴─────────────────────────────────────┐
│  引擎 core/ + decl/（纯 MoonBit 库）                          │
│  ┌────────────┐ ┌────────────┐ ┌───────────┐ ┌───────────┐ │
│  │ DesignTokens│ │ Components │ │ Project   │ │ Agent API │ │
│  │ 16色/7距/  │ │ 8组件×22   │ │ 多画板/流  │ │ lint/diff │ │
│  │ 6角/8字号  │ │ 变体       │ │ /令牌/组件 │ │ /suggest  │ │
│  └────────────┘ └────────────┘ └───────────┘ └───────────┘ │
│  ┌────────────┐ ┌────────────┐ ┌───────────┐ ┌───────────┐ │
│  │ Scene Graph │ │ 布局求解    │ │ 不崩谓词   │ │ 声明往返   │ │
│  │ 节点树      │ │ Fixed/Fill │ │ P0–P4     │ │ .mbt.md   │ │
│  └────────────┘ └────────────┘ └───────────┘ └───────────┘ │
│  ┌────────────┐ ┌────────────┐ ┌───────────┐               │
│  │ SVG 输出    │ │ PNG 像素   │ │ 终端画布   │               │
│  │            │ │ DEFLATE+AA │ │ ANSI 真彩 │               │
│  └────────────┘ └────────────┘ └───────────┘               │
└──────────────┬────────▲─────────────────────────────────────┘
               │ .mbt.md 事实源
┌──────────────▼────────┴─────────────────────────────────────┐
│  decl/login.mbt.md 等（随 moon check/test 编译执行）           │
└─────────────────────────────────────────────────────────────┘
```

## Agent 工具清单（47 个）

| 工具 | 语义 |
| :--- | :--- |
| `list_components` | 列出所有可用 UI 组件（含变体/描述/分类） |
| `list_tokens` | 列出设计令牌（颜色/间距/圆角/字号） |
| `create_artboard` | 创建新画板（name, width, height） |
| `list_artboards` | 列出项目中的所有画板及元数据 |
| `place_component` | 在画板上放置组件实例 |
| `query_nodes` | 按类型/组件/文字内容查询节点 |
| `lint_design` | 设计质量检查（对比度/触控/间距/一致性） |
| `get_violations` | 获取不崩谓词违规列表 |
| `suggest_fix` | 针对违规给出可执行修复补丁 |
| `export_svg` | 导出画板为引擎派生 SVG |
| `read_mbt` | 读取并校验完整 `.mbt.md` 源码 |
| `render_mbt` | 从 `.mbt.md` 重新解析并渲染 |
| `ddp_view` | 只读 DDP 查看与渲染契约 |
| `export_react` | React TSX 组件桩（仅代码生成，不是事实源） |
| `apply_template` | 从模板生成完整画板（一句话→整页面） |
| `fork_variants` | 分叉设计变体（A/B 测试并行探索） |
| `score_variants` | 对所有变体评分（违规/lint/对齐/丰富度） |
| `merge_variant` | 合并最优变体回主分支 |
| `auto_arrange` | 垂直等间距自动排列 |
| `snap_to_grid` | 吸附到 N px 网格 |
| `center_in_parent` | 父容器居中 |
| `suggest_alignment` | 检测近似对齐并建议吸附 |

## 内置页面模板（8 个完整页面）

| 模板 | 内容 |
|:---|:---|
| `login` | Logo + 标题 + 邮箱 + 密码 + 登录按钮 + 注册链接 |
| `signup` | 标题 + 姓名 + 邮箱 + 密码 × 2 + 注册按钮 |
| `dashboard` | App Bar + 统计卡片 2×2 + 图表 + 活动列表 |
| `profile` | 头像 + 姓名 + 简介 + 统计 + 操作 + 内容列表 |
| `settings` | 4 分组（通知/隐私/外观/关于）+ 退出按钮 |
| `list_detail` | 列表页 + 详情页 |
| `onboarding` | 三页引导 |
| `empty_state` | 插图 + 文案 + CTA 按钮 |

## 内置组件库（8 组件 × 22 变体）

| 组件 | 分类 | 变体 |
| :--- | :--- | :--- |
| `button` | actions | primary / secondary / danger |
| `text_input` | inputs | default / filled |
| `card` | layout | elevated |
| `app_bar` | layout | surface / primary |
| `divider` | layout | default |
| `heading` | display | h1 / h2 / h3 / h4 |
| `body_text` | display | body / caption |
| `badge` | display | primary / success |

## 设计 Lint

| 规则 | 严重级 | 检查 |
| :--- | :--- | :--- |
| `contrast` | error | 文字对比度 ≥ WCAG AA 4.5:1 |
| `touch_target` | warning | 交互元素 ≥ 44×44 |
| `spacing` | info | 容器内间距 ≥ 8 |
| `empty_container` | warning | Frame 无子元素 |

## 快速开始

### 环境搭建

```bash
# 1. 安装 MoonBit 工具链（需要 moon ≥ 最新稳定版）
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
moon version    # 验证：~/.moon/bin/moon 已在 PATH

# 2. clone 引擎仓库
git clone https://github.com/asdshuaishuai/moonviz && cd moonviz

# 3.（可选，DDP 加密分发需要）构建 Rust 编解码器
cd ddp && cargo build --release && cd ..
#    产物 ddp/target/release/ddp_codec（stdin JSON → stdout JSON）
#    可用 MOONVIZ_DDP_HELPER 指定路径；SDK 会自动在 ddp/target/{debug,release} 下查找

# 4. 全量测试（174 项）
moon test
```

### 首次运行

```bash
# A. 有状态 CLI 会话：stdin 逐行命令 → stdout 逐行 JSON
moon run --target native cli
template login t_login 390 844     # 从模板建画板
update t_login welcome_title text="欢迎回来"
flow t_login t_home login_btn      # 登录按钮 → 跳转主页
export-mbt-human                    # HumanGate 校验 + 返回 canonical .mbt.md
exit

# B. 无会话单发：渲染 / 校验（base64 承载多行 MBT 源码）
moon run --target native cli <<< "render-mbt-b64 $(base64 <<< "$MBT")"

# C. MCP Server（stdio JSON-RPC，接入任意 MCP 客户端）
moon run --target native mcp

# D. 预编译二进制（无需工具链，毫秒级启动）
moon build --release --target native mcp
_build/native/release/build/mcp/mcp.exe   # 自包含可执行（仅链接 libc）

# E. 交互式画布 / 脚本演示
moon run --target native playground       # 交互式（png 命令出 PNG）
moon run playground                       # 脚本演示
```

## 目录导览

```
moonviz/
├── core/
│   ├── node.mbt       节点树（Scene Graph）
│   ├── layout.mbt     布局求解器
│   ├── predicates.mbt 不崩谓词 P0–P4
│   ├── policy.mbt     双路线策略（人类软/Agent 硬）
│   ├── patch.mbt      事务式补丁
│   ├── tokens.mbt     设计令牌（Material 3 风格）
│   ├── component.mbt  组件系统（8 组件×22 变体）
│   ├── project.mbt    多画板项目 + 导航流 + lint + 修复建议
│   ├── agent_api.mbt  Agent 工具 API（47 工具 + list-ops 字典）
│   ├── autofix.mbt    自动修复引擎（溢出缩放/重叠平移）
│   ├── templates.mbt  页面模板库（登录/仪表盘/设置/个人主页/空状态…）
│   ├── align.mbt      智能对齐（网格吸附/居中/等距/近似检测）
│   ├── variants.mbt   变体探索（fork/评分/合并）
│   ├── interaction.mbt 交互原型（Trigger/Action/Transition/导航栈）
│   ├── artifact.mbt   Agent 中间产物（.moonviz 跨 Agent 交接）
│   ├── runtime.mbt    嵌入式运行时 SDK（事件/渲染计划/热重载/输入）
│   ├── intelligence.mbt 设计智能（页面类型推断/缺失检测/建议/评分）
│   ├── lineage.mbt    血缘追踪（令牌/组件使用 + 变更影响分析 + 设计系统审计）
│   ├── prototest.mbt  原型测试（断言式验证导航/输入/渲染/违规）
│   ├── reasoning.mbt  布局推理（自然语言约束→StackLayout/对齐/缩放）
│   ├── responsive.mbt 响应式断点（手机/平板/桌面自动适配）
│   ├── collab.mbt     多Agent协作（操作变换OT/冲突检测/三方合并）
│   ├── history.mbt    设计版本控制（时间旅行/分支/变更回放/undo-redo）
│   ├── critique.mbt   AI设计批评（8项设计原则自动评审）
│   ├── annotate.mbt   设计标注（自动生成Spec文档/CSS变量/间距颜色字体标注）
│   ├── animation.mbt  属性动画（关键帧/缓动函数/时间线编排/CSS导出）
│   ├── extract.mbt    设计系统反向提取（从现有设计推推断牌+组件模式）
│   ├── theme.mbt      主题系统（6预定义主题/自动暗色/令牌级切换/注册表）
│   ├── slots.mbt      组件插槽系统（6组合式组件/嵌套内容分发/递归组合）
│   ├── benchmark.mbt  性能基准引擎（节点统计/复杂度分析/反模式检测/优化建议）
│   ├── diff.mbt       语义 diff（added/moved/resized/restyled）
│   ├── export.mbt     HTML 原型 + React TSX 导出
│   ├── svg.mbt        SVG 渲染
│   └── agent_test.mbt Agent 工作流端到端测试
├── decl/              声明 DSL + .mbt.md 往返
├── cli/               Agent 命令行接口（换行分帧 JSON 行协议，一个进程 = 一个有状态会话）
├── mcp/               MCP Server（stdio JSON-RPC，工具面同 CLI）
├── wasm/              WASM-GC 边界（render_mbt / validate_mbt，JS String Builtins 直通）
├── ddp/               Rust ddp_codec：DDP1 加密（Argon2id+XChaCha20-Poly1305）/ DDP2 免密（zstd+CRC32）
├── sdk/node/          Node SDK「moonviz-engine-sdk」：会话/Project 构建器/DDP 桥（纯传输层）
├── sdk/wasm/          WASM SDK「moonviz-engine-wasm」：进程内渲染/校验，零工具链（Node ≥22 / 现代浏览器）
├── npm/               npm 分发：moonviz-mcp（启动器）+ moonviz-bin-<platform>（预编译平台包）
├── playground/        终端画布 + PNG 渲染 + REPL
├── site/              官网（GitHub Pages：asdshuaishuai.github.io/moonviz/）
├── scripts/           publish-npm.sh 等发布脚本
└── docs/              设计文档 01–09
```

## 交互原型系统

原型不是静态图——MoonViz 有完整的交互运行时：

| 概念 | 说明 |
|:---|:---|
| **Trigger** | tap / long_press / swipe / keyboard / focus / blur |
| **Action** | navigate_to / back / toggle_state / set_text / submit_form / show_toast |
| **Transition** | push / pop / modal / sheet / fade |
| **ComponentState** | 组件多态（default / pressed / disabled / loading） |
| **NavigationState** | 导航栈（push / pop / back） |

## Agent 中间产物（.moonviz）

Agent A 设计完 → 导出 `.moonviz` JSON 文件 → Agent B 读取继续工作。

```json
{
  "meta": { "version": "0.1.0", "created_by": "agent-abc", "context": "Food delivery app" },
  "artboards": { "login": { "name": "Login", "size": [390,844], "decl": "..." } },
  "flows": [{ "from": "login", "to": "home", "trigger": "tap:submit" }],
  "todo": ["Add form validation", "Create error state"],
  "notes": [{ "artboard": "login", "note": "Email needs regex", "priority": "high" }]
}
```

## 嵌入式运行时 SDK

其他项目嵌入 MoonViz 的方式：

```moonbit
let rt = MoonVizRT::create(project, initial_artboard="login")?
rt.set_input("email", "user@test.com")
let changes = rt.handle_event(TapEvent(160.0, 422.0))  // → 导航到 home
let plan = rt.render_plan()                               // → RenderPlan（后端无关显示列表）
rt.hot_reload(new_decl)                                   // → 热重载（保留导航栈和输入值）
```

RenderPlan 是**后端无关的显示列表**（CmdRect / CmdText / CmdLine / CmdClip），
任何渲染后端（Canvas / Skia / SVG / 终端 / OpenGL）都能消费。

## 设计智能

引擎不只是执行设计——它**理解**设计：

| 能力 | 说明 |
|:---|:---|
| `infer_page_type` | 从节点结构推断页面类型（auth/dashboard/list/profile/settings...） |
| `infer_missing` | 基于页面类型推断缺失元素（"登录页缺忘记密码链接"） |
| `suggest_improvements` | 基于设计原则建议改进（层次/间距/一致性/密度） |
| `design_quality_score` | 综合评分 A-D（层次/一致性/稳定性/丰富度） |

## 血缘追踪

改了一个令牌，哪些节点会受影响？

| 能力 | 说明 |
|:---|:---|
| `token_lineage("primary")` | 所有使用 primary 色的节点（含画板+字段） |
| `component_lineage("button")` | 所有 button 实例的位置和尺寸 |
| `impact_analysis(patch)` | 预览补丁影响（颜色对比度/尺寸溢出/位置） |
| `audit_design_system` | 审计硬编码颜色 → 建议替换为最近令牌 |

## 原型测试

原型不只是"看起来对"——它是**可测试的**：

```moonbit
let pt = ProtoTest::create(project, initial="login")?
pt.tap_and_expect_navigate(160, 422, "home")  // 点击登录→到首页
pt.back_and_expect("login")                    // 返回→回到登录
pt.set_input_and_expect("email", "a@b.com")    // 输入值正确存储
pt.expect_no_violations()                      // 无布局违规
pt.expect_renderable()                         // 渲染计划非空
pt.result() // → {"status":"PASS","passed":5,"failed":0}
```

## 布局推理引擎

Agent 说"居中对齐按钮"，引擎推断参数并执行——不需要 Agent 知道 StackLayout 的 API：

```moonbit
p.apply_constraint("居中对齐", artboard="login")       // → center_in_parent
p.apply_constraint("垂直排列", artboard="login")       // → StackLayout(Vertical)
p.apply_constraint("等宽", artboard="login")          // → 所有 width = Fill
p.apply_constraint("间距 16", artboard="login")       // → gap = 16
p.apply_constraint("放大 1.5", artboard="login")      // → 全部尺寸 × 1.5
p.apply_constraint("网格 8", artboard="login")        // → snap_to_grid(8)
```

支持中英文共 12 种布局意图，数字自动提取（"间距 16px" → gap=16.0）。

## 响应式断点

同一设计自动适配手机/平板/桌面三种尺寸：

```moonbit
p.generate_responsive(artboard="login")
// → 自动创建 login_tablet (768×1024) + login_desktop (1200×800)
//   布局自动适配：手机垂直→平板加宽→桌面水平多列

p.preview_breakpoint(artboard="login", breakpoint="tablet")
// → 预览平板效果

p.list_breakpoint_variants(artboard="login")
// → [{"breakpoint":"mobile","width":390}, {"breakpoint":"tablet","width":768}, ...]
```

| 断点 | 尺寸 | 适配策略 |
|:---|:---|:---|
| mobile | 390×844 | 垂直单列，紧凑间距 |
| tablet | 768×1024 | 垂直保持，卡片加宽×1.2，间距 16 |
| desktop | 1200×800 | 切换水平多列，间距 24，边距 48 |

## 多 Agent 协作

AI 时代的核心场景：**多个 Agent 同时在一个原型上工作**。

```moonbit
let cm = CollabManager::new(base_revision=1)
let agent_a = cm.join("designer_bot")     // Agent A：设计登录页
let agent_b = cm.join("ux_optimizer")     // Agent B：优化布局

agent_a.add_op(OpSetFill("login_btn", "#4B6BFB", "#FF0000"))
agent_b.add_op(OpSetPosition("login_btn", 24.0, 100.0, 400.0, 450.0))

let conflicts = cm.total_conflicts()  // → 0（不同字段，可并行）

// 如果冲突：
agent_b.add_op(OpSetFill("login_btn", "#4B6BFB", "#00FF00"))  // 同字段不同值
cm.total_conflicts()  // → 1（需要解决）
cm.status()           // → "Conflicts: 1 ⚠"
```

**冲突判定规则**：

| 情况 | 结果 |
|:---|:---|
| 不同节点 | ✅ 不冲突 |
| 同节点不同字段 | ✅ 不冲突（可并行） |
| 同节点同字段，值相同 | ✅ 幂等，自动解决 |
| 同节点同字段，值不同 | ⚠️ 冲突，需手动选择 |
| 一方删除 + 另一方修改 | ⚠️ 冲突，建议保留修改方 |
| 双方都删除 | ✅ 幂等 |

**操作变换（OT）**：同时插入同位置时，按时间戳排序确定先后。

## 设计版本控制

每次修改产生一个 commit，Agent 可以时间旅行、分叉分支、回放变更：

```moonbit
let h = DesignHistory::new(doc)
h.commit("agent_a", "改按钮颜色", ops, doc)   // rev 1
h.commit("agent_b", "增大间距", ops2, doc)     // rev 2

h.log()          // → "→ rev2 [agent_b] 增大间距
  rev1 [agent_a] 改按钮颜色
..."
h.checkout(1)    // → 时间旅行到 rev1 的文档快照
h.undo()         // → 回到 rev1
h.redo()         // → 恢复到 rev2
h.replay(0, 2)   // → 回放所有操作
h.branch(1, "experiment") // → 从 rev1 分叉新分支
h.diff(0, 2)     // → 两个版本间的语义差异
```

## AI 设计批评引擎

引擎像**资深设计师**一样评审原型——不是检查规则（那是 lint），而是基于 8 项设计原则给出整体评价：

| 原则 | 检查什么 |
|:---|:---|
| 视觉层次 | 字号种类是否 ≥ 3（有明确的大小对比） |
| 亲密性 | 相关元素间距是否 ≥ 8px（格式塔原理） |
| 对齐 | 节点是否对齐到网格 |
| 一致性 | 颜色是否使用设计令牌 |
| 留白 | 密度是否合理（不过密不过稀） |
| 平衡 | 左右视觉重量是否均衡 |
| 焦点 | 是否有明确的主 CTA（primary 按钮） |
| 节奏 | 间距值是否统一到标准令牌 |

```moonbit
p.critique(artboard="login")
// → {"principles":8,"results":[
//     {"principle":"visual_hierarchy","score":9,"verdict":"good",...},
//     {"principle":"balance","score":6,"verdict":"fair",...},...]}

p.critique_summary(artboard="login")
// → "Design Critique: B (7/10)"
```

## 设计标注（Developer Handoff）

从原型自动生成开发者交接规范——Figma Dev Mode 的等价物：

```moonbit
p.generate_spec(artboard="login")
// → Markdown 文档包含：
//   ## Components（组件清单+变体+尺寸）
//   ## Colors（颜色+语义令牌映射）
//   ## Typography（字号+令牌）
//   ## Spacing（精确坐标）
//   ## Layout（flex-direction/gap/padding）
//   ## CSS Custom Properties（--color-* / --spacing-*）
```

## 属性动画系统

原型需要动效——属性插值 / 缓动函数 / 时间线编排：

```moonbit
let tl = Timeline::new()
tl.add(fade_in_animation("title"))         // 淡入
tl.add(slide_in_right("card"))             // 右滑入
tl.add(press_animation("submit_btn"))      // 按压弹性
tl.add_sequence([modal_present("modal"), shake_animation("error")]) // 顺序编排

tl.to_css() // → 生成完整 CSS @keyframes + animation
```

**6 种缓动函数**：Linear / EaseIn / EaseOut / EaseInOut / Spring / Bounce
**6 种动画预设**：press / fade_in / slide_in_right / modal_present / shake / pop
**编排模式**：并行（add）/ 顺序（add_sequence）/ 延迟

## 设计系统反向提取

Agent 拿到已有原型，引擎自动**反推**出设计系统：

```moonbit
let ds = p.extract_design_system(artboard="dashboard")
ds.summary()
// → Extracted Design System:
//     Colors: 6 tokens
//       primary = #4B6BFB (used 5x, confidence 0.9)
//       surface = #FFFFFF (used 12x, confidence 0.9)
//       error = #BA1A1A (used 1x, confidence 0.5)
//     Spacing: 3 values
//       md = 8px, xl = 16px, xxl = 24px
//     Typography: 4 sizes
//       h2 = 24px, h3 = 20px, body = 14px, caption = 12px
//     Components: 3 patterns
//       card (4 instances), button (2 instances), heading (3 instances)
```

**推断逻辑**：
- 颜色：按使用频率排序 → 亮度/饱和度分析 → 推断语义名（primary/surface/error）
- 间距：识别 gap/padding → 匹配标准令牌名（xs/sm/md/lg/xl）
- 字号：匹配标准阶（display/h1-h4/body/caption/overline）
- 组件：相同 (kind, fill, radius) 的节点 ≥2 个 → 推断为同一组件模式

**提取→再利用闭环**：Agent 从设计 A 提取设计系统 → 用这套令牌和组件创建设计 B → 视觉一致性自动保证。

## 主题系统

一键切换深色/浅色/自定义主题——**所有引用令牌的节点自动更新**：

```moonbit
p.apply_theme("dark")         // → surface 变 #1A1C1E，text 变 #E0E0E0
p.apply_theme("nord")         // → 极地配色
p.apply_theme("high_contrast") // → WCAG AAA 高对比度

p.set_token("primary", "#FF5722")  // 单令牌修改，全局生效
p.preview_themes("btn")            // 预览各主题下按钮的颜色

p.enable_auto_dark()          // 从当前主题自动推导暗色版本
```

**6 种预定义主题**：

| 主题 | 风格 | primary | surface |
|:---|:---|:---|:---|
| light | 浅色（默认） | #4B6BFB | #FFFFFF |
| dark | 深色 | #A5B4FC | #1A1C1E |
| high_contrast | 高对比度 | #0000EE | #FFFFFF |
| sepia | 复古棕 | #8D6E63 | #FAF6F0 |
| nord | 极地 | #88C0D0 | #3B4252 |
| sunset | 落日暖 | #FF7043 | #FFF8E1 |

**自动暗色推导**：`Theme::auto_dark(light)` → 反转亮度，保留色相 → 自动生成暗色版本。

## 组件插槽系统

像 React/Vue 的 children/slots 一样，Agent 把内容放进组件的指定槽位：

```moonbit
p.place_slotted(artboard="page", component_id="modal", instance_id="dialog")
p.fill_slot(artboard="page", instance_id="dialog", slot_name="title", content="Confirm")
p.fill_slot(artboard="page", instance_id="dialog", slot_name="content", content="Are you sure?")
p.fill_slot_with_component(artboard="page", instance_id="dialog",
  slot_name="actions", child_component="button", child_id="ok_btn")  // 递归组合
```

**6 种组合式组件**：

| 组件 | 槽位 | 布局 |
|:---|:---|:---|
| `card` | header / content / footer | 垂直，gap=8，padding=16 |
| `list` | header / item_1..3 | 垂直，gap=4 |
| `form_field` | label / input / error | 垂直，gap=4 |
| `modal` | title / content / actions | 垂直，gap=16，padding=24 |
| `app_bar` | leading / title / trailing | 水平，gap=12 |
| `tab_bar` | tab_1..4 | 水平，gap=0 |

**关键能力**：
- **默认内容**：槽位为空时自动填入默认值（Card header → "Title"）
- **递归组合**：`fill_slot_with_component` 把 Button 放进 Modal 的 actions 槽
- **槽位查看**：`list_slots` 返回所有槽位及其当前内容

## 性能基准引擎

Agent 生成设计后，引擎分析"这个设计跑得动吗"：

```moonbit
let bench = p.benchmark_artboard(artboard="dashboard")
// → { nodes: 15, depth: 3, fill: 8, hug: 2, score: 85 }

let proj = p.benchmark()
proj.report()
// → Performance Benchmark Report
//   Overall: B (72/100)
//   Total nodes: 45
//   [dashboard] 15 nodes, depth 3, 8 Fill, 2 Hug, score 85/100
//   [login] 10 nodes, depth 2, 3 Fill, 1 Hug, score 90/100

p.suggest_optimizations(artboard="dashboard")
// → {"optimizations":1,"detail":[{"type":"reduce_fill","description":"8 个 Fill，固定尺寸可减少求解"}]}
```

**基准指标**：

| 指标 | 含义 | 反模式阈值 |
|:---|:---|:---|
| node_count | 节点总数 | > 100 |
| max_depth | 树最大深度 | > 8 |
| fill_node_count | Fill 节点数（布局求解开销） | > 30 |
| hug_node_count | Hug 节点数（最高开销） | > 20 |
| avg_children | 平均子节点数 | > 15 |
| layout_complexity | 布局求解操作计数 | - |
| svg_bytes | SVG 渲染输出字节数 | - |
| memory_estimate | 内存估算（节点数×200 + 文本×2） | - |

**评分体系**（0-100）：节点数(30) + 深度(25) + Fill(25) + Hug(20) → A/B/C/D

## 双 Gate 与视觉债

两条编辑路线对同一组不崩谓词（P0–P4）采用不同合并门槛（`core/policy.mbt`）：

| | HumanGate（`export-mbt-human` / `apply-human-mbt-op-b64`） | AgentGate（`export-mbt-agent` / `apply-agent-mbt-op-b64` / `render-mbt-b64`） |
|---|---|---|
| 结构谓词（节点丢失/画板空/流断裂） | **硬阻断**——补丁整体拒绝 | **硬阻断** |
| 视觉谓词（溢出/重叠/对比度） | 软提示——允许合并，违规记为**视觉债（debt）** | **硬阻断**——任何违规整体拒绝 |
| 典型形态 | 画布拖拽的中间态可以带债保存 | 程序化修改必须一次到位 |

- **debt 不是错误**：人类路线导出结果中 `debt` 字段携带当前视觉债清单，Studio 侧以角标提示，后续操作或 `auto_fix` 可清偿。
- **Agent 的责任边界**：Agent 路线零容忍——引擎以 Reject 返回阻断性违规清单（画板 + 谓词名 + 详情），Agent 修正后重放补丁；这保证了 Agent 写入永远不劣化文档质量。
- **渲染即验收**：`render-mbt-b64` 按 AgentGate 级标准从源完整重建，任何路线的产物都要过同一道渲染验收。

## 集成方式总览

六条集成路线，同一份 `.mbt.md` 事实源，同一套双 Gate：

| 路线 | 形态 | 适用 |
|---|---|---|
| **CLI 行协议** | `moon run --target native cli`（换行分帧 JSON，一个进程 = 一个有状态 Project 会话） | 脚本、CI、手动驱动 |
| **MCP** | `npx -y moonviz-mcp`（平台预编译二进制，stdio JSON-RPC）或 `moon run --target native mcp` | Claude Desktop / ZCode / Cursor 等 MCP 客户端 |
| **Node SDK** | npm `moonviz-engine-sdk`（spawn CLI：会话/Project 构建器/双 Gate 操作/DDP 桥） | Node 宿主的后端/工具链 |
| **WASM SDK** | npm `moonviz-engine-wasm`（wasm-gc 产物进程内渲染/校验，JS String 直通） | 浏览器、Edge Function、Node ≥22 零依赖渲染 |
| **SKILL** | 仓库根 `SKILL.md`（Agent 操作规范：事实源纪律/双 Gate 语义/红线） | 任意 coding agent 技能挂载 |
| **DDP 容器** | Rust `ddp_codec`（DDP1 加密 / DDP2 免密） | 设计文档加密分发、只读查看器 |

MCP 客户端配置（npx 预编译路线）：

```json
{
  "mcpServers": {
    "moonviz": {
      "command": "npx",
      "args": ["-y", "moonviz-mcp"],
      "env": { "MOONVIZ_DIR": "/path/to/moonviz" }
    }
  }
}
```

环境变量速查：`MOONVIZ_DIR`（引擎根，须含 `cli/moon.pkg`）· `MOONVIZ_MOON`/`MOON`（moon 可执行目录）· `MOONVIZ_DDP_HELPER`（ddp_codec 完整路径）· `MOONVIZ_CLI_BIN`（预编译 CLI 二进制，优先于 moon run）。

## 技术栈与二进制分发

### 绘制方案一句话

一份 `.mbt.md` → 声明解析（literate 块扫描）→ 场景图（节点树 + Fixed/Fill/Hug 尺寸规格）→ **两遍法布局求解**（先尺寸后位置，失败≠崩溃）→ P0–P4 不崩谓词 + 双 Gate 验收 → 三个纯 MoonBit 渲染后端任意消费：**SVG**（矢量主路径：系统字体栈 + elevation 阴影令牌 + 渐变 paint）、**PNG**（自研软光栅：2x 超采样抗锯齿 + 圆角扫描 + 5×7 位图字体 + 纯 MoonBit DEFLATE，产物小 5–20 倍）、**终端 ANSI 真彩画布**（Camera 平移缩放 + pick 拖拽）。任意宿主后端（Canvas/Skia/OpenGL）经后端无关的 **RenderPlan 显示列表**接入。完整管线见 [docs/10-render-pipeline.md](docs/10-render-pipeline.md)。

### 技术栈构成

| 层 | 技术 | 外部依赖 |
|---|---|---|
| 引擎内核 + 三渲染后端 + CLI/MCP | **100% MoonBit** | 仅 `moonbitlang/core` 标准库 |
| WASM 边界 | MoonBit → wasm-gc | 无（JS String Builtins） |
| DDP 编解码 | Rust（独立进程 ddp_codec） | argon2 / chacha20poly1305 / zstd |
| npm 启动器 / Node SDK | 极薄 JS | 零依赖 |

### 二进制分发：moon 只在编译时存在

`moon build --release --target native` 产出**自包含二进制**（CLI 1.26MB / MCP 1.10MB，`otool -L` 验证仅链系统 libc），复制到无 moon、无源码的机器直接可用。分发矩阵：

| 消费者 | 依赖 moon？ | 依赖引擎源码？ |
|---|---|---|
| `npx moonviz-mcp`（MCP 客户端） | ✗ | ✗（源侧工具另配 MOONVIZ_DIR） |
| Node SDK + `moonviz-bin-<platform>` | ✗（自动发现预编译 CLI） | ✗ |
| 浏览器 / Edge（moonviz-engine-wasm） | ✗ | ✗ |
| 引擎开发者 | ✓ | ✓ |

二进制归档同时发布在 GitHub Releases（`engine-v*` tag）——分发不完全依赖 npm。

### MoonBit 工具链风险管理

MoonBit 快速演进，minor 版本存在行为差异的现实风险，对策分四层：

1. **产物冻结**（根本手段）：预编译二进制与 WASM 一经发布即快照——工具链后续破坏性变更不影响任何已分发产物，语言不确定性被隔离在构建时。
2. **构建 pin**：CI（`binaries.yml`）安装**固定版本** moon（`MOON_VERSION` env，当前 0.1.20260209）；升级工具链必须走显式 PR，每次构建以 174 项测试 + CLI/MCP 冒烟挡板验证。
3. **协议稳定**：`SolvedLayout` / `GateDecision` / `RenderPlan` 等对外协议刻意稳定（求解器预留 Cassowary 替换接口），不随语言版本漂移。
4. **组件隔离兜底**：DDP 已示范非 MoonBit 组件独立进程化路线，极端情况下任何组件可按此模式替换而不动 `.mbt.md` 事实源格式。

## 架构红线

- **引擎不依赖任何客户端**：core/decl 是纯库
- **Agent 对引擎零依赖**：通过 JSON 文本协议交互
- **100% MoonBit**：零手写 JS/Node/前端代码

## 文档索引

- 官网与完整使用文档：https://asdshuaishuai.github.io/moonviz/ （使用说明 / CLI / Node SDK / WASM / MCP / SKILL / DDP）

1. [01-architecture.md](docs/01-architecture.md) — 分层架构
2. [02-mbtmd-format.md](docs/02-mbtmd-format.md) — `.mbt.md` 规范与声明 DSL
3. [03-scene-graph.md](docs/03-scene-graph.md) — 视觉文档模型
4. [04-layout-and-predicates.md](docs/04-layout-and-predicates.md) — 布局引擎与不崩谓词
5. [05-sync-pipeline.md](docs/05-sync-pipeline.md) — 双向增量同步管道
6. [06-render.md](docs/06-render.md) — 渲染后端
7. [07-agent-loop.md](docs/07-agent-loop.md) — Agent 工作流与错误修复循环
8. [08-roadmap-risks.md](docs/08-roadmap-risks.md) — 实现路径与风险
9. [09-rendering-ecosystem.md](docs/09-rendering-ecosystem.md) — MoonBit 绘制引擎生态调研
10. [10-render-pipeline.md](docs/10-render-pipeline.md) — **绘制方案与渲染管线完整技术说明**（声明解析 → 布局 → 谓词 → SVG/PNG/终端三后端 + 技术栈 + 二进制分发与工具链风险）
