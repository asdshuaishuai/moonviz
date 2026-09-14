///|
/// MoonBit 画布交互命令层（全目标共享；输入循环由各 target 的 main 提供）。
///
/// 命令：help / render / list / decl / svg / pick / drag / pan / zoom /
/// agent <id> width|height <num> / agent text <id> <文本> / exit
struct ReplState {
  camera : Camera
  mut decl : String
  mut highlight : String?
}

///|
fn repl_state_new(initial : String) -> ReplState {
  { camera: Camera::new(), decl: initial, highlight: None }
}

///|
const CANVAS_COLS : Int = 64

///|
const CANVAS_ROWS : Int = 26

///|
fn repaint(st : ReplState) -> String {
  match @decl.parse_decl(st.decl) {
    Err(e) => "!! 声明解析错误：" + e.describe() + "\n"
    Ok(page) => {
      let buf = screen_new(CANVAS_COLS, CANVAS_ROWS)
      draw_document(buf, st.camera, page.build(), st.highlight)
      "MoonViz 画布 pan=(\{st.camera.pan_x}, \{st.camera.pan_y}) zoom=\{st.camera.zoom}\n\n" +
      frame_of(buf) +
      "\n帮助见 help\n"
    }
  }
}

///|
fn tokenize(line : String) -> Array[String] {
  let out : Array[String] = Array::new()
  let mut buf = StringBuilder::new()
  for c in line.iter() {
    if c == ' ' || c == '\t' {
      if buf.to_string().length() > 0 {
        out.push(buf.to_string())
        buf = StringBuilder::new()
      }
    } else {
      buf.write_char(c)
    }
  }
  let rest = buf.to_string()
  if rest.length() > 0 {
    out.push(rest)
  }
  out
}

///|
let help_text : String = "命令：\n  render 重绘画布\n  list / decl / svg  节点表 / 当前声明 / SVG\n" +
  "  pick <col> <row>  屏幕命中\n  drag <col> <row>  拖拽命中节点（人类策略）\n" +
  "  pan <dx> <dy>  平移视口（世界像素）\n  zoom in | zoom out | zoom reset\n" +
  "  agent <id> width|height <num> / agent text <id> <文本>（Agent 硬门槛）\n  exit\n"

///|
pub fn apply_command(st : ReplState, line : String) -> String {
  let toks = tokenize(line)
  if toks.length() == 0 {
    return ""
  }
  match toks[0] {
    "help" => help_text
    "render" | "r" => repaint(st)
    "list" =>
      match @decl.parse_decl(st.decl) {
        Err(e) => "!! " + e.describe()
        Ok(page) => {
          let doc = page.build()
          let layout = @core.solve(doc)
          let sb = StringBuilder::new()
          for id in doc.nodes.keys() {
            match layout.rect_of(id) {
              Some(r) =>
                sb.write_string(
                  "\{id} (\{r.x.to_int()}, \{r.y.to_int()}, \{r.width.to_int()}x\{r.height.to_int()})\n",
                )
              None => ()
            }
          }
          sb.to_string()
        }
      }
    "decl" => st.decl
    "pick" | "p" => cmd_pick(st, toks)
    "drag" | "d" => cmd_drag(st, toks)
    "pan" =>
      if toks.length() < 3 {
        "!! 用法：pan <dx> <dy>（世界像素）"
      } else {
        camera_pan(
          st.camera,
          parse_num_or(toks[1], 0.0),
          parse_num_or(toks[2], 0.0),
        )
        repaint(st)
      }
    "zoom" => cmd_zoom(st, toks)
    "agent" => apply_agent_edit(st, toks)
    "png" =>
      match @decl.parse_decl(st.decl) {
        Err(e) => "!! " + e.describe()
        Ok(page) => {
          let bytes = render_png_hires(page.build(), 195, 422)
          "PNG(base64, 解码后可打开):\n" + base64_encode(bytes)
        }
      }
    "svg" =>
      match @decl.parse_decl(st.decl) {
        Err(e) => "!! " + e.describe()
        Ok(page) => page.render()
      }
    "exit" | "quit" | "q" => ":exit"
    other => "!! 未知命令 \{other}（help 查看命令）"
  }
}

///|
fn parse_num_or(t : String, fallback : Double) -> Double {
  match parse_num(t) {
    Some(v) => v
    None => fallback
  }
}

///|
fn cmd_pick(st : ReplState, toks : Array[String]) -> String {
  if toks.length() < 3 {
    return "!! 用法：pick <col> <row>"
  }
  match @decl.parse_decl(st.decl) {
    Err(e) => "!! " + e.describe()
    Ok(page) => {
      let doc = page.build()
      match
        pick_at(
          doc,
          st.camera,
          parse_num_or(toks[1], -1.0),
          parse_num_or(toks[2], -1.0),
        ) {
        Some(id) => "命中：" + id
        None => "空白区域"
      }
    }
  }
}

