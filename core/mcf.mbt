///|
/// MCF — MoonViz Component Format（v1，docs/11-user-components.md §3）。
///
/// 组件对外分发的唯一形态：专有二进制容器，无密码；`.mbt.md` 源码只在
/// 引擎内部（本地库/注册管线）存在。与 DDP（文档容器）是两个独立格式族。
///
/// 布局：
///   off  len  field
///   0    4    magic "MVCC"
///   4    1    version = 0x01
///   5    1    flags（预留 0）
///   6    4    header_len  LE u32
///   10   8    payload_len LE u64
///   18   4    header_crc32  LE u32（原始 header 字节）
///   22   4    payload_crc32 LE u32（混淆后 payload 字节）
///   26   H    header：TLV 专有序列化（type 0x01 = JSON 元信息）
///   26+H P    payload：mbt.md 组件声明（PCG-xor 自逆变换后）
///   尾   8    格式指纹 LE u64 = FNV-1a64("MVCC:moonviz:1")

///|
const MCF_MAGIC : String = "MVCC"

///|
const MCF_VERSION : Int = 1

///|
const MCF_FINGERPRINT_INPUT : String = "MVCC:moonviz:1"

///|
/// FNV-1a 64
fn fnv1a64(s : String) -> Int64 {
  let mut h : Int64 = 0xcbf29ce484222325L
  for i = 0; i < s.length(); i = i + 1 {
    h = (h ^ s[i].to_int().to_int64()) * 0x100000001b3L
  }
  h
}

///|
fn mcf_crc32(bytes : Array[Byte], start : Int, len : Int) -> Int {
  let mut crc : Int64 = 4294967295L
  let poly : Int64 = 3988292384L // 0xEDB88320
  for i in 0..<len {
    let b0 = match bytes.get(start + i) {
      Some(b) => b.to_int().to_int64()
      None => 0L
    }
    crc = crc ^ (b0 & 255L)
    for _bit in 0..<8 {
      if (crc & 1L) == 1L {
        crc = (crc >> 1) ^ poly
      } else {
        crc = crc >> 1
      }
    }
  }
  (crc ^ 4294967295L).to_int()
}

///|
/// LE u32 写入
fn push_le32(out : Array[Byte], v : Int) -> Unit {
  out.push(((v) & 0xFF).to_byte())
  out.push(((v >> 8) & 0xFF).to_byte())
  out.push(((v >> 16) & 0xFF).to_byte())
  out.push(((v >> 24) & 0xFF).to_byte())
}

///|
fn push_le64(out : Array[Byte], v : Int64) -> Unit {
  let lo = v.to_int()
  let hi = (v >> 32).to_int()
  push_le32(out, lo)
  push_le32(out, hi)
}

///|
fn read_le32(bytes : Array[Byte], at : Int) -> Int {
  let b = (i : Int) => match bytes.get(at + i) {
    Some(x) => x.to_int() & 0xFF
    None => 0
  }
  b(0) | (b(1) << 8) | (b(2) << 16) | (b(3) << 24)
}

///|
fn read_le64(bytes : Array[Byte], at : Int) -> Int64 {
  (read_le32(bytes, at).to_int64() & 0xFFFFFFFFL) |
  ((read_le32(bytes, at + 4).to_int64() & 0xFFFFFFFFL) << 32)
}

///|
/// header TLV 封装：[0x01][len LE u16][json bytes]
fn mcf_wrap_header(json : String) -> Array[Byte] {
  let body = @utf8.encode(json)
  let out : Array[Byte] = []
  out.push((1).to_byte())
  out.push((body.length() & 0xFF).to_byte())
  out.push(((body.length() >> 8) & 0xFF).to_byte())
  for i = 0; i < body.length(); i = i + 1 {
    match body.get(i) {
      Some(b) => out.push(b)
      None => ()
    }
  }
  out
}

