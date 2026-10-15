// ===========================================================================
// mv_shim.h — MoonViz Desktop Shim 统一 ABI 契约（抽象统一层）
// ===========================================================================
// 每个平台的 shim（desktop_mac.m / desktop_win.c / desktop_linux.c）必须
// 导出【完全相同】的符号集与语义。MoonBit 层（desktop.mbt）只认本契约，
// 永远不感知平台差异；平台选择发生在构建期（哪个平台编哪个实现文件）。
// 构建期链接 flags 目前为 mac 专属（Cocoa/WebKit frameworks）——Win/Linux
// shim 落地时由各自的构建配置提供 flags（预构建脚本按平台注入），届时
// supported-targets 随之放开。
//
// Agent 面保证：Agent（personal agent / coding agent）只与引擎协议通信
// （data / render-node-svg / export-svg …）。桌面宿主的平台、webview 种类、
// 窗口形态对本契约之上的一切消费者不可见。
//
// 字符串约定：UTF-8；MoonBit 侧传 NUL 终止 Bytes（官方 C-FFI）；
// C→MoonBit 回传一律经 moonbit_make_string 产出 GC 串（见 cwrap.m）。
// 内存约定：本契约导出的 char* 结果由 shim 持有/管理，调用方只读；
// mv_free 仅供 shim 内部与MoonBit 侧释放 shim malloc 的暂存（如有）。
// ===========================================================================

#ifndef MV_SHIM_H
#define MV_SHIM_H

// ---- 宿主生命周期 ---------------------------------------------------------
// 打开宿主窗口并加载 host 页面。mode: 0 = window（标准窗口）, 1 = card
// （小程序卡级别：无边框、浮动层、360×560 固定）。返回 0 成功 / -1 失败
// （失败原因经 mv_last_error 可取，实现方自行维护）。
int mv_open(int card, const char *title_utf8, const char *html_utf8);

// 处理一批平台窗口事件（非阻塞；macOS=手动 NSApp 事件泵）。
// 控制权留在宿主主循环（MoonBit），平台不启动自有 run loop。
void mv_app_pump(void);

// ---- webview 双向通道 -----------------------------------------------------
// 宿主 → webview：在 webview 内执行 JS（局部 patch、底版注入均走此口）。
void mv_eval(const char *js_utf8);

// webview → 宿主：弹出一条待处理事件（UTF-8 JSON），"" = 无事件。
// 事件 JSON schema（跨平台统一，平台 shim 负责把原生事件翻译成它）：
//   {"t":"tap",   "id":"<node_id>"}                       — 节点点击
//   {"t":"input", "id":"<node_id>", "value":"<text>"}     — 输入提交
//   {"t":"custom", "name":"<n>", "payload":{…}}           — 平台扩展预留
moonbit_string_t mv_ios_poll(void);

// shim 内部：WKScriptMessageHandler 等原生回调把事件写入队列时使用
// （实现文件内部符号；列出仅为契约完整性）。
void mv_ios_push_internal(const char *json_utf8);

// ---- 宿主运行态与健康检查 -------------------------------------------------
// 窗口未关闭且可见（主循环优雅退出依据）。
int mv_app_running(void);
// 引擎 sidecar 存活（kill(pid,0) 探测，零崩溃）。
int mv_engine_alive(void);
// 自愈：主动终止引擎（自愈测试/强制重生用），清理管道与 pid。
int mv_engine_kill(void);

// ---- 引擎 sidecar（MoonViz CLI 行协议子进程）-----------------------------
// 启动引擎子进程（管道互连）。返回 0 / -1。重复调用幂等（已启动即 0）。
int mv_engine_spawn(const char *exe_path);

// 发送一行命令（自动补 \n 并 flush——依赖 CLI 0.1.9-fix 起的逐行 flush）。
// 返回 0 / -1。
int mv_engine_send(const char *line_utf8);

// 阻塞读一条回执（本地 sidecar 毫秒级）。返回 moonbit GC 串；引擎 EOF 返回 ""。
moonbit_string_t mv_engine_recv(void);

// ---- 环境（模式/开关经 env 传入，不经命令行参数）------------------------
// 取环境变量（UTF-8）；未设置返回 ""。
moonbit_string_t mv_getenv(const char *name);

// ---- 内存 -----------------------------------------------------------------
// 释放 shim malloc 暴露给外部的指针（如有）；NULL 安全。
void mv_free(char *ptr);

#endif // MV_SHIM_H
