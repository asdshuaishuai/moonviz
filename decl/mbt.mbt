/// `.mbt.md` 文学化 MoonBit 源文件的扫描与 Moonviz 视觉扩展。
///
/// 这里不执行任意 MoonBit 代码，也不把 Markdown 当 HTML。扫描器只识别
/// 官方代码块类型，并从显式 `moonviz:artboard` 标记后面的 `mbt` 块提取
/// Moonviz 声明；实际声明仍由 parse_decl 负责解析。

///|
pub(all) struct MbtCodeBlock {
  kind : String
  text : String
  start_line : Int
  end_line : Int
  artboard_id : String?
  visual : Bool
}

///|
pub(all) struct MbtDocument {
  source : String
  front_matter : String
  title : String
  revision : Int
  entry : String
  theme : String
  blocks : Array[MbtCodeBlock]
  visual_blocks : Array[MbtCodeBlock]
}

///|
fn mbt_has_prefix(s : String, prefix : String) -> Bool {
  s.length() >= prefix.length() &&
  s.substring(start=0, end=prefix.length()) == prefix
}

///|
fn mbt_trim(s : String) -> String {
  let mut a = 0
  let mut b = s.length()
  while a < b {
    match s.get_char(a) {
      Some(' ') | Some('\t') | Some('\r') => a = a + 1
      _ => break
    }
  }
  while b > a {
    match s.get_char(b - 1) {
      Some(' ') | Some('\t') | Some('\r') => b = b - 1
      _ => break
    }
  }
  s.substring(start=a, end=b)
}

///|
fn mbt_lines(text : String) -> Array[String] {
  let out : Array[String] = []
  let mut buf = StringBuilder::new()
  for c in text.iter() {
    if c == '\n' {
      out.push(buf.to_string())
      buf = StringBuilder::new()
    } else {
      buf.write_char(c)
    }
  }
  if text.length() > 0 {
    out.push(buf.to_string())
  } else {
    out.push("")
  }
  out
}

///|
fn mbt_join(lines : Array[String], start : Int, end : Int) -> String {
  let out = StringBuilder::new()
  let mut i = start
  while i < end && i < lines.length() {
    if i > start {
      out.write_char('\n')
    }
    out.write_string(lines[i])
    i = i + 1
  }
  out.to_string()
}

///|
fn mbt_fence_length(line : String) -> Int {
  let t = mbt_trim(line)
  let mut count = 0
  while count < t.length() && t.get_char(count) == Some('`') {
    count = count + 1
  }
  count
}

///|
fn mbt_fence_kind(line : String) -> String? {
  let t = mbt_trim(line)
  if mbt_fence_length(t) != 3 {
    return None
  }
  let body = mbt_trim(t.substring(start=3))
  if body == "mbt" ||
    body == "mbt check" ||
    body == "mbt nocheck" ||
    body == "moonbit" {
    Some(body)
  } else {
    // 其他 fenced code 是普通 Markdown 展示块，不能被 Moonviz 执行。
    None
  }
}

///|
fn mbt_marker_id(line : String) -> String? {
  let t = mbt_trim(line)
  let prefix = "<!-- moonviz:artboard "
  let suffix = " -->"
  if mbt_has_prefix(t, prefix) && t.length() > prefix.length() + suffix.length() {
    let end = t.length() - suffix.length()
    if t.substring(start=end, end=t.length()) == suffix {
      let id = mbt_trim(t.substring(start=prefix.length(), end~))
      if id != "" {
        return Some(id)
      }
    }
  }
  None
}

///|
fn mbt_field(front : String, key : String) -> String {
  let lines = mbt_lines(front)
  let prefix = key + ":"
  for line in lines.iter() {
    let t = mbt_trim(line)
    if mbt_has_prefix(t, prefix) {
      return mbt_trim(t.substring(start=prefix.length()))
    }
  }
  ""
}

