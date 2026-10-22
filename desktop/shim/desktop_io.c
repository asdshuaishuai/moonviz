// MoonViz 自渲染系统 I/O 统一实现（客户端引导模型——引擎无 UI，契约见 mv_shim.h）
// 单文件、纯 C 标准库：三平台无差异、零框架链接。
// UTF-8 → UTF-16 严格解码：2/3 字节序列直映，4 字节序列拆代理对；逐续字节校验
// 高两位为 10，拒绝 overlong（C0/C1、E0 后<A0、F0 后<90）、代理区（ED 后≥A0）
// 与超 U+10FFFF（F4 后>8F、F5-F7 lead）——非法序列一律回退 U+FFFD 且只进 1 字节
// （3 字节续字必须 <<6，否则中文解成乱码——读回校验曾暴露此缺陷）。
// 长度语义：读写显式字节长度传递、不依赖 NUL 终止——读侧检出内嵌 0x00 拒读
// （返回 ""），写侧按 len 落盘；strlen 截断 + 假成功链路已消除。
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <moonbit.h>
#include "mv_shim.h"

// 严格 UTF-8 解码（显式长度 s[0..n)）：产出 UTF-16 码元序列（moonbit 串）。
// wbuf 按 n*2+2 上界预分配（每输入字节至多产出 1 个码元：ASCII 1 个、
// 非法回退 FFFD 1 个、合法多字节序列摊薄）。
static moonbit_string_t mv_utf8_to_mbt(const unsigned char *s, size_t n) {
  uint16_t *wbuf = (uint16_t*)malloc(sizeof(uint16_t) * (n * 2 + 2));
  if (wbuf == NULL) { return moonbit_make_string(0, 0); }
  size_t w = 0;
  size_t i = 0;
  while (i < n) {
    unsigned char b = s[i];
    if (b < 0x80) {
      wbuf[w++] = (uint16_t)b; i += 1;
      continue;
    }
    size_t len = 0;
    uint32_t cp = 0;
    if ((b >> 5) == 0x6) {
      len = 2; cp = b & 0x1F;
    } else if ((b >> 4) == 0xE) {
      len = 3; cp = b & 0x0F;
    } else if ((b >> 3) == 0x1E) {
      len = 4; cp = b & 0x07;
    }
    // 合法性：序列完整（不越界）+ 每个续字节高两位为 10
    int ok = (len != 0 && i + len <= n);
    for (size_t k = 1; ok && k < len; k++) {
      if ((s[i + k] & 0xC0) != 0x80) { ok = 0; }
    }
    if (ok) {
      for (size_t k = 1; k < len; k++) { cp = (cp << 6) | (s[i + k] & 0x3F); }
      // 解码值判定一次覆盖全部拒绝形态：overlong（长度编码的码点值过小）、
      // 代理区（仅 3 字节 ED A0-BF 可达）、超 U+10FFFF（F4 后>8F / F5-F7 lead）
      if ((len == 2 && cp < 0x80) || (len == 3 && cp < 0x800) ||
          (len == 4 && cp < 0x10000) ||
          (cp >= 0xD800 && cp <= 0xDFFF) || cp > 0x10FFFF) {
        ok = 0;
      }
    }
    if (ok) {
      if (len == 4) {
        cp -= 0x10000;
        wbuf[w++] = (uint16_t)(0xD800 + (cp >> 10));
        wbuf[w++] = (uint16_t)(0xDC00 + (cp & 0x3FF));
      } else {
        wbuf[w++] = (uint16_t)cp;
      }
      i += len;
    } else {
      wbuf[w++] = 0xFFFD; i += 1;  // 非法/截断：回退 FFFD，只进 1 字节重新同步
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
  // env 值按 C 契约必然 NUL 终止、不可能内嵌 NUL，strlen 计长安全
  return mv_utf8_to_mbt((const unsigned char*)v, strlen(v));
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
  // 拒内嵌 NUL：本契约只承载 UTF-8 文本，含 0x00 的源按不可读返回 ""
  // （调用方报 doc_unreadable / smoke FAIL）——杜绝 strlen 解码静默截断。
  if (memchr(buf, 0, rd) != NULL) { free(buf); return moonbit_make_string(0, 0); }
  // 显式长度解码（rd 而非 strlen）：文件内容不再受 NUL 终止假设约束
  moonbit_string_t ms = mv_utf8_to_mbt((const unsigned char*)buf, rd);
  free(buf);
  return ms;
}

int mv_write_file(const char *path_utf8, const char *data_utf8, int len) {
  if (path_utf8 == NULL || data_utf8 == NULL || len < 0) return -1;
  FILE *f = fopen(path_utf8, "wb");
  if (f == NULL) return -1;
  // 显式长度落盘：不再 strlen 计长——内嵌 NUL 曾截断产物且 w==n 恒过、
  // 假报成功；len 语义（字节长度）由 MoonBit 侧经 FFI 传入并担保有效。
  size_t w = fwrite(data_utf8, 1, (size_t)len, f);
  int rc = fclose(f);
  return (w == (size_t)len && rc == 0) ? 0 : -1;
}

void mv_free(char *ptr) { free(ptr); }

void mv_exit(int code) { exit(code); }
