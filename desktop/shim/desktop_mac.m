// MoonViz Desktop Shell — macOS shim（系统 WKWebView，Tauri 哲学：系统 webview + 薄壳）
// 形态：window（标准窗口）/ card（小程序卡级别：无边框浮动固定尺寸）
// 本文件同时承载：窗口/webview、webview→宿主事件队列、引擎 sidecar 管道
#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <moonbit.h>
#import <signal.h>
#import <unistd.h>
#import <spawn.h>
#import "mv_shim.h"

// 契约符号核查（编译期锚定）：本 shim 必须导出 mv_shim.h 的全部符号
// mv_open / mv_app_pump / mv_eval / mv_ios_poll / mv_ios_push_internal /
// mv_engine_spawn / mv_engine_send / mv_engine_recv / mv_getenv / mv_free

moonbit_string_t mv_cstr_to_mbt(const char *ptr); // 前向声明（cwrap.m 定义）

// ---------------------------------------------------------------------------
// 引擎 sidecar（MoonViz CLI 行协议子进程）：一命令一回执（CLI 已逐行 flush）
// ---------------------------------------------------------------------------
static pid_t g_engine_pid = -1;
static int g_engine_in = -1;   // 写给引擎（stdin）
static FILE *g_engine_out = NULL; // 读引擎回执（stdout）

int mv_engine_spawn(const char *exe_path) {
  signal(SIGPIPE, SIG_IGN); // 引擎死亡后写管道不得误杀薄壳自身
  if (g_engine_pid != -1 && kill(g_engine_pid, 0) == 0) return 0; // 存活：幂等
  // 死亡/残留：收割并复位（自愈重生路径）
  if (g_engine_pid != -1) {
    waitpid(g_engine_pid, NULL, 0);
    g_engine_pid = -1;
    if (g_engine_in != -1) { close(g_engine_in); g_engine_in = -1; }
    if (g_engine_out != NULL) { fclose(g_engine_out); g_engine_out = NULL; }
  }
  int in_pipe[2], out_pipe[2];
  if (pipe(in_pipe) != 0) return -1;
  if (pipe(out_pipe) != 0) { close(in_pipe[0]); close(in_pipe[1]); return -1; }
  posix_spawn_file_actions_t fa;
  posix_spawn_file_actions_init(&fa);
  posix_spawn_file_actions_adddup2(&fa, in_pipe[0], 0);
  posix_spawn_file_actions_adddup2(&fa, out_pipe[1], 1);
  posix_spawn_file_actions_addclose(&fa, in_pipe[1]);
  posix_spawn_file_actions_addclose(&fa, out_pipe[0]);
  char *argv[] = { (char*)exe_path, NULL };
  extern char **environ;
  int rc = posix_spawn(&g_engine_pid, exe_path, &fa, NULL, argv, environ);
  posix_spawn_file_actions_destroy(&fa);
  close(in_pipe[0]); close(out_pipe[1]);
  if (rc != 0) { g_engine_pid = -1; close(in_pipe[1]); close(out_pipe[0]); return -1; }
  g_engine_in = in_pipe[1];
  g_engine_out = fdopen(out_pipe[0], "r");
  return 0;
}

int mv_engine_send(const char *line_utf8) {
  if (g_engine_in == -1) return -1;
  size_t n = strlen(line_utf8);
  if (write(g_engine_in, line_utf8, n) < 0) return -1;
  if (write(g_engine_in, "\n", 1) < 0) return -1;
  return 0;
}

