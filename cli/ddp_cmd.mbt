// DDP 无 GUI 渲染链路（Smart UX 渲染面）：引擎自主编排
//   DDP 容器 → ddp_codec sidecar 解码 → 装载 → Smart UX 渲染（终端/SVG/导出）
// ddp_codec（Rust 编解码器，独立交付）只承担加解密/压缩——不依赖
// deepDesign / ddpView 等任何上层实现。

///|
#borrow(cmd)
extern "c" fn mv_capture(cmd : Bytes) -> String = "mv_capture"

///|
extern "c" fn mv_last_rc() -> Int = "mv_last_rc"

///|
#borrow(path)
extern "c" fn mv_file_exists_c(path : Bytes) -> Int = "mv_file_exists"

///|
#borrow(path)
extern "c" fn mv_read_file_b64(path : Bytes) -> String = "mv_read_file_b64"

///|
#borrow(path, data)
extern "c" fn mv_write_file_c(path : Bytes, data : Bytes, len : Int) -> Int = "mv_write_file"

///|
#borrow(name)
extern "c" fn mv_getenv_str(name : Bytes) -> String = "mv_getenv_str"

///|
fn c_bytes(s : String) -> Bytes {
  let utf8 = @utf8.encode(s)
  let arr = utf8.to_array()
  arr.push(0)
  Bytes::from_array(arr)
}

///|
/// base64 → UTF-8 字符串（非法输入返回 ""）
fn b64_decode_str(b64 : String) -> String {
  let bytes = @base64.decode(b64) catch {
    _ => return ""
  }
  @utf8.decode(bytes) catch {
    _ => ""
  }
}

///|
/// base64 ← UTF-8 字符串
fn b64_encode_str(data : String) -> String {
  @base64.encode(@utf8.encode(data)).to_string()
}

///|
fn ddp_helper_path() -> String {
  let env = mv_getenv_str("MOONVIZ_DDP_HELPER")
  if env != "" {
    return env
  }
  for p in ["ddp/target/release/ddp_codec", "ddp/target/debug/ddp_codec"].iter() {
    if mv_file_exists_c(c_bytes(p)) == 1 {
      return p
    }
  }
  "ddp_codec"
}

///|
/// 捕获式执行（sh -c 语义，支持 IO 重定向），返回 stdout 全文
fn capture(cmd : String) -> String {
  mv_capture(c_bytes(cmd))
}

///|
fn ddp_helper_available() -> Bool {
  let h = ddp_helper_path()
  h == "ddp_codec" || mv_file_exists_c(c_bytes(h)) == 1
}

///|
/// ddp-decode <file.ddp> [password]：解码容器 → 装载当前会话（替换）。
/// 装载后全部 Smart UX 渲染面（render-term / export-svg / critique…）可用。
pub fn cli_ddp_decode(p : @core.Project, parts : Array[String]) -> String {
  if parts.length() < 2 {
    return cli_err("usage: ddp-decode <file.ddp> [password]")
  }
  let path = parts[1]
  let password = if parts.length() >= 3 { parts[2] } else { "" }
  if mv_file_exists_c(c_bytes(path)) == 0 {
    return cli_err("ddp_file_missing: " + path)
  }
  if !ddp_helper_available() {
    return cli_err("ddp_codec_missing（设 MOONVIZ_DDP_HELPER 或置于 ddp/target/）")
  }
  let b64 = mv_read_file_b64(c_bytes(path))
  let req = "{\"operation\":\"decrypt\",\"password\":\"" +
    @core.json_escape(password) + "\",\"ddp_b64\":\"" + b64 + "\"}"
  let req_path = "/tmp/moonviz-ddp-req.json"
  let req_bytes = c_bytes(req)
  let _ = mv_write_file_c(c_bytes(req_path), req_bytes, req_bytes.length())
  let reply = capture(ddp_helper_path() + " < " + req_path)
  if mv_last_rc() != 0 {
    return cli_err("ddp_codec_failed: " + reply)
  }
  let marker = "\"mbt_b64\":\""
  match reply.find(marker) {
    None => cli_err("ddp_codec_reply_invalid: " + reply)
    Some(i) => {
      let s = i + marker.length()
      let mut j = s
      while j < reply.length() && reply.get_char(j) != Some('"') {
        j = j + 1
      }
      let mbt = b64_decode_str(reply.substring(start=s, end=j).to_string())
      match @decl.load_mbt_project(mbt) {
        Err(e) => cli_err(e)
        Ok(model) => {
          let entry = @core.json_escape(model.entry)
          p.replace_with(model.project)
          "{\"ok\":true,\"op\":\"ddp-decode\",\"entry\":\"\{entry}\"}"
        }
      }
    }
  }
}

///|
/// ddp-save <file.ddp> [password]：当前会话 canonical → DDP 容器落盘。
pub fn cli_ddp_save(p : @core.Project, parts : Array[String]) -> String {
  if parts.length() < 2 {
    return cli_err("usage: ddp-save <file.ddp> [password]")
  }
  let path = parts[1]
  let password = if parts.length() >= 3 { parts[2] } else { "" }
  if !ddp_helper_available() {
    return cli_err("ddp_codec_missing（设 MOONVIZ_DDP_HELPER 或置于 ddp/target/）")
  }
  let model = match @decl.project_to_mbt(p) {
    Ok(m) => m
    Err(e) => return cli_err(e)
  }
  let canonical = model.to_mbt()
  let mbt_b64 = @base64.encode(@utf8.encode(canonical)).to_string().to_string()
  let req = "{\"operation\":\"encrypt\",\"password\":\"" +
    @core.json_escape(password) + "\",\"mbt_b64\":\"" + mbt_b64 + "\"}"
  let req_path = "/tmp/moonviz-ddp-req.json"
  let req_bytes = c_bytes(req)
  let _ = mv_write_file_c(c_bytes(req_path), req_bytes, req_bytes.length())
  let reply = capture(ddp_helper_path() + " < " + req_path)
  if mv_last_rc() != 0 {
    return cli_err("ddp_codec_failed: " + reply)
  }
  let ddp_b64 = b64_field(reply, "ddp_b64")
  if ddp_b64 == "" {
    return cli_err("ddp_codec_reply_invalid: " + reply)
  }
  let bytes = @base64.decode(ddp_b64) catch {
    _ => return cli_err("ddp_b64_invalid")
  }
  let _ = mv_write_file_c(c_bytes(path), bytes, bytes.length())
  "{\"ok\":true,\"op\":\"ddp-save\",\"path\":\"" + @core.json_escape(path) + "\",\"bytes\":" + bytes.length().to_string() + "}"
}

///|
fn b64_field(reply : String, field : String) -> String {
  let marker = "\"" + field + "\":\""
  match reply.find(marker) {
    None => ""
    Some(i) => {
      let s = i + marker.length()
      let mut j = s
      while j < reply.length() && reply.get_char(j) != Some('"') {
        j = j + 1
      }
      reply.substring(start=s, end=j).to_string()
    }
  }
}
