///|
/// 非 native 目标：脚本演示（渲染 / 硬门槛 / 视觉债 / 声明往返 / 画布帧）
fn repl_loop() -> Unit {
  println(scenario_report())
  println("\n---- MoonBit 画布演示：默认视口 ----")
  println(draw_canvas_at(0.0, 0.0, 1.0))
  println("放大两倍后（zoom=2，同一文档）")
  println(draw_canvas_at(0.0, 0.0, 2.0))
  println(
    "\n提示：交互式画布请用 native 目标运行：moon run --target native playground",
  )
}

///|
fn draw_canvas_at(pan_x : Double, pan_y : Double, zoom : Double) -> String {
  match @decl.parse_decl(MOCKUP) {
    Err(e) => "画布解析错误：\{e.describe()}"
    Ok(page) => {
      let cam = Camera::new()
      cam.pan_x = pan_x
      cam.pan_y = pan_y
      cam.zoom = zoom
      let buf = screen_new(CANVAS_COLS, CANVAS_ROWS)
      draw_document(buf, cam, page.build(), None)
      frame_of(buf)
    }
  }
}
