// 修复批次回归测试：save/open 往返（F9/F10）、网格吸附（F11）、
// 响应式变体层级（F12）、React 导出（F13）、SVG 属性良构（F14）、
// 项目加载事务（F15）、自动暗色状态（F17）。

///|
/// 回归（F9）：parse_string 曾把 \n \t \\ 等转义序列拆坏（反斜杠被直接吞掉，
/// 剩余字符原样保留），save/open 往返对含换行/反斜杠/控制符的文本静默损坏。
test "文档 JSON：含转义字符的 name/text 往返恒等" {
  let doc = Document::new({ width: 390.0, height: 844.0 })
  let t = {
    ..Node::make("tricky", Text),
    name: "名字\"含\\特殊\n字符",
    text: "第一行\n第二行\t缩进\\反斜杠\"引号",
    width: Hug,
    height: Hug,
    x: AlignStart(0.0),
    y: AlignStart(0.0),
  }
  let _ = doc.insert_node(t, "root")
  match Document::from_json(doc.to_json()) {
    Err(e) => assert_true(false, msg=e)
    Ok(reloaded) =>
      match reloaded.get("tricky") {
        Some(n) => {
          assert_eq(n.text, "第一行\n第二行\t缩进\\反斜杠\"引号")
          assert_eq(n.name, "名字\"含\\特殊\n字符")
        }
        None => assert_true(false)
      }
  }
}

///|
/// 回归（F9）：json_escape 对 C0 控制符输出 \u00xx，解析侧必须还原同码点。
test "文档 JSON：控制符 \\u00xx 往返还原" {
  let doc = Document::new({ width: 390.0, height: 844.0 })
  let t = {
    ..Node::make("bell", Text),
    text: "a\u{0007}b",
    width: Hug,
    height: Hug,
    x: AlignStart(0.0),
    y: AlignStart(0.0),
  }
  let _ = doc.insert_node(t, "root")
  match Document::from_json(doc.to_json()) {
    Err(e) => assert_true(false, msg=e)
    Ok(reloaded) =>
      match reloaded.get("bell") {
        Some(n) => assert_eq(n.text, "a\u{0007}b")
        None => assert_true(false)
      }
  }
}

///|
/// 回归（F10）：to_json/from_json 曾丢 component 与 stroke_width/text_align/
/// font_style/stroke_dash/visible——save→open 静默丢失组件语义与视觉状态。
test "文档 JSON：component 与扩展 style 字段往返不丢" {
  let p = Project::new()
  let ab = p.create_artboard(name="roundtrip")
  let _ = p.place_component(artboard=ab, component_id="button", instance_id="btn")
  match p.artboards.get(ab) {
    Some(x) => {
      let _ = x.doc.update_node("btn", fn(n) {
        {
          ..n,
          style: {
            ..n.style,
            stroke: "#FF0000",
            stroke_width: 2.0,
            stroke_dash: "dashed",
            text_align: "center",
            font_style: "italic",
            visible: false,
          },
        }
      })
      match Document::from_json(x.doc.to_json()) {
        Err(e) => assert_true(false, msg=e)
        Ok(reloaded) =>
          match reloaded.get("btn") {
            Some(n) => {
              assert_eq(n.component, "button")
              assert_eq(n.style.stroke_width, 2.0)
              assert_eq(n.style.stroke_dash, "dashed")
              assert_eq(n.style.text_align, "center")
              assert_eq(n.style.font_style, "italic")
              assert_true(!n.style.visible)
            }
            None => assert_true(false)
          }
      }
    }
    None => assert_true(false)
  }
}

///|
/// 回归（F11）：snap_to_grid 曾把画布绝对吸附坐标当父容器相对偏移写回，
/// 嵌套节点吸附后整体偏移一个父容器原点。
test "网格吸附：嵌套容器内节点按父新原点换算偏移" {
  let p = Project::new()
  let ab = p.create_artboard(name="nested_grid")
  match p.artboards.get(ab) {
    Some(x) => {
      let box_ = {
        ..Node::make("box", Frame),
        width: Fixed(200.0),
        height: Fixed(200.0),
        x: Fixed(12.0),
        y: Fixed(12.0),
        style: { ..NodeStyle::default(), fill: "#EEEEEE" },
      }
      let _ = x.doc.insert_node(box_, "root")
      let inner = {
        ..Node::make("inner", Rect),
        width: Fixed(20.0),
        height: Fixed(20.0),
        x: Fixed(5.0),
        y: Fixed(5.0),
        style: { ..NodeStyle::default(), fill: "#333333" },
      }
      let _ = x.doc.insert_node(inner, "box")
      match p.snap_to_grid(artboard=ab, grid=8.0) {
        Ok(_) => ()
        Err(e) => assert_true(false, msg=e)
      }
      let layout = solve(x.doc)
      // box 绝对 (12,12) → (8,8)；inner 绝对 (17,17) → (16,16)：
      // 相对偏移 = 吸附目标 − 父的新绝对原点（8,8）
      match layout.rect_of("box") {
        Some(r) => {
          assert_eq(r.x, 8.0)
          assert_eq(r.y, 8.0)
        }
        None => assert_true(false)
      }
      match layout.rect_of("inner") {
        Some(r) => {
          assert_eq(r.x, 16.0)
          assert_eq(r.y, 16.0)
        }
        None => assert_true(false)
      }
    }
    None => assert_true(false)
  }
}

