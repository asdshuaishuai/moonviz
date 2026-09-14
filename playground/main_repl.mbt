///|
/// native 目标：交互式画布闭环（getchar 读命令，每条后重绘）
///
/// 运行：moon run --target native playground
extern "c" fn getchar() -> Int = "getchar"

///|
fn read_line() -> String {
  let line = collect_chars()
  line
}

///|
fn collect_chars() -> String {
  let mut acc = ""
  let mut on = true
  while on {
    let c = getchar()
    if c == 10 {
      on = false
    } else if c == -1 {
      on = false
    } else {
      match Int::to_char(c) {
        Some(ch) => acc = acc + ch.to_string()
        None => on = false
      }
    }
  }
  acc
}

///|
/// 交互回路：画布 + 命令
fn repl_loop() -> Unit {
  let st = repl_state_new(MOCKUP)
  // 启动帧
  println(
    "== MoonViz 交互式画布（参数式命令，命令后重绘） ==",
  )
  println(apply_command(st, "render"))
  let mut running = true
  while running {
    println("")
    let line = read_line()
    let resp = apply_command(st, line)
    if resp == ":exit" {
      running = false
      println("退出")
    } else {
      println(resp)
    }
  }
}
