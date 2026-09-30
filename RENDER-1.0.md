# 渲染精致化专项规划（1.0 · M1.5）

> 分支：`release/1.0` · 立项证据：examples/login-demo.mbt.md 实测 SVG（v0.1.6-moon 渲染）
> 本文档是渲染精致化阶段的规划事实源；完成后并入 ROADMAP-1.0 的 GA 门禁。

---

## 0. 立项原因：现状审计（以 login-demo 实测 SVG 为证据）

引擎渲染基座比预期扎实——渐变（2 色线性+角度）、多行文本、图片+圆角裁剪、
虚线描边、e1–e3 投影、9 种混合模式字段、6 主题**均已实现**。粗糙不在"没有"，
而在**精度与体系**。逐项证据：

| # | 粗糙点 | 实测证据（login-demo SVG） |
|---|---|---|
| 1 | 按钮文字未居中 | `登 录` x=36 text-anchor=start，贴左缘；基线 y=550.9 偏低 |
| 2 | 无字重/字体系统 | 全部 `font-weight="normal"`——24px 标题也是 normal；无字体族 token |
| 3 | 输入框=纯色块 | #E8EAF6 填充 + 正文同色占位符；无边框、无焦点环、无内阴影 |
| 4 | 零图标系统 | logo 是纯色圆；输入框无 leading icon；按钮无图标位 |
| 5 | 零 elevation | 按钮/卡片 `shadow: none`——e1–e3 存在但模板无人用 |
| 6 | 无渐变/层次使用 | logo 纯色圆、按钮纯色块（渐变能力已有，组件/模板未消费） |
| 7 | 无状态形态 | hover/pressed/disabled/focus 全无渲染差异 |
| 8 | 对比度不达标 | 副标 #9098A1 on #FFFFFF ≈ 2.9:1（< 4.5:1） |
| 9 | 组件组合深度浅 | 输入框=rect+兄弟 text 节点拼装，无 icon+text 复合结构 |
| 10 | 无装饰能力 | 无噪点/光斑/玻璃/背景模糊（节点 blur 不是 backdrop） |

**结论：精致化的主战场是「组件与模板的消费层」+「绘画规格模型」，不是渲染器推倒重写。**

---

## 1. 目标观感（1.0 验收锚）

- `examples/login-demo.mbt.md` **同一份文档重渲**，达到可直接用作产品宣传图的水准
  （before/after 对照图随版本发布）；
- 「精致度基准页」：65 组件 × 变体矩阵单页渲染，作为质量看板——每次渲染改动看这张图；
- 三份真实 demo（登录 / 仪表盘 / 落地页）全部达到"能当官网首页配图"。

---

## 2. 阶段划分

### R1 · 绘画基座（Paint & Type）

- **PaintSpec 统一绘制模型**：`fill` 从纯色字符串升级为
  `solid | linear(+stops+angle) | radial | image`（向后兼容：纯色字符串仍合法）；
- **字体系统**：字体族 token（display/body/mono 三栈）+ 字重真实映射
  （`semibold/bold` → 600/700，标题不再 normal）+ CJK fallback 链显式声明；
- **文本精度**：placeholder 独立色、垂直居中自动基线（按钮/输入框文字自动居中——修证据 #1）、
  字距/行高按 token；
- **文字自适应缩放与自动换行** ✅（已落地：wrap 按词/逐字断行、`fit=auto|shrink`
  双向字号适配、Fill 宽文本 resize 联动重排，契约测试锚定）：
  - 自动换行 ✅：`wrap_text_lines`——拉丁文按词贪心、CJK 逐字断行，渲染时按节点
    矩形宽实时测量（Text 节点与 rect 载字两条路径均生效）；
  - 自适应字号 ✅：`fit=auto|shrink`——溢出等比缩小（下限 8px），auto 单行文本
    放大填充纵向留白（2× preferred 封顶）；单次比例计算无循环；
  - resize 联动 ✅：画板 resize 后 Fill 宽文本节点渲染时自动重新测量换行。
- **阴影规格化**：ShadowSpec（多层叠加 / 彩色阴影 / inset）+ elevation token（e0–e5），
  组件默认按 elevation 取阴影（修证据 #5）；
- **边框细化**：per-side 宽度、渐变描边、双线。

### R2 · 视觉资产系统

- **内置图标库**：mono stroke 风格 ~120 枚（与 65 组件打通：leading/trailing icon 槽），
  修证据 #4；
- **图片完善**：object-fit（cover/contain/fill）、focal point（已有 slice 裁剪基础）；
- **装饰层**：噪点、光斑（radial bloom）、mesh 渐变预设——给"精致"提供弹药；
- **玻璃拟态**：backdrop blur 的 SVG 近似（半透明+feGaussianBlur 背板）。