///|
fn mbt_int(text : String) -> Int {
  let t = mbt_trim(text)
  let mut sign = 1
  let mut i = 0
  if t.length() > 0 && t.get_char(0) == Some('-') {
    sign = -1
    i = 1
  }
  let mut n = 0
  while i < t.length() {
    match t.get_char(i) {
      Some(c) => {
        let d = c.to_int()
        if d < 48 || d > 57 {
          break
        }
        n = n * 10 + d - 48
      }
      None => break
    }
    i = i + 1
  }
  n * sign
}

///|
/// 扫描官方 `.mbt.md` 文件，并提取显式 Moonviz visual block。
///
/// visual block 必须满足：
/// `<!-- moonviz:artboard <id> -->` 紧邻一个 ` ```mbt ` 代码块。
/// `mbt check` 仅作为 MoonBit 文档测试保留，不会被误当成页面声明。
pub fn scan_mbt(text : String) -> Result[MbtDocument, String] {
  let lines = mbt_lines(text)
  let mut front = ""
  let mut title = ""
  let mut revision = 1
  let mut entry = ""
  let mut theme = ""
  let mut body_start = 0
  if lines.length() > 0 && mbt_trim(lines[0]) == "---" {
    let mut close = -1
    let mut j = 1
    while j < lines.length() {
      if mbt_trim(lines[j]) == "---" {
        close = j
        break
      }
      j = j + 1
    }
    if close < 0 {
      return Err("mbt_front_matter_unclosed")
    }
    front = mbt_join(lines, 1, close)
    title = mbt_field(front, "title")
    revision = mbt_int(mbt_field(front, "revision"))
    if revision <= 0 {
      revision = 1
    }
    entry = mbt_field(front, "entry")
    theme = mbt_field(front, "theme")
    body_start = close + 1
  }
  let blocks : Array[MbtCodeBlock] = []
  let visual_blocks : Array[MbtCodeBlock] = []
  let mut i = body_start
  while i < lines.length() {
    let fence = mbt_trim(lines[i])
    if !mbt_has_prefix(fence, "```") {
      i = i + 1
      continue
    }
    let start = i + 1
    let opening_length = mbt_fence_length(fence)
    let mut close = -1
    let mut j = start
    while j < lines.length() {
      let candidate = mbt_trim(lines[j])
      if mbt_fence_length(candidate) >= opening_length {
        let rest = mbt_trim(candidate.substring(start=opening_length))
        if rest == "" {
          close = j
          break
        }
      }
      j = j + 1
    }
    if close < 0 {
      return Err("mbt_fence_unclosed_line:" + (i + 1).to_string())
    }
    match mbt_fence_kind(lines[i]) {
      None =>
        // 非 MoonBit fence 是普通 Markdown 内容：整块跳过，避免块内文字
        // 意外被解释成嵌套 MoonBit fence 或视觉声明。
        i = close + 1
      Some(kind) => {
        let mut marker : String? = None
        if i > body_start {
          marker = mbt_marker_id(lines[i - 1])
        }
        let visual = kind == "mbt" && marker is Some(_)
        let block : MbtCodeBlock = {
          kind,
          text: mbt_join(lines, start, close),
          start_line: start + 1,
          end_line: close,
          artboard_id: marker,
          visual,
        }
        blocks.push(block)
        if visual {
          visual_blocks.push(block)
        }
        i = close + 1
      }
    }
  }
  if title == "" {
    title = "MoonViz 文档"
  }
  Ok({
    source: text,
    front_matter: front,
    title,
    revision,
    entry,
    theme,
    blocks,
    visual_blocks,
  })
}

///|
pub fn MbtDocument::visual_count(self : MbtDocument) -> Int {
  self.visual_blocks.length()
}

///|
pub fn MbtDocument::block_kind_counts(self : MbtDocument) -> String {
  let mut mbt = 0
  let mut check = 0
  let mut nocheck = 0
  let mut moonbit = 0
  for b in self.blocks.iter() {
    match b.kind {
      "mbt" => mbt = mbt + 1
      "mbt check" => check = check + 1
      "mbt nocheck" => nocheck = nocheck + 1
      "moonbit" => moonbit = moonbit + 1
      _ => ()
    }
  }
  "{\"mbt\":" +
  mbt.to_string() +
  ",\"mbt_check\":" +
  check.to_string() +
  ",\"mbt_nocheck\":" +
  nocheck.to_string() +
  ",\"moonbit\":" +
  moonbit.to_string() +
  "}"
}

