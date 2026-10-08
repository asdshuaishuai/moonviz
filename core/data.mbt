// ---------------------------------------------------------------------------
// Smart UX M-S1：数据树与绑定（SMART-UX-1.0.md 支柱 B 的地基）
// ---------------------------------------------------------------------------

///|
/// 轻量 JSON 数据树（Smart UI 注入数据的载体）。
/// 刻意不用第三方依赖、不做图灵完备表达式——绑定只允许点路径插值。
pub(all) enum DataValue {
  DNull
  DBool(Bool)
  DNum(Double)
  DStr(String)
  DArr(Array[DataValue])
  DObj(Map[String, DataValue])
}

///|
/// 递归下降 JSON 解析（非崩纪律：任何非法输入返回 Err，绝不 abort）。
/// 数字统一 Double；字符串支持标准转义；尾随内容视为错误。
pub fn parse_data_json(text : String) -> Result[DataValue, String] {
  let p = DataParser::new(text)
  let v = p.parse_value()
  if p.failed is Some(e) {
    Err(e)
  } else if p.skip_ws() {
    Err("data_json_trailing_content")
  } else {
    Ok(v)
  }
}

///|
struct DataParser {
  text : String
  mut pos : Int
  mut failed : String?
}

///|
fn DataParser::new(text : String) -> DataParser {
  { text, pos: 0, failed: None }
}

///|
/// 跳过空白；返回是否还有剩余字符
fn DataParser::skip_ws(self : DataParser) -> Bool {
  let n = self.text.length()
  while self.pos < n {
    match self.text.get_char(self.pos) {
      Some(' ') | Some('\t') | Some('\r') | Some('\n') => self.pos = self.pos + 1
      _ => break
    }
  }
  self.pos < n
}

///|
fn DataParser::fail(self : DataParser, e : String) -> Unit {
  if self.failed is None {
    self.failed = Some(e)
  }
}

///|
fn DataParser::parse_value(self : DataParser) -> DataValue {
  if !self.skip_ws() {
    self.fail("data_json_unexpected_end")
    return DNull
  }
  match self.text.get_char(self.pos) {
    Some('{') => self.parse_obj()
    Some('[') => self.parse_arr()
    Some('"') => match self.parse_string() {
      Some(s) => DStr(s)
      None => DNull
    }
    Some('t') => self.parse_lit("true", DBool(true))
    Some('f') => self.parse_lit("false", DBool(false))
    Some('n') => self.parse_lit("null", DNull)
    Some(c) =>
      if c == '-' || (c >= '0' && c <= '9') {
        self.parse_num()
      } else {
        self.fail("data_json_unexpected_char")
        DNull
      }
    None => {
      self.fail("data_json_unexpected_end")
      DNull
    }
  }
}

///|
fn DataParser::parse_lit(
  self : DataParser,
  lit : String,
  v : DataValue,
) -> DataValue {
  let n = lit.length()
  if self.pos + n <= self.text.length() &&
    self.text.substring(start=self.pos, end=self.pos + n) == lit {
    self.pos = self.pos + n
    v
  } else {
    self.fail("data_json_bad_literal")
    DNull
  }
}

///|
fn DataParser::parse_num(self : DataParser) -> DataValue {
  let n = self.text.length()
  let start = self.pos
  if self.pos < n && self.text.get_char(self.pos) == Some('-') {
    self.pos = self.pos + 1
  }
  let mut digits = 0
  while self.pos < n {
    match self.text.get_char(self.pos) {
      Some(c) if c >= '0' && c <= '9' => {
        digits = digits + 1
        self.pos = self.pos + 1
      }
      _ => break
    }
  }
  if self.pos < n && self.text.get_char(self.pos) == Some('.') {
    self.pos = self.pos + 1
    while self.pos < n {
      match self.text.get_char(self.pos) {
        Some(c) if c >= '0' && c <= '9' => {
          digits = digits + 1
          self.pos = self.pos + 1
        }
        _ => break
      }
    }
  }
  if digits == 0 {
    self.fail("data_json_bad_number")
    return DNull
  }
  let raw = self.text.substring(start=start, end=self.pos).to_string()
  DNum(parse_double(raw))
}

