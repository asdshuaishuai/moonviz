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
// ---------------------------------------------------------------------------
// Smart UX M-S1：DataSchema——UI 期望的数据契约（data_schema 导出读取）
// ---------------------------------------------------------------------------

///|
/// 轻量 DataSchema：字段名 → 类型名的类型化契约。类型词汇刻意收窄为
/// string|number|boolean（SMART-UX-1.0 支柱 B 最小实现；array/object/
/// 必填/枚举留给后续里程碑）。与 data 同为运行时态——不入 canonical。
pub(all) struct DataSchema {
  fields : Map[String, String]
}

///|
/// schema 合法类型词汇：string | number | boolean
fn data_schema_valid_type(t : String) -> Bool {
  t == "string" || t == "number" || t == "boolean"
}

///|
/// 键内容序比较（UTF-16 码元字典序）。不使用 String::compare——当前
/// 工具链的该实现按长度序而非内容序（"b" < "aaaa"），Array::sort 同染；
/// schema JSON 的逐字节确定性必须建立在真内容序上（白盒测试锁定）。
fn data_schema_key_lt(a : String, b : String) -> Bool {
  let la = a.length()
  let lb = b.length()
  let n = if la < lb { la } else { lb }
  let mut i = 0
  while i < n {
    let ca = match a.get_char(i) {
      Some(c) => c.to_int()
      None => 0
    }
    let cb = match b.get_char(i) {
      Some(c) => c.to_int()
      None => 0
    }
    if ca != cb {
      return ca < cb
    }
    i = i + 1
  }
  la < lb
}

///|
/// 码元字典序插入排序（小数组 n≤键数，O(n²) 足够；绕开工具链
/// String::compare 长度序缺陷，见 data_schema_key_lt）。
fn data_schema_sort_keys(keys : Array[String]) -> Unit {
  for i in 1..<keys.length() {
    let k = keys[i]
    let mut j = i - 1
    while j >= 0 && data_schema_key_lt(k, keys[j]) {
      keys[j + 1] = keys[j]
      j = j - 1
    }
    keys[j + 1] = k
  }
}

///|
/// 从 JSON 样例推断：顶层字段 DStr→string、DNum→number、DBool→boolean；
/// 数组/对象/null 字段跳过（词汇外类型宁缺勿错）。非对象样例得空 schema。
pub fn DataSchema::infer(sample : DataValue) -> DataSchema {
  let fields : Map[String, String] = Map::new()
  match sample {
    DObj(m) =>
      for k in m.keys() {
        match m.get(k) {
          Some(DStr(_)) => fields.set(k, "string")
          Some(DNum(_)) => fields.set(k, "number")
          Some(DBool(_)) => fields.set(k, "boolean")
          _ => () // 数组/对象/null：词汇外，跳过
        }
      }
    _ => ()
  }
  { fields, }
}

///|
/// 显式声明：spec 必须是对象且每个值都是合法类型名字符串；任何非法
/// 项整体拒绝（不部分应用），返回首个错误（不崩纪律：Err 而非 abort）。
pub fn DataSchema::from_spec(spec : DataValue) -> Result[DataSchema, String] {
  match spec {
    DObj(m) => {
      let fields : Map[String, String] = Map::new()
      for k in m.keys() {
        match m.get(k) {
          Some(DStr(t)) =>
            if data_schema_valid_type(t) {
              fields.set(k, t)
            } else {
              return Err("schema_unknown_type: \{k}=\{t}")
            }
          _ => return Err("schema_type_must_be_string: \{k}")
        }
      }
      Ok({ fields, })
    }
    _ => Err("schema_spec_must_be_object")
  }
}

///|
/// schema → JSON（{"field":"type",…}，键按字典序输出保证逐字节确定性；
/// 空契约输出 {}——空集合 envelope 一律合法 JSON）。
pub fn DataSchema::to_json(self : DataSchema) -> String {
  let keys : Array[String] = []
  for k in self.fields.keys() {
    keys.push(k)
  }
  data_schema_sort_keys(keys)
  let parts : Array[String] = []
  for k in keys {
    match self.fields.get(k) {
      Some(t) => parts.push("\"\{json_escape(k)}\":\"\{json_escape(t)}\"")
      None => ()
    }
  }
  let joined = parts.join(",")
  "{\{joined}}"
}

///|
/// 数据值 → JSON（collect_data_json 用）。键按码元字典序输出（与
/// DataSchema::to_json 同一确定性约定，宿主可逐字节 diff）；字符串经
/// json_escape，非 ASCII 原样保留。
pub fn data_to_json(v : DataValue) -> String {
  match v {
    DNull => "null"
    DBool(true) => "true"
    DBool(false) => "false"
    DNum(n) =>
      if n == n.floor() && n.abs() < 1000000000000000.0 {
        n.to_int().to_string()
      } else {
        n.to_string()
      }
    DStr(s) => "\"\{json_escape(s)}\""
    DArr(a) => {
      let parts : Array[String] = []
      for item in a.iter() {
        parts.push(data_to_json(item))
      }
      "[\{parts.join(",")}]"
    }
    DObj(m) => {
      let keys : Array[String] = []
      for k in m.keys() {
        keys.push(k)
      }
      data_schema_sort_keys(keys)
      let parts : Array[String] = []
      for k in keys {
        match m.get(k) {
          Some(v) => parts.push("\"\{json_escape(k)}\":\{data_to_json(v)}")
          None => ()
        }
      }
      "{\{parts.join(",")}}"
    }
  }
}

