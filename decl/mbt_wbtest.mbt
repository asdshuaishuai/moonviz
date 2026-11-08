/// `.mbt.md` 文学化源码扫描与 Moonviz 单文件项目测试。

///|
let sample_mbt = "---\nmoonbit:\n  backend: native\nmoonviz:\n  format: visual-document\n  revision: 7\n  entry: login\n  flows:\n    - from: login\n      to: dashboard\n      trigger: tap:submit\n---\n\n# 登录和首页\n\n<!-- moonviz:artboard login -->\n```mbt\nfn visual_login() -> @decl.Prototype {\n  let page = @decl.prototype(name=\"登录\", width=390.0, height=844.0)\n  page.set_layout(@decl.flex(direction=@decl.vertical, gap=16.0, padding=24.0))\n  page.add(@decl.text(id=\"title\", content=\"欢迎回来\", size=28.0))\n  page.add(@decl.button(id=\"submit\", width=@decl.fill, height=@decl.fixed(48.0), label=\"登录\"))\n  page\n}\n```\n\n```mbt check\ntest \"login docs test\" {\n  let page = visual_login()\n  assert_eq(page.check().length(), 0)\n}\n```\n\n```mbt nocheck\nfn shown_only() -> Int { 42 }\n```\n\n```moonbit\nfn documentation_only() -> Int { 42 }\n```\n\n<!-- moonviz:artboard dashboard -->\n```mbt\nfn visual_dashboard() -> @decl.Prototype {\n  let page = @decl.prototype(name=\"首页\", width=390.0, height=844.0)\n  page.add(@decl.text(id=\"headline\", content=\"仪表盘\", size=24.0))\n  page\n}\n```\n"

///|
test "scan_mbt preserves official fence kinds and only marks explicit visual blocks" {
  let document = match scan_mbt(sample_mbt) {
    Ok(value) => value
    Err(error) => abort(error)
  }
  assert_eq(document.revision, 7)
  assert_eq(document.entry, "login")
  assert_eq(document.blocks.length(), 5)
  assert_eq(document.visual_count(), 2)
  assert_true(document.block_kind_counts().contains("\"mbt\":2"))
  assert_true(document.block_kind_counts().contains("\"mbt_check\":1"))
  assert_true(document.block_kind_counts().contains("\"mbt_nocheck\":1"))
  assert_true(document.block_kind_counts().contains("\"moonbit\":1"))
}

///|
test "load_mbt_project renders multiple artboards from one MBT source" {
  let model = match load_mbt_project(sample_mbt) {
    Ok(value) => value
    Err(error) => abort(error)
  }
  assert_eq(model.entry, "login")
  assert_eq(model.project.artboards.length(), 2)
  assert_eq(model.project.flows.length(), 1)
  let rendered = model.render_json()
  assert_true(rendered.contains("\"id\":\"login\""))
  assert_true(rendered.contains("\"id\":\"dashboard\""))
  assert_true(rendered.contains("欢迎回来"))
  assert_true(rendered.contains("仪表盘"))
}

///|
test "canonical MBT reloads as the same multi-artboard visual project" {
  let first = match load_mbt_project(sample_mbt) {
    Ok(value) => value
    Err(error) => abort(error)
  }
  let canonical = first.to_mbt()
  assert_true(canonical.contains("<!-- moonviz:artboard login -->"))
  assert_true(canonical.contains("```mbt check"))
  let second = match load_mbt_project(canonical) {
    Ok(value) => value
    Err(error) => abort(error)
  }
  assert_eq(second.project.artboards.length(), 2)
  assert_eq(second.project.flows.length(), 1)
  assert_eq(second.entry, "login")
}