///|
pub(all) struct MbtProject {
  project : @core.Project
  document : MbtDocument
  entry : String
}

///|
fn mbt_paren_delta(line : String) -> Int {
  let mut delta = 0
  for c in line.iter() {
    match c {
      '(' => delta = delta + 1
      ')' => delta = delta - 1
      _ => ()
    }
  }
  delta
}

///|
fn mbt_visual_line(line : String) -> Bool {
  mbt_has_prefix(line, "let page = @decl.prototype(") ||
  mbt_has_prefix(line, "page.set_layout(") ||
  mbt_has_prefix(line, "page.add(") ||
  mbt_has_prefix(line, "page.add_to(")
}

///|
/// 从一个已标记的 `mbt` visual block 中抽取受支持的声明 DSL。
///
/// visual block 本身是合法的 MoonBit 函数体；这里仅抽取 Moonviz 声明行，
/// 不执行其它 MoonBit 语句。多行 page.add(...) 在抽取时规范为单行。
fn mbt_visual_decl(block : MbtCodeBlock) -> Result[String, String] {
  let lines = mbt_lines(block.text)
  let out = StringBuilder::new()
  let mut i = 0
  let mut found = 0
  while i < lines.length() {
    let line = mbt_trim(lines[i])
    if !mbt_visual_line(line) {
      // 函数壳、MoonBit 的 top-level 分隔符、以及最终的 `page` 返回表达式
      // 只是单文件视觉声明的结构，不属于可执行的额外视觉逻辑。
      if line == "" ||
        mbt_has_prefix(line, "///|") ||
        mbt_has_prefix(line, "fn visual_") ||
        line == "page" ||
        line == "}" {
        i = i + 1
        continue
      }
      return Err(
        "not_renderable_visual_logic_line:" + (block.start_line + i).to_string(),
      )
    }
    let statement = StringBuilder::new()
    let mut balance = 0
    let mut started = false
    while i < lines.length() {
      let part = mbt_trim(lines[i])
      if part != "" {
        statement.write_string(part)
        balance = balance + mbt_paren_delta(part)
        started = true
      }
      i = i + 1
      if started && balance <= 0 {
        break
      }
    }
    let text = statement.to_string()
    if text == "" || balance != 0 {
      return Err(
        "not_renderable_visual_block_line:" + block.start_line.to_string(),
      )
    }
    out.write_string(text)
    out.write_char('\n')
    found = found + 1
  }
  if found == 0 {
    Err("not_renderable_visual_block_line:" + block.start_line.to_string())
  } else {
    Ok(out.to_string())
  }
}

///|
fn mbt_root_size(root : @core.Node) -> (Double, Double) {
  let width = match root.width {
    @core.Fixed(v) => v
    _ => 390.0
  }
  let height = match root.height {
    @core.Fixed(v) => v
    _ => 844.0
  }
  (width, height)
}

///|
///|
/// frontmatter `tokens:` 段解析：`  <role>: "<value>"` 两空格缩进键值对。
fn mbt_parse_token_overrides(
  front : String,
) -> Map[String, String] {
  let out : Map[String, String] = Map::new()
  let lines = mbt_lines(front)
  let mut in_tokens = false
  for raw in lines.iter() {
    let line = mbt_trim(raw)
    if mbt_has_prefix(line, "moonviz:") || mbt_has_prefix(line, "moonbit:") {
      in_tokens = false
    }
    if line == "tokens:" {
      in_tokens = true
      continue
    }
    if !in_tokens {
      continue
    }
    // 键值行：role: "#VALUE"（值可带引号）；遇到非缩进的其他段键则退出
    let colon = line.find(":")
    match colon {
      Some(idx) => {
        let key = mbt_trim(line.substring(start=0, end=idx))
        let mut value = mbt_trim(line.substring(start=idx + 1))
        if value.length() >= 2 {
          let q = value.substring(start=0, end=1)
          if (q == "\"" || q == "'") && value.substring(start=value.length() - 1) == q {
            value = value.substring(start=1, end=value.length() - 1)
          }
        }
        if key != "" && value != "" && !key.contains(" ") {
          out.set(key, value)
        }
      }
      None => ()
    }
  }
  out
}

