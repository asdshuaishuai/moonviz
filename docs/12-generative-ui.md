# 12 — 生成式 UI 与 Agent 执行策略（genUI 第一公民 · 工具模式兜底）

> 状态：**已实现**（dev 线）。核心：`core/generate.mbt`（意图解析 + 生成管线 +
> 组合意图）、`core/autofill.mbt`（报告驱动补缺）、`core/ops.mbt`
> （apply_operations 批量 + autofill op）。接入面：CLI / MCP / wasm
> session / op 词汇表四面同构。测试锚点：`core/generate_wbtest.mbt`、
> `core/autofill_wbtest.mbt`、`cli/main_test.mbt`（generate/ops-batch 协议
> 与 canonical 往返）。

---

## 0. 理念与双模裁决

**genUI 是第一公民，工具模式是兜底（以前的不抛弃）**——执行阶梯按成本排
通道、不设权限门槛：

1. `generate` 一句话意图（第一优先）；
2. `template` 显式模板选择；
3. `batch_apply` / `ops-batch-b64` 确定精修一批一次提交；
4. 单条工具——兜底通道：自由形态画板、模板之外的布局、外科手术式修改、
   探查。55 工具 / 27 op 一个不少，逐层下探是正确行为而非失败。

架构红线沿用（docs/01）：**引擎零 LLM、零网络**——自然语言理解属于
Agent 侧；引擎的意图解析是**确定性关键词分类**（同输入恒同决策，歧义给
候选），规范的裁决与布局决策全部留在引擎内。

## 1. 生成管线

```
意图一句话（zh/en + 主题/设备暗示 + "+" 组合段）
   │  parse_generate_intent：确定性关键词计分（先具体后泛化）
   │  兜底：无命中 → empty_state（低置信，page_hint 标注）
   ▼
模板实例化（templates.mbt：模板理解页面语义，14 完整页面）
   │  主题先行（apply_theme 全局，模板经令牌取色）
   ▼
生成即合规（auto_fix：Norms 触控/圆角/撞色先修 + 谓词循环清偿）
   ▼
报告信封：autofix（引擎修了什么）/ missing（infer_missing 缺什么）
         / score（A–D 质量分）/ alternatives（同分候选）
```

信封契约（单通道）：`ok / op / artboard / template / width / height /
replaced（同名覆盖提示）/ page_hint / theme_applied / alternatives /
autofix / missing / score / next`。`replaced` 与 `width/height` 是诚实性
字段——模板可能不消费意图宽度（多数保留内建 390×844），Agent 据此发现
「平板 仪表盘」产出 390 宽这类与意图不符的结果。

## 2. 报告驱动闭环（infer_missing → autofill）

报告不该只读。`autofill <artboard>`（op，debt 类）把 `infer_missing`
报告物化为真实节点：

- **配方表**：按页面类型（auth：忘记密码/注册链接/记住我；list：搜索栏
  锚定 app_bar 下 + 筛选；dashboard：刷新；profile：编辑资料；settings：
  退出登录；通用：加载态）。状态类缺失（表单错误态）不物化——走组件
  状态多态，配方跳过并如实报告。
- **放置策略**：底缘光标堆叠（16px 步进、24px 边距、**root wrapper
  排除**——计入会把光标顶到画布外）；重叠/溢出/触控交由 auto_fix 清偿。
- **幂等性（闭环性质）**：补缺物料文本恰好满足检测器关键词
  （"忘记密码？""记住我"）——补完 `infer_missing` 归零，重跑不放置。

## 3. 组合意图（多画板 + 相邻自动导航流）

`generate "登录+注册"`（+ / ＋ 连接，≤ `GENERATE_MULTI_MAX`=4 段）：

1. **分段**：保守分隔符——空格是单意图正常组成（"登录页 dark" 不受影响）；
   纯主题段（dark）只全局换主题不生成板；过滤后单段退回单通道（主题
   关键词拼回意图，取**唯一页面段**而非 segments[0]——主题段前置不丢页）。
2. **实例化**：逐段分类；同模板重名经 sanitize_id 归一后追加序号
   （去重键与画板 id 同一归一，否则两名归一相同时静默互覆）。
3. **出口启发**：相邻板 A→B 在 A 上就地找含 B 语义关键词（hint 去尾
   "页"）的节点；**中英双语匹配**（内置模板文案是英文——signup/register
   等同义词表），找不到才合成 "前往X" 按钮再连线。流必须指向真实节点
   （validate_flows 契约）。
4. **信封**：`mode:"multi"` + 逐板 `id/template/page_hint/replaced/
   missing_count/score` + `flows` 清单；CLI/MCP/wasm 三面零改动透传。

**canonical 往返零损失**（协议测试锚定）：multi 产物经
`export-mbt-agent` → `load-mbt-b64` 重载，双板与双流原样保留——会话
保存/重开与 wasm canonical 交换同走此路径。

## 4. 批量精修（第二级）

`apply_operations`（core/ops.mbt）：顺序执行、遇错即停、回传断点索引
（与逐条执行语义完全一致）；上限 `OPS_BATCH_LIMIT`=64。CLI
`ops-batch-b64` / MCP `batch_apply`（base64 换行分隔 ops）。

## 5. 接入面矩阵

| 渠道 | 生成（tier-1） | 批量（tier-2） | 补缺 |
|---|---|---|---|
| CLI | `generate` | `ops-batch-b64` | `autofill` / apply-op |
| MCP | `generate` | `batch_apply` | session_apply_agent |
| wasm 会话 | `session_generate`（intent/name 双槽） | session_apply_agent 循环 | `autofill` op 直达 |
| playground | ✦ 生成按钮（意图输入框） | — | ✚ 补缺按钮 |

wasm 宿主契约：`session_generate` 是 sess_mut 语义——成功信封回传
canonical mbt，键控缓存宿主保存它供下次 session_open 使用。

## 6. 不变量（强制）

1. **报告先行**：先读 `score`/`missing` 再决定动作；报告是评审环。
2. **幂等**：组合重跑不崩；autofill 重跑不放置。
3. **单段兼容**：无 "+" 的意图信封字节级不变。
4. **引擎零 LLM**：意图解析确定性；歧义给 alternatives 留精修线索。
5. **工具兜底完整保留**：55 工具 / 27 op 无一删除——阶梯是成本排序，
   不是权限门槛。
6. **生成即合规**：生成物不允许带可见债交付（auto_fix 在信封发出前跑）。

## 7. 测试锚点

- `core/generate_wbtest.mbt`：意图确定性 / 生成即合规 / 组合意图与导航流 /
  主题段 / 上限 / 工具字典计数。
- `core/autofill_wbtest.mbt`：补缺幂等 / 状态类跳过。
- `cli/main_test.mbt`：generate/ops-batch 协议、as 尾部语义、canonical
  往返零损失。
- `wasm/contract_test.mbt`：session_generate 变更回传 canonical mbt + 槽
  变体等价。