///|
test "human gate records visual debt while agent gate blocks the same MBT" {
  let model = match load_mbt_project(sample_mbt) {
    Ok(value) => value
    Err(error) => abort(error)
  }
  match model.project.artboards.get("login") {
    Some(artboard) => {
      let _ = artboard.doc.update_node("submit", fn(node) {
        { ..node, x: @core.AlignStart(999.0), }
      })
    }
    None => assert_true(false)
  }
  match model.validate_for(@core.HumanGate) {
    Ok(debt) => assert_true(debt > 0)
    Err(error) => abort(error)
  }
  match model.validate_for(@core.AgentGate) {
    Ok(_) => assert_true(false)
    Err(error) =>
      assert_true(
        error.contains("mbt_gate_block:login:contained_in_parent:submit"),
      )
  }
}

///|
test "空态合法：零视觉块文档加载为空项目（issue #27）" {
  let empty = "<!-- moonviz:artboard wrong -->\n```mbt check\ntest \"x\" { }\n```\n"
  match load_mbt_project(empty) {
    Ok(model) => assert_eq(model.project.artboards.length(), 0)
    Err(error) => fail("零视觉块文档必须合法：\{error}")
  }
}

///|
test "scanner skips nested MoonBit fences inside non-MoonBit documentation blocks" {
  let source = "````text\n```mbt\nlet page = @decl.prototype(name=\"wrong\")\n```\n````\n\n" +
    sample_mbt
  let document = match scan_mbt(source) {
    Ok(value) => value
    Err(error) => abort(error)
  }
  assert_eq(document.blocks.length(), 5)
  assert_eq(document.visual_count(), 2)
}

///|
test "visual declarations reject unsupported dynamic MoonBit logic" {
  let source = sample_mbt.replace(
    old="  page\n}",
    new="  let dynamic = 42\n  page\n}",
  )
  match load_mbt_project(source) {
    Ok(_) => assert_true(false)
    Err(error) =>
      assert_true(error.contains("not_renderable_visual_logic_line:"))
  }
}

///|
test "visual declarations reject references to missing flow nodes" {
  let invalid = sample_mbt.replace(old="tap:submit", new="tap:missing")
  match load_mbt_project(invalid) {
    Ok(_) => assert_true(false)
    Err(error) =>
      assert_true(error.contains("mbt_flow_unknown_node:login:missing"))
  }
}

///|
/// 回归：文本中的逗号、括号、引号必须在 canonical 往返后原样保留。
/// 旧实现在 split_params 不识别引号，且 json_escape 不转义 `,()`，
/// "Users: 8,421 (active)" 这类文案会在导出后自毁。
test "canonical MBT round-trips text containing commas parens and quotes" {
  let source = sample_mbt.replace(
    old="content=\"欢迎回来\"",
    new="content=\"Users: 8,421 (active), \\\"live\\\" counts\"",
  )
  let model = match load_mbt_project(source) {
    Ok(value) => value
    Err(error) => abort(error)
  }
  let canonical = model.to_mbt()
  let reloaded = match load_mbt_project(canonical) {
    Ok(value) => value
    Err(error) => abort(error)
  }
  let rendered = reloaded.render_json()
  assert_true(rendered.contains("Users: 8,421 (active)"))
  assert_true(rendered.contains("\\\"live\\\""))
}

///|
/// 回归：负数样式值（如 tracking=-0.05）必须可以解析和再次导出。
/// 旧 parse_number 拒绝前导 '-'，载入即失败。
let negative_mbt = "---\nmoonviz:\n  format: visual-document\n  revision: 1\n  entry: board\n---\n\n# 负值样式\n\n<!-- moonviz:artboard board -->\n```mbt\nfn visual_board() -> @decl.Prototype {\n  let page = @decl.prototype(name=\"负值\", width=390.0, height=844.0)\n  page.add(@decl.generic_node(id=\"meta\", component=\"text\", kind=\"text\", width=@decl.fixed(300.0), height=@decl.fixed(20.0), text=\"Track\", tracking=-0.05, rotate=-15.0))\n  page\n}\n```\n"

