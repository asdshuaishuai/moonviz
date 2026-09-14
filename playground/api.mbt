///|
/// playground 引擎会话协议（纯 MoonBit，文本进出，无任何宿主依赖）。
///
/// 文本协议：首行为操作名，其后为载荷：
///
/// - `render\n<声明文本>`          → 解析 + Agent 硬门槛 + SVG
/// - `human_move\n<id>\n<x>\n<y>\n<声明文本>` → 人类策略（结构硬 / 视觉软）
///
/// 会话无内部状态：声明文本本身就是状态。任何宿主（CLI、编辑器、未来的
/// 画布进程）都可以用同一协议驱动引擎，引擎对其一无所知。
pub fn version() -> String {
  "moonviz-playground 0.1.0"
}

///|
/// Agent / 渲染入口：违规整体拒绝
pub fn handle(request : String) -> String {
  handle_with_gate(request, @core.AgentGate)
}

///|
/// 人类入口：结构硬、视觉软；成功携带视觉债
pub fn handle_human(request : String) -> String {
  handle_with_gate(request, @core.HumanGate)
}

///|
fn handle_with_gate(request : String, default_gate : @core.Gate) -> String {
  let lines = split_first_line(request)
  match lines.op {
    "render" =>
      match @decl.parse_decl(lines.rest) {
        Err(e) => parse_error_response(e)
        Ok(page) => {
          let violations = page.check()
          match @core.decide(default_gate, violations) {
            @core.Reject(blocking) => block_response("hard_block", blocking)
            @core.Allow(_) =>
              ok_response(page.render(), page.to_decl_text(), 0, [])
          }
        }
      }
    "human_move" =>
      match move_payload(lines.rest) {
        Err(e) => error_payload("protocol_error", e)
        Ok(mv) =>
          match @decl.parse_decl(mv.rest) {
            Err(e) => parse_error_response(e)
            Ok(page) => {
              let moved = page.move_node(id=mv.id, x=mv.x, y=mv.y)
              match moved {
                Err(msg) => error_payload("unknown_node", msg)
                Ok(_) => {
                  let violations = page.check()
                  match @core.decide(@core.HumanGate, violations) {
                    @core.Reject(blocking) =>
                      block_response("structural_block", blocking)
                    @core.Allow(debt) =>
                      ok_response(
                        page.render(),
                        page.to_decl_text(),
                        debt.length(),
                        debt,
                      )
                  }
                }
              }
            }
          }
      }
    other => error_payload("unknown_op", other)
  }
}

///|
struct FirstLine {
  op : String
  rest : String
}

///|
fn split_first_line(request : String) -> FirstLine {
  let mut idx : Int? = None
  let mut pos = 0
  for c in request.iter() {
    match idx {
      Some(_) => ()
      None => if c == '\n' { idx = Some(pos) } else { pos = pos + 1 }
    }
  }
  match idx {
    Some(i) =>
      {
        op: trim_line(request.substring(start=0, end=i)),
        rest: request.substring(start=i + 1),
      }
    None => { op: trim_line(request), rest: "" }
  }
}

///|
struct MovePayload {
  id : String
  x : Double
  y : Double
  rest : String
}

///|
/// human_move 载荷：第 1..3 行 = id / x / y，其余行 = 当前声明文本
fn move_payload(rest : String) -> Result[MovePayload, String] {
  let lines : Array[String] = Array::new()
  let mut buf = StringBuilder::new()
  for c in rest.iter() {
    if c == '\n' {
      lines.push(buf.to_string())
      buf = StringBuilder::new()
    } else {
      buf.write_char(c)
    }
  }
  lines.push(buf.to_string())
  if lines.length() < 4 {
    return Err("human_move 需要 4 段：id / x / y / 声明文本")
  }
  let x : Double = match parse_num(lines[1]) {
    Some(v) => v
    None => return Err("无法解析 x 数值")
  }
  let y : Double = match parse_num(lines[2]) {
    Some(v) => v
    None => return Err("无法解析 y 数值")
  }
  Ok({ id: trim_line(lines[0]), x, y, rest: join_from(lines, 3) })
}

///|
fn join_from(lines : Array[String], from : Int) -> String {
  let sb = StringBuilder::new()
  for i in from..<lines.length() {
    if i > from {
      sb.write_char('\n')
    }
    sb.write_string(lines[i])
  }
  sb.to_string()
}

///|
fn trim_line(s : String) -> String {
  match s.find_by(fn(c) { c != ' ' }) {
    None => ""
    Some(a) => {
      let mut b = s.length() - 1
      let mut end = a
      let mut running = true
      while b >= a && running {
        match s.get_char(b) {
          Some(c) =>
            if c != ' ' {
              end = b
              running = false
            } else {
              b = b - 1
            }
          None => running = false
        }
      }
      s.substring(start=a, end=end + 1)
    }
  }
}

///|
/// 正/负整数与小数（坐标域）
fn parse_num(s : String) -> Double? {
  let t : String = trim_line(s)
  if t.length() == 0 {
    return None
  }
  let is_neg : Bool = t.get_char(0) == Some('-')
  let body : String = if is_neg { t.substring(start=1) } else { t }
  let dot : Int? = body.find(".")
  let intp : String = match dot {
    Some(i) => body.substring(start=0, end=i)
    None => body
  }
  let fracp : String = match dot {
    Some(i) => body.substring(start=i + 1)
    None => "0"
  }
  if intp.length() == 0 && body.find(".") != Some(0) {
    return None
  }
  let mut acc = 0
  for c in intp.iter() {
    let code = c.to_int()
    if code < 48 || code > 57 {
      return None
    }
    acc = acc * 10 + (code - 48)
  }
  let mut frac = 0.0
  let mut scale = 0.1
  for c in fracp.iter() {
    let code = c.to_int()
    if code < 48 || code > 57 {
      return None
    }
    frac = frac + (code - 48).to_double() * scale
    scale = scale / 10.0
  }
  let v = acc.to_double() + frac
  Some(if is_neg { -v } else { v })
}

// ---------------------------------------------------------------------------
// 响应序列化（JSON 文本）
// ---------------------------------------------------------------------------

///|
fn join_comma(parts : Array[String]) -> String {
  let sb = StringBuilder::new()
  for i in 0..<parts.length() {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string(parts[i])
  }
  sb.to_string()
}

///|
fn ok_response(
  svg : String,
  decl : String,
  debt : Int,
  violations : Array[@core.Violation],
) -> String {
  let parts : Array[String] = Array::new()
  for v in violations.iter() {
    parts.push(v.to_json())
  }
  "{\n  \"ok\": true,\n  \"debt\": \{debt},\n  \"violations\": [\{join_comma(parts)}],\n  \"decl\": \"\{@core.json_escape(decl)}\",\n  \"svg\": \"\{@core.json_escape(svg)}\"\n}"
}

///|
fn parse_error_response(e : @decl.DeclParseError) -> String {
  "{\"error\": \"parse_error\", \"line\": \{e.line}, \"message\": \"\{@core.json_escape(e.message)}\"}"
}

///|
fn error_payload(kind : String, detail : String) -> String {
  "{\"error\": \"\{kind}\", \"detail\": \"\{@core.json_escape(detail)}\"}"
}

///|
fn block_response(kind : String, blocking : Array[@core.Violation]) -> String {
  let parts : Array[String] = Array::new()
  for v in blocking.iter() {
    parts.push(v.to_json())
  }
  "{\"error\": \"\{kind}\", \"violations\": [\{join_comma(parts)}]}"
}
