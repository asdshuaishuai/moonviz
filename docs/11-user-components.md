# 11 — 用户自定义组件系统（NL 生成 · 本地持久化 · MCF 专有格式）

> 状态：设计方案（未编码）。需求原文：自然语言描述生成组件；持久化到本地可复用；Agent 与内置组件无差别感知；可通过**专有格式**文件分发（无密码、仅引擎可解析、载荷仍是 `.mbt.md`、声明头与 DDP 分开）。

---

## 0. 需求精确化与架构裁决

**「自然语言生成」的职责切分**（引擎架构红线决定）：

引擎零 LLM、零网络——自然语言理解属于 Agent 侧（DeepOrca / ZCode / 任意 MCP 客户端）。引擎提供的是**组件编译管线**：接收 Agent 翻译好的组件声明，负责校验、实例化测试、规范化、注册。

```
用户（自然语言）──► Agent（LLM 翻译）──► 组件声明（.mbt.md 文本）
                                              │
                    ┌─────────────────────────▼──────────────────────────┐
                    │ 引擎组件编译管线（本方案核心）                        │
                    │ 声明解析 → 结构校验 → 参数闭合检查 → 实例化测试渲染   │
                    │ → 谓词验收（AgentGate）→ canonical 规范化 → 注册入库  │
                    └────────────────────────────────────────────────────┘
                                              │
                    本地组件库（项目级 > 用户级 > 内置）◄── MCF 导入
                                              │
                    place/template/list-components ——与内置组件完全同权
```

这样「用户生成的组件和内置没有任何区别」是架构结果而非模拟：注册表统一、命令面统一、Gate 统一。

## 1. 组件模型（声明 DSL）

自定义组件 = **带参数槽的节点树模板**，声明形式就是一段 `.mbt.md`（与事实源同文法，复用全部解析/序列化设施）：

```moonbit
<!-- moonviz:component cart_button -->
```mbt
///| @moonviz:component cart_button
fn component_cart_button() -> @decl.ComponentDecl {
  @decl.component(
    name="cart_button", category="user", device="mobile",
    params=[
      @decl.param("badge",  kind="text",   default="3"),
      @decl.param("accent", kind="color",  default="#E11D48"),
      @decl.param("size",   kind="number", default="48"),
    ],
    variants=[ "default", "compact" ]
  )
  // 组件体：相对坐标节点树；参数以 @decl.ref("badge") 引用
  let root = @decl.proto(w=@decl.ref("size"), h=@decl.ref("size"))
  root.add(@decl.generic_node(id="icon", component="badge", kind="rect", ...))
  root.add(@decl.generic_node(id="badge", text=@decl.ref("badge"), fill=@decl.ref("accent"), ...))
  root
}
```
```

设计要点：

- **参数槽（v1）**：`text / color / number / enum` 四种 kind，默认值必填；节点属性处 `@decl.ref("<param>")` 引用（实现为 SizeSpec 之外的第三种规格 `Ref(String)`，布局两遍法第一遍前先做**参数代入**得到具体值——管线顺序：代入 → 求解 → 渲染）
- **变体**：命名的参数预设组合（`compact` = `size=36` + 隐藏 subtitle 类节点），v1 用「参数覆盖表」表达，不做结构性变体
- **组合**：v1 组件体只能用内置原语（generic_node）+ 内置组件，**不允许引用其他用户组件**（防依赖环与库扩散；v2 再开 DAG 组合）
- **相对坐标**：组件体以自身 (0,0) 为原点；place 时引擎平移到目标位置

## 2. 本地组件库与加载合并

```
~/.moonviz/components/                 # 用户级（跨项目）
  registry.json                        # 注册表索引
  <component_id>.mbt.md                # canonical 组件声明源码
<project>/.moonviz/components/         # 项目级（随 git 走）
  registry.json
  <component_id>.mbt.md
```

