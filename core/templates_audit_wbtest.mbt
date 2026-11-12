/// 模板系统化打磨的审计锚（P8）：遍历模板，把验收里的可量化项直接断言。
///
/// 与 generate_wbtest / norms_wbtest 的分工：这里只测「模板出厂几何 +
/// critique/lint 度量」，不测生成算法。度量项（alignment/balance/rhythm/
/// norms/hierarchy/focus）走 critique 信封，几何项走 solve 后的绝对 rect。

///|
fn audit_apply(
  id : String,
  width~ : Double = 0.0,
  height~ : Double = 0.0,
) -> (Project, String) {
  let p = Project::new()
  let ab = match p.apply_template(template_id=id, width~, height~) {
    Ok(a) => a
    Err(e) => abort("模板 \{id} 应用失败：\{e}")
  }
  (p, ab)
}

///|
fn audit_critique(p : Project, ab : String) -> String {
  match p.critique(artboard=ab) {
    Ok(j) => j
    Err(e) => abort("critique 失败：\{e}")
  }
}

///|
/// 从 critique 信封取某维度分数（顺序固定：principle 后紧跟 score）。
fn audit_score(json : String, principle : String) -> Int32 {
  let pat = "\"principle\":\"" + principle + "\",\"score\":"
  match json.find(pat) {
    None => -1
    Some(pos) => {
      let rest = json.substring(start=pos + pat.length())
      let mut n = 0
      let mut i = 0
      while i < rest.length() {
        match rest.get_char(i) {
          Some(c) =>
            if c >= '0' && c <= '9' {
              n = n * 10 + (c.to_int() - 48)
              i = i + 1
            } else {
              break
            }
          None => break
        }
      }
      n
    }
  }
}

///|
fn audit_lint_errors(json : String) -> Int32 {
  count_occurrences(json, "\"severity\":\"error\"")
}

///|
fn audit_node(doc : Document, id : String) -> Node {
  match doc.nodes.get(id) {
    Some(n) => n
    None => abort("节点缺失：\{id}")
  }
}

///|
/// 卡片上下内边距（绝对坐标）：首子 top 距 + 末子 bottom 距。
fn audit_card_padding(doc : Document, card_id : String) -> (Double, Double) {
  let layout = solve(doc)
  let card = audit_node(doc, card_id)
  let c = match layout.rect_of(card_id) {
    Some(r) => r
    None => abort("卡片无布局：\{card_id}")
  }
  let mut min_top = 1000000.0
  // 下内边距取「最低子节点」的底距（min），不是最大底距——最大底距来自
  // 最上面的子节点，会把内边距算成整个内容块高度
  let mut min_bottom = 1000000.0
  for cid in card.children.iter() {
    match layout.rect_of(cid) {
      Some(r) => {
        let top = r.y - c.y
        let bottom = c.y + c.height - (r.y + r.height)
        if top < min_top {
          min_top = top
        }
        if bottom < min_bottom {
          min_bottom = bottom
        }
      }
      None => ()
    }
  }
  if min_top == 1000000.0 {
    (0.0, 0.0)
  } else {
    (min_top, min_bottom)
  }
}

///|
fn audit_abs_x(doc : Document, id : String) -> Double {
  match solve(doc).rect_of(id) {
    Some(r) => r.x
    None => abort("节点无布局：\{id}")
  }
}

///|
fn audit_abs_right(doc : Document, id : String) -> Double {
  match solve(doc).rect_of(id) {
    Some(r) => r.x + r.width
    None => -1.0
  }
}

///|
fn audit_distinct_font_sizes(doc : Document) -> Int32 {
  let sizes : Map[Double, Bool] = Map([])
  for id in doc.nodes.keys() {
    match doc.nodes.get(id) {
      Some(n) => sizes.set(n.style.font_size, true)
      None => ()
    }
  }
  sizes.length()
}

///|
fn audit_max_top_bottom(doc : Document) -> Double {
  let layout = solve(doc)
  let root = audit_node(doc, doc.root_id)
  let mut max_bottom = 0.0
  for cid in root.children.iter() {
    match layout.rect_of(cid) {
      Some(r) => if r.y + r.height > max_bottom { max_bottom = r.y + r.height }
      None => ()
    }
  }
  max_bottom
}