///|
/// 点路径写穿（Smart UX M-S2 表单回写）：把字符串值写到 root 的 path 处，
/// 返回（可能新建的）根——root 为 DNull（从未注入数据）时以空对象起根，
/// 调用方必须把返回值写回（Project::dispatch_event 负责赋回 self.data）。
///
/// 语义（SMART-UX-1.0 支柱 B 最小闭环，契约测试锁定）：
/// - 路径不存在 → 逐段创建中间 DObj（写穿播种——表单绑定常指向尚未
///   喂数据的占位路径，提交即落值，不报错）；
/// - 根为 DNull（从未注入数据）→ 以空对象起根；显式 null 值仍按标量
///   冲突拒绝（不静默改写设计者的 null）；
/// - 中途遇标量/越界数组段 → data_path_conflict 整体拒绝（不部分应用，
///   与 set_data_json 的整体语义一致）；
/// - 路径末段为数组段（{{items.0}}）→ data_path_conflict 整体拒绝：
///   数组只作导航（items.0.title 可写既有元素内的键），元素本身不作
///   写入落点——评审修复的假成功信封缺口（验证遍放行、落地遍只导航
///   不写值却返回 Ok）在验证遍即拦下，杜绝任何静默无写入的 Ok；
/// - 空路径 → data_path_empty。
/// 原地突变 DObj 内 Map（data 与 artboards 同为引用随行语义，见
/// Project::clone 注释）；验证遍先整体把关，通过才触碰 Map，无半写状态。
pub fn data_set_path(
  root : DataValue,
  path : String,
  value : String,
) -> Result[DataValue, String] {
  if path.length() == 0 {
    return Err("data_path_empty")
  }
  let base : DataValue = match root {
    DNull => DObj(Map::new())
    v => v
  }
  // 第一遍：验证全路径可写（缺键可建；标量/越界/末段数组段冲突）
  let segs : Array[String] = []
  for seg in path.split(".") {
    segs.push(seg.to_string())
  }
  let mut cur = base
  let n = segs.length()
  for i in 0..<n {
    let seg = segs[i].to_string()
    let last = i == n - 1
    match cur {
      DObj(m) =>
        match m.get(seg) {
          Some(v) => cur = v
          None => cur = DObj(Map::new()) // 将创建：占位继续验证
        }
      DArr(a) => {
        // 末段数组段：无写入落点，整体拒绝（防假成功信封，评审 Finding 1）
        if last {
          return Err("data_path_conflict: \{seg}（末段数组元素不作写入落点）")
        }
        let idx = data_arr_index(seg)
        match idx {
          Some(ix) =>
            if ix < a.length() {
              cur = a[ix]
            } else {
              return Err("data_path_conflict: \{seg}（数组不越界创建）")
            }
          None => return Err("data_path_conflict: \{seg}（数组段须为数字）")
        }
      }
      _ => return Err("data_path_conflict: \{seg}（标量不可再深入）")
    }
  }
  // 第二遍：逐段落地（缺键建 DObj，末段写 DStr）；数组段仅导航——
  // 末段数组段已在验证遍拒绝，此处遇 DArr 必为非末段
  let mut cur2 = base
  for i in 0..<n {
    let seg = segs[i].to_string()
    let last = i == n - 1
    match cur2 {
      DObj(m) =>
        if last {
          m.set(seg, DStr(value))
        } else {
          match m.get(seg) {
            Some(v) => cur2 = v
            None => {
              let child : Map[String, DataValue] = Map::new()
              m.set(seg, DObj(child))
              cur2 = DObj(child)
            }
          }
        }
      DArr(a) => {
        // 验证遍已保证索引合法且非末段
        let ix = match data_arr_index(seg) {
          Some(x) => x
          None => return Err("data_path_conflict: \{seg}")
        }
        cur2 = a[ix]
      }
      _ => return Err("data_path_conflict: \{seg}")
    }
  }
  Ok(base)
}

///|
/// 数组段 → 非负十进制索引（与 data_lookup 同规则）；非法返回 None。
fn data_arr_index(seg : String) -> Int? {
  let mut idx = 0
  let mut ok = seg.length() > 0
  let mut i = 0
  while i < seg.length() {
    match seg.get_char(i) {
      Some(ch) if ch >= '0' && ch <= '9' => {
        idx = idx * 10 + (ch.to_int() - 48)
        i = i + 1
      }
      _ => {
        ok = false
        i = seg.length()
      }
    }
  }
  if ok {
    Some(idx)
  } else {
    None
  }
}

///|
/// 节点 text 是否为单一绑定 "{{path}}"（整段恰为一个占位）：是则返回
/// 路径。与 resolve_bindings 的取段规则对称——占位内文本原样作路径。
pub fn binding_path(text : String) -> String? {
  let n = text.length()
  if n < 5 {
    return None // 最短 "{{a}}"
  }
  if text.substring(start=0, end=2) != "{{" ||
    text.substring(start=n - 2, end=n) != "}}" {
    return None
  }
  let inner = text.substring(start=2, end=n - 2).to_string()
  // 内嵌 "{{"/"}}"：不是单一干净绑定，按字面量处理
  if inner.contains("{{") || inner.contains("}}") {
    return None
  }
  Some(inner)
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