///|
fn mbt_parse_flows(front : String) -> Array[@core.FlowEdge] {
  let flows : Array[@core.FlowEdge] = []
  let lines = mbt_lines(front)
  let mut in_flows = false
  let mut from = ""
  let mut to = ""
  let mut trigger = ""
  for raw in lines.iter() {
    let line = mbt_trim(raw)
    if line == "flows:" {
      in_flows = true
      continue
    }
    if !in_flows {
      continue
    }
    if mbt_has_prefix(line, "- from:") {
      if from != "" && to != "" {
        flows.push({
          from,
          to,
          trigger: if trigger == "" {
            "tap"
          } else {
            trigger
          },
        })
      }
      from = mbt_trim(line.substring(start=7))
      to = ""
      trigger = ""
    } else if mbt_has_prefix(line, "to:") {
      to = mbt_trim(line.substring(start=3))
    } else if mbt_has_prefix(line, "trigger:") {
      trigger = mbt_trim(line.substring(start=8))
    } else if line != "" &&
      !mbt_has_prefix(line, "-") &&
      !mbt_has_prefix(line, " ") {
      in_flows = false
    }
  }
  if from != "" && to != "" {
    flows.push({
      from,
      to,
      trigger: if trigger == "" {
        "tap"
      } else {
        trigger
      },
    })
  }
  flows
}

///|
pub fn mbt_validate_flows(project : @core.Project) -> Result[Unit, String] {
  for flow in project.flows.iter() {
    match (project.artboards.get(flow.from), project.artboards.get(flow.to)) {
      (Some(from), Some(_)) =>
        if mbt_has_prefix(flow.trigger, "tap:") {
          let node_id = flow.trigger.substring(start=4)
          if !from.doc.has(node_id) {
            return Err("mbt_flow_unknown_node:" + flow.from + ":" + node_id)
          }
        }
      _ => return Err("mbt_flow_unknown_artboard:" + flow.from + ":" + flow.to)
    }
  }
  Ok(())
}

///|
/// 完整 `.mbt.md` → Moonviz Project。
///
/// 只消费显式 visual block；`mbt check`、`mbt nocheck`、`moonbit` 代码块不会
/// 生成画板。所有返回画布都是这份 MBT 文本的派生结果。
pub fn load_mbt_project(text : String) -> Result[MbtProject, String] {
  match scan_mbt(text) {
    Err(error) => Err(error)
    Ok(document) => {
      if document.visual_blocks.length() == 0 {
        return Err("mbt_no_visual_blocks")
      }
      let project = @core.Project::new()
      for block in document.visual_blocks.iter() {
        let artboard_id = match block.artboard_id {
          Some(id) => id
          None =>
            return Err(
              "mbt_visual_block_missing_id:" + block.start_line.to_string(),
            )
        }
        if project.artboards.contains(artboard_id) {
          return Err("mbt_duplicate_artboard:" + artboard_id)
        }
        let decl = match mbt_visual_decl(block) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        let prototype = match parse_decl(decl) {
          Ok(page) => page
          Err(error) =>
            return Err(
              "mbt_visual_parse_error:" +
              artboard_id +
              ":line:" +
              (block.start_line + error.line - 1).to_string() +
              ":" +
              error.message,
            )
        }
        let root = prototype.root
        let (width, height) = mbt_root_size(root)
        let built = prototype.build()
        project.artboards.set(artboard_id, {
          id: artboard_id,
          name: root.name,
          width,
          height,
          doc: built,
        })
      }
      for flow in mbt_parse_flows(document.front_matter).iter() {
        project.flows.push(flow)
      }
      // 组件多态状态随节点名标记往返；内存表需在重建 Project 后回填，
      // 否则每次 load-mbt-b64 都会丢掉全部状态定义。
      for artboard_id in project.artboards.keys() {
        project.rebuild_node_states(artboard=artboard_id)
      }
      let entry = if document.entry != "" {
        document.entry
      } else {
        match document.visual_blocks[0].artboard_id {
          Some(id) => id
          None => ""
        }
      }
      if !project.artboards.contains(entry) {
        return Err("mbt_unknown_entry:" + entry)
      }
      project.revision = document.revision
      if document.theme != "" {
        project.set_theme_tokens(document.theme)
      }
      // 令牌自定义覆盖最后叠加：它比主题更具体（设计者明确意图）
      let overrides = mbt_parse_token_overrides(document.front_matter)
      for role in overrides.keys() {
        match overrides.get(role) {
          Some(v) => {
            let _ = project.set_token(role, v)
          }
          None => ()
        }
      }
      match mbt_validate_flows(project) {
        Err(error) => Err(error)
        Ok(_) => Ok({ project, document, entry })
      }
    }
  }
}

