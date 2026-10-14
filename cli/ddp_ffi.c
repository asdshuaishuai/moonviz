// MoonViz CLI — DDP helper sidecar 桥（native 目标）
// 职责：进程捕获执行（ddp_codec JSON 协议）、文件读写、env 读取。
// 字符串出参一律经 moonbit_make_string 产出 GC 串（官方 C-FFI 约定）。
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <moonbit.h>

moonbit_string_t mv_cstr_to_mbt_str(const char *ptr) {
  if (ptr == NULL) return moonbit_make_string(0, 0);
  int32_t len = (int32_t)strlen(ptr);
  moonbit_string_t ms = moonbit_make_string(len, 0);
  for (int32_t i = 0; i < len; i++) ms[i] = (uint16_t)ptr[i];
  return ms;
}

// 捕获式执行：返回 stdout 全文；退出码经 mv_last_rc 查询
static int g_last_rc = -1;

moonbit_string_t mv_capture(const char *cmd) {
  g_last_rc = -1;
  FILE *f = popen(cmd, "r");
  if (f == NULL) return moonbit_make_string(0, 0);
  size_t cap = 8192, len = 0;
  char *out = (char*)malloc(cap);
  char buf[4096];
  while (fgets(buf, sizeof(buf), f) != NULL) {
    size_t n = strlen(buf);
    if (len + n + 1 > cap) {
      cap = (len + n + 1) * 2;
      char *nx = (char*)realloc(out, cap);
      if (nx == NULL) break;
      out = nx;
    }
    memcpy(out + len, buf, n);
    len += n;
  }
  g_last_rc = pclose(f);
  out[len] = 0;
  moonbit_string_t ms = moonbit_make_string((int32_t)len, 0);
  for (size_t i = 0; i < len; i++) ms[i] = (uint16_t)out[i];
  free(out);
  return ms;
}

int mv_last_rc(void) { return g_last_rc; }

int mv_file_exists(const char *path) {
  FILE *f = fopen(path, "rb");
  if (f == NULL) return 0;
  fclose(f);
  return 1;
}

moonbit_string_t mv_read_file(const char *path) {
  FILE *f = fopen(path, "rb");
  if (f == NULL) return moonbit_make_string(0, 0);
  fseek(f, 0, SEEK_END);
  long n = ftell(f);
  fseek(f, 0, SEEK_SET);
  if (n < 0) { fclose(f); return moonbit_make_string(0, 0); }
  char *buf = (char*)malloc((size_t)n + 1);
  size_t rd = fread(buf, 1, (size_t)n, f);
  fclose(f);
  buf[rd] = 0;
  moonbit_string_t ms = moonbit_make_string((int32_t)rd, 0);
  for (ssize_t i = 0; i < rd; i++) ms[i] = (uint16_t)buf[i];
  free(buf);
  return ms;
}

int mv_write_file(const char *path, const char *data, int32_t len) {
  FILE *f = fopen(path, "wb");
  if (f == NULL) return -1;
  size_t w = fwrite(data, 1, (size_t)len, f);
  fclose(f);
  return (int)w;
}

moonbit_string_t mv_getenv_str(const char *name) {
  const char *v = getenv(name);
  if (v == NULL) return moonbit_make_string(0, 0);
  int32_t len = (int32_t)strlen(v);
  moonbit_string_t ms = moonbit_make_string(len, 0);
  for (int32_t i = 0; i < len; i++) ms[i] = (uint16_t)v[i];
  return ms;
}

// ---- 二进制安全：文件 → base64（避免二进制过 UTF-16 字符串边界被改写）----
static const char B64C[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

moonbit_string_t mv_read_file_b64(const char *path) {
  FILE *f = fopen(path, "rb");
  if (f == NULL) return moonbit_make_string(0, 0);
  fseek(f, 0, SEEK_END);
  long n = ftell(f);
  fseek(f, 0, SEEK_SET);
  if (n < 0) { fclose(f); return moonbit_make_string(0, 0); }
  long groups = (n + 2) / 3;
  int32_t olen = (int32_t)(groups * 4);
  moonbit_string_t ms = moonbit_make_string(olen, 0);
  long i = 0;
  int32_t o = 0;
  unsigned char prev[3] = {0, 0, 0};
  while (i < n) {
    int cnt = 0;
    for (int k = 0; k < 3; k++) {
      if (i < n) { prev[k] = (unsigned char)fgetc(f); i++; cnt++; }
      else prev[k] = 0;
    }
    unsigned v = (prev[0] << 16) | (prev[1] << 8) | prev[2];
    ms[o++] = (uint16_t)B64C[(v >> 18) & 63];
    ms[o++] = (uint16_t)B64C[(v >> 12) & 63];
    ms[o++] = (uint16_t)(cnt > 1 ? B64C[(v >> 6) & 63] : '=');
    ms[o++] = (uint16_t)(cnt > 2 ? B64C[v & 63] : '=');
  }
  fclose(f);
  return ms;
}