///|
test "canonical MBT round-trips negative style values" {
  let model = match load_mbt_project(negative_mbt) {
    Ok(value) => value
    Err(error) => abort(error)
  }
  let canonical = model.to_mbt()
  assert_true(canonical.contains("tracking=-0.05"))
  assert_true(canonical.contains("rotate=-15"))
  let reloaded = match load_mbt_project(canonical) {
    Ok(value) => value
    Err(error) => abort(error)
  }
  assert_true(reloaded.render_json().contains("Track"))
}

///|
/// 回归：画板显示名（如「登录」）必须在 canonical 往返后保留，
/// 不能回落到 Document 根节点的默认名「画布」。
test "artboard display names survive canonical round-trip" {
  let first = match load_mbt_project(sample_mbt) {
    Ok(value) => value
    Err(error) => abort(error)
  }
  let canonical = first.to_mbt()
  let second = match load_mbt_project(canonical) {
    Ok(value) => value
    Err(error) => abort(error)
  }
  match second.project.artboards.get("login") {
    Some(artboard) => assert_eq(artboard.name, "登录")
    None => assert_true(false)
  }
  match second.project.artboards.get("dashboard") {
    Some(artboard) => assert_eq(artboard.name, "首页")
    None => assert_true(false)
  }
}

///|
/// 回归：单独创建 signup 模板时，不能写出指向不存在的 login 画板的
/// 悬空 flow（mbt_flow_unknown_artboard:signup:login）。
test "standalone signup template exports a valid single-file MBT" {
  let project = @core.Project::new()
  let _ = project.apply_template(template_id="signup")
  let model = match project_to_mbt(project) {
    Ok(value) => value
    Err(error) => abort(error)
  }
  let canonical = model.to_mbt()
  let reloaded = match load_mbt_project(canonical) {
    Ok(value) => value
    Err(error) => abort(error)
  }
  assert_eq(reloaded.project.flows.length(), 0)
  assert_eq(reloaded.project.artboards.length(), 1)
}

///|
/// 回归：结构式模板（嵌套容器）的 canonical 不得把容器子级翻倍。
/// 旧 doc_walk 保留 doc 侧 children，nav 的子节点被写入两次，
/// adaptive_landing 导出即 duplicate_id 损坏。
test "structural templates round-trip without duplicating container children" {
  let project = @core.Project::new()
  let ab = match
    project.apply_template(
      template_id="adaptive_landing",
      name="landing",
      width=1280.0,
      height=0.0,
    ) {
    Ok(value) => value
    Err(error) => abort(error)
  }
  match project_to_mbt(project) {
    Err(error) => abort(error)
    Ok(model) => {
      let canonical = model.to_mbt()
      // visual block 与 mbt check block 各声明一次 nav_logo，共两次；
      // 翻倍时会出现四次。
      let mut count = 0
      let mut idx = 0
      let text = canonical
      let mut scanning = true
      while scanning {
        let marker = "id=\"nav_logo\""
        let hit = find_from(text, marker, idx)
        match hit {
          None => scanning = false
          Some(pos) => {
            count = count + 1
            idx = pos + marker.length()
          }
        }
      }
      assert_eq(count, 2)
      // canonical 重新载入必须成功（旧实现在此 duplicate_id 失败）
      let reloaded = match load_mbt_project(canonical) {
        Ok(value) => value
        Err(error) => abort(error)
      }
      assert_eq(reloaded.project.artboards.length(), 1)
    }
  }
}

