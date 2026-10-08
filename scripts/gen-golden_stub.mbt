///|
/// 非 native 目标：golden 生成器不可用（FS 走 libc FFI）
fn main {
  println(
    "{\"error\":\"golden generator requires native target: moon run --target native scripts -- test/golden\"}",
  )
}
