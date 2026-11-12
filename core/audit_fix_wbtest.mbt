/// 视觉审计修复回归锚（2026-11 视觉审计批次）：
/// S1 容器变体文字角色 × 两种放置顺序、S2 暗色画布底兜底（fix 不再改坏
/// 正确文字）、S5 全主题角色集完备 + 提示文字可读、S6 按宽折行 / 保留空白 /
/// 行盒垂直居中、S3 结构式模板 kids 回归与居中。

///|
/// S1 回归锚：带文字的容器变体（card/app_bar/text_input/tab_bar）在
/// 「先切主题」与「先放模板」两种顺序下落到同一组（fill, text_color）——
/// theme→template 走放置时令牌解析，template→theme 走 recolor 字面量反查，
/// 两条路径必须同效（暗色下出厂黑字压深底的整类事故由此锚死）。
test "主题：容器文字角色在两种放置顺序下同效" {
  for theme_name in ["apple_dark", "harmony_dark", "dark", "nord"].iter() {
    // web_login/detail 覆盖 badge on_primary 与 button secondary_container
    // 两类反查歧义位（第 4 轮 web_login brand_logo 50/51 唯一差即前者）
    for
      tpl in ["login", "dashboard", "settings", "list", "web_login", "detail"].iter() {
      let pa = Project::new()
      let _ = pa.apply_theme(theme_name)
      let _ = pa.apply_template(template_id=tpl, name="board")
      let pb = Project::new()
      let _ = pb.apply_template(template_id=tpl, name="board")
      let _ = pb.apply_theme(theme_name)
      match (pa.artboards.get("board"), pb.artboards.get("board")) {
        (Some(aba), Some(abb)) =>
          for nid in aba.doc.nodes.keys() {
            match (aba.doc.get(nid), abb.doc.get(nid)) {
              (Some(na), Some(nb)) => {
                // 同 id 节点两种顺序下底色与文字色一致（文字色不一致正是
                // 「顺序决定生死」事故的表征）
                assert_eq(
                  na.style.fill,
                  nb.style.fill,
                  msg="\{theme_name}/\{tpl} 节点 \{nid} fill 两顺序不一致",
                )
                if na.text.length() > 0 {
                  assert_eq(
                    na.style.text_color,
                    nb.style.text_color,
                    msg="\{theme_name}/\{tpl} 节点 \{nid} text_color 两顺序不一致",
                  )
                }
              }
              _ =>
                assert_true(
                  false,
                  msg="\{theme_name}/\{tpl} 节点 \{nid} 缺失",
                )
            }
          }
        _ => assert_true(false)
      }
    }
  }
}

///|
/// S1/S5 回归锚：暗色主题下任何模板的任何文字节点都不再落出厂黑 #111111
/// （撞色红线 2.0 以下整类清除）。
test "主题：暗色主题下模板文字无出厂黑" {
  for theme_name in ["apple_dark", "harmony_dark", "dark"].iter() {
    for
      tpl in [
        "login", "signup", "dashboard", "profile", "settings", "list", "detail",
        "checkout", "list_detail", "onboarding", "empty_state", "web_landing", "web_login",
        "web_dashboard", "pc_app", "adaptive_landing", "login_v2",
      ].iter() {
      let p = Project::new()
      let _ = p.apply_theme(theme_name)
      let _ = p.apply_template(template_id=tpl, name="board")
      match p.artboards.get("board") {
        None => assert_true(false, msg="\{tpl} 缺画板")
        Some(ab) =>
          for nid in ab.doc.nodes.keys() {
            match ab.doc.get(nid) {
              Some(n) =>
                if n.text.length() > 0 {
                  assert_false(
                    n.style.text_color == "#111111",
                    msg="\{theme_name}/\{tpl} 节点 \{nid} 文字仍是出厂黑 #111111",
                  )
                }
              None => ()
            }
          }
      }
    }
  }
}

