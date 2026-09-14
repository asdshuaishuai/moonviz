///|
/// 非 native 目标：CLI 不可用（需要 C FFI getchar）
fn main {
  println(
    "{\"error\":\"CLI requires native target: moon run --target native cli\"}",
  )
}
