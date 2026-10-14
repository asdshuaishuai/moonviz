# MoonViz Desktop Shell — Smart UX 桌面级渲染

系统 webview 直接渲染 MoonViz 原型/Smart UI 界面（Tauri 哲学：不打包浏览器
内核，用操作系统自带的 webview；薄壳 + 引擎 sidecar）。**薄壳与协议层全程
MoonBit**，仅平台 webview 绑定为极简 C/ObjC shim（`shim/`）。

## 平台矩阵（首批）

| 平台 | webview | 状态 |
|---|---|---|
| macOS 15+ | WKWebView（本 shim 经 ObjC runtime） | ✅ 已实现+自检通过 |
| Windows 10+ | WebView2（ Evergreen） | 🔜 shim 骨架待补（`shim/desktop_win.c`，契约同 mac） |
| Linux | 发行版自带 WebKitGTK 4.x | 🔜 shim 骨架待补（`shim/desktop_linux.c`，契约同 mac） |

## 两种形态

- **window**（缺省）：标准可缩放窗口
- **card**：`MOONVIZ_DESKTOP_MODE=card` —— 小程序卡级别：无边框、浮动层、360×560 固定

## 运行

```bash
moon build --target native desktop
./_build/native/debug/build/desktop/desktop.exe                 # 标准窗口（演示文档+数据轮转）
MOONVIZ_DESKTOP_MODE=card ./…desktop.exe                        # 小程序卡形态
MOONVIZ_SMOKE=1 ./…desktop.exe                                  # 无头自检（引擎桥/diff/节点片段）
MOONVIZ_CLI_BIN=/path/to/cli ./…desktop.exe                     # 指定引擎 sidecar
```

## 架构（Smart UX 增量链路）

```
webview（系统 WKWebView/WebView2/WebKitGTK）
   │  __mv_patch(id, frag)  ← 局部替换 <g id>，不全量重渲
   │  click/input → postMessage → shim 事件队列
Rust/MoonBit 薄壳（desktop.mbt：主循环 + patch 调度）
   │  行协议（spawn CLI sidecar；一命令一回执）
引擎 CLI（MoonViz MoonBit 引擎：data → changed → render-node-svg）
```

引擎侧能力：`data` 注入携带 changed 绑定影响面清单；`render-node-svg`
按节点出 SVG 片段。宿主只 patch 清单内节点——增量语义与 wasm/Node 宿主
完全同形（见 `scripts/demo-incremental.mjs` 等价性证明）。

## 已知边界（首批）

- 交互执行（tap→flow/dispatch 语义）列入 M-S3；本批点击仅上报日志
- Windows/Linux shim 骨架待补后进 CI 矩阵（当前仅在 macOS 实测）
- 引擎启动横幅不经 flush，与首条回执同时到达——薄壳按 `{"moonviz":"cli"`
  指纹跳过（engine_cmd skip 循环）