///|
/// ① 度量：lint 对比度回溯祖先背景（pc_app 9→0）；balance 中心 ±2px 中性；
/// alignment 计入右缘/右对齐文本。
test "模板审计：lint 对比度不误报 + balance 中心中性 + alignment 右缘" {
  // 全部模板 lint 零 error（pc_app/web_dashboard/web_login 的深色 chrome
  // 浅色文字此前被按白底误报）
  for
    id in [
      "login", "signup", "dashboard", "profile", "settings", "list", "detail", "checkout",
      "list_detail", "onboarding", "empty_state", "web_landing", "web_login", "web_dashboard",
      "pc_app", "adaptive_landing", "login_v2",
    ].iter() {
    let (p, ab) = audit_apply(id)
    let lint = match p.lint(artboard=ab) {
      Ok(j) => j
      Err(e) => abort("lint 失败：\{e}")
    }
    assert_eq(
      audit_lint_errors(lint),
      0,
      msg="模板 \{id} lint 不应有 contrast error",
    )
  }
  // balance：居中的登录/注册/仪表盘不再被算成「左0%/右100%」
  for id in ["login", "signup", "dashboard"].iter() {
    let (p, ab) = audit_apply(id)
    let score = audit_score(audit_critique(p, ab), "balance")
    assert_true(score >= 6, msg="\{id} balance 应 ≥6，实际 \{score}")
  }
  // alignment：右对齐文本的节点（金额/规格/行尾）必须算右缘对齐
  let checks : Array[(String, String, String)] = [
    ("checkout", "fee_v0", "10"),
    ("detail", "spec_v0", "10"),
    ("settings", "item_c3_0", "10"),
  ]
  for c in checks.iter() {
    let (id, nid, want) = c
    let (p, ab) = audit_apply(id)
    let doc = match p.artboards.get(ab) {
      Some(a) => a.doc
      None => {
        assert_true(false)
        return
      }
    }
    assert_eq(audit_node(doc, nid).style.text_align, "right")
    assert_eq(
      audit_score(audit_critique(p, ab), "alignment").to_string(),
      want,
      msg="\{id} alignment 应含右缘节点 \{nid}",
    )
  }
}

///|
/// ② 五处卡片上下内边距对称（差 ≤2px）：dashboard 22/22、checkout 25/25、
/// profile stat 18/18 与 post 23/23（两卡不同档但各自对称）、
/// web_dashboard 18/18、adaptive 居中。数值为 solve 后实测，改模板块距时须同步。
test "模板审计：五处卡片上下内边距差 ≤2px" {
  let cases : Array[(String, String)] = [
    ("dashboard", "stat_0"),
    ("checkout", "summary"),
    ("profile", "stat_0"),
    ("profile", "post_0"),
    ("web_dashboard", "wd_stat0"),
    ("adaptive_landing", "feat_c0"),
  ]
  for c in cases.iter() {
    let (id, card_id) = c
    let (p, ab) = if id == "adaptive_landing" {
      audit_apply(id, width=1280.0)
    } else {
      audit_apply(id)
    }
    let doc = match p.artboards.get(ab) {
      Some(a) => a.doc
      None => {
        assert_true(false)
        return
      }
    }
    let (top, bottom) = audit_card_padding(doc, card_id)
    let diff = if top > bottom { top - bottom } else { bottom - top }
    assert_true(
      diff <= 2.0,
      msg="\{id}/\{card_id} 上下内边距应 ≤2px，实际 \{top}/\{bottom}",
    )
  }
}

///|
/// ③ 居中类模板对齐：empty_state 0→10、onboarding 5/8→10、login ≥9。
test "模板审计：empty_state/onboarding/login 对齐达标" {
  for c in [("empty_state", 10), ("onboarding", 10), ("login", 9)].iter() {
    let (id, min_score) = c
    let (p, ab) = audit_apply(id)
    let score = audit_score(audit_critique(p, ab), "alignment")
    assert_true(
      score >= min_score,
      msg="\{id} alignment 应 ≥\{min_score}，实际 \{score}",
    )
  }
}