///|
/// S5 回归锚：角色集在全部内置主题完备——token 解析不会把角色名原样
/// 落成非法色值（结构式模板按角色取色的前提）。
test "主题：全部内置主题令牌角色集完备" {
  let roles = [
    "primary", "primary_container", "on_primary", "on_secondary_container", "secondary",
    "secondary_container", "text_on_primary", "surface", "surface_variant", "background",
    "error", "error_container", "success", "warning", "outline", "outline_variant",
    "text_primary", "text_secondary", "text_hint",
  ]
  for th in builtin_themes().iter() {
    for role in roles.iter() {
      let v = th.tokens.resolve_color(role)
      assert_true(
        norm_is_hex6(v),
        msg="主题 \{th.name} 角色 \{role} 未定义（解析出 \{v}）",
      )
    }
  }
}

///|
/// S2 回归锚：透明底文字的有效背景兜底 = 画板/主题底色。暗色画布上的
/// 亮色文字（#F5F5F7 on #1C1C1E 实为 12.8:1 合规）不再被误判为白底撞色、
/// 也不再被 fix 翻成近黑在画布上不可见（审计 R6：12 模板 16 节点被改坏）。
test "norms：暗色画布底兜底——fix 不再翻转正确的亮色文字" {
  let doc = Document::new({ width: 390.0, height: 844.0, })
  let title = {
    ..Node::make("title", Text),
    width: Fixed(300.0),
    height: Fixed(40.0),
    style: { ..NodeStyle::default(), text_color: "#F5F5F7", },
    text: "Alice Baker",
  }
  let _ = doc.insert_node(title, "root")
  let layout = solve(doc)
  let canvas_bg = "#1C1C1E"
  // 检测：不以白底兜底误报撞色
  assert_eq(
    norm_issues(doc, layout, canvas_bg~).length(),
    0,
    msg="暗底亮字被误报撞色",
  )
  // 修复：不产生任何撞色修复，文字保持亮色
  let fixes = norm_fix_pass(doc, layout, canvas_bg~)
  assert_eq(fixes.length(), 0, msg="暗底亮字被 fix 改动")
  match doc.get("title") {
    Some(n) => assert_eq(n.style.text_color, "#F5F5F7")
    None => assert_true(false)
  }
  // 反向对照：白底兜底（旧行为）确实会误报——证明兜底值真的被消费
  assert_true(norm_issues(doc, layout).length() > 0)
}

///|
/// S6 回归锚：按节点宽贪心折行（拉丁按词 / CJK 逐字 / 超宽 token 硬断）。
test "文本：wrap_text_lines 折行口径" {
  // 拉丁按词折行：每行不超宽，行数 > 1
  let latin = "A short paragraph describing this item in two or three lines."
  let lines = wrap_text_lines(latin, 14.0, 342.0)
  assert_true(lines.length() > 1, msg="342 宽应折成多行")
  for l in lines.iter() {
    assert_true(
      token_advance(l, 14.0) <= 342.0 + 0.5,
      msg="折行后行宽超盒：\{l}",
    )
  }
  // CJK 逐字断：14px 全角每字 14，100 宽每行 7 字
  let cjk = "一二三四五六七八九十甲乙丙丁戊己庚辛壬癸"
  let clines = wrap_text_lines(cjk, 14.0, 100.0)
  assert_eq(clines.length(), 3)
  assert_eq(clines[0], "一二三四五六七")
  // 超宽无空格 token 按字符硬断
  let hard = wrap_text_lines("abcdefghijklmnopqrstuvwxyz", 10.0, 50.0)
  assert_true(hard.length() > 1, msg="超宽 token 应硬断")
  // 显式 \n 保留分段语义
  assert_eq(wrap_text_lines("a\nb", 14.0, 342.0).length(), 2)
}