///|
/// 回归（F12）：generate_responsive 曾把嵌套文档压平——全部节点重挂 root
/// 却保留原 children 表，TreeValid 报重复引用，自产变体过不了引擎自身门禁。
test "响应式：嵌套文档变体保持层级且 validate 为空" {
  let p = Project::new()
  let ab = p.create_artboard(name="nest_base", width=390.0, height=844.0)
  match p.artboards.get(ab) {
    Some(x) => {
      let outer = {
        ..Node::make("outer-card", Frame),
        width: Fixed(300.0),
        height: Fixed(200.0),
        x: Fixed(20.0),
        y: Fixed(20.0),
        style: { ..NodeStyle::default(), fill: "#EEEEEE" },
      }
      let _ = x.doc.insert_node(outer, "root")
      let inner = {
        ..Node::make("inner-label", Text),
        text: "嵌套",
        width: Fixed(60.0),
        height: Fixed(24.0),
        x: Fixed(8.0),
        y: Fixed(8.0),
      }
      let _ = x.doc.insert_node(inner, "outer-card")
    }
    None => assert_true(false)
  }
  match p.generate_responsive(artboard=ab) {
    Ok(_) => ()
    Err(e) => assert_true(false, msg=e)
  }
  for suffix in ["_tablet", "_desktop"] {
    match p.artboards.get(ab + suffix) {
      Some(vab) => {
        assert_eq(validate(vab.doc).length(), 0)
        // 层级保持：inner-label 仍挂在 outer-card 下
        match vab.doc.find_parent("inner-label") {
          Some(pid) => assert_eq(pid, "outer-card")
          None => assert_true(false)
        }
      }
      None => assert_true(false)
    }
  }
}

///|
/// 回归（F13）：export_react 的 Text 分支曾漏掉 span 开标签的 `>`，
/// 输出非法 JSX；文本字面量未转义会破坏标签结构。
test "export_react：Text 节点输出合法 span（含文本转义）" {
  let p = Project::new()
  let _ = p.create_artboard(name="tsx_text")
  match p.artboards.get("tsx_text") {
    Some(x) => {
      let t = {
        ..Node::make("label", Text),
        text: "a<b & {c}",
        width: Hug,
        height: Hug,
        x: AlignStart(10.0),
        y: AlignStart(10.0),
      }
      let _ = x.doc.insert_node(t, "root")
    }
    None => assert_true(false)
  }
  let tsx = p.export_react()
  // 开标签闭合 `>` 在位，文本按实体转义
  assert_true(tsx.contains("}}>a&lt;b &amp; &#123;c&#125;</span>"), msg=tsx)
}

///|
/// 子串出现次数（F14 断言辅助：单属性输出必须恰好一次）
fn occurrence_count(hay : String, needle : String) -> Int {
  let mut count = 0
  let mut i = 0
  let n = hay.length()
  let m = needle.length()
  while i + m <= n {
    if hay.substring(start=i, end=i + m) == needle {
      count = count + 1
      i = i + m
    } else {
      i = i + 1
    }
  }
  count
}

///|
/// 回归（F14）：render_svg 曾在 rotate+flip 同设时输出两个 transform 属性、
/// shadow+blur 同设时输出两个 filter 属性——XML 非良构，flip/blur 静默丢失。
test "渲染：rotate+flip / shadow+blur 合并为单一属性（XML 良构）" {
  let doc = Document::new({ width: 200.0, height: 200.0 })
  let n = {
    ..Node::make("fx", Rect),
    width: Fixed(40.0),
    height: Fixed(40.0),
    x: Fixed(10.0),
    y: Fixed(10.0),
    style: {
      ..NodeStyle::default(),
      fill: "#4B6BFB",
      rotate: 15.0,
      flip: "h",
      shadow: "e2",
      blur: 3.0,
    },
  }
  let _ = doc.insert_node(n, "root")
  let svg = render_svg(doc)
  // 单 transform：flip 左乘 rotate（变换列表从右向左作用）
  assert_eq(occurrence_count(svg, "transform=\""), 1)
  assert_true(svg.contains("scale(-1,1)"), msg=svg)
  assert_true(svg.contains("rotate(15"), msg=svg)
  match (svg.find("scale(-1,1)"), svg.find("rotate(15")) {
    (Some(fi), Some(ri)) => assert_true(fi < ri, msg=svg)
    _ => assert_true(false)
  }
  // 单 filter：引用合并滤镜 def（先模糊、再对模糊结果投阴影）
  assert_eq(occurrence_count(svg, "filter=\"url(#"), 1)
  assert_true(svg.contains("<filter id=\"fx_"), msg=svg)
  assert_true(svg.contains("feDropShadow"), msg=svg)
}

