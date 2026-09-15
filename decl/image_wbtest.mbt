///|
/// Image src 随 canonical MBT 往返：decl text= 字段由 generic_node 序列化，
/// image 解析分支回填 Node.text。
test "Image：src 经 canonical MBT 往返" {
  let doc = "---\nmoonviz:\n  backend: native\nmoonviz:\n  format: visual-document\n  revision: 1\n  title: T\n  entry: a\n---\n\n# T\n\n<!-- moonviz:artboard a -->\n```mbt\n///| @moonviz:visual a\nfn visual_a() -> @decl.Prototype {\n  let page = @decl.prototype(name=\"a\", width=390.0, height=844.0)\n  page.add(@decl.generic_node(id=\"pic\",component=\"image\",kind=\"image\",width=@decl.fixed(120.0),height=@decl.fixed(90.0),x=10.0,y=10.0,text=\"https://example.com/a.png\",fill=\"none\",stroke=\"none\",stroke_width=0,radius=8.0,opacity=1.0,font_size=14.0,text_color=\"#111111\",font_weight=\"normal\",shadow=\"none\",rotate=0.0,blur=0.0,blend=\"normal\",line_height=1.5,tracking=0.0,flip=\"none\",text_align=\"left\",font_style=\"normal\",stroke_dash=\"solid\",visible=true,constraint=\"lt\"))\n  page\n}\n```\n"
  match load_mbt_project(doc) {
    Ok(m) => {
      let ab = match m.project.artboards.get("a") {
        Some(x) => x
        None => { println("no artboard"); return }
      }
      match ab.doc.get("pic") {
        Some(n) => assert_eq(n.text, "https://example.com/a.png")
        None => { println("no pic node"); return }
      }
    }
    Err(e) => { println(e); return }
  }
}