///|
/// S6 回归锚：渲染输出——xml:space=preserve（模板空格分列不被折叠）、
/// 折行 tspan、行盒垂直居中（36 高行盒 + 14px 单行 → 基线在盒中线下移）。
test "渲染：preserve / 折行 tspan / 行盒垂直居中" {
  let doc = Document::new({ width: 390.0, height: 844.0, })
  // 行盒垂直居中：36 高盒 + 14px 单行（块高 21）→ block_top = y + 7.5，
  // 基线 = block_top + 14 = y + 21.5；节点在原点 → 基线 21.5
  // （旧行为首行基线 y+14，文字顶在行盒上沿）
  let fee = {
    ..Node::make("fee", Text),
    width: Fixed(342.0),
    height: Fixed(36.0),
    style: { ..NodeStyle::default(), text_color: "#42474F", },
    text: "Subtotal",
  }
  let _ = doc.insert_node(fee, "root")
  // 折行：340 宽盒放 60+ 字符 → tspan 多行
  let desc = {
    ..Node::make("desc", Text),
    width: Fixed(340.0),
    height: Fixed(60.0),
    style: { ..NodeStyle::default(), text_color: "#42474F", },
    text: "A short paragraph describing this item in two or three lines of real copy.",
  }
  let _ = doc.insert_node(desc, "root")
  // 空格保留：字段间隔空格原样输出
  let status = {
    ..Node::make("status", Text),
    width: Fixed(342.0),
    height: Fixed(18.0),
    style: { ..NodeStyle::default(), text_color: "#42474F", },
    text: "ops: 3   revision: 12",
  }
  let _ = doc.insert_node(status, "root")
  let svg = render_svg(doc)
  assert_true(
    svg.contains("xml:space=\"preserve\""),
    msg="渲染未输出 xml:space=preserve",
  )
  assert_true(
    svg.contains("ops: 3   revision: 12"),
    msg="连续空格被折叠",
  )
  assert_true(
    svg.contains("y=\"21.5\""),
    msg="行盒未垂直居中（期望基线 21.5）",
  )
  // desc 节点应产出多个 tspan（折行生效）
  let seg = extract_g(svg, "desc")
  assert_true(seg.contains("<tspan"), msg="desc 未折行（无 tspan）")
}

///|
/// 第 5 轮回归锚：主题往返切换（apple→apple_dark→apple）必须还原
/// divider/次按钮的 outline_variant/secondary_container 角色——旧行为
/// 按 base rank 字典序塌缩成 surface_variant #EDEDF2（14 模板 39 节点）。
test "主题：往返切换还原描边与容器角色（消歧 ctx 回归锚）" {
  let p = Project::new()
  let _ = p.apply_template(template_id="detail", name="board")
  let _ = p.apply_theme("apple_dark")
  let _ = p.apply_theme("apple")
  match p.artboards.get("board") {
    None => assert_true(false)
    Some(ab) => {
      match ab.doc.get("divider_0") {
        Some(n) =>
          assert_eq(
            n.style.fill,
            "#E5E5EA",
            msg="divider 往返后应还原 outline_variant",
          )
        None => assert_true(false, msg="divider_0 缺失")
      }
      match ab.doc.get("back_btn") {
        Some(n) =>
          assert_eq(
            n.style.fill,
            "#E9E9EE",
            msg="次按钮往返后应还原 secondary_container",
          )
        None => assert_true(false, msg="back_btn 缺失")
      }
    }
  }
}