- **合并优先级**：项目级 > 用户级 > 内置（同名覆盖，`list-components` 以 `source: builtin|user|project` 标注）
- **加载时机**：CLI 会话首条命令前 / MCP `initialize` 时扫描合并；解析失败的组件**不阻断启动**，记入 `component-load-errors` 供诊断
- **注册表索引**：`{ id, name, version, params[], variants[], source, file_hash, engine_compat, created_at }`——Agent 感知与 MCF 声明头共用此 schema

**引擎内核改动面**：`core/component.mbt` 的注册表从纯内置改为「内置 + 动态注入」双源；`components_ext.mbt` 现有扩展机制承接注入点；新增 `core/usercomp.mbt`（扫描/解析/合并/生命周期）。

## 3. MCF — MoonViz Component Format（专有组件包）

**与 DDP 的关系**：完全独立的容器族——DDP（`DDP1/DDP2` magic）承载**文档**，MCF 承载**组件**；工具路径、magic、语义互不重叠。声明头（元信息）与载荷（源码）分区，正如需求所述「声明头和 DDP 的格式分开」。

### 字节布局（v1 规范草案）

```
偏移   长度   字段
──────────────────────────────────────────────────────
0      4     magic = ASCII "MVCC"
4      1     version = 0x01
5      1     flags  （bit0: header 压缩；其余预留）
6      4     header_len   LE u32
10     8     payload_len  LE u64
18     4     header_crc32   LE u32（原始 header 字节）
22     4     payload_crc32  LE u32（混淆后的 payload 字节）
26     H     HEADER：专有序列化（TLV 二进制，非 JSON）
                  组件 id/名称/版本/params schema/variants/
                  engine_compat 区间/created_at/author 标签
26+H   P     PAYLOAD：mbt.md 组件声明源码
             （经引擎自逆字节变换，见下）
尾     8     引擎指纹 = FNV-1a(engine_revision || magic) LE u64
```

### 「只有引擎能解析」的三层实现（诚实边界）

无密码格式**不可能防专业逆向**（这是密码学常识），方案把壁垒做成三层结构性私有：

1. **格式私有**：header 用专有 TLV 序列化（非标准容器，第三方无 schema 读不出结构）；payload 施加**内生自逆变换**——xor 流的密钥由 header 前若干字节 + header_crc 派生（不来自任何密码，来自格式自身），顺带 payload_crc 对变换后字节计算，第三方即便猜到是 mbt.md 也须逆向整套规范
2. **管线私有**：MCF 的唯一合法入口是 `component-import`——导入必经「结构校验 + 参数闭合 + 实例化测试渲染 + AgentGate 谓词验收」编译管线，**离开引擎的注册管线，一个解开的 mbt.md 也无法获得组件地位**（不能 place、不被 list、不进注册表）。真正的护城河在管线，文件格式是第一道门
3. **指纹绑定**：尾部引擎指纹 + `engine_compat` 区间校验，防第三方工具伪造合法 MCF 分发链；不匹配拒绝导入并给出可读错误

### 编解码归属

MCF 编解码落在 **ddp_codec（Rust 工具）新增 operation**，不新建二进制：

```
{"operation":"mcf_pack",   "header_b64":..., "mbt_b64":...}            → {"ok":true,"mcf_b64":...}
{"operation":"mcf_unpack", "mcf_b64":...}                              → {"ok":true,"header_b64":...,"mbt_b64":...}
```

引擎侧只做规范常量与校验（magic/指纹/crc），不重复实现编解码——与 DDP 同样的「Rust 编解码、引擎管语义」分工。规范文档随本方案冻结为 `docs/mcf-spec.md` + 字节级测试向量。

## 4. 命令面（CLI / MCP 同步暴露）