// 阻塞读一行（本地 sidecar，毫秒级回执；GUI 轮询线程即主线程，可接受）
moonbit_string_t mv_engine_recv(void) {
  if (g_engine_out == NULL) return moonbit_make_string(0, 0);
  char *line = NULL;
  size_t cap = 0;
  ssize_t n = getline(&line, &cap, g_engine_out);
  if (n < 0) { free(line); close(g_engine_in); g_engine_in = -1; return moonbit_make_string(0, 0); }
  if (n > 0 && line[n-1] == '\n') n -= 1;
  // UTF-8 → UTF-16 正确解码（修评审 mojibake：逐字节强转会损坏中文等非 ASCII）
  // UTF-8 → UTF-16 码元（自管缓冲，最后一次性 make）
  uint16_t *wbuf = (uint16_t*)malloc(sizeof(uint16_t) * (size_t)(n + 1));
  ssize_t w = 0;
  ssize_t i = 0;
  while (i < n) {
    unsigned char b = (unsigned char)line[i];
    if (b < 0x80) {
      wbuf[w++] = (uint16_t)b; i += 1;
    } else if ((b >> 5) == 0x6 && i + 2 <= n) {
      uint32_t cp = ((b & 0x1F) << 6) | (line[i+1] & 0x3F);
      wbuf[w++] = (uint16_t)cp; i += 2;
    } else if ((b >> 4) == 0xE && i + 2 < n) {
      uint32_t cp = ((b & 0x0F) << 12) | ((line[i+1] & 0x3F) << 6) | (line[i+2] & 0x3F);
      wbuf[w++] = (uint16_t)cp; i += 3;
    } else if ((b >> 3) == 0x1E && i + 3 < n) {
      uint32_t cp = ((b & 0x07) << 18) | ((line[i+1] & 0x3F) << 12) | ((line[i+2] & 0x3F) << 6) | (line[i+3] & 0x3F);
      cp -= 0x10000;
      wbuf[w++] = (uint16_t)(0xD800 + (cp >> 10));
      wbuf[w++] = (uint16_t)(0xDC00 + (cp & 0x3FF));
      i += 4;
    } else {
      wbuf[w++] = 0xFFFD; i += 1;
    }
  }
  moonbit_string_t ms = moonbit_make_string((int32_t)w, 0);
  for (ssize_t k = 0; k < w; k++) ms[k] = wbuf[k];
  free(wbuf);
  free(line);
  return ms;
}

// ---------------------------------------------------------------------------
// webview→宿主 事件队列（WKScriptMessageHandler 写入，MoonBit 主循环轮询）
// ---------------------------------------------------------------------------
static NSMutableArray *g_events = NULL;

void mv_ios_push_internal(const char *json_utf8) {
  if (g_events == NULL) { g_events = [NSMutableArray new]; }
  NSString *s = [NSString stringWithUTF8String:json_utf8];
  @synchronized (g_events) { [g_events addObject:s]; }
}

// ---------------------------------------------------------------------------
// 窗口 + WKWebView
// ---------------------------------------------------------------------------
static NSWindow *g_window = NULL;
static WKWebView *g_webview = NULL;
static BOOL g_window_closed = NO; // 红按钮/⌘W → 主循环优雅退出

@interface MVHandler : NSObject <WKScriptMessageHandler>
@end
@implementation MVHandler
- (void)userContentController:(WKUserContentController *)ucc
      didReceiveScriptMessage:(WKScriptMessage *)message {
  if ([message.body isKindOfClass:[NSString class]]) {
    mv_ios_push_internal([message.body UTF8String]);
  }
}
@end

// 手动事件泵（macOS 主线程自驱，不用 NSApp run——控制权留在 MoonBit 主循环）
void mv_app_pump(void) {
  NSApplication *app = [NSApplication sharedApplication];
  while (true) {
    NSEvent *ev = [app nextEventMatchingMask:NSEventMaskAny
                                   untilDate:[NSDate distantPast]
                                      inMode:NSDefaultRunLoopMode
                                     dequeue:YES];
    if (ev == nil) break;
    [app sendEvent:ev];
  }
}