///|
fn DataParser::parse_string(self : DataParser) -> String? {
  // 前提：当前位置是 '"'
  self.pos = self.pos + 1
  let sb = StringBuilder::new()
  let n = self.text.length()
  while self.pos < n {
    match self.text.get_char(self.pos) {
      Some('"') => {
        self.pos = self.pos + 1
        return Some(sb.to_string())
      }
      Some('\\') => {
        self.pos = self.pos + 1
        if self.pos >= n {
          break
        }
        match self.text.get_char(self.pos) {
          Some('"') => sb.write_char('"')
          Some('\\') => sb.write_char('\\')
          Some('/') => sb.write_char('/')
          Some('n') => sb.write_char('\n')
          Some('t') => sb.write_char('\t')
          Some('r') => sb.write_char('\r')
          Some('u') => {
            // \uXXXX（含代理对简化：两段分别解码，未组合成增补平面字符——
            // Smart UI 数据面暂不涉及 emoji 字面转义，不崩优先）
            let cp = self.read_hex4()
            match cp {
              Some(c) => sb.write_char(c)
              None => {
                self.fail("data_json_bad_escape")
                return None
              }
            }
          }
          _ => {
            self.fail("data_json_bad_escape")
            return None
          }
        }
        self.pos = self.pos + 1
      }
      Some(c) => {
        sb.write_char(c)
        self.pos = self.pos + 1
      }
      None => break
    }
  }
  self.fail("data_json_unterminated_string")
  None
}

///|
fn DataParser::read_hex4(self : DataParser) -> Char? {
  if self.pos + 4 >= self.text.length() + 1 && self.pos + 4 > self.text.length() - 1 {
    // 位置检查：需要 pos+1..pos+4 四个 hex 字符
  }
  if self.pos + 4 >= self.text.length() + 1 {
    return None
  }
  let mut v = 0
  for i in 1..=4 {
    match self.text.get_char(self.pos + i) {
      Some(c) => {
        let d = match c {
          '0'..='9' => c.to_int() - 48
          'a'..='f' => c.to_int() - 87
          'A'..='F' => c.to_int() - 55
          _ => return None
        }
        v = v * 16 + d
      }
      None => return None
    }
  }
  self.pos = self.pos + 4
  Int::to_char(v)
}

///|
fn DataParser::parse_obj(self : DataParser) -> DataValue {
  self.pos = self.pos + 1 // {
  let m : Map[String, DataValue] = Map::new()
  if self.skip_ws() && self.text.get_char(self.pos) == Some('}') {
    self.pos = self.pos + 1
    return DObj(m)
  }
  let mut done = false
  while !done {
    if !self.skip_ws() {
      self.fail("data_json_unterminated_object")
      return DObj(m)
    }
    if self.text.get_char(self.pos) != Some('"') {
      self.fail("data_json_object_key_expected")
      return DObj(m)
    }
    let key = match self.parse_string() {
      Some(k) => k
      None => return DObj(m)
    }
    if !self.skip_ws() || self.text.get_char(self.pos) != Some(':') {
      self.fail("data_json_colon_expected")
      return DObj(m)
    }
    self.pos = self.pos + 1
    let v = self.parse_value()
    if self.failed is Some(_) {
      return DObj(m)
    }
    m.set(key, v)
    if !self.skip_ws() {
      self.fail("data_json_unterminated_object")
      return DObj(m)
    }
    // 逗号：落入下一轮键值对；右括号：正常结束
    if self.text.get_char(self.pos) == Some(',') {
      self.pos = self.pos + 1
      continue
    }
    if self.text.get_char(self.pos) == Some('}') {
      self.pos = self.pos + 1
      done = true
    } else {
      self.fail("data_json_comma_or_brace_expected")
      return DObj(m)
    }
  }
  DObj(m)
}

