// C↔MoonBit 字符串包装（官方 C-FFI 约定：moonbit_make_string 产出 GC 串）
#import <string.h>
#import <stdlib.h>
#import <moonbit.h>

moonbit_string_t mv_cstr_to_mbt(const char *ptr) {
  if (ptr == NULL) { return moonbit_make_string(0, 0); }
  size_t n = strlen(ptr);
  uint16_t *wbuf = (uint16_t*)malloc(sizeof(uint16_t) * (n + 1));
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
      uint32_t cp = ((b & 0x0F) << 12) | (((unsigned char*)ptr)[i+1] & 0x3F) | 0;
      wbuf[w++] = (uint16_t)cp; i += 3;
    } else {
      wbuf[w++] = 0xFFFD; i += 1;
    }
  }
  moonbit_string_t ms = moonbit_make_string((int32_t)w, 0);
  for (size_t k = 0; k < w; k++) ms[k] = wbuf[k];
  free(wbuf);
  return ms;
}