### R3 · 组件精致化审计（65 组件逐个过堂）

- 每组件审计单：内边距节奏 / 字阶 / 对比度（≥4.5:1，修证据 #8）/ 图标位 / 状态；
- **状态变体入目录**：default/hover/pressed/disabled 进组件变体体系
  （变体数 115 → ~250+，原型可直接表达交互态）；
- 输入类组件复合化：icon+placeholder+焦点环一体（修证据 #3/#9）；
- **文字自适应审计**：每个含文本的组件在 3 种画板尺寸下验证
  自动换行断行位置合理、自适应字号不溢出不截断、CJK/英文混排换行正确；
- 交付：精致度基准页（组件矩阵单页渲染）。

### R4 · 主题 × 回归

- 6 主题 × 65 组件渲染快照 golden 基线（SVG 源 diff，非 PNG）+ diff 测试进 CI；
- login-demo before/after 重渲 + 三 demo 验收；
- 性能护栏：基准页渲染耗时不劣化超 10%。

---

## 3. 组件自适应能力（1.0 核心，与渲染精致化并列）

组件应当**自行与画板的尺寸、位置自适应**——现在 place 默认 Fixed 尺寸 +
AlignStart 锚定，画板 resize 后组件纹丝不动，精致感无从谈起。

基座已在：PosSpec（Fill/Hug/Fixed + AlignStart/Center/End）、constraint 锚定
（resize_canvas 按 constraint 重排）。缺口是**组件定义不携带自适应策略**、
**place 不写约束**、**父容器尺寸变化不联动**。

交付三件：
- **组件定义携带 adaptive 预设**（ComponentDef 扩展）：如
  `width: Fill` / `anchor: bottom-right` / `保持纵横比` / `外边距恒定`——
  65 组件逐个标定（按钮=横向 Fill、卡片=Fill×Hug、fab=锚右下…）；
- **place 写入约束**：place 时按组件预设落 constraint（Agent 仍可用
  `adaptive <ab> <node> <preset>` 显式覆盖），后续画板/父容器 resize 自动重排；
- **resize_canvas 联动验证**：约束重排已有基座，补快照测试锚定
  「resize 前后布局语义一致」。

- **文字联动自适应**：Fill 宽文本节点 resize 后自动重新换行 + 按比例缩放字号
  （宽度自适应的文本引擎层能力，与组件自适应预设协同）。

验收：调整画板尺寸（390×844 → 1280×800）后，全部组件按预设自适应、
文本节点自动换行且字号自适应、零违规（快照测试锚定）。

---

## 4. 工程约束（沿用既有纪律）

- NodeStyle 字段扩展走 overlay 先例流程：canonical 条件写出 + apply_decl_style 解析 +
  字典/help/SKILL 同步 + 契约测试；
- 旧文档零破坏：PaintSpec 解析器必须兼容纯色字符串（既有 .mbt.md 不改一字仍可渲）；
- 每个视觉改动以「基准页」为验收面板，改动前先出 before 留档。

---

## 5. GA 门禁增补（并入 ROADMAP-1.0）

- [ ] 基准页 before/after 对照随 1.0 发布
- [ ] 6 主题 × 65 组件快照基线进 CI
- [ ] login-demo 重渲达到宣传图水准（消费侧验收）
- [ ] 图标库 / 状态变体 / PaintSpec 进 tools 与 ops 字典
- [ ] 文字自适应缩放 + 自动换行在 3 种画板尺寸下全组件通过

---

## 6. 风险

| 风险 | 应对 |
|---|---|
| NodeStyle 扩展引发序列化面连锁 | 沿 overlay 先例：条件写出 + 解析器兼容 + 契约测试先行 |
| 字体授权 | 只用系统栈 + 开源字体（JetBrains Mono / Noto 家族），不内嵌商用字体 |
| 快照基线体积 | golden 用规范化的 SVG 源 diff（剔除 id/时间戳）而非 PNG |
| 范围膨胀 | 1.0 冻结组件大类（65 个），精致化只做深不做广 |

---

## 7. DSL 完善纪律（1.0 · 渲染/声明双向升级的总开关）

> 核心不变量：`.mbt.md` 仍是唯一事实源。DSL 升级只允许两种形态——
> **新增声明/属性**（overlay 先例）与**既有字段文法扩展**（PaintSpec 先例）；
> 任何升级最终必须能序列化回同一份文档，否则就是第二事实源，直接否决。

