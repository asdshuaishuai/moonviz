// C↔MoonBit 字符串包装（官方 C-FFI 约定：moonbit_make_string 产出 GC 串）
#import <string.h>
#import <moonbit.h>

moonbit_string_t mv_cstr_to_mbt(const char *ptr) {
  if (ptr == NULL) { return moonbit_make_string(0, 0); }
  int32_t len = (int32_t)strlen(ptr);
  moonbit_string_t ms = moonbit_make_string(len, 0);
  for (int32_t i = 0; i < len; i++) { ms[i] = (uint16_t)ptr[i]; }
  return ms;
}