///|
fn mcf_unwrap_header(bytes : Array[Byte]) -> Result[String, String] {
  if bytes.length() < 3 {
    return Err("mcf_header_short")
  }
  let t = match bytes.get(0) {
    Some(b) => b.to_int() & 0xFF
    None => 0
  }
  if t != 0x01 {
    return Err("mcf_header_type")
  }
  let len = (match bytes.get(1) {
    Some(b) => b.to_int() & 0xFF
    None => 0
  }) | ((match bytes.get(2) {
    Some(b) => b.to_int() & 0xFF
    None => 0
  }) << 8)
  if bytes.length() < 3 + len {
    return Err("mcf_header_truncated")
  }
  let body : Array[Byte] = []
  for i = 0; i < len; i = i + 1 {
    match bytes.get(3 + i) {
      Some(b) => body.push(b)
      None => ()
    }
  }
  Ok(@utf8.decode(bytes_of(body)) catch { _ => return Err("mcf_header_utf8") })
}

///|
fn bytes_of(arr : Array[Byte]) -> Bytes {
  Bytes::from_iter(arr.iter())
}

///|
/// PCG 式 xor 流（自逆）：state 种子由 header 字节派生——不是密码，
/// 是格式内生的可逆变换（规范的一部分）。
fn mcf_xor_stream(
  payload : Array[Byte],
  header : Array[Byte],
) -> Array[Byte] {
  let mut state : Int64 = fnv1a64(MCF_FINGERPRINT_INPUT)
  for i = 0; i < header.length() && i < 16; i = i + 1 {
    match header.get(i) {
      Some(b) => state = state ^ ((b.to_int() & 0xFF).to_int64() << (i * 3))
      None => ()
    }
  }
  if state == 0L {
    state = 0x853c49e6748fea9bL
  }
  let out : Array[Byte] = []
  for i = 0; i < payload.length(); i = i + 1 {
    state = state * 6364136223846793005L + 1442695040888963407L
    let key = ((state >> 56) & 0xFF).to_int()
    match payload.get(i) {
      Some(b) => out.push(((b.to_int() & 0xFF) ^ key).to_byte())
      None => ()
    }
  }
  out
}

///|
/// 组件元信息 → MCF header JSON（CLI/MCP 共用的唯一构造点，
/// 保证同一 mcf-v1 版本的 header schema 一致）
pub fn mcf_header_json(def : UserComponentDef) -> String {
  let ps : Array[String] = []
  for param in def.params.iter() {
    ps.push(
      "{\"name\":\"\{json_escape(param.name)}\",\"kind\":\"\{param.kind}\",\"default\":\"\{json_escape(param.default_value)}\"}",
    )
  }
  let vs : Array[String] = []
  for v in def.variants.keys() {
    vs.push("\"\{v}\"")
  }
  let joined : Array[String] = []
  for i = 0; i < ps.length(); i = i + 1 {
    joined.push(ps[i])
  }
  "{\"id\":\"\{json_escape(def.id)}\",\"description\":\"\{json_escape(def.description)}\",\"params\":[\{mcf_join_str(joined)}],\"variants\":[\{mcf_join_str(vs)}],\"format\":\"mcf-v1\"}"
}

///|
fn mcf_join_str(items : Array[String]) -> String {
  let sb = StringBuilder::new()
  let mut first = true
  for item in items.iter() {
    if first == false {
      sb.write_string(",")
    }
    first = false
    sb.write_string(item)
  }
  sb.to_string()
}

