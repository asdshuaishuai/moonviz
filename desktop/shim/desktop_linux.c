// MoonViz Desktop Shim — Linux（发行版自带 WebKitGTK 4.x）
// 状态：骨架（同符号契约见 mv_shim.h）。实现要点：
//   mv_open        → gtk_init + gtk_window + webkit_web_view_new（card=GTK_WINDOW_POPUP 固定尺寸）
//   mv_eval        → webkit_web_view_evaluate_javascript
//   mv_ios_poll    → script-message-handler → 队列
//   mv_app_pump    → gtk_main_iteration_do(FALSE) 非阻塞泵
//   mv_engine_*    → 复用共享管道实现（可提至公共 .c）
// 平台守卫：非 Linux 编译为空 TU（跨平台零扰动）。
#if defined(__linux__)
#include <gtk/gtk.h>
#include <webkit2/webkit2.h>
typedef void *moonbit_string_t; // 编译占位：Linux 构建接线时替换为 moonbit.h
static char *g_linux_title;
static char *g_linux_html;
int mv_open(int card, const char *title, const char *html) {
  (void)card; g_linux_title = (char*)title; g_linux_html = (char*)html; return -1; // 待实现
}
void mv_app_pump(void) { /* gtk_main_iteration_do(FALSE); */ }
void mv_eval(const char *js) { (void)js; }
void mv_ios_push_internal(const char *json_utf8) { (void)json_utf8; }
moonbit_string_t mv_ios_poll(void) { return (moonbit_string_t)0; }
int mv_app_running(void) { return 0; }
int mv_engine_alive(void) { return 0; }
int mv_engine_kill(void) { return 0; }
int mv_engine_spawn(const char *exe) { (void)exe; return -1; }
int mv_engine_send(const char *line) { (void)line; return -1; }
moonbit_string_t mv_engine_recv(void) { return (moonbit_string_t)0; }
moonbit_string_t mv_getenv(const char *name) { (void)name; return (moonbit_string_t)0; }
void mv_free(char *p) { (void)p; }
#endif