int mv_open(int card, const char *title_utf8, const char *html_utf8) {
  // 平台门禁（产品约束）：macOS 15+
  NSOperatingSystemVersion v = [[NSProcessInfo processInfo] operatingSystemVersion];
  if (v.majorVersion < 15) {
    NSLog(@"[moonviz-desktop] 需要 macOS 15+（当前 %ld.%ld）", (long)v.majorVersion, (long)v.minorVersion);
    return -1;
  }
  NSApplication *app = [NSApplication sharedApplication];
  [app setActivationPolicy:NSApplicationActivationPolicyRegular];
  NSString *title = [NSString stringWithUTF8String:title_utf8];
  NSString *html = [NSString stringWithUTF8String:html_utf8];
  NSRect frame = NSMakeRect(0, 0, card ? 360 : 400, card ? 560 : 700);
  NSUInteger style = card
    ? NSWindowStyleMaskBorderless
    : (NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable);
  g_window = [[NSWindow alloc] initWithContentRect:frame
                                         styleMask:style
                                           backing:NSBackingStoreBuffered
                                             defer:NO];
  if (card) { [g_window setLevel:NSFloatingWindowLevel]; }
  [g_window setTitle:title];
  WKWebViewConfiguration *cfg = [WKWebViewConfiguration new];
  // 即用即销毁/不允许持久化（不变量）：webview 走非持久 data store——
  // localStorage/IndexedDB/缓存全部随进程蒸发，跨运行零残留
  cfg.websiteDataStore = [WKWebsiteDataStore nonPersistentDataStore];
  WKUserContentController *ucc = [WKUserContentController new];
  MVHandler *handler = [MVHandler new];
  [ucc addScriptMessageHandler:handler name:@"mv"];
  cfg.userContentController = ucc;
  g_webview = [[WKWebView alloc] initWithFrame:frame configuration:cfg];
  [g_webview loadHTMLString:html baseURL:nil];
  [g_window setContentView:g_webview];
  [g_window makeKeyAndOrderFrontNil];
  [app activateIgnoringOtherApps:YES];
  // 窗口关闭（红按钮/⌘W）→ 置位关闭旗标，宿主主循环优雅退出
  [[NSNotificationCenter defaultCenter]
    addObserverForName:NSWindowWillCloseNotification
                object:g_window
                 queue:nil
            usingBlock:^(NSNotification *_) { g_window_closed = YES; }];
  return 0;
}

void mv_eval(const char *js_utf8) {
  if (g_webview == NULL) return;
  NSString *js = [NSString stringWithUTF8String:js_utf8];
  [g_webview evaluateJavaScript:js completionHandler:nil];
}

// ---- 契约：内存 -----------------------------------------------------------
void mv_free(char *ptr) { free(ptr); }

// 环境变量（模式/开关经 env 传入：MOONVIZ_DESKTOP_MODE=card、MOONVIZ_SMOKE=1）
moonbit_string_t mv_getenv(const char *name) {
  const char *v = getenv(name);
  if (v == NULL) return moonbit_make_string(0, 0);
  int32_t len = (int32_t)strlen(v);
  moonbit_string_t ms = moonbit_make_string(len, 0);
  for (int32_t i = 0; i < len; i++) { ms[i] = (uint16_t)v[i]; }
  return ms;
}

// ---- 契约：运行态与健康检查 ----------------------------------------------
// （g_window_closed 定义见文件头 g_window 处）

int mv_app_running(void) {
  if (g_window_closed) return 0;
  return g_window != nil && [g_window isVisible];
}

int mv_engine_alive(void) {
  return g_engine_pid != -1 && kill(g_engine_pid, 0) == 0;
}

// 自愈：主动终止引擎（自愈测试/强制重生）
int mv_engine_kill(void) {
  if (g_engine_pid == -1) return 0;
  kill(g_engine_pid, SIGTERM);
  g_engine_pid = -1;
  if (g_engine_in != -1) { close(g_engine_in); g_engine_in = -1; }
  if (g_engine_out != NULL) { fclose(g_engine_out); g_engine_out = NULL; }
  return 0;
}

// 事件队列弹出（"" = 无事件）
moonbit_string_t mv_ios_poll(void) {
  if (g_events == NULL) return moonbit_make_string(0, 0);
  @synchronized (g_events) {
    if (g_events.count == 0) return moonbit_make_string(0, 0);
    NSString *s = g_events[0];
    [g_events removeObjectAtIndex:0];
    return mv_cstr_to_mbt([s UTF8String]);
  }
}