| 命令 / 工具 | 输入 | 行为 |
|---|---|---|
| `component-compile-b64 <b64>` | 组件声明 mbt.md | 全管线验收 → canonical 化 → 写入本地库（默认用户级，`--scope project` 可选）→ 返回注册表条目 |
| `component-describe <id>` | 组件 id | 输出参数 schema/变体/用法模板（Agent 据此生成 place 命令） |
| `list-components` | — | **合并输出**内置+用户+项目，带 `source` 字段（既有命令语义升级，向后兼容） |
| `component-delete <id> [--scope]` | 组件 id | 移出本地库（内置不可删） |
| `component-export <id> [--out <file>]` | 组件 id | 经 ddp_codec `mcf_pack` 产出 `.mcf` |
| `component-import <file.mcf>` | MCF 文件 | 指纹/crc 校验 → mcf_unpack → **重跑完整编译管线** → 注册（版本冲突提示，`--force` 覆盖） |

`place <artboard> <component_id> <inst> [variant|-] x y [w] [h] [k=v…]` 直接消费用户组件——传参即代入参数槽；`[w] [h]` 一步指定最终尺寸（门在最终 bbox 评估，消除默认尺寸中间态拒绝）。

## 5. Agent 感知与 SKILL 增补

- `list-components` 合并视图 + `component-describe` 的用法模板 → Agent 无需任何特殊知识即可使用用户组件
- `SKILL.md` 新增「组件创建工作流」章节：NL →（Agent 起草声明，参数化抽取名词/颜色/尺寸）→ `component-compile` →（引擎返回的校验违规清单驱动修订）→ `place`；强调「先 describe 后 place」与参数闭合纪律
- MCP：`component_compile / component_describe / component_import / component_export` 四工具与 CLI 对齐

## 6. 质量与安全

- **验收即防线**：导入/自建组件一律过实例化测试渲染 + AgentGate（劣质/恶意结构进不了库）；MCF 是纯数据容器，无代码执行面
- **上限**：复用 DDP 的 8MB 明文 / 16MB 容器上限；单库组件数上限（建议 512）防注册表膨胀
- **可迁移性**：项目级库随 git 走（.moonviz/components 纳入版本管理）；用户级库可整库备份（目录即全部状态，registry 可由源码重建）
- **回滚**：组件注册是运行时合并，删文件即卸载；引擎内核内置面零改动时行为与现状完全一致（无本地库 = 纯内置，回归零风险）

## 7. 分阶段路线与出口判据

| 阶段 | 内容 | 出口 |
|---|---|---|
| **C0 规范冻结** | 本方案评审 + MCF 字节布局冻结 + 测试向量 | `docs/mcf-spec.md` 定稿 |
| **C1 组件管线** | `Ref` 规格 + 参数代入 + `usercomp.mbt` + `component-compile/describe/delete` + `list-components` 合并 | 自建组件可 place，`moon test` 全绿 + 新增约 25 项组件测试 |
| **C2 MCF 格式** | ddp_codec `mcf_pack/mcf_unpack` + export/import + 指纹 | 往返测试 + 坏格式/坏指纹/坏 crc 全拒 |
| **C3 Agent 面** | MCP 四工具 + SKILL 章节 + e2e：NL→compile→place→export→import（第二台"机器"） | 全链路自检脚本绿 |
| **C4 生态位** | examples 增 MCF 样例；官网/SKILL 文档同步 | 文档发布 |

## 8. 待拍板（开工前）

1. **参数槽 v1 范围**：`text/color/number/enum` 四种是否够？（建议：够，v2 加 `image_ref`）
2. **变体表达**：参数预设表（本方案）vs 结构性变体（v2）
3. **MCF 指纹强度**：仅 engine_revision 派生（本方案），还是要加许可证位（为将来付费组件铺路）？
4. **用户级目录**：`~/.moonviz/components/`（本方案）——与 moon 工具链目录共栖是否可接受，还是独立 `~/.moonviz-library/`？
5. **组合组件**：v1 禁用（本方案）确认？

---

*落点预览：`core/usercomp.mbt`（新）· `core/component.mbt`（注册表双源化）· `decl`（ComponentDecl/param/ref 文法）· `cli/mcp`（六命令）· `ddp/src/lib.rs`（mcf 两操作）· `SKILL.md` · `docs/mcf-spec.md`（新）。*
