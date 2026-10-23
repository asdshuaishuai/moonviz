# classic wasm 字符串 ABI（宿主契约）

> 适用产物：`moonviz-wasm-classic-<ver>.wasm`（`moon build --target wasm`）。
> wasm-gc 产物（JS 宿主）不适用——字符串经 JS String Builtins 直通。
>
> 状态：**宿主契约**（自 0.1.1-session 起）。CI 断言：`scripts/check-wasm-abi.mjs`。变更须走显式 PR 并同步本文件
> 与 CI 布局断言（`scripts/check-wasm-abi.mjs`）。

## 1. 模块形态

纯 WASM MVP：线性内存（导出名 `memory`）、0 imports、所有函数签名为
`(i32...) -> i32`。任何符合 WASM MVP 规范的运行时（wasmtime/wasmi…）
可直接实例化。

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

`chunk` 为小端 4 字节 UTF-8，`n` 为有效字节数（1-4）。例（Rust）：

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

带 `_in` 后缀的入口（当前 26 个）：`render_mbt_in validate_mbt_in export_html_in apply_agent_op_in apply_human_op_in session_open_in session_apply_agent_in session_apply_human_in session_export_svg_in session_lint_in session_query_nodes_in session_interactions_in session_states_in session_spec_in session_infer_page_type_in session_infer_missing_in session_extract_design_system_in session_generate_responsive_in session_generate_in session_component_compile_b64_in session_constrain_in session_tap_in session_critique_in session_auto_fix_in session_open_project_json_in session_history_in`。

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
