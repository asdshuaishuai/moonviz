// MoonViz 自渲染系统 I/O 统一实现（客户端引导模型——引擎无 UI，契约见 mv_shim.h）
// 单文件、纯 C 标准库：三平台无差异、零框架链接。
// UTF-8 → UTF-16 完整解码：2/3 字节序列直映，4 字节序列拆代理对
// （3 字节续字必须 <<6，否则中文解成乱码——读回校验曾暴露此缺陷）。
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <moonbit.h>
#include "mv_shim.h"

static moonbit_string_t mv_cstr_to_mbt(const char *ptr) {
  if (ptr == NULL) { return moonbit_make_string(0, 0); }
  size_t n = strlen(ptr);
  uint16_t *wbuf = (uint16_t*)malloc(sizeof(uint16_t) * (n * 2 + 2));
  if (wbuf == NULL) { return moonbit_make_string(0, 0); }
  size_t w = 0;
  size_t i = 0;
  while (i < n) {
    unsigned char b = ((unsigned char*)ptr)[i];
    if (b < 0x80) {
      wbuf[w++] = (uint16_t)b; i += 1;
    } else if ((b >> 5) == 0x6 && i + 1 < n) {
      uint32_t cp = ((b & 0x1F) << 6) | (((unsigned char*)ptr)[i+1] & 0x3F);
      wbuf[w++] = (uint16_t)cp; i += 2;
    } else if ((b >> 4) == 0xE && i + 2 < n) {
      uint32_t cp = ((b & 0x0F) << 12)
                  | ((((unsigned char*)ptr)[i+1] & 0x3F) << 6)
                  | (((unsigned char*)ptr)[i+2] & 0x3F);
      wbuf[w++] = (uint16_t)cp; i += 3;
    } else if ((b >> 3) == 0x1E && i + 3 < n) {
      uint32_t cp = ((b & 0x07) << 18)
                  | ((((unsigned char*)ptr)[i+1] & 0x3F) << 12)
                  | ((((unsigned char*)ptr)[i+2] & 0x3F) << 6)
                  | (((unsigned char*)ptr)[i+3] & 0x3F);
      cp -= 0x10000;
      wbuf[w++] = (uint16_t)(0xD800 + (cp >> 10));
      wbuf[w++] = (uint16_t)(0xDC00 + (cp & 0x3FF));
      i += 4;
    } else {
      wbuf[w++] = 0xFFFD; i += 1;
    }
  }
  moonbit_string_t ms = moonbit_make_string((int32_t)w, 0);
  for (size_t k = 0; k < w; k++) ms[k] = wbuf[k];
  free(wbuf);
  return ms;
}

moonbit_string_t mv_getenv(const char *name) {
  if (name == NULL) return moonbit_make_string(0, 0);
  const char *v = getenv(name);
  if (v == NULL) return moonbit_make_string(0, 0);
  return mv_cstr_to_mbt(v);
}

moonbit_string_t mv_read_file(const char *path_utf8) {
  if (path_utf8 == NULL) return moonbit_make_string(0, 0);
  FILE *f = fopen(path_utf8, "rb");
  if (f == NULL) return moonbit_make_string(0, 0);
  if (fseek(f, 0, SEEK_END) != 0) { fclose(f); return moonbit_make_string(0, 0); }
  long n = ftell(f);
  if (n < 0) { fclose(f); return moonbit_make_string(0, 0); }
  if (fseek(f, 0, SEEK_SET) != 0) { fclose(f); return moonbit_make_string(0, 0); }
  char *buf = (char*)malloc((size_t)n + 1);
  if (buf == NULL) { fclose(f); return moonbit_make_string(0, 0); }
  size_t rd = fread(buf, 1, (size_t)n, f);
  fclose(f);
  buf[rd] = 0;
  moonbit_string_t ms = mv_cstr_to_mbt(buf);
  free(buf);
  return ms;
}

int mv_write_file(const char *path_utf8, const char *data_utf8) {
  if (path_utf8 == NULL || data_utf8 == NULL) return -1;
  FILE *f = fopen(path_utf8, "wb");
  if (f == NULL) return -1;
  size_t n = strlen(data_utf8);
  size_t w = fwrite(data_utf8, 1, n, f);
  int rc = fclose(f);
  return (w == n && rc == 0) ? 0 : -1;
}

void mv_free(char *ptr) { free(ptr); }