///|
/// 使用指定的双路线 Gate 校验由 MBT 编译出的所有画板。
/// 返回的人类 debt 数只描述当前 MBT 的视觉债；任何结构问题都会拒绝。
///|
/// 直接在 Project 上做门检查（不序列化、不渲染）：违规按 gate 分类，
/// 阻断项非空即 Err(mbt_gate_block:...)，放行则返回视觉债计数。
/// 会话路径（session_apply_agent/human）用它在已解析的 Project 上完成
/// 门检查——省掉「序列化→重解析」的三重往返（issue #6）。
pub fn project_gate_check(
  p : @core.Project,
  gate : @core.Gate,
) -> Result[Int, String] {
  let mut debt_count = 0
  for artboard_id in p.artboards.keys() {
    match p.artboards.get(artboard_id) {
      None => ()
      Some(artboard) => {
        let violations = @core.validate(artboard.doc)
        match @core.decide(gate, violations) {
          @core.Allow(debt) => debt_count = debt_count + debt.length()
          @core.Reject(blocking) =>
            match blocking.get(0) {
              Some(first) =>
                return Err(
                  "mbt_gate_block:" +
                  artboard_id +
                  ":" +
                  first.predicate.name() +
                  ":" +
                  first.node_id,
                )
              None => return Err("mbt_gate_block:" + artboard_id)
            }
        }
      }
    }
  }
  Ok(debt_count)
}

///|
pub fn MbtProject::validate_for(
  self : MbtProject,
  gate : @core.Gate,
) -> Result[Int, String] {
  let mut debt_count = 0
  for artboard_id in self.project.artboards.keys() {
    match self.project.artboards.get(artboard_id) {
      None => ()
      Some(artboard) => {
        let violations = @core.validate(artboard.doc)
        match @core.decide(gate, violations) {
          @core.Allow(debt) => debt_count = debt_count + debt.length()
          @core.Reject(blocking) =>
            match blocking.get(0) {
              Some(first) =>
                return Err(
                  "mbt_gate_block:" +
                  artboard_id +
                  ":" +
                  first.predicate.name() +
                  ":" +
                  first.node_id,
                )
              None => return Err("mbt_gate_block:" + artboard_id)
            }
        }
      }
    }
  }
  Ok(debt_count)
}

///|
/// 将既有 Project 投影为同一份 `.mbt.md` 的临时模型。
///
/// 模板/迁移只可通过这个入口进入 MBT 主链路；后续保存和渲染均从 to_mbt()
/// 生成的文本重新加载，Project 不会成为独立的持久事实源。
pub fn project_to_mbt(
  project : @core.Project,
  title? : String = "MoonViz 文档",
  entry? : String = "",
) -> Result[MbtProject, String] {
  let ids : Array[String] = []
  for id in project.artboards.keys() {
    ids.push(id)
  }
  if ids.length() == 0 {
    return Err("mbt_project_without_artboards")
  }
  let actual_entry = if entry != "" { entry } else { ids[0] }
  if !project.artboards.contains(actual_entry) {
    return Err("mbt_unknown_entry:" + actual_entry)
  }
  let document : MbtDocument = {
    source: "",
    front_matter: "",
    title,
    revision: if project.revision > 0 {
      project.revision
    } else {
      1
    },
    entry: actual_entry,
    theme: project.active_theme,
    blocks: [],
    visual_blocks: [],
  }
  Ok({ project, document, entry: actual_entry })
}

