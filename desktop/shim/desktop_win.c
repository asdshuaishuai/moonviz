// MoonViz Desktop Shim — Windows（WebView2 Evergreen）
// 状态：骨架（同符号契约见 mv_shim.h）。实现要点：
//   mv_open        → CreateCoreWebView2Environment/Controller（COM），无边框=WS_POPUP
//   mv_eval        → ExecuteScript
//   mv_ios_poll    → WebMessageReceived → 队列
//   mv_app_pump    → 消息循环 PeekMessage/DispatchMessage
//   mv_engine_*    → 复用共享管道实现（可提至公共 .c）
// 平台守卫：非 Windows 编译为空 TU（跨平台零扰动）。
#if defined(_WIN32)
#include <windows.h>
typedef void *moonbit_string_t; // 编译占位：Windows 构建接线时替换为 moonbit.h
void mv_ios_push_internal(const char *json_utf8) { (void)json_utf8; }
moonbit_string_t mv_ios_poll(void) { return (moonbit_string_t)0; }
int mv_open(int card, const char *title, const char *html) { (void)card; (void)title; (void)html; return -1; }
void mv_app_pump(void) {}
void mv_eval(const char *js) { (void)js; }
int mv_app_running(void) { return 0; }
int mv_engine_alive(void) { return 0; }
int mv_engine_kill(void) { return 0; }
int mv_engine_spawn(const char *exe) { (void)exe; return -1; }
int mv_engine_send(const char *line) { (void)line; return -1; }
moonbit_string_t mv_engine_recv(void) { return (moonbit_string_t)0; }
moonbit_string_t mv_getenv(const char *name) { (void)name; return (moonbit_string_t)0; }
void mv_free(char *p) { (void)p; }
// 自渲染系统 I/O（契约第二层通道）：骨架返回不可读/不可写——宿主自动走
// stdout 兜底（渲染结果直接返回），契约符号集与 mac 保持完全一致。
moonbit_string_t mv_read_file(const char *path) { (void)path; return (moonbit_string_t)0; }
int mv_write_file(const char *path, const char *data) { (void)path; (void)data; return -1; }
#endif
