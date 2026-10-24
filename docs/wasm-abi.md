# classic wasm 字符串 ABI（宿主契约）

> 适用产物：`moonviz-wasm-classic-<ver>.wasm`（`moon build --target wasm`）。
> wasm-gc 产物（JS 宿主）不适用——字符串经 JS String Builtins 直通。
>
> 状态：**宿主契约**（自 0.1.1-session 起）。CI 断言：`scripts/check-wasm-abi.mjs`。变更须走显式 PR 并同步本文件
> 与 CI 布局断言（`scripts/check-wasm-abi.mjs`）。

## 1. 模块形态

纯 WASM MVP：线性内存（导出名 `memory`）、0 imports。函数签名以
`(i32...) -> i32` 为主：句柄/计数走 i32，`Double` 形参走 f64（仅
`session_tap` / `session_tap_in` 的 x/y），槽协议的 reset/push/len 导出
无返回值（Unit，wasm 层无结果）。任何符合 WASM MVP 规范的运行时
（wasmtime/wasmi…）可直接实例化。

## 2. 字符串对象布局

MoonBit classic 后端的 String 是线性内存对象，**两种布局并存**：

| 布局 | 触发 | 结构 |
|---|---|---|
| 动态构造 | 运行时 `unsafe_make_string_raw` 分配 | `[4B refcnt=0xFFFFFFFF][4B header][len×UTF-16LE]`，指针指向 refcnt |
| 静态字面量 | data 段初始化 | `[4B len][len×UTF-16LE]`，指针指向 len 字段 |

**header** = `(kind << 30) \| (elem_size_shift << 28) \| len`；字符串
kind=1、shift=1 → header = `0x5000_0000 | len`。

**读取判别式**（宿主必须实现双布局兼容）：
读 `ptr+4` 处 u32，若 `(w >>> 28) === 0x5` 按动态布局（len = w & 0x0FFFFFFF，
数据在 ptr+8）；否则按静态布局（len = ptr-4 处 u32，数据在 ptr）。

## 3. 写入安全区（不推荐依赖）

引擎堆是 bump 分配器。深究的宿主曾依赖「写入区锚在当前 memory.size()
+ 64KB 之上」的不变量——**请改用 §5 槽协议**，宿主完全不需要在引擎堆
上构造字符串，也就不依赖此不变量。

## 4. refcnt 哨兵

动态布局首 4 字节是引用计数；`0xFFFFFFFF` 表示静态/永生（引擎不回收）。
宿主自建字符串时可写 `0xFFFFFFE0` 防引擎回收，但槽协议（§5）完全避开
refcnt 管理，是推荐路径。

## 5. 推荐协议：in_/arg_ 字符串槽

无 String 参数的直传困难（宿主无法构造 MoonBit String 对象），因此
所有带文本参数的入口都有 `_in` 后缀变体，配三槽协议：

```
in_reset() / in_push(chunk,n) / in_len()      主槽：MBT 文档文本
arg_reset() / arg_push(chunk,n) / arg_len()   辅槽：op / artboard 文本
arg2_reset() / arg2_push(chunk,n)             三槽：intent / value 文本
```

`chunk` 为小端 4 字节 UTF-8，`n` 为有效字节数（1-4）；`n < 1` 被忽略
（no-op，不向槽写入任何字节——宿主越界误用不污染槽）。例（Rust）：

```rust
// render_mbt_in：主槽压入 SEED 后调用
for chunk in seed.as_bytes().chunks(4) {
    let mut buf = [0u8; 4]; buf.copy_from_slice(chunk);
    let word = u32::from_le_bytes(buf);
    in_push(word as i32, chunk.len() as i32);
}
let ptr = render_mbt_in();
let json = read_moonstr(ptr);   // §2 判别式读取
```

带 `_in` 后缀的入口当前 26 个，与 `wasm/moon.pkg` classic exports 段
一一对应。一般槽位规则：主槽放文档级长文本，辅槽放 op/artboard 参数
文本，三槽放 intent/value 自由文本。**唯一特例 `session_generate_in`：
辅槽 = intent、三槽 = name**——name 是新画板名而非既有画板引用，故
不走 constrain_in 的 arg=artboard 布局；宿主若按一般规则把 intent 放
三槽会装反。逐导出槽位映射：

| 导出 | 主槽 in_ | 辅槽 arg_ | 三槽 arg2_ | 其他形参 |
|---|---|---|---|---|
| render_mbt_in | MBT 文档 | — | — | |
| validate_mbt_in | MBT 文档 | — | — | |
| export_html_in | MBT 文档 | — | — | |
| apply_agent_op_in | MBT 文档 | op | — | |
| apply_human_op_in | MBT 文档 | op | — | |
| session_open_in | MBT 文档 | — | — | |
| session_open_project_json_in | project_json | — | — | |
| session_apply_agent_in | — | op | — | |
| session_apply_human_in | — | op | — | |
| session_export_svg_in | — | artboard | — | |
| session_lint_in | — | artboard | — | |
| session_query_nodes_in | — | artboard | — | |
| session_interactions_in | — | artboard | — | |
| session_states_in | — | artboard | — | |
| session_spec_in | — | artboard | — | |
| session_infer_page_type_in | — | artboard | — | |
| session_infer_missing_in | — | artboard | — | |
| session_extract_design_system_in | — | artboard | — | |
| session_generate_responsive_in | — | artboard | — | |
| session_generate_in | — | **intent（特例）** | name | |
| session_component_compile_b64_in | — | base64 组件声明 | — | |
| session_constrain_in | — | artboard | intent | |
| session_tap_in | — | artboard | — | x、y: f64 |
| session_critique_in | — | artboard | — | |
| session_auto_fix_in | — | artboard | — | |
| session_history_in | — | history line | — | |

## 6. 防漂移

`scripts/check-wasm-abi.mjs` 三层守卫（CI 的 Dual wasm build 步骤以
Node ≥ 24 对双产物实跑）：
1. required 烘焙同步——脚本内 required 数组必须与 moon.pkg classic 段
   逐字一致（忘烘焙即红）；
2. 双清单锁步——moon.pkg 的 wasm / wasm-gc exports 段逐字相等（漏配
   一侧即红，如 gc 段漏 session_generate_in 的回归）；
3. 双产物实测——classic 全量（0 imports + version_info 字符串判别式
   实测往返）；wasm-gc 按 js-string builtins 实例化后 required 全导出
   + version 冒烟。布局/编码/清单漂移在 CI 直接报错，不再静默损坏宿主。