### 7.1 DSL 升级七步流程（overlay 已跑通，每个新声明/属性照走一遍）

1. **模型层**：`core/node.mbt` 的 Node/NodeStyle 加字段，`default` 给向后兼容的缺省值；
2. **写出层**：`decltext.mbt` 的 `node_call` **条件写出**（仅偏离缺省时写，保持既有 canonical 零扰动）；
3. **解析层**：`apply_decl_style` 加解析分支，`generic_node` 签名零改动（新增一律走 k=v 扩展位，位置参数冻结）；
4. **门语义**：predicates/autofix 显式决策——新声明是豁免还是新债，不允许"默认行为"，必须写进规划；
5. **读面**：query_nodes 补字段（图层树/属性面板可达，无不可达字段）；
6. **字典**：agent_api + CLI help + SKILL keys 同步（工具字典单一事实源纪律）；
7. **测试**：三段式（未声明行为 → 声明后行为 → 对照不被遮蔽）+ canonical 往返断言。

R1 的 PaintSpec/ShadowSpec/字体 token、R2 的图标槽/装饰层、§3 的 adaptive
预设，每个都按这七步走——"渲染认、解析丢、字典漏"的三不管不允许出现。

### 7.2 PaintSpec 文法细则（`fill` 联合体升级，DSL 升级里最危险的一个）

overlay 是加新字段，旧文档天然兼容；PaintSpec 是把 `fill` 从纯色字符串升级为
`solid | linear | radial | image` 联合体，是文法层面的破坏性候选，必须多想三层：

- **解析分发用显式前缀，不靠猜**：`fill="#FF7A45"` 走旧路径；
  `fill=linear:…` / `radial:…` 走新路径——与渲染消费层既有的
  `linear:`/`radial:` 前缀约定（`core/svg.mbt` Paint DSL 引用）一致，
  前缀即分发依据；
- **写出规范形**：`to_mbt` 写出的 PaintSpec 必须是"解析器能读回且语义同一"的
  规范形（stops 排序、angle 归一化），否则 canonical 往返漂移；
- **`set_token` 穿透决策**：主题切换时纯色 fill 会重着色，渐变里的色标跟随还是
  冻结——R1 内显式定掉（跟随 or 冻结），不留默认行为。

### 7.3 引用语义（图标槽 / 状态变体：声明引用外部资产，DSL 必须定义引用语义）

图标槽和状态变体与 overlay 那种"本节点自包含属性"不同，它们是**引用**：
节点声明 `icon="search"`，实际图形来自引擎内置库。DSL 要回答：

- **引用失效**：图标名拼错 → 解析错误（fail-fast），不静默无图标；
- **状态变体声明位置**：节点上的 `state:pressed` 修饰 vs 独立变体块——
  R3 内评审定掉一种，前者简单，后者可表达整套状态一起定义；
- **读面压力**：变体数 115 → ~250+ 后，`list_components` 变体枚举与 playground
  组件面板的分页/分组——不是文法问题，但 R3 留工作量。

### 7.4 adaptive 是"行为声明"（DSL 从静态描述走向行为的第一步，单独对待）

overlay/PaintSpec/icon 都是"是什么"，adaptive 是"怎么变"（Fill/锚定/保持比例
是 resize 时的行为规则）。推论：

- **区分属性与策略**：DSL 文法上区分**属性**（当前值）与**策略**（变化规则）；
  策略字段缺省值即当前行为（Fixed + AlignStart），旧文档零扰动；
- **`adaptive` op 双门可达**：改的是未来行为不是当前视觉，与 overlay 同级，
  不搞特殊 Gate；
- **语义保持测试**：resize 快照测试"resize 前后布局语义一致"是 DSL
  **语义保持定理**的第一个实例——以后每个行为声明都要有对应的语义保持测试。

### 7.5 双引擎门语义分层（原型 + UI 双重引擎的前提决策，M1 内定掉）

原型引擎容忍粗糙（视觉债放行），UI 引擎要精致（elevation、字重映射、对比度、
adaptive 自适应）。同一个 AgentGate 服务两种精度要求，谓词体系要分层——
UI 模式下现在的"债"哪些升级成"阻断"，必须在 M1 语义补全里定掉并进冻结表；
1.0 后再动门语义就是破坏性变更。

### 7.6 分层原则（引擎宿主中立，deepDesign 做产品表达）

classic 零 import 红线保证引擎不被任何上层绑架；deepDesign 的撤销/组件库/
交互面板是消费侧创新，不反渗引擎内核。两边契约即 session 信封 +
canonical mbt（#19 补齐的那条线）——DSL 侧的新能力经此线透出，不另开通道。