///|
/// 第 6 轮回归锚：text 语境直派——语义色实底（error/primary 面板）与
/// secondary_container 底上的文字随主题直派 on_*，往返切换字节稳定。
/// 旧行为：text_rank 只认自身 fill 的 primary/secondary，logout_btn
/// （error 底）与透明底压 primary 面板的 brand_title 被误归 text_*，
/// light→dark→light 把白字永久漂成近黑（撞色）。
test "主题：语义底文字直派与往返稳定（text ctx 回归锚）" {
  // settings logout_btn：button danger（error 底）→ on_primary
  let p1 = Project::new()
  let _ = p1.apply_theme("light")
  let _ = p1.apply_template(template_id="settings", name="board")
  let _ = p1.apply_theme("dark")
  let _ = p1.apply_theme("light")
  match p1.artboards.get("board") {
    None => assert_true(false)
    Some(ab) =>
      match ab.doc.get("logout_btn") {
        Some(n) =>
          assert_eq(
            n.style.text_color,
            "#FFFFFF",
            msg="danger 底文字应还原 on_primary 白",
          )
        None => assert_true(false, msg="logout_btn 缺失")
      }
  }
  // web_login brand_title：透明底压 brand_pane（primary）→ on_primary
  let p2 = Project::new()
  let _ = p2.apply_theme("light")
  let _ = p2.apply_template(template_id="web_login", name="board")
  let _ = p2.apply_theme("dark")
  let _ = p2.apply_theme("light")
  match p2.artboards.get("board") {
    None => assert_true(false)
    Some(ab) =>
      match ab.doc.get("brand_title") {
        Some(n) =>
          assert_eq(
            n.style.text_color,
            "#FFFFFF",
            msg="primary 面板文字应还原 on_primary 白",
          )
        None => assert_true(false, msg="brand_title 缺失")
      }
  }
  // sunset back_btn：button secondary（secondary_container 底）→
  // on_secondary_container，sunset→apple→sunset 文字不漂 text_primary
  let p3 = Project::new()
  let _ = p3.apply_theme("sunset")
  let _ = p3.apply_template(template_id="detail", name="board")
  let _ = p3.apply_theme("apple")
  let _ = p3.apply_theme("sunset")
  match p3.artboards.get("board") {
    None => assert_true(false)
    Some(ab) =>
      match ab.doc.get("back_btn") {
        Some(n) => {
          assert_eq(
            n.style.fill,
            "#FBE9E7",
            msg="次按钮底应还原 secondary_container",
          )
          assert_eq(
            n.style.text_color,
            "#4E2A18",
            msg="次按钮文字应还原 on_secondary_container",
          )
        }
        None => assert_true(false, msg="back_btn 缺失")
      }
  }
}

///|
fn extract_g(svg : String, id : String) -> String {
  let open = "<g id=\"n_" + id + "\""
  match find_sub(svg, open) {
    None => ""
    Some(start) => {
      let close = find_sub_from(svg, "</g>", start)
      match close {
        None => ""
        Some(end) => svg[start:end + 4].to_owned()
      }
    }
  }
}

///|
fn find_sub(s : String, needle : String) -> Int32? {
  find_sub_from(s, needle, 0)
}