///|
/// 在文本中从 from 位置查找子串（回归测试辅助）。
fn find_from(text : String, needle : String, from : Int) -> Int? {
  let n = needle.length()
  let mut i = from
  while i + n <= text.length() {
    if text.substring(start=i, end=i + n) == needle {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
/// 子串出现次数（motion= 只应在设置了该字段的节点上出现一次）。
fn count_needle(text : String, needle : String) -> Int {
  let mut count = 0
  let mut idx = 0
  let mut scanning = true
  while scanning {
    match find_from(text, needle, idx) {
      None => scanning = false
      Some(pos) => {
        count = count + 1
        idx = pos + needle.length()
      }
    }
  }
  count
}

///|
/// 回归：节点 name 与容器 layout 必须经 MBT 往返存活。
/// 此前 name 完全未序列化（交互标记写在其中，往返即丢），且 layout 只在
/// frame/兜底分支解析——Rect/button/text/image 上的栈布局会被静默丢弃。
test "往返：name 与 layout 经 MBT 存活" {
  let p = @core.Project::new()
  let ab = match p.apply_template(template_id="login") {
    Ok(id) => id
    Err(_) => {
      assert_true(false)
      return
    }
  }
  match
    p.edit_node(artboard=ab, node_id="login_btn", kvs=[
      ("name", "main_cta"),
      ("layout", "vertical"),
      ("gap", "8"),
    ]) {
    Ok(_) => ()
    Err(_) => assert_true(false)
  }
  let model = match project_to_mbt(p) {
    Ok(m) => m
    Err(_) => {
      assert_true(false)
      return
    }
  }
  let mbt = model.to_mbt()
  assert_true(mbt.contains("name=\"main_cta\""))
  assert_true(mbt.contains("@decl.flex("))
  match load_mbt_project(mbt) {
    Ok(reloaded) =>
      match reloaded.project.artboards.get(ab) {
        Some(rab) =>
          match rab.doc.nodes.get("login_btn") {
            Some(n) => {
              assert_eq(n.name, "main_cta")
              match n.layout {
                Some(l) => assert_eq(l.gap, 8.0)
                None => assert_true(false)
              }
            }
            None => assert_true(false)
          }
        None => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "空态往返：零画板项目 → canonical → load 闭环（issue #27）" {
  let project = @core.Project::new()
  match project_to_mbt(project) {
    Err(error) => fail("零画板项目必须可序列化：\{error}")
    Ok(model) => {
      let canonical = model.to_mbt()
      match load_mbt_project(canonical) {
        Err(error) => fail("空态 canonical 必须可再次 load：\{error}")
        Ok(back) => assert_eq(back.project.artboards.length(), 0)
      }
    }
  }
}

///|
test "frontmatter 未知键透传：moonviz 子键与顶层键双通道（issue #20）" {  let src = "---\nmoonbit:\n  backend: native\nmoonviz:\n  format: visual-document\n  entry: w\n  extra_section: hello\n  artboards:\n    - w\n  deepdesign_ink:\n    v: 1\ncustom_top: 42\n---\n\n# T\n\n<!-- moonviz:artboard w -->\n```mbt\n///| @moonviz:visual w\nfn visual_w() -> @decl.Prototype {\n  let page = @decl.prototype(name=\"w\", width=390.0, height=844.0)\n  page\n}\n```\n"
  let model = match load_mbt_project(src) {
    Ok(m) => m
    Err(e) => {
      fail("load 失败：\{e}")
      abort("")
    }
  }
  let canonical = model.to_mbt()
  assert_true(
    canonical.contains("extra_section: hello"),
    msg="moonviz 未知子键必须透传：\{canonical}",
  )
  assert_true(
    canonical.contains("deepdesign_ink:"),
    msg="moonviz 嵌套未知子键必须透传：\{canonical}",
  )
  assert_true(
    canonical.contains("custom_top: 42"),
    msg="顶层未知键必须透传：\{canonical}",
  )
  // 幂等：canonical 再次加载后仍保留，不翻倍
  let back = match load_mbt_project(canonical) {
    Ok(m) => m
    Err(e) => {
      fail("canonical 回载失败：\{e}")
      abort("")
    }
  }
  let canonical2 = back.to_mbt()
  let needles = ["extra_section: hello", "deepdesign_ink:", "custom_top: 42"]
  for needle in needles.iter() {
    assert_true(canonical2.contains(needle), msg="二次往返必须保持 \{needle}")
  }
}

///|
/// 节点级 motion 声明面：generic_node 的 motion="fade_in" 解析进
/// NodeStyle.motion；canonical 只在设置时输出 motion=，二次加载字节稳定。
test "往返：节点 motion 经 MBT 存活且字节稳定" {
  let src = "---\nmoonviz:\n  format: visual-document\n  revision: 1\n  entry: hero\n---\n\n# Motion\n\n<!-- moonviz:artboard hero -->\n```mbt\nfn visual_hero() -> @decl.Prototype {\n  let page = @decl.prototype(name=\"hero\", width=390.0, height=844.0)\n  page.add(@decl.generic_node(id=\"hero\", component=\"frame\", kind=\"frame\", width=@decl.fixed(390.0), height=@decl.fixed(200.0), fill=\"#FFFFFF\", motion=\"fade_in\"))\n  page.add(@decl.generic_node(id=\"plain\", component=\"rect\", kind=\"rect\", width=@decl.fixed(100.0), height=@decl.fixed(100.0), fill=\"#FFFFFF\"))\n  page\n}\n```\n"
  let model = match load_mbt_project(src) {
    Ok(m) => m
    Err(e) => {
      fail("motion 文档加载失败：\{e}")
      abort("")
    }
  }
  match model.project.artboards.get("hero") {
    Some(ab) =>
      match ab.doc.nodes.get("hero") {
        Some(n) => assert_eq(n.style.motion, "fade_in")
        None => assert_true(false)
      }
    None => assert_true(false)
  }
  let canonical = model.to_mbt()
  assert_true(canonical.contains("motion=\"fade_in\""), msg=canonical)
  // 未设置 motion 的节点不写该参数：canonical 每个节点出现两次
  // （视觉块 + mbt check 块），所以只有 hero 带 motion 时计数应为 2
  // （两个 plain 节点若被误写会到 4）
  assert_eq(count_needle(canonical, "motion="), 2)
  // 二次加载 + 再次序列化：字节稳定
  let back = match load_mbt_project(canonical) {
    Ok(m) => m
    Err(e) => {
      fail("canonical 回载失败：\{e}")
      abort("")
    }
  }
  assert_eq(back.to_mbt(), canonical)
}

///|
/// 节点 motion 白名单：未知预设与写死几何的预设都必须拒绝（不静默降级
/// 成无动画字段）——press/pop/modal_present 等参数化前不开放。
test "节点 motion 白名单：未知与写死几何预设拒绝" {
  let base = "---\nmoonviz:\n  format: visual-document\n  revision: 1\n  entry: m\n---\n\n# M\n\n<!-- moonviz:artboard m -->\n```mbt\nfn visual_m() -> @decl.Prototype {\n  let page = @decl.prototype(name=\"m\", width=390.0, height=844.0)\n  page.add(@decl.generic_node(id=\"n\", component=\"rect\", kind=\"rect\", width=@decl.fixed(10.0), height=@decl.fixed(10.0), motion=\"__P__\"))\n  page\n}\n```\n"
  match load_mbt_project(base.replace(old="__P__", new="nope")) {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.contains("unknown_motion_preset"), msg=e)
  }
  for preset in ["press", "pop", "modal_present", "slide_in_right"].iter() {
    match load_mbt_project(base.replace(old="__P__", new=preset)) {
      Ok(_) => assert_true(false)
      Err(e) =>
        assert_true(e.contains("motion_preset_not_node_safe"), msg=e)
    }
  }
}

///|
/// 手势 flow 声明：.mbt.md 的 trigger 可写 swipe_left / long_press:0.8 /
/// focus（不再只认 tap:），canonical 往返保留；未知 trigger 与 focus:<node>
/// 指向不存在节点都必须报错。
test "flows：手势 trigger 声明往返与未知触发报错" {
  let src = "---\nmoonviz:\n  format: visual-document\n  revision: 1\n  entry: f1\n  flows:\n    - from: f1\n      to: f2\n      trigger: swipe_left\n    - from: f1\n      to: f2\n      trigger: long_press:0.8\n    - from: f1\n      to: f2\n      trigger: focus\n---\n\n# F\n\n<!-- moonviz:artboard f1 -->\n```mbt\nfn visual_f1() -> @decl.Prototype {\n  let page = @decl.prototype(name=\"f1\", width=390.0, height=844.0)\n  page\n}\n```\n\n<!-- moonviz:artboard f2 -->\n```mbt\nfn visual_f2() -> @decl.Prototype {\n  let page = @decl.prototype(name=\"f2\", width=390.0, height=844.0)\n  page\n}\n```\n"
  let model = match load_mbt_project(src) {
    Ok(m) => m
    Err(e) => {
      fail("手势 flow 文档加载失败：\{e}")
      abort("")
    }
  }
  assert_eq(model.project.flows.length(), 3)
  let canonical = model.to_mbt()
  assert_true(canonical.contains("trigger: swipe_left"), msg=canonical)
  assert_true(canonical.contains("trigger: long_press:0.8"), msg=canonical)
  assert_true(canonical.contains("trigger: focus"), msg=canonical)
  let back = match load_mbt_project(canonical) {
    Ok(m) => m
    Err(e) => {
      fail("canonical 回载失败：\{e}")
      abort("")
    }
  }
  assert_eq(back.project.flows.length(), 3)
  // 未知 trigger
  let bad = src.replace(old="trigger: swipe_left", new="trigger: nonsense:xyz")
  match load_mbt_project(bad) {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.contains("mbt_flow_unknown_trigger"), msg=e)
  }
  // focus:<node> 指向不存在节点
  let bad2 = src.replace(old="trigger: focus", new="trigger: focus:missing")
  match load_mbt_project(bad2) {
    Ok(_) => assert_true(false)
    Err(e) =>
      assert_true(e.contains("mbt_flow_unknown_node:f1:missing"), msg=e)
  }
}

///|
/// 分板过渡声明：transition: modal_present 落 frontmatter 并往返；默认
/// push 不写（旧文档字节稳定）；未知过渡加载即报错。
test "flows：transition 声明往返与默认 Push 省略" {
  let src = "---\nmoonviz:\n  format: visual-document\n  revision: 1\n  entry: t1\n  flows:\n    - from: t1\n      to: t2\n      trigger: focus\n      transition: modal_present\n    - from: t1\n      to: t2\n      trigger: swipe_left\n---\n\n# T\n\n<!-- moonviz:artboard t1 -->\n```mbt\nfn visual_t1() -> @decl.Prototype {\n  let page = @decl.prototype(name=\"t1\", width=390.0, height=844.0)\n  page\n}\n```\n\n<!-- moonviz:artboard t2 -->\n```mbt\nfn visual_t2() -> @decl.Prototype {\n  let page = @decl.prototype(name=\"t2\", width=390.0, height=844.0)\n  page\n}\n```\n"
  let model = match load_mbt_project(src) {
    Ok(m) => m
    Err(e) => {
      fail("transition 文档加载失败：\{e}")
      abort("")
    }
  }
  assert_eq(model.project.flows.length(), 2)
  assert_eq(model.project.flows[0].transition, "modal_present")
  assert_eq(model.project.flows[1].transition, "push")
  let canonical = model.to_mbt()
  assert_true(canonical.contains("transition: modal_present"), msg=canonical)
  // 默认 push 不写：全文只出现一次 transition:
  assert_eq(count_needle(canonical, "transition:"), 1)
  let fj = model.project.flow_json()
  assert_true(fj.contains("\"transition\":\"modal_present\""), msg=fj)
  assert_true(fj.contains("\"transition\":\"push\""), msg=fj)
  let back = match load_mbt_project(canonical) {
    Ok(m) => m
    Err(e) => {
      fail("canonical 回载失败：\{e}")
      abort("")
    }
  }
  assert_eq(back.project.flows[0].transition, "modal_present")
  // 未知过渡
  let bad = src.replace(old="transition: modal_present", new="transition: nonsense")
  match load_mbt_project(bad) {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.contains("mbt_flow_unknown_transition"), msg=e)
  }
}