///|
fn cmd_drag(st : ReplState, toks : Array[String]) -> String {
  if toks.length() < 3 {
    return "!! 用法：drag <col> <row>"
  }
  match @decl.parse_decl(st.decl) {
    Err(e) => "!! " + e.describe()
    Ok(page) => {
      let doc = page.build()
      let col = parse_num_or(toks[1], -1.0)
      let row = parse_num_or(toks[2], -1.0)
      match pick_at(doc, st.camera, col, row) {
        None => "!! 点中空白，无法拖拽"
        Some(id) => {
          st.highlight = Some(id)
          let xy = to_world_pt(st.camera, col, row)
          match page.move_node(id~, x=xy.0, y=xy.1) {
            Err(msg) => "!! " + msg
            Ok(_) => {
              st.decl = page.to_decl_text()
              repaint(st)
            }
          }
        }
      }
    }
  }
}

///|
/// 屏幕 → 世界（拖拽用）
fn to_world_pt(c : Camera, col : Double, row : Double) -> (Double, Double) {
  (col / c.zoom + c.pan_x, row * 2.0 / c.zoom + c.pan_y)
}

///|
fn cmd_zoom(st : ReplState, toks : Array[String]) -> String {
  if toks.length() < 2 {
    return "!! zoom in | zoom out | zoom reset"
  }
  if toks[1] == "in" {
    camera_zoom_in(st.camera)
  } else if toks[1] == "out" {
    camera_zoom_out(st.camera)
  } else {
    st.camera.pan_x = 0.0
    st.camera.pan_y = 0.0
    st.camera.zoom = 1.0
  }
  repaint(st)
}

///|
/// agent <id> width|height <num>  /  agent text <id> <文本>
fn apply_agent_edit(st : ReplState, toks : Array[String]) -> String {
  match @decl.parse_decl(st.decl) {
    Err(e) => "!! " + e.describe()
    Ok(page) => {
      let doc = page.build()
      let id = agent_target(toks)
      match id {
        None =>
          "!! 用法：agent <id> width|height <num> / agent text <id> <文本>"
        Some(id) => {
          let patch : @core.NodePatch? = agent_patch(toks)
          match patch {
            None =>
              "!! 用法：agent <id> width|height <num> / agent text <id> <文本>"
            Some(p) => {
              let result = @core.apply_agent_patch(doc, {
                base_revision: doc.revision,
                message: "agent 命令行编辑",
                ops: [@core.UpdateNode(id, p)],
              })
              match result {
                Err(err) =>
                  "Agent 提交被拒（硬门槛，未落盘）：\n" +
                  err_summary(err)
                Ok(_) => {
                  st.decl = @decl.from_document(doc).to_decl_text()
                  st.highlight = Some(id)
                  repaint(st)
                }
              }
            }
          }
        }
      }
    }
  }
}

///|
fn agent_target(toks : Array[String]) -> String? {
  if toks[1] == "text" {
    if toks.length() >= 4 {
      Some(toks[2])
    } else {
      None
    }
  } else if toks.length() >= 2 {
    Some(toks[1])
  } else {
    None
  }
}

///|
fn join_from_idx(toks : Array[String], from : Int) -> String {
  let sb = StringBuilder::new()
  for i in from..<toks.length() {
    if i > from {
      sb.write_char(' ')
    }
    sb.write_string(toks[i])
  }
  sb.to_string()
}

///|
///agent 子命令的补丁：text / width / height
fn agent_patch(toks : Array[String]) -> @core.NodePatch? {
  if toks[1] == "text" {
    Some({ ..@core.NodePatch::empty(), text: Some(join_from_idx(toks, 3)) })
  } else if toks[2] == "width" {
    Some({
      ..@core.NodePatch::empty(),
      width: Some(fixed_spec(parse_num(toks[3]))),
    })
  } else if toks[2] == "height" {
    Some({
      ..@core.NodePatch::empty(),
      height: Some(fixed_spec(parse_num(toks[3]))),
    })
  } else {
    None
  }
}

///|
fn fixed_spec(v : Double?) -> @core.SizeSpec {
  match v {
    Some(d) => @core.Fixed(d)
    None => @core.Fixed(0.0)
  }
}

///|
/// 补丁错误摘要（一行）
fn err_summary(err : @core.PatchError) -> String {
  match err {
    @core.StaleBase(cur) =>
      "patch 过时（文档当前 \{cur}），请重新读取后再提交"
    @core.HardBlock(vs) =>
      "hard_block：阻断违规 \{vs.length()} 条：" + viol_brief(vs)
    @core.StructuralBlock(vs) => "structural_block：违规 \{vs.length()} 条"
    @core.UnknownNode(id) => "unknown_node " + id
    @core.UnknownParent(id) => "unknown_parent " + id
    @core.DuplicateId(id) => "duplicate_id " + id
    @core.HierarchyError(msg) => msg
  }
}

///|
fn viol_brief(vs : Array[@core.Violation]) -> String {
  vs[0].to_json()
}
