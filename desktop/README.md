# MoonViz 自渲染宿主 — webview self-rendering（dev 线）

引擎**直接为客户端提供渲染能力**：客户端（Tauri / Electron / 任意原生壳）只需
提供一个 webview 来源，渲染本身零客户端代码。两层检测、系统兜底，把客户端的
使用与开发成本压到最低。**引擎核心全程 MoonBit**——渲染链路
`.mbt.md → load_mbt_project → export_html` 全部进程内完成，无 sidecar、
无上层框架依赖。

## 两层检测，系统兜底

| 层 | 条件 | 行为 |
|---|---|---|
| 第一层 webview | 系统 webview 可用（macOS = WKWebView） | 拉起窗口直接渲染自包含交互原型；关窗即退出（即用即销毁） |
| 第二层 系统 | webview 不可用 | 引擎直接调用系统层渲染并**返回结果**：兜底产物写盘（`moonviz-render.html`），写盘也不可用时把自包含 HTML 打到 stdout |

每一级失败自动降级到下一级，宿主"总能渲染出点什么"（显式源解析失败还会
先回退内置演示画板）。

## 客户端契约（Tauri / Electron 零渲染代码）

```
moonviz desktop.exe                 # 窗口形态（引擎自渲染）
MOONVIZ_DESKTOP_MODE=card …         # 小程序卡形态（无边框 360×560）
MOONVIZ_DOC=app.mbt.md …            # 渲染指定 .mbt.md（唯一事实源）
MOONVIZ_OUT=out/index.html …        # 第二层产物路径（客户端 webview 加载它）
MOONVIZ_SMOKE=1 …                   # 无头自检（CI：源/管线/渲染/兜底写读）
```

嵌入形态 = 运行第二层拿到产物 → 交给客户端自己的 webview 加载。产物是
**自包含交互 HTML**（画板切换 / 导航流 / toast / 状态多态的运行时全部内嵌），
任何 webview 打开即是活的原型——客户端不写一行渲染逻辑。

## 抽象统一层（shim/ — 契约单一事实源 mv_shim.h）

三平台 shim 必须导出**完全相同**的符号集与语义；MoonBit 层只认契约，永远
不感知平台差异：

`mv_open` / `mv_app_pump` / `mv_eval` / `mv_ios_poll` / `mv_ios_push_internal` /
`mv_engine_spawn` / `mv_engine_send` / `mv_engine_recv` / `mv_engine_alive` /
`mv_engine_kill` / `mv_getenv` / `mv_read_file` / `mv_write_file` / `mv_free`

dev 线宿主当前只消费 webview 生命周期 + 系统 I/O（`mv_read_file`/
`mv_write_file` 是两层检测的第二层通道）；sidecar/eval 符号保留在契约里供
组件级实时更新演进，agent 与消费者永远不需要感知平台与 shim 内部。

| 平台 | webview | 状态 |
|---|---|---|
| macOS 15+ | WKWebView | ✅ 已实现 + 窗口/SMOKE 实测 |
| Windows 10+ | WebView2 | 🔜 骨架（`shim/desktop_win.c`，契约同 mac；落地前自动走第二层） |
| Linux | WebKitGTK | 🔜 骨架（`shim/desktop_linux.c`，契约同 mac；落地前自动走第二层） |

## 构建与验证

```bash
moon build --target native desktop
./_build/native/debug/build/desktop/desktop.exe                 # 窗口：示例原型直接渲染
MOONVIZ_DESKTOP_MODE=card ./…desktop.exe                        # 小程序卡形态
MOONVIZ_DOC=examples/login-demo.mbt.md ./…desktop.exe           # 渲染指定源
MOONVIZ_SMOKE=1 ./…desktop.exe                                  # 无头自检（CI 用）
```

CI（ci.yml `desktop-selfrender` job，macOS runner）执行 `MOONVIZ_SMOKE=1`；
Linux runner 只跑 `moon check/test`（mac shim 平台守卫编译为空 TU，desktop
二进制不在 Linux 产出——骨架平台届时由第二层兜底承接）。

## 不变量（强制）

1. **核心不变**：desktop 只是渲染宿主，不承载引擎语义；`.mbt.md` 唯一事实源、
   wasm 零 import 红线不受影响。
2. **即用即销毁**：webview 走非持久 data store，跨运行零残留；第一层零磁盘写入。
3. **第二层产物是交付物**：只在无 webview 时产生，生命周期归客户端自管。
4. **全程 MoonBit**：薄壳与协议层 MoonBit，仅平台 webview 绑定为极简 C/ObjC shim。
