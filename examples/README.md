# MoonViz 示例文件 — DDP2 解析与渲染层复刻指南

本目录提供一个完整的「输入 → 期望输出」样例，供在任何平台（Windows/Linux/Web）**只基于引擎格式规范**重新实现 DDP2 解析与渲染层时对照验证。

## 文件清单

| 文件 | 内容 |
|---|---|
| `login-demo.ddp` | DDP2 免密容器（二进制）：三画板登录演示（登录 → 主页 → 个人页），2 条交互流 |
| `login-demo.mbt.md` | 容器解包后的明文 `.mbt.md`（29,912 字节 UTF-8）——引擎唯一事实源格式 |
| `login-demo.render.json` | 引擎对上文的**黄金渲染参照**（`render-mbt-b64` 输出）：每画板 SVG + nodes 索引 + flows + entry |

## DDP2 容器二进制格式（权威定义：`ddp/src/lib.rs`）

```
偏移   长度   字段
──────────────────────────────────────────────
0      4     magic  = ASCII "DDP2"（0x44 44 50 32）
4      1     version = 0x01
5      4     crc32  = IEEE CRC-32（多项式 0xEDB88320，即 zlib/PNG 同款），小端序
9      N     payload = 单帧标准 zstd 流（压缩级别 8，内容为 UTF-8 的 .mbt.md 明文）
```

### 解析步骤（任意语言）

1. 读前 10 字节；校验 `magic == "DDP2"`（不匹配则是 DDP1 加密容器或非法文件）
2. 校验 `version == 1`
3. 取 `payload = bytes[9:]`，计算 IEEE CRC-32 并与 `bytes[5..9]`（小端 u32）比对——不匹配报完整性错误
4. 用任意标准 zstd 库解压 `payload` → UTF-8 字符串即 `.mbt.md` 明文
   - 解码窗口上限 8 MB（`window_log_max = 23`），明文上限 8 MB，容器上限 16 MB + 16 B

### 各语言 zstd 参考实现

- **C#/.NET**：`ZstdSharp`（纯托管）或 P/Invoke 官方 `libzstd.dll`
- **C++**：官方 `zstd.h`（单 dll）
- **Rust**：`zstd` crate（引擎自身方案）
- **Python**：`zstandard` 包
- **Web**：`fzstd`（纯 JS）或 WASM 版 `libzstd`

CRC-32（IEEE）是 zlib 同款：初值 `0xFFFFFFFF`、每字节 8 轮移位（`poly 0xEDB88320`）、终值取反——所有平台的标准 `crc32` 实现均一致。

## `.mbt.md` 格式要点（渲染层需要解析的部分）

文档 = **YAML frontmatter** + **Markdown 正文**：

- frontmatter（`---` 围栏）：`moonviz.entry`（入口画板 id）、`moonviz.artboards`（画板列表）、`moonviz.flows`（交互流：`from / to / trigger`，trigger 形如 `tap:<node_id>`）、`moonviz.revision`
- 正文：每个画板一个二级标题 + `<!-- moonviz:artboard <id> -->` 标记的 ` ```mbt ` 代码块
- 块内是声明式 API：`@decl.prototype(name=..., width=..., height=...)` 建画板，`page.add(@decl.generic_node(id=..., component=..., kind=..., x=..., y=..., width=@decl.fixed(w), height=@decl.fixed(h), text=..., fill=..., radius=..., font_size=..., text_color=..., ...))` 逐节点添加
- 完整文法见 [docs/02-mbtmd-format.md](../docs/02-mbtmd-format.md)

## 渲染层需要复刻的管线（详见 docs/10-render-pipeline.md）

```
.mbt.md → 解析 frontmatter + 各画板节点声明 → 节点树
        → 布局求解（两遍法：先尺寸后位置 → 每节点画布绝对矩形）
        → 绘制（按树序：容器先画、子节点覆盖）
```

- `width=@decl.fixed(w)` 为定值尺寸（v1 模板全为 Fixed——本示例无需实现 Fill/Hug）
- 文本绘制参照 `login-demo.render.json` 中引擎产出的 SVG（系统字体栈、居中基线 `y + (h + font_size×0.7)/2`）
- 交互流：`flows` 中 `tap:<node>` 的节点渲染为可点击区域，触发画板切换

## 自验方法

1. **解包验证**：解出的明文应与 `login-demo.mbt.md` **逐字节一致**
2. **渲染验证**：对每画板生成 SVG，与 `login-demo.render.json` 的 `artboards[].svg` 对照（允许实现差异，但节点位置/尺寸/颜色应一致）；`nodes[]` 提供了节点矩形索引可直接比对数值
3. **命令行重放**（有引擎侧时）：`printf "render-mbt-b64 <b64>\nexit\n" | moonviz-cli`

## 相关文档

- [docs/02-mbtmd-format.md](../docs/02-mbtmd-format.md) — `.mbt.md` 文法规范
- [docs/10-render-pipeline.md](../docs/10-render-pipeline.md) — 绘制方案与渲染管线完整说明
- [ddp/src/lib.rs](../ddp/src/lib.rs) — DDP 容器权威实现（Rust）