///|
/// ④ 宽屏内容线：web_landing 三条左线同 x=96、CTA/卡右缘 1184；
/// adaptive nav/footer padding=24；pc_app title/toolbar/status 内容同 x。
test "模板审计：web_landing/pc_app/adaptive 内容线与栅格" {
  let (p, ab) = audit_apply("web_landing")
  let doc = match p.artboards.get(ab) {
    Some(a) => a.doc
    None => {
      assert_true(false)
      return
    }
  }
  assert_eq(audit_score(audit_critique(p, ab), "alignment"), 10)
  assert_eq(audit_abs_x(doc, "nav_logo"), 96.0)
  assert_eq(audit_abs_x(doc, "hero_title"), 96.0)
  assert_eq(audit_abs_x(doc, "footer_note"), 96.0)
  assert_eq(audit_abs_right(doc, "nav_cta"), 1184.0)
  assert_eq(audit_abs_right(doc, "feat_card2"), 1184.0)

  let (pa, aba) = audit_apply("adaptive_landing", width=1280.0)
  let doca = match pa.artboards.get(aba) {
    Some(a) => a.doc
    None => {
      assert_true(false)
      return
    }
  }
  for nid in ["nav", "footer"].iter() {
    match audit_node(doca, nid).layout {
      Some(l) => assert_eq(l.padding.top, 24.0, msg="\{nid} padding 应为 24")
      None => assert_true(false)
    }
  }
  let crit = audit_critique(pa, aba)
  assert_eq(audit_score(crit, "rhythm"), 8, msg="adaptive rhythm 应 8")
  assert_true(audit_score(crit, "norms") >= 7, msg="adaptive norms 应 ≥7")
  assert_false(
    crit.contains("not on 4pt grid"),
    msg="adaptive 不应有 4pt 偏差",
  )

  let (pp, abp) = audit_apply("pc_app")
  let docp = match pp.artboards.get(abp) {
    Some(a) => a.doc
    None => {
      assert_true(false)
      return
    }
  }
  let x_title = audit_abs_x(docp, "tl_title")
  let x_toolbar = audit_abs_x(docp, "pc_tbn0")
  let x_status = audit_abs_x(docp, "pc_st")
  assert_eq(x_title, x_toolbar, msg="titlebar/toolbar 内容 x 应一致")
  assert_eq(x_toolbar, x_status, msg="toolbar/status 内容 x 应一致")
}

///|
/// ⑤ 层级与行结构：list/list_detail ≥3 字号；list 行 children≥2；
/// chat 行 children=4。
test "模板审计：list/list_detail 层级与行内结构" {
  let (pl, abl) = audit_apply("list")
  let docl = match pl.artboards.get(abl) {
    Some(a) => a.doc
    None => {
      assert_true(false)
      return
    }
  }
  assert_true(
    audit_distinct_font_sizes(docl) >= 3,
    msg="list 应 ≥3 档字号",
  )
  assert_eq(audit_score(audit_critique(pl, abl), "visual_hierarchy"), 9)
  for i in 0..<5 {
    let n = audit_node(docl, "item_\{i}")
    assert_true(n.children.length() >= 2, msg="list 行应有 ≥2 子节点")
  }
  let (pd, abd) = audit_apply("list_detail")
  let docd = match pd.artboards.get(abd) {
    Some(a) => a.doc
    None => {
      assert_true(false)
      return
    }
  }
  assert_true(
    audit_distinct_font_sizes(docd) >= 3,
    msg="list_detail 应 ≥3 档字号",
  )
  assert_eq(audit_score(audit_critique(pd, abd), "visual_hierarchy"), 9)
  for i in 0..<5 {
    let n = audit_node(docd, "chat_\{i}")
    assert_eq(
      n.children.length(),
      4,
      msg="chat 行应为头像/姓名/预览/时间 4 子节点",
    )
  }
}

///|
/// ⑥ 结构式模板：login_v2 norms ≥8 + focus 9；adaptive norms ≥7 + rhythm 8。
test "模板审计：login_v2/adaptive 规范与节奏" {
  let (p, ab) = audit_apply("login_v2")
  let crit = audit_critique(p, ab)
  assert_true(audit_score(crit, "norms") >= 8, msg="login_v2 norms 应 ≥8")
  assert_eq(audit_score(crit, "focus"), 9, msg="login_v2 focus 应 9")
}