///|
/// 回归（F15）：from_project_json 曾先清空现有画板再解析——单画板 LoadErr
/// 被静默吞掉、≥1 画板成功即 Ok。现在全部成功才原子替换，失败零副作用。
test "项目 JSON：部分画板失败时回滚现状并汇总错误" {
  let p = Project::new()
  let ab = p.create_artboard(name="keep_me")
  assert_eq(ab, "keep_me")
  let good_doc = Document::new({ width: 390.0, height: 844.0 })
  let good = "{\"id\":\"good\",\"name\":\"good\",\"width\":390,\"height\":844,\"doc\":\{good_doc.to_json()}}"
  // broken 画板缺 "doc" 对象 → LoadErr(missing_doc)
  let payload = "{\"moonviz\":\"studio\",\"version\":2,\"artboards\":[\{good},{\"id\":\"broken\",\"name\":\"broken\",\"width\":100,\"height\":100}]}"
  match p.from_project_json(payload) {
    Ok(_) => assert_true(false, msg="partial load must fail")
    Err(e) => assert_true(e.contains("artboard_load_failed"), msg=e)
  }
  // 现状保持：原画板未被清掉，坏载荷的画板也未混入
  assert_true(p.artboards.contains("keep_me"))
  assert_true(!p.artboards.contains("good"))
  assert_true(!p.artboards.contains("broken"))
}

///|
test "项目 JSON：全部成功后原子替换现有画板" {
  let p = Project::new()
  let _ = p.create_artboard(name="old_board")
  let d1 = Document::new({ width: 320.0, height: 600.0 })
  let d2 = Document::new({ width: 800.0, height: 600.0 })
  let payload = "{\"artboards\":[{\"id\":\"a1\",\"name\":\"a1\",\"width\":320,\"height\":600,\"doc\":\{d1.to_json()}},{\"id\":\"a2\",\"name\":\"a2\",\"width\":800,\"height\":600,\"doc\":\{d2.to_json()}}]}"
  match p.from_project_json(payload) {
    Ok(_) => ()
    Err(e) => assert_true(false, msg=e)
  }
  assert_true(p.artboards.contains("a1"))
  assert_true(p.artboards.contains("a2"))
  assert_true(!p.artboards.contains("old_board"))
}

///|
/// 回归（F17）：enable_auto_dark 曾恒从 light 推导、不重着色节点、
/// 不更新 active_theme/token_overrides。现在从 active_theme 推导并
/// 对齐状态三元组（tokens / active_theme / token_overrides）。
test "主题：enable_auto_dark 从 active_theme 推导并对齐状态三元组" {
  let p = Project::new()
  let ab = p.create_artboard(name="ad")
  let _ = p.place_component(artboard=ab, component_id="button", instance_id="b1")
  let _ = p.apply_theme("nord")
  match p.enable_auto_dark() {
    Ok(json) => {
      assert_true(json.contains("\"ok\":true"))
      // 从 nord 推导（而非恒从 light）
      assert_true(json.contains("\"original\":\"nord\""), msg=json)
    }
    Err(e) => assert_true(false, msg=e)
  }
  // active_theme 同步为派生名
  assert_true(p.active_theme.contains("nord"), msg=p.active_theme)
  assert_true(p.active_theme.contains("auto_dark"), msg=p.active_theme)
  // token_overrides 记录派生值（随 frontmatter tokens: 段往返）
  match p.token_overrides {
    Some(ov) =>
      match ov.get("surface") {
        Some(v) => {
          // nord surface #3B4252 反转 = #c4bdad；若从 light 推导会是 #000000
          assert_eq(v, "#c4bdad")
          assert_eq(v, p.tokens.resolve_color("surface"))
        }
        None => assert_true(false)
      }
    None => assert_true(false)
  }
  // 节点字面量已重着色到派生值（nord primary #88C0D0 → 反转 #773f2f）
  match p.artboards.get(ab) {
    Some(x) =>
      match x.doc.get("b1") {
        Some(nd) => assert_eq(nd.style.fill, "#773f2f")
        None => assert_true(false)
      }
    None => assert_true(false)
  }
}
