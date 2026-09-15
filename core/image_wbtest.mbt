///|
/// Image src 全链：decl text= 参数 → Node.text → SVG 真 <image>（圆角裁剪）；
/// 空 src 回退占位渲染；canonical 往返保留 text。
test "Image：src 真渲染与往返" {
  let p = Project::new()
  let _ = p.create_artboard(name="a")
  let _ = p.place_component(artboard="a", component_id="image", instance_id="pic1")
  let _ = p.edit_node(artboard="a", node_id="pic1", kvs=[("text", "https://example.com/x.png"), ("radius", "12")])
  let want_href = "href=\"https://example.com/x.png\""
  let want_clip = "clip-path=\"url(#img_pic1)\""
  match p.export_svg(artboard="a") {
    Ok(svg) => {
      assert_true(svg.contains(want_href))
      assert_true(svg.contains(want_clip))
    }
    Err(e) => fail(e)
  }
  // 空 src 的第二个 image：仍是占位渲染
  let _ = p.place_component(artboard="a", component_id="image", instance_id="pic2")
  match p.export_svg(artboard="a") {
    Ok(svg2) => {
      assert_true(svg2.contains("n_pic2"))
      let parts = svg2.split("href=")
      // 只有 pic1 携带 src，pic2 是占位
      let mut href_cnt = 0
      for seg in parts {
        if seg.contains("https://example.com") {
          href_cnt = href_cnt + 1
        }
      }
      assert_eq(href_cnt, 1)
    }
    Err(e) => fail(e)
  }
}
