///|
/// 令牌自定义覆盖全链：op 入口 → 节点重着色 → frontmatter tokens: 段
/// 持久化 → 重载恢复 → 改回原值节点还原且覆盖清除（可逆）。
test "令牌覆盖：set_token 全链往返" {
  let want = "#FF7A45"
  let ovline = "primary: \"" + want + "\""
  let fillback = "fill=\"#4361EE\""
  let seed = "---\nmoonviz:\n  backend: native\nmoonviz:\n  format: visual-document\n  revision: 2\n  title: T\n  entry: a1\n---\n\n# T\n\n<!-- moonviz:artboard a1 -->\n```mbt\n///| @moonviz:visual a1\nfn visual_a1() -> @decl.Prototype {\n  let page = @decl.prototype(name=\"a1\", width=390.0, height=844.0)\n  page.add(@decl.button(id=\"btn\", width=@decl.fill, height=@decl.fixed(48.0), label=\"Go\"))\n  page\n}\n```\n"
  match load_mbt_project(seed) {
    Err(e) => fail(e)
    Ok(m) =>
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
              match @core.apply_operation(m2.project, "token primary #4361EE") {
                Err(e) => fail(e)
                Ok(_) => {
                  let canon2 = m2.to_mbt()
                  assert_true(canon2.contains(fillback))
                  assert_false(canon2.contains(ovline))
                  // 改回默认值后 tokens: 段整体消失（与默认同值的恒真条目不序列化）
                  assert_false(canon2.contains("tokens:"))
                }
              }
            }
          }
        }
      }
  }
}

///|
/// 动效令牌与颜色覆盖共用 frontmatter `tokens:` 段：motion.* 以数字形态
/// 写出（免引号），load 后令牌表恢复、导出面同值；改回默认值即撤销条目。
test "动效令牌：set_token → frontmatter → load 全链往返" {
  let p = @core.Project::new()
  let _ = p.create_artboard(name="a")
  match p.set_token("motion.base", "320") {
    Ok(_) => ()
    Err(e) => fail("motion.base 应可设置：\{e}")
  }
  match p.set_token("motion.tick", "200") {
    Ok(_) => ()
    Err(e) => fail("motion.tick 应可设置：\{e}")
  }
  assert_true(p.motion_tokens_css().contains("--mv-dur:320ms"))
  let model = match project_to_mbt(p) {
    Ok(m) => m
    Err(e) => {
      fail("序列化失败：\{e}")
      abort("")
    }
  }
  let mbt = model.to_mbt()
  assert_true(mbt.contains("motion.base: 320"), msg=mbt)
  assert_true(mbt.contains("motion.tick: 200"), msg=mbt)
  // 数字形态：不带引号（颜色角色才引号）
  assert_false(mbt.contains("motion.base: \"320\""))
  let back = match load_mbt_project(mbt) {
    Ok(m) => m
    Err(e) => {
      fail("回载失败：\{e}")
      abort("")
    }
  }
  assert_true(back.project.motion_tokens_css().contains("--mv-dur:320ms"))
  assert_true(back.project.motion_tokens_css().contains("--mv-dur-tick:200ms"))
  assert_true(back.to_mbt().contains("motion.base: 320"))
  // 未知 motion.foo：Err 且不落值
  match back.project.set_token("motion.foo", "10") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.contains("unknown_token"))
  }
  // 改回默认值：覆盖条目撤销（motion 段整体消失）
  match back.project.set_token("motion.base", "240") {
    Ok(_) => ()
    Err(e) => fail("改回默认失败：\{e}")
  }
  match back.project.set_token("motion.tick", "180") {
    Ok(_) => ()
    Err(e) => fail("改回默认失败：\{e}")
  }
  let canon = back.to_mbt()
  assert_false(canon.contains("motion.base:"))
  assert_false(canon.contains("motion.tick:"))
}