fn DataParser::parse_arr(self : DataParser) -> DataValue {
  self.pos = self.pos + 1 // [
  let arr : Array[DataValue] = []
  if self.skip_ws() && self.text.get_char(self.pos) == Some(']') {
    self.pos = self.pos + 1
    return DArr(arr)
  }
  let mut done = false
  while !done {
    let v = self.parse_value()
    if self.failed is Some(_) {
      return DArr(arr)
    }
    arr.push(v)
    if !self.skip_ws() {
      self.fail("data_json_unterminated_array")
      return DArr(arr)
    }
    if self.text.get_char(self.pos) == Some(',') {
      self.pos = self.pos + 1
      continue
    }
    if self.text.get_char(self.pos) == Some(']') {
      self.pos = self.pos + 1
      done = true
    } else {
      self.fail("data_json_comma_or_bracket_expected")
      return DArr(arr)
    }
  }
  DArr(arr)
}
///|
/// 点路径查找："user.name"、"items.0.title"。任何一段缺失返回 None，绝不崩。
pub fn data_lookup(root : DataValue, path : String) -> DataValue? {
  let parts = path.split(".")
  let mut cur : DataValue? = Some(root)
  for seg in parts.iter() {
    match cur {
      Some(DObj(m)) => cur = m.get(seg.to_string())
      Some(DArr(a)) => {
        // 数组段：非负十进制
        let mut idx = 0
        let mut ok = seg.length() > 0
        let mut i = 0
        let segv = seg.to_string()
        while i < segv.length() {
          let c = segv.get_char(i)
          match c {
            Some(ch) if ch >= '0' && ch <= '9' => {
              idx = idx * 10 + (ch.to_int() - 48)
              i = i + 1
            }
            _ => {
              ok = false
              i = segv.length()
            }
          }
        }
        cur = if ok && idx < a.length() { Some(a[idx]) } else { None }
      }
      _ => cur = None
    }
    if cur is None {
      return None
    }
  }
  cur
}

///|
/// 数据值 → 渲染显示字符串。数组逗号连接、对象 k:v 空格连接——
/// 智能占位显示；真正的结构化展示（列表展开）由组件版式承担，不经字符串化。
pub fn data_to_display(v : DataValue) -> String {
  let sb = StringBuilder::new()
  fn walk(v : DataValue, sb : StringBuilder) -> Unit {
    match v {
      DNull => sb.write_string("—")
      DBool(true) => sb.write_string("true")
      DBool(false) => sb.write_string("false")
      DNum(n) => {
        // 整数不带小数点，小数原样（MoonBit Double::to_string 去尾零语义足够）
        if n == n.floor() && n.abs() < 1000000000000000.0 {
          sb.write_string(n.to_int().to_string())
        } else {
          sb.write_string(n.to_string())
        }
      }
      DStr(s) => sb.write_string(s)
      DArr(a) => {
        for i, item in a {
          if i > 0 {
            sb.write_string(", ")
          }
          walk(item, sb)
        }
      }
      DObj(m) => {
        let mut first = true
        for k in m.keys() {
          if !first {
            sb.write_string(" ")
          }
          first = false
          sb.write_string(k)
          sb.write_string(":")
          match m.get(k) {
            Some(v) => walk(v, sb)
            None => ()
          }
        }
      }
    }
  }

  walk(v, sb)
  sb.to_string()
}
///|
/// 绑定解析：把 text 里的 `{{path}}` 替换为数据值显示串；
/// 未命中的占位保留字面（诚实占位：设计者一眼看到哪个绑定没喂数据），永不崩。
pub fn resolve_bindings(text : String, data : DataValue) -> String {
  if data is DNull {
    return text
  }
  let n = text.length()
  let sb = StringBuilder::new()
  let mut i = 0
  while i < n {
    let c = text.get_char(i)
    match c {
      Some('{') if i + 1 < n && text.get_char(i + 1) == Some('{') => {
        // 找闭合 }}
        let mut j = i + 2
        let mut closed = -1
        while j + 1 < n {
          if text.get_char(j) == Some('}') && text.get_char(j + 1) == Some('}') {
            closed = j
            break
          }
          j = j + 1
        }
        if closed < 0 {
          sb.write_char('{')
          i = i + 1
          continue
        }
        let path = text.substring(start=i + 2, end=closed).to_string()
        match data_lookup(data, path) {
          Some(v) => sb.write_string(data_to_display(v))
          None => {
            // 未命中：保留字面占位
            sb.write_string(text.substring(start=i, end=closed + 2).to_string())
          }
        }
        i = closed + 2
      }
      Some(ch) => {
        sb.write_char(ch)
        i = i + 1
      }
      None => break
    }
  }
  sb.to_string()
}