///|
/// 打包：header_json + mbt 源码 → MCF 字节。
/// header TLV 长度字段是 u16：超限直接拒绝（防静默截断）。
pub fn mcf_pack(
  header_json : String,
  mbt_source : String,
) -> Result[Bytes, String] {
  if header_json.length() > 65535 {
    return Err("mcf_header_too_large:\{header_json.length()}")
  }
  let header = mcf_wrap_header(header_json)
  let raw : Array[Byte] = []
  let src = @utf8.encode(mbt_source)
  for i = 0; i < src.length(); i = i + 1 {
    match src.get(i) {
      Some(b) => raw.push(b)
      None => ()
    }
  }
  let payload = mcf_xor_stream(raw, header)
  let header_crc = mcf_crc32(header, 0, header.length())
  let payload_crc = mcf_crc32(payload, 0, payload.length())
  let out : Array[Byte] = []
  for ch in MCF_MAGIC.iter() {
    out.push(ch.to_int().to_byte())
  }
  out.push(MCF_VERSION.to_byte())
  out.push((0).to_byte())
  push_le32(out, header.length())
  push_le64(out, payload.length().to_int64())
  push_le32(out, header_crc)
  push_le32(out, payload_crc)
  for b in header.iter() {
    out.push(b)
  }
  for b in payload.iter() {
    out.push(b)
  }
  push_le64(out, fnv1a64(MCF_FINGERPRINT_INPUT))
  Ok(bytes_of(out))
}

///|
/// 解包：严格校验 magic/version/长度/双 crc/指纹，任一不符即拒绝。
pub fn mcf_unpack(
  bytes : Bytes,
) -> Result[(String, String), String] { // (header_json, mbt_source)
  let arr : Array[Byte] = []
  for i = 0; i < bytes.length(); i = i + 1 {
    match bytes.get(i) {
      Some(b) => arr.push(b)
      None => ()
    }
  }
  if arr.length() < 34 {
    return Err("mcf_too_short")
  }
  let magic_bytes : Array[Byte] = []
  for i = 0; i < 4; i = i + 1 {
    match arr.get(i) {
      Some(b) => magic_bytes.push(b)
      None => ()
    }
  }
  let magic = @utf8.decode(bytes_of(magic_bytes)) catch {
    _ => return Err("mcf_magic")
  }
  if magic != MCF_MAGIC {
    return Err("mcf_magic_invalid")
  }
  match arr.get(4) {
    Some(b) => if (b.to_int() & 0xFF) != MCF_VERSION {
      return Err("mcf_version_unsupported")
    }
    None => return Err("mcf_version_unsupported")
  }
  let header_len = read_le32(arr, 6)
  let payload_len = read_le64(arr, 10).to_int()
  // Int64→Int 截断可为负：先拒绝，再谈总长
  if payload_len < 0 || payload_len > arr.length() || header_len < 0 {
    return Err("mcf_payload_len_invalid")
  }
  let header_crc = read_le32(arr, 18)
  let payload_crc = read_le32(arr, 22)
  if header_len < 3 || header_len > arr.length() {
    return Err("mcf_header_len")
  }
  if 26 + header_len + payload_len + 8 != arr.length() {
    return Err("mcf_total_len")
  }
  let header : Array[Byte] = []
  for i = 0; i < header_len; i = i + 1 {
    match arr.get(26 + i) {
      Some(b) => header.push(b)
      None => ()
    }
  }
  let mixed : Array[Byte] = []
  for i = 0; i < payload_len; i = i + 1 {
    match arr.get(26 + header_len + i) {
      Some(b) => mixed.push(b)
      None => ()
    }
  }
  let fp_stored = read_le64(arr, 26 + header_len + payload_len)
  if fp_stored != fnv1a64(MCF_FINGERPRINT_INPUT) {
    return Err("mcf_fingerprint_invalid")
  }
  if mcf_crc32(header, 0, header.length()) != header_crc {
    return Err("mcf_header_checksum")
  }
  if mcf_crc32(mixed, 0, mixed.length()) != payload_crc {
    return Err("mcf_payload_checksum")
  }
  let header_json = match mcf_unwrap_header(header) {
    Ok(j) => j
    Err(e) => return Err(e)
  }
  let plain = mcf_xor_stream(mixed, header)
  let source = @utf8.decode(bytes_of(plain)) catch {
    _ => return Err("mcf_payload_utf8")
  }
  Ok((header_json, source))
}
