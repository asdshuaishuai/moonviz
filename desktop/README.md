# MoonViz 自渲染服务 — webview self-rendering（dev 线，客户端引导模型）

引擎**直接为客户端提供渲染能力**：客户端（Tauri / Electron / 任意原生壳）只需
提供一个 webview 来源，渲染本身零客户端代码。**引擎无 UI、无窗口、不自行获取
渲染面**——自渲染能力必须依托客户端的引导使用，引擎不能自己直接取用：

1. 客户端引导：拉起引擎、指定渲染源（`MOONVIZ_DOC` 指向 `.mbt.md` 唯一事实源）、
   承接渲染结果；
2. 表面一（客户端 webview）：客户端把自己的 webview 指向渲染产物，即获得活原型
   （交互运行时内嵌：画板切换 / 导航流 / toast / 状态多态）——Tauri/Electron
   零渲染代码；
3. 表面二（系统兜底）：原生环境没有 webview 时，引擎直接调用系统层渲染并
   **返回结果**——产物写盘（`MOONVIZ_OUT`，缺省 `moonviz-render.html`），写盘
   也不可用时把自包含 HTML 打到 stdout（渲染结果即返回值）。

渲染链路 `.mbt.md → load_mbt_project → export_html` 全程进程内、纯 MoonBit——
无 sidecar、无上层框架依赖。**引擎全程不拉起 webview、不建窗口**；无引导
（未设 `MOONVIZ_DOC`）时只回 usage 信封，不渲染、不写文件（CI 有硬门断言）。

## 客户端引导接入（零渲染代码）

```
desktop.exe                                          # 无引导 → {"error":"not_guided",…} 保持惰性
MOONVIZ_DOC=app.mbt.md desktop.exe                   # 引导渲染 → ./moonviz-render.html
MOONVIZ_DOC=app.mbt.md MOONVIZ_OUT=out/index.html …  # 指定产物路径
MOONVIZ_SMOKE=1 desktop.exe                          # 无头自检（CI 硬门）
```

（`desktop.exe` = `moon build --target native desktop` 产物；客户端可自行重命名分发。）

Tauri / Electron：spawn 引擎（env 指源与产物）→ 信封返回 `artifact` →
`webview.loadURL(file://…artifact)`。产物是**自包含交互 HTML**，任何 webview
打开即是活的原型。

## 抽象统一层（shim/ — 契约单一事实源 mv_shim.h）

引擎侧底层只有**系统 I/O**，单文件 `shim/desktop_io.c` 纯 C 标准库实现
（三平台无差异、零框架链接；webview 的创建/窗口/事件全部属于客户端，引擎侧
不存在任何 UI 符号）：

`mv_getenv` / `mv_read_file` / `mv_write_file` / `mv_free`

Agent 与一切消费者永远不需要感知平台差异——底层实现不在 agent 的考虑范围内。

## 构建与验证

```bash
moon build --target native desktop
MOONVIZ_SMOKE=1 ./_build/native/debug/build/desktop/desktop.exe   # 无头自检
```

CI（ci.yml 主 job，Linux runner）：构建 + SMOKE 硬门 + 「无引导惰性」断言
（不产生 `moonviz-render.html`）。

## 不变量（强制）

1. **客户端引导**：引擎不自行取用自渲染能力——无 UI、无窗口、无未引导渲染。
2. **核心不变**：desktop 只是渲染服务，不承载引擎语义；`.mbt.md` 唯一事实源、
   wasm 零 import 红线不受影响。
3. **全程 MoonBit**：服务层 MoonBit，仅系统 I/O 为极简 C shim（无框架）。
4. **渲染结果即交付物**：只在客户端引导时产生，生命周期归客户端自管。