///|
fn find_sub_from(s : String, needle : String, from : Int32) -> Int32? {
  let n = s.length()
  let m = needle.length()
  let sc = s.to_array()
  let nc = needle.to_array()
  let mut i = from
  while i + m <= n {
    let mut ok = true
    let mut j = 0
    while j < m {
      if sc[i + j] != nc[j] {
        ok = false
        j = m
      }
      j = j + 1
    }
    if ok {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
/// S3 回归锚（64bb71d kids 回归）：结构式模板的卡片子树必须完整落图——
/// login_v2 登录卡 8 个子节点、adaptive_landing 特性卡内容不丢。
test "结构式模板：卡片子树完整（kids 回归锚）" {
  let p = Project::new()
  let _ = p.apply_template(template_id="login_v2", name="lv2")
  match p.artboards.get("lv2") {
    None => assert_true(false)
    Some(ab) => {
      for
        must in [
          "email", "pass", "forgot", "login_btn", "title", "sub", "signup",
        ].iter() {
        assert_true(
          ab.doc.nodes.contains(must),
          msg="login_v2 丢子节点 \{must}（lt_card kids 回归）",
        )
      }
      // 文本子节点居中：title 是 Text 且 text_align=center
      match ab.doc.get("title") {
        Some(n) => assert_eq(n.style.text_align, "center")
        None => assert_true(false)
      }
      // 登录按钮与输入框同宽（Fill），不再是 152 定宽孤块
      match ab.doc.get("login_btn") {
        Some(n) =>
          match n.width {
            Fill => ()
            _ => assert_true(false, msg="login_btn 应为 Fill 宽")
          }
        None => assert_true(false)
      }
    }
  }
  let p2 = Project::new()
  let _ = p2.apply_template(template_id="adaptive_landing", name="al")
  match p2.artboards.get("al") {
    None => assert_true(false)
    Some(ab) =>
      for i in 0..<3 {
        let tid = "feat_t\{i}"
        let cid = "feat_c\{i}"
        match ab.doc.get(tid) {
          Some(n) =>
            match ab.doc.find_parent(n.id) {
              Some(parent) =>
                assert_eq(parent, cid, msg="\{tid} 应收编进 \{cid}")
              None => assert_true(false, msg="\{tid} 无父节点")
            }
          None =>
            assert_true(
              false,
              msg="特性卡内容 \{tid} 丢失（kids 回归）",
            )
        }
      }
  }
}

///|
/// S3 回归锚：结构式模板随主题取色——先切暗色主题再生成，hero_art/按钮/
/// 卡片都落暗色令牌（不再出厂白卡压暗画布）；且布局容器（page/lt_v/
/// spacer）不再被渲染层描虚线线框。
test "结构式模板：暗色令牌 + 布局容器无虚线" {
  let p = Project::new()
  let _ = p.apply_theme("apple_dark")
  let _ = p.apply_template(template_id="adaptive_landing", name="al")
  let _ = p.apply_template(template_id="login_v2", name="lv2")
  let svg_dark = match p.export_svg(artboard="al") {
    Ok(s) => s
    Err(_) => ""
  }
  // hero_art = primary_container 暗色值，而非出厂 #EDF1FE
  assert_false(
    svg_dark.contains("#EDF1FE"),
    msg="插图占位仍是硬编码亮色",
  )
  // 布局容器/spacer 不再有装饰虚线框（线框稿观感的根因）
  assert_false(
    svg_dark.contains("stroke-dasharray=\"4 3\""),
    msg="布局容器仍被描虚线",
  )
  match p.export_svg(artboard="lv2") {
    Ok(s) =>
      assert_false(
        s.contains("fill=\"#FFFFFF\""),
        msg="login_v2 卡仍是出厂白",
      )
    Err(_) => assert_true(false)
  }
}

///|
/// 第 2 轮盲区回归锚：norms「文字折行超盒高」检测——固定矮盒装不下
/// 折出的行数时按检测项报出（此前 profile 统计卡越出 34px、detail 描述
/// 越 130px、onboarding 副标题越 213px 全部无人报）。
test "norms：文字折行超盒高检测" {
  let doc = Document::new({ width: 390.0, height: 844.0, })
  // 200 宽 × 24 高的盒放 60 字符（14px ≈ 288px 宽 → 折 2 行 42 高，超盒）
  let over = {
    ..Node::make("over", Text),
    width: Fixed(200.0),
    height: Fixed(24.0),
    style: { ..NodeStyle::default(), text_color: "#42474F", },
    text: "A short paragraph describing this item in two or three lines.",
  }
  let _ = doc.insert_node(over, "root")
  // 足够高的盒：不报
  let fits = {
    ..Node::make("fits", Text),
    width: Fixed(200.0),
    height: Fixed(60.0),
    style: { ..NodeStyle::default(), text_color: "#42474F", },
    text: "A short paragraph describing this item in two or three lines.",
  }
  let _ = doc.insert_node(fits, "root")
  let issues = norm_readability_issues(doc, solve(doc))
  assert_true(
    issues.length() == 1 && issues[0].contains("over"),
    msg="应只对超盒高的 over 报折行越界: " + jstr9(issues),
  )
}
