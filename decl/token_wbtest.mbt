///|
/// 令牌自定义覆盖全链：op 入口 → 节点重着色 → frontmatter tokens: 段
/// 持久化 → 重载恢复 → 改回原值节点还原且覆盖清除（可逆）。
test "令牌覆盖：set_token 全链往返" {
  let want = "#FF7A45"
  let ovline = "primary: \"" + want + "\""
  let fillback = "fill=\"#4B6BFB\""
  let seed = "---\nmoonviz:\n  backend: native\nmoonviz:\n  format: visual-document\n  revision: 2\n  title: T\n  entry: a1\n---\n\n# T\n\n<!-- moonviz:artboard a1 -->\n```mbt\n///| @moonviz:visual a1\nfn visual_a1() -> @decl.Prototype {\n  let page = @decl.prototype(name=\"a1\", width=390.0, height=844.0)\n  page.add(@decl.button(id=\"btn\", width=@decl.fill, height=@decl.fixed(48.0), label=\"Go\"))\n  page\n}\n```\n"
  match load_mbt_project(seed) {
    Err(e) => fail(e)
    Ok(m) => {
      match @core.apply_operation(m.project, "token primary " + want) {
        Err(e) => fail(e)
        Ok(_) => {
          let canon = m.to_mbt()
          assert_true(canon.contains(ovline))
          assert_true(canon.contains(want))
          match load_mbt_project(canon) {
            Err(e) => fail(e)
            Ok(m2) => {
              let primary = m2.project.tokens.resolve_color("primary")
              assert_eq(primary, want)
              match @core.apply_operation(m2.project, "token primary #4B6BFB") {
                Err(e) => fail(e)
                Ok(_) => {
                  let canon2 = m2.to_mbt()
                  assert_true(canon2.contains(fillback))
                  assert_false(canon2.contains(ovline))
                }
              }
            }
          }
        }
      }
    }
  }
}