///|
fn mbt_yaml_list(
  out : StringBuilder,
  values : Array[String],
  indent : String,
) -> Unit {
  for value in values.iter() {
    out.write_string(indent + "- " + value + "\n")
  }
}

///|
fn mbt_function_name(id : String) -> String {
  "visual_" + id
}

///|
/// Moonviz Project → 单一 canonical `.mbt.md`。
///
/// 多画板被规范化为多个 `mbt` visual block；每个 block 都是有效 MoonBit
/// 函数，避免多个画板在同一文学化源码文件中重复定义顶层 `page` 变量。
pub fn MbtProject::to_mbt(self : MbtProject) -> String {
  let out = StringBuilder::new()
  out.write_string("---\n")
  out.write_string("moonbit:\n")
  out.write_string("  backend: native\n")
  out.write_string("  import:\n")
  out.write_string("    - path: moonviz/decl\n")
  out.write_string("      alias: decl\n")
  out.write_string("moonviz:\n")
  out.write_string("  format: visual-document\n")
  out.write_string("  revision: " + self.project.revision.to_string() + "\n")
  if self.project.active_theme != "" {
    out.write_string("  theme: " + self.project.active_theme + "\n")
  }
  match self.project.token_overrides {
    Some(ov) => {
      let mut count = 0
      for role in ov.keys() {
        // 与默认调色板同值的覆盖不序列化：set 回原值即撤销自定义，
        // canonical 里不该留下 primary: "#4B6BFB" 这类恒真条目
        let is_default = match @core.DesignTokens::default().colors.get(role) {
          Some(dv) =>
            match ov.get(role) {
              Some(v) => v == dv
              None => false
            }
          None => false
        }
        if !is_default {
          count = count + 1
        }
      }
      if count > 0 {
        out.write_string("  tokens:\n")
        for role in ov.keys() {
          match ov.get(role) {
            Some(v) =>
              out.write_string("    " + role + ": \"" + v + "\"\n")
            None => ()
          }
        }
      }
    }
    None => ()
  }
  out.write_string("  title: " + self.document.title + "\n")
  let ids : Array[String] = []
  for id in self.project.artboards.keys() {
    ids.push(id)
  }
  // entry 画板可能已被 delete-artboard 移除：序列化悬空 entry 会让下一次
  // load 直接 mbt_unknown_entry，文档就此打不开。失效时重定向到首个剩余画板。
  let entry = if self.project.artboards.contains(self.entry) {
    self.entry
  } else {
    ids[0]
  }
  out.write_string("  entry: " + entry + "\n")
  out.write_string("  artboards:\n")
  mbt_yaml_list(out, ids, "    ")
  if self.project.flows.length() > 0 {
    out.write_string("  flows:\n")
    for flow in self.project.flows.iter() {
      out.write_string("    - from: " + flow.from + "\n")
      out.write_string("      to: " + flow.to + "\n")
      out.write_string("      trigger: " + flow.trigger + "\n")
    }
  }
  out.write_string("---\n\n")
  out.write_string("# " + self.document.title + "\n\n")
  out.write_string(
    "这是一份 MoonBit `.mbt.md` 视觉文档。人类画布操作与 Agent 修改都必须回写到本文件；Moonviz 只从本文件重新构建和渲染画布。\n\n",
  )
  for id in ids.iter() {
    match self.project.artboards.get(id) {
      None => ()
      Some(artboard) => {
        // 序列化前把根节点名对齐 ArtboardMeta.name，否则 from_document 会
        // 永远输出 Document::new 的默认名「画布」，canonical 往返丢失真实名。
        let proto = from_document(artboard.doc)
        proto.root = { ..proto.root, name: artboard.name }
        let declaration = proto.to_decl_text()
        let function_name = mbt_function_name(id)
        // debt 快照：HumanGate 允许视觉债落盘，验收断言必须反映被接受的
        // 状态而不是硬编码 0，否则带债文档自带的 mbt check 在 moon test 下自败。
        let violations = @core.validate(artboard.doc).length()
        out.write_string("## " + artboard.name + "\n\n")
        out.write_string("<!-- moonviz:artboard " + id + " -->\n")
        out.write_string("```mbt\n")
        out.write_string("///| @moonviz:visual " + id + "\n")
        out.write_string("fn " + function_name + "() -> @decl.Prototype {\n")
        for line in mbt_lines(declaration).iter() {
          if line != "" {
            out.write_string("  " + line + "\n")
          }
        }
        out.write_string("  page\n")
        out.write_string("}\n")
        out.write_string("```\n\n")
        out.write_string("```mbt check\n")
        out.write_string("test \"" + id + " visual declaration\" {\n")
        for line in mbt_lines(declaration).iter() {
          if line != "" {
            out.write_string("  " + line + "\n")
          }
        }
        out.write_string("  assert_eq(page.check().length(), \{violations})\n")
        out.write_string("  assert_true(page.render().contains(\"<svg\"))\n")
        out.write_string("}\n")
        out.write_string("```\n\n")
      }
    }
  }
  out.to_string()
}