///|
/// ⑦ 底部操作条：detail/checkout 全宽 bar（0..390、直角、surface、顶部
/// hairline），bar 顶到按钮 ≤32；list_detail 尾部 ≤120。
test "模板审计：detail/checkout 底部操作条与 list_detail 尾部" {
  let surface = DesignTokens::default().resolve_color("surface")
  for c in [("detail", "primary_btn"), ("checkout", "submit_btn")].iter() {
    let (id, btn) = c
    let (p, ab) = audit_apply(id)
    let doc = match p.artboards.get(ab) {
      Some(a) => a.doc
      None => {
        assert_true(false)
        return
      }
    }
    let bar = audit_node(doc, "cta_bar")
    assert_eq(bar.style.corner_radius, 0.0, msg="bar 必须直角")
    assert_eq(bar.style.fill, surface, msg="bar 必须 surface 底")
    let bar_rect = match solve(doc).rect_of("cta_bar") {
      Some(r) => r
      None => {
        assert_true(false)
        return
      }
    }
    let btn_rect = match solve(doc).rect_of(btn) {
      Some(r) => r
      None => {
        assert_true(false)
        return
      }
    }
    assert_eq(bar_rect.x, 0.0, msg="bar 必须从 0 起")
    assert_eq(bar_rect.width, 390.0, msg="bar 必须全宽")
    assert_true(
      btn_rect.y - bar_rect.y <= 32.0,
      msg="bar 顶到按钮应 ≤32",
    )
    let hair = audit_node(doc, "cta_hair")
    assert_eq(
      hair.style.fill,
      DesignTokens::default().resolve_color("outline_variant"),
    )
    let hair_rect = match solve(doc).rect_of("cta_hair") {
      Some(r) => r
      None => {
        assert_true(false)
        return
      }
    }
    assert_eq(hair_rect.y, bar_rect.y, msg="hairline 应贴 bar 顶")
  }
  let (pl, abl) = audit_apply("list_detail")
  let docl = match pl.artboards.get(abl) {
    Some(a) => a.doc
    None => {
      assert_true(false)
      return
    }
  }
  let tail = 844.0 - audit_max_top_bottom(docl)
  assert_true(
    tail <= 120.0,
    msg="list_detail 尾部应 ≤120，实际 \{tail}",
  )
}

///|
/// ⑧ 分宽度 flow 完整性：adaptive_landing 390/768/1280 三档生成的每条
/// tap:<node> flow 都必须指向该画板真实存在的节点（nav_cta 只在桌面树）。
test "模板审计：adaptive 全宽度 flow 目标都存在" {
  for w in [390.0, 768.0, 1280.0].iter() {
    let (p, ab) = audit_apply("adaptive_landing", width=w)
    let doc = match p.artboards.get(ab) {
      Some(a) => a.doc
      None => {
        assert_true(false)
        return
      }
    }
    for f in p.flows.iter() {
      if f.from == ab && f.trigger.has_prefix("tap:") {
        let nid = f.trigger.substring(start=4)
        assert_true(
          doc.has(nid),
          msg="宽 \{w}：flow tap:\{nid} 指向不存在的节点",
        )
      }
    }
  }
}

///|
/// ⑨ 8pt 栅格按字面锁定：login/onboarding/empty_state 的固定宽度与
/// StackLayout 的 padding/gap 都必须是 8 的倍数。画布根宽 390 是设备
/// 宽度、不属组件尺寸，跳过；Fill/Hug 由父约束求解，也不在此列。
/// 这条是把验收③从「看起来对齐」变成「生成即满足」的回归锚。
test "模板审计：login/onboarding/empty_state 宽度与间距取 8 的倍数" {
  for id in ["login", "onboarding", "empty_state"].iter() {
    let (p, ab) = audit_apply(id)
    let doc = match p.artboards.get(ab) {
      Some(a) => a.doc
      None => abort("模板 \{id} 无画板")
    }
    for nid in doc.nodes.keys() {
      if nid == "root" {
        continue
      }
      let n = match doc.nodes.get(nid) {
        Some(n) => n
        None => abort("节点缺失：\{nid}")
      }
      match n.width {
        Fixed(w) =>
          if w % 8.0 != 0.0 {
            abort("\{id}:\{nid} 宽度 \{w} 不是 8 的倍数")
          }
        _ => ()
      }
      match n.layout {
        Some(l) => {
          let pads : Array[(String, Double)] = [
            ("top", l.padding.top),
            ("right", l.padding.right),
            ("bottom", l.padding.bottom),
            ("left", l.padding.left),
            ("gap", l.gap),
          ]
          for pad in pads.iter() {
            let (side, v) = pad
            if v % 8.0 != 0.0 {
              abort("\{id}:\{nid} \{side} \{v} 不是 8 的倍数")
            }
          }
        }
        None => ()
      }
    }
  }
}