///|

///|
/// 从当前临时 Project 写出 canonical MBT 后重新载入，再按指定 Gate 渲染。
///
/// 该方法是两条路线的提交边界：画布永远不会从操作后的内存 Project 直接
/// 渲染，必须先把变更落到唯一 `.mbt.md` 文本，再从文本重建。
pub fn MbtProject::commit_and_render(
  self : MbtProject,
  gate : @core.Gate,
) -> Result[String, String] {
  let canonical = self.to_mbt()
  match load_mbt_project(canonical) {
    Err(error) => Err(error)
    Ok(reloaded) =>
      match reloaded.validate_for(gate) {
        Err(error) => Err(error)
        Ok(debt) => {
          let rendered = reloaded.render_json()
          Ok(
            "{\"ok\":true,\"debt\":" +
            debt.to_string() +
            "," +
            rendered.substring(start=11),
          )
        }
      }
  }
}

///|
pub fn MbtProject::render_json(self : MbtProject) -> String {
  let artboards : Array[String] = []
  for id in self.project.artboards.keys() {
    match
      (self.project.artboards.get(id), self.project.export_svg(artboard=id)) {
      (Some(artboard), Ok(svg)) => {
        let nodes = match self.project.query_nodes(artboard=id) {
          Ok(json) => json
          Err(_) => "[]"
        }
        artboards.push(
          "{\"id\":\"" +
          @core.json_escape(id) +
          "\",\"name\":\"" +
          @core.json_escape(artboard.name) +
          "\",\"width\":" +
          artboard.width.to_string() +
          ",\"height\":" +
          artboard.height.to_string() +
          ",\"nodes\":" +
          nodes +
          ",\"svg\":\"" +
          @core.json_escape(svg) +
          "\"}",
        )
      }
      _ => ()
    }
  }
  let out = StringBuilder::new()
  out.write_string(
    "{\"ok\":true,\"entry\":\"" + @core.json_escape(self.entry) + "\",",
  )
  out.write_string("\"revision\":" + self.project.revision.to_string() + ",")
  out.write_string("\"blockKinds\":" + self.document.block_kind_counts() + ",")
  out.write_string("\"flows\":" + self.project.flow_json() + ",")
  out.write_string(
    "\"mbt\":\"" +
    @core.json_escape(
      if self.document.source != "" {
        self.document.source
      } else {
        self.to_mbt()
      },
    ) +
    "\",\"artboards\":[",
  )
  for i in 0..<artboards.length() {
    if i > 0 {
      out.write_string(",")
    }
    out.write_string(artboards[i])
  }
  out.write_string("]}")
  out.to_string()
}
