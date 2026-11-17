///|
/// 交互原型系统：原型不是静态图——它有状态、有事件、有转场。
///
/// 核心概念：
/// - Trigger：什么触发了交互（tap / 长按 / 滑动 / 键盘）
/// - Action：交互发生什么（导航 / 切换状态 / 更新文字 / 提交表单）
/// - Transition：页面如何过渡（push / modal / fade）
/// - ComponentState：交互组件的多态（default / pressed / disabled / loading）
///
/// 运行时引擎（runtime.mbt）消费这些定义，驱动可交互的原型。

// ---------------------------------------------------------------------------
// 触发器
// ---------------------------------------------------------------------------

pub(all) enum Trigger {
  Tap // 单击
  LongPress(Double) // 长按（秒）
  SwipeLeft // 左滑
  SwipeRight // 右滑
  SwipeUp // 上滑
  SwipeDown // 下滑
  ScrollEnd // 滚动到底
  KeyboardEnter // 回车键
  Focus // 获得焦点
  Blur // 失去焦点
}

///|
pub fn Trigger::name(self : Trigger) -> String {
  match self {
    Tap => "tap"
    LongPress(_) => "long_press"
    SwipeLeft => "swipe_left"
    SwipeRight => "swipe_right"
    SwipeUp => "swipe_up"
    SwipeDown => "swipe_down"
    ScrollEnd => "scroll_end"
    KeyboardEnter => "keyboard_enter"
    Focus => "focus"
    Blur => "blur"
  }
}

///|
/// Trigger → 规范 spec（与 trigger_from_spec 对称）。LongPress 保留时长
/// （"long_press:0.8"）——此前 name() 丢时长，0.8s 与 0.5s 无法区分。
pub fn Trigger::spec(self : Trigger) -> String {
  match self {
    LongPress(sec) => "long_press:" + double_text(sec)
    _ => self.name()
  }
}

// ---------------------------------------------------------------------------
// 动作
// ---------------------------------------------------------------------------

///|
pub(all) enum Action {
  NavigateTo(String) // 跳转到画板
  Back // 返回上一页（弹出导航栈）
  ToggleState(String, String) // 切换组件状态 (node_id, state_name)
  SetState(String, String) // 设置组件状态 (node_id, state_name)
  SetText(String, String) // 更新文字 (node_id, new_text)
  SubmitForm(Array[String]) // 提交表单（收集输入框 node_ids）
  ShowToast(String) // 显示临时消息
  HapticFeedback // 触觉反馈
  PlaySound(String) // 播放音效
}

///|
pub fn Action::describe(self : Action) -> String {
  match self {
    NavigateTo(target) => "navigate_to:\{target}"
    Back => "back"
    ToggleState(id, _) => "toggle_state:\{id}"
    SetState(id, state) => "set_state:\{id}:\{state}"
    SetText(id, text) => "set_text:\{id}:\"\{text}\""
    // 字段 id 列表（不是 [N fields] 占位）：spec 语法要能反解析回节点集合，
    // 导出层也据此把 submit_form 绑定成真实字段数组
    SubmitForm(ids) => "submit_form:" + ids.join(",")
    ShowToast(msg) => "show_toast:\"\{msg}\""
    HapticFeedback => "haptic"
    PlaySound(name) => "play_sound:\{name}"
  }
}

///|
/// 动作种类名（interactions v2 / manifest / 一致性脚本的稳定标识）。
pub fn Action::kind(self : Action) -> String {
  match self {
    NavigateTo(_) => "navigate_to"
    Back => "back"
    ToggleState(_, _) => "toggle_state"
    SetState(_, _) => "set_state"
    SetText(_, _) => "set_text"
    SubmitForm(_) => "submit_form"
    ShowToast(_) => "show_toast"
    HapticFeedback => "haptic"
    PlaySound(_) => "play_sound"
  }
}

///|
/// 动作参数 JSON（interactions v2 的 action.params）：按 kind 给出结构化
/// 参数，供宿主/Agent 直接消费，不必再解析 spec 字符串。
pub fn Action::params_json(self : Action) -> String {
  match self {
    NavigateTo(target) => "{\"target\":\"" + json_escape(target) + "\"}"
    Back => "{}"
    ToggleState(id, _) => "{\"node\":\"" + json_escape(id) + "\"}"
    SetState(id, st) =>
      "{\"node\":\"" +
      json_escape(id) +
      "\",\"state\":\"" +
      json_escape(st) +
      "\"}"
    SetText(id, txt) =>
      "{\"node\":\"" +
      json_escape(id) +
      "\",\"text\":\"" +
      json_escape(txt) +
      "\"}"
    SubmitForm(ids) => "{\"fields\":" + json_string_array(ids) + "}"
    ShowToast(msg) => "{\"message\":\"" + json_escape(msg) + "\"}"
    HapticFeedback => "{}"
    PlaySound(name) => "{\"name\":\"" + json_escape(name) + "\"}"
  }
}

// ---------------------------------------------------------------------------
// 转场
// ---------------------------------------------------------------------------

///|
pub(all) enum Transition {
  Push // 从右滑入
  Pop // 从左滑出（返回）
  ModalPresent // 从底部滑入（模态）
  ModalDismiss // 向底部滑出（关闭模态）
  SheetPresent // 部分滑入（半屏 sheet）
  Fade // 交叉淡入淡出
  NoTransition // 无动画
}

///|
pub fn Transition::name(self : Transition) -> String {
  match self {
    Push => "push"
    Pop => "pop"
    ModalPresent => "modal_present"
    ModalDismiss => "modal_dismiss"
    SheetPresent => "sheet_present"
    Fade => "fade"
    NoTransition => "none"
  }
}

///|
/// 过渡名 → Transition（frontmatter `transition:` / flow op / CLI 共用）。
pub fn transition_from_name(name : String) -> Transition? {
  match name {
    "push" => Some(Push)
    "pop" => Some(Pop)
    "modal_present" => Some(ModalPresent)
    "modal_dismiss" => Some(ModalDismiss)
    "sheet_present" => Some(SheetPresent)
    "fade" => Some(Fade)
    "none" => Some(NoTransition)
    _ => None
  }
}

///|
/// 过渡 spec 规范化：空 = 默认 push；未知 → Err(unknown_transition: …)。
pub fn normalize_transition(name : String) -> Result[String, String] {
  if name == "" {
    return Ok("push")
  }
  match transition_from_name(name) {
    Some(t) => Ok(t.name())
    None => Err("unknown_transition: " + name)
  }
}

// ---------------------------------------------------------------------------
// 交互定义
// ---------------------------------------------------------------------------

///|
/// 组件多态（同一组件的不同视觉状态）
pub(all) struct ComponentStateDef {
  node_id : String
  states : Map[String, NodePatch] // "default" → base, "pressed" → darker fill...
  mut current : String
}

// ---------------------------------------------------------------------------
// 交互注册与管理
// ---------------------------------------------------------------------------

///|
/// 为节点添加交互定义
///
/// 转场已下沉到 FlowEdge.transition（分板过渡单一来源）：标记本身只
/// 表达 trigger→action，节点交互不再携带一份被丢弃的 transition。
pub fn Project::add_interaction(
  self : Project,
  artboard~ : String,
  node_id~ : String,
  trigger~ : Trigger,
  action~ : Action,
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard")
    Some(ab) => {
      if !ab.doc.has(node_id) {
        return Err("unknown_node: \{node_id}")
      }
      match ab.doc.nodes.get(node_id) {
        Some(n) => {
          // 把交互信息序列化到节点的 metadata（v1：存 text 前缀标记）
          let marker = "⚡\{trigger.name()}→\{action.describe()}"
          let _ = ab.doc.update_node(node_id, fn(x) {
            { ..x, name: "\{x.name} \{marker}", }
          })
          Ok(
            "{\"ok\":true,\"interaction\":\"\{node_id}:\{trigger.name()}→\{action.describe()}\"}",
          )
        }
        None => Err("node_not_found")
      }
    }
  }
}

///|
/// 为组件定义多态状态（真实存储补丁，而非仅写标记）。
///
/// 状态作用于渲染/命中前的节点变换：default 为该节点的基准补丁，
/// pressed/disabled 等为相对基准的覆盖。此前该函数接收 patch 却完全丢弃，
/// 只留一个无人读取的名字标记——签名承诺的能力实际不存在。
pub fn Project::define_component_state(
  self : Project,
  artboard~ : String,
  node_id~ : String,
  state_name~ : String,
  patch~ : NodePatch,
) -> Result[String, String] {
  let ab = match self.artboards.get(artboard) {
    Some(a) => a
    None => return Err("unknown_artboard: \{artboard}")
  }
  if !ab.doc.has(node_id) {
    return Err("unknown_node: \{node_id}")
  }
  let def = match self.node_states.get(node_id) {
    Some(d) => d
    None => { node_id, states: Map([]), current: "default", }
  }
  def.states.set(state_name, patch)
  self.node_states.set(node_id, def)
  // 状态定义必须随 canonical MBT 往返：序列化到节点名标记（[state:...]）。
  // 仅存内存会在每次 load-mbt-b64 重建 Project 时静默丢失。
  let count = def.states.length().to_string()
  let markers = states_to_markers(def)
  let cur = if def.current != "default" {
    ["[cur:" + def.current + "]"]
  } else {
    []
  }
  for m in cur {
    markers.push(m)
  }
  let _ = ab.doc.update_node(node_id, fn(n) {
    { ..n, name: rebuild_name(n.name, markers), }
  })
  self.revision = self.revision + 1
  Ok(
    "{\"ok\":true,\"node\":\"\{node_id}\",\"state\":\"\{state_name}\",\"states\":\{count}}",
  )
}

///|
/// 状态定义 → 名字标记列表：`[state:<name>:k=v,k=v]`
fn states_to_markers(def : ComponentStateDef) -> Array[String] {
  let out : Array[String] = []
  for name in def.states.keys() {
    match def.states.get(name) {
      Some(p) => out.push("[state:" + name + ":" + patch_to_spec(p) + "]")
      None => ()
    }
  }
  out
}

///|
/// 状态标记 spec 值的转义协议（标记格式自有，与 decl 层转义无关）：
/// `\` → `\\`、`,` → `\,`、`[` → `\[`、`]` → `\]`。text 值经此写入
/// [state:name:spec] 标记——裸写时 split_commas 逢逗号即切、标记解析
/// 逢 ] 即收尾，含逗号/方括号的状态文本每次 canonical 重建都被截断。
fn spec_escape(s : String) -> String {
  let sb = StringBuilder()
  for c in s.iter() {
    match c {
      '\\' => sb.write_string("\\\\")
      ',' => sb.write_string("\\,")
      '[' => sb.write_string("\\[")
      ']' => sb.write_string("\\]")
      _ => sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
/// spec_escape 的逆（成对存在）。尾部孤立反斜杠原样保留，不做有损丢弃。
fn spec_unescape(s : String) -> String {
  let sb = StringBuilder()
  let mut esc = false
  for c in s.iter() {
    if esc {
      sb.write_char(c)
      esc = false
    } else if c == '\\' {
      esc = true
    } else {
      sb.write_char(c)
    }
  }
  if esc {
    sb.write_char('\\')
  }
  sb.to_string()
}

///|
/// NodePatch → 紧凑规格 "k=v,k=v"（与 marker_to_patch 对称）。
fn patch_to_spec(p : NodePatch) -> String {
  let parts : Array[String] = []
  match p.fill {
    Some(v) => parts.push("fill=" + v)
    None => ()
  }
  match p.text_color {
    Some(v) => parts.push("text_color=" + v)
    None => ()
  }
  match p.stroke {
    Some(v) => parts.push("stroke=" + v)
    None => ()
  }
  match p.text {
    Some(v) => parts.push("text=" + spec_escape(v))
    None => ()
  }
  match p.corner_radius {
    Some(v) => parts.push("radius=" + double_text(v))
    None => ()
  }
  match p.font_size {
    Some(v) => parts.push("font_size=" + double_text(v))
    None => ()
  }
  match p.layout_gap {
    Some(v) => parts.push("gap=" + double_text(v))
    None => ()
  }
  let sb = StringBuilder()
  for i = 0; i < parts.length(); i = i + 1 {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string(parts[i])
  }
  sb.to_string()
}

///|
/// 从 name 中提取交互标记（"⚡..."），无则空串。
pub fn extract_interaction_marker(name : String) -> String {
  match name.find("⚡") {
    None => ""
    Some(i) => {
      let tail = name[i:name.length()].to_owned()
      // 交互标记到下一个状态标记为止
      match tail.find("[state:") {
        None => tail.trim().to_owned()
        Some(j) => tail[0:j].to_owned().trim().to_owned()
      }
    }
  }
}

///|
/// 用新的状态标记重建节点名：保留原始名与交互标记，替换全部状态标记。
pub fn rebuild_name(name : String, state_markers : Array[String]) -> String {
  let base = strip_all_markers(name)
  let inter = extract_interaction_marker(name)
  let sb = StringBuilder()
  sb.write_string(base)
  if inter != "" {
    if base != "" {
      sb.write_string(" ")
    }
    sb.write_string(inter)
  }
  for m in state_markers.iter() {
    if sb.to_string() != "" {
      sb.write_string(" ")
    }
    sb.write_string(m)
  }
  sb.to_string()
}

///|
/// 去掉节点名中的全部标记（交互 ⚡ 与状态 [state:），还原原始名。
pub fn strip_all_markers(name : String) -> String {
  let mut cut = name.length()
  match name.find("⚡") {
    Some(i) => if i < cut { cut = i }
    None => ()
  }
  match name.find("[state:") {
    Some(i) => if i < cut { cut = i }
    None => ()
  }
  match name.find("[cur:") {
    Some(i) => if i < cut { cut = i }
    None => ()
  }
  let head = name[0:cut].to_owned()
  let mut end = head.length()
  while end > 0 && head[end - 1:end].to_owned() == " " {
    end = end - 1
  }
  head[0:end].to_owned()
}

///|
/// 扫描节点名标记，重建 Project 的状态表（load 后调用）。
/// 状态定义随名字往返，但内存表需在重建 Project 后重新填充。
pub fn Project::rebuild_node_states(self : Project, artboard~ : String) -> Unit {
  let ab = match self.artboards.get(artboard) {
    Some(a) => a
    None => return
  }
  for id in ab.doc.nodes.keys() {
    match ab.doc.nodes.get(id) {
      Some(n) =>
        match parse_state_markers(n.name) {
          Some(states) => {
            let def = match self.node_states.get(id) {
              Some(d) => d
              None => { node_id: id, states: Map([]), current: "default", }
            }
            for kv in states.iter() {
              let (sname, patch) = kv
              def.states.set(sname, patch)
            }
            // [cur:<name>]：重载时恢复当前激活状态（定位转义感知——
            // 前面 state spec 的 text 值里可有 \[cur: 形态的转义文本）
            match find_unescaped_seq(n.name, 0, "[cur:") {
              Some(ci) => {
                let rest_name = n.name[ci + 5:].to_owned()
                match rest_name.find("]") {
                  Some(e) => {
                    let cname = rest_name[0:e].to_owned()
                    if cname != "" && def.states.contains(cname) {
                      def.current = cname
                    }
                  }
                  None => ()
                }
              }
              None => ()
            }
            self.node_states.set(id, def)
          }
          None => ()
        }
      None => ()
    }
  }
}

///|
/// 解析名字中的全部 [state:name:spec] 标记 → (state_name, NodePatch) 列表。
/// 标记定位转义感知（find_unescaped_seq）：spec 的 text 值经 spec_escape
/// 写入，值里的 \] / \[state: 不是结构字符。
pub fn parse_state_markers(name : String) -> Array[(String, NodePatch)]? {
  let out : Array[(String, NodePatch)] = []
  let mut rest = name
  while true {
    match find_unescaped_seq(rest, 0, "[state:") {
      None => break
      Some(i) => {
        let tail = rest[i + 7:rest.length()].to_owned()
        match find_unescaped_seq(tail, 0, "]") {
          None => break
          Some(j) => {
            let body = tail[0:j].to_owned()
            match body.find(":") {
              None => ()
              Some(k) => {
                let sname = body[0:k].to_owned()
                let spec = body[k + 1:body.length()].to_owned()
                if sname != "" {
                  out.push((sname, spec_to_patch(spec)))
                }
              }
            }
            rest = tail[j + 1:tail.length()].to_owned()
          }
        }
      }
    }
  }
  if out.length() == 0 {
    None
  } else {
    Some(out)
  }
}

///|
/// 紧凑规格 "k=v,k=v" → NodePatch（与 patch_to_spec 对称）。
fn spec_to_patch(spec : String) -> NodePatch {
  let mut fill : String? = None
  let mut text_color : String? = None
  let mut stroke : String? = None
  let mut text : String? = None
  let mut radius : Double? = None
  let mut font_size : Double? = None
  let mut gap : Double? = None
  for kv in split_commas(spec).iter() {
    match kv.find("=") {
      None => ()
      Some(eq) => {
        let k = kv[0:eq].to_owned()
        // 值反转义（text 经 spec_escape 写入；其余值不含转义字符，原样通过）
        let v = spec_unescape(kv[eq + 1:kv.length()].to_owned())
        match k {
          "fill" => fill = Some(v)
          "text_color" => text_color = Some(v)
          "stroke" => stroke = Some(v)
          "text" => text = Some(v)
          "radius" => radius = Some(parse_double(v))
          "font_size" => font_size = Some(parse_double(v))
          "gap" => gap = Some(parse_double(v))
          _ => ()
        }
      }
    }
  }
  {
    ..NodePatch::empty(),
    fill,
    text_color,
    stroke,
    text,
    corner_radius: radius,
    font_size,
    layout_gap: gap,
  }
}

///|
/// 转义感知的逗号切分：`\,` 不切（spec_escape 协议），其余逗号照切。
/// 反斜杠保留在 token 里，由调用方对值做 spec_unescape。
fn split_commas(s : String) -> Array[String] {
  let out : Array[String] = []
  let cur = StringBuilder()
  let mut esc = false
  for c in s.iter() {
    if esc {
      cur.write_char(c)
      esc = false
    } else if c == '\\' {
      cur.write_char(c)
      esc = true
    } else if c == ',' {
      out.push(cur.to_string())
      cur.reset()
    } else {
      cur.write_char(c)
    }
  }
  out.push(cur.to_string())
  out
}

///|
/// 自 start 起查找未被反斜杠转义的子串 seq 首现下标（无则 None）。
/// 状态标记 spec 的 text 值走 spec_escape 协议——裸 find 会把值里的
/// \] 当成标记收尾、\[state: 当成下一个标记，往返即截断/误读。
fn find_unescaped_seq(s : String, start : Int32, seq : String) -> Int32? {
  let n = s.length()
  let m = seq.length()
  if m == 0 || m > n {
    return None
  }
  let first = match seq.get_char(0) {
    Some(c) => c
    None => return None
  }
  let mut esc = false
  let mut i = start
  while i < n {
    match s.get_char(i) {
      Some(c) =>
        if esc {
          esc = false
        } else if c == '\\' {
          esc = true
        } else if c == first &&
          i + m <= n &&
          s[i:i + m].to_owned() == seq {
          return Some(i)
        }
      None => esc = false
    }
    i = i + 1
  }
  None
}

///|
/// 数值 → 紧凑文本（整数省略小数点，与 decl 层 num_text 视觉一致）
fn double_text(d : Double) -> String {
  if d == d.to_int().to_double() {
    d.to_int().to_string()
  } else {
    d.to_string()
  }
}

///|
/// 切换/设置节点当前状态并返回变更后的节点。
/// ToggleState：在 default 与目标状态间切换；SetState：直接设为目标状态。
pub fn Project::set_node_state(
  self : Project,
  node_id~ : String,
  state_name~ : String,
  toggle~ : Bool = false,
) -> Result[String, String] {
  let def = match self.node_states.get(node_id) {
    Some(d) => d
    None => return Err("no_states: \{node_id}")
  }
  if !def.states.contains(state_name) {
    return Err("unknown_state: \{state_name}")
  }
  let next = if toggle && def.current == state_name {
    "default"
  } else {
    state_name
  }
  def.current = next
  self.node_states.set(node_id, def)
  // current 写回节点名标记：[cur:<name>]，随 canonical MBT 往返。
  // 此前仅改内存，重载后永远回 default。
  let artboard_id = self.find_node_artboard(node_id)
  match artboard_id {
    Some(aid) =>
      match self.artboards.get(aid) {
        Some(ab) => {
          let markers = states_to_markers(def)
          if next != "default" {
            markers.push("[cur:" + next + "]")
          }
          let _ = ab.doc.update_node(node_id, fn(n) {
            { ..n, name: rebuild_name(n.name, markers), }
          })
        }
        None => ()
      }
    None => ()
  }
  self.revision = self.revision + 1
  Ok("{\"ok\":true,\"node\":\"\{node_id}\",\"current\":\"\{next}\"}")
}

///|
/// 找到节点所在的画板 id（状态表是项目级的，名字标记在画板文档里）
fn Project::find_node_artboard(self : Project, node_id : String) -> String? {
  for aid in self.artboards.keys() {
    match self.artboards.get(aid) {
      Some(ab) => if ab.doc.has(node_id) { return Some(aid) }
      None => ()
    }
  }
  None
}

///|
/// 当前状态下节点应有的补丁（default 缺省则返回空补丁）。
pub fn Project::active_state_patch(
  self : Project,
  node_id : String,
) -> NodePatch? {
  match self.node_states.get(node_id) {
    None => None
    Some(def) =>
      match def.states.get(def.current) {
        Some(p) => Some(p)
        None =>
          match def.states.get("default") {
            Some(p) => Some(p)
            None => None
          }
      }
  }
}

///|
/// 结构化回读：节点的全部已定义状态与其当前值。
pub fn Project::node_states_json(
  self : Project,
  artboard~ : String,
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard: \{artboard}")
    Some(ab) => {
      let items : Array[String] = []
      for id in ab.doc.nodes.keys() {
        match self.node_states.get(id) {
          Some(def) => {
            let names : Array[String] = []
            for s in def.states.keys() {
              names.push("\"\{s}\"")
            }
            items.push(
              "{\"node\":\"\{id}\",\"current\":\"\{def.current}\",\"states\":[\{jstr12(names)}]}",
            )
          }
          None => ()
        }
      }
      Ok("[\{jstr12(items)}]")
    }
  }
}

// ---------------------------------------------------------------------------
// 导航栈（运行时状态）
// ---------------------------------------------------------------------------

///|
pub(all) struct NavigationState {
  mut stack : Array[String] // 当前导航栈
  mut current : String // 当前画板 ID
}

///|
pub fn NavigationState::new(initial : String) -> NavigationState {
  { stack: [initial], current: initial, }
}

///|
pub fn NavigationState::navigate(
  self : NavigationState,
  target : String,
) -> String {
  self.stack.push(target)
  self.current = target
  target
}

///|
pub fn NavigationState::go_back(self : NavigationState) -> String? {
  if self.stack.length() > 1 {
    let _ = self.stack.pop()
    match self.stack.get(self.stack.length() - 1) {
      Some(top) => {
        self.current = top
        Some(top)
      }
      None => None
    }
  } else {
    None
  }
}

// ---------------------------------------------------------------------------
// 交互清单（Agent 审阅用）
// ---------------------------------------------------------------------------

///|
/// 列出画板的所有交互定义（从节点名解析）
pub fn Project::list_interactions(
  self : Project,
  artboard~ : String,
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard")
    Some(ab) => {
      let items : Array[String] = []
      for id in ab.doc.nodes.keys() {
        match ab.doc.nodes.get(id) {
          Some(n) =>
            if n.name.contains("⚡") {
              // id/name/artboard 过 json_escape（与 query_node_json 同一
              // 约定）：update name= 值可含字面双引号，裸插值产出非法
              // JSON 信封（issue #10 同类事故源）
              items.push(
                "{\"node\":\"\{json_escape(id)}\",\"name\":\"\{json_escape(n.name)}\",\"artboard\":\"\{json_escape(artboard)}\"}",
              )
            }
          None => ()
        }
      }
      // 内置返回热区：back-like 节点即使无 ⚡ 标记也导出（runtime 对其 tap
      // 有内置返回兜底）——宿主据此绘制热区，无需各自维护启发式
      for id in ab.doc.nodes.keys() {
        match ab.doc.nodes.get(id) {
          Some(n) =>
            if !n.name.contains("⚡") && is_back_like_node(n) {
              items.push(
                "{\"node\":\"\{json_escape(id)}\",\"name\":\"\{json_escape(n.name)}\",\"artboard\":\"\{json_escape(artboard)}\",\"builtin\":\"back\"}",
              )
            }
          None => ()
        }
      }
      let j = jstr12(items)
      Ok("[\{j}]")
    }
  }
}

///|
fn jstr12(parts : Array[String]) -> String {
  let sb = StringBuilder()
  for i in 0..<parts.length() {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string(parts[i])
  }
  sb.to_string()
}

// ---------------------------------------------------------------------------
// 交互标记解析（运行时消费 / CLI 构造共用）
// ---------------------------------------------------------------------------

///|
/// 从节点名提取交互标记 → (trigger, action_spec)。
/// 标记由 add_interaction 追加，格式 "…⚡<trigger>→<action>"。
/// 用字符迭代 + ASCII 白名单提取 trigger，避免多字节 emoji 的字节偏移歧义。
pub fn parse_interaction_marker(name : String) -> (String, String)? {
  let before = StringBuilder()
  let seen_arrow : Ref[Bool] = Ref(false)
  let after = StringBuilder()
  for c in name.iter() {
    if c == '→' {
      seen_arrow.val = true
      continue
    }
    if seen_arrow.val {
      after.write_char(c)
    } else {
      before.write_char(c)
    }
  }
  if !seen_arrow.val {
    return None
  }
  // trigger = 箭头前最后一个空白分隔 token 中的 ASCII 标识符部分
  let chars : Array[Char] = []
  for c in before.to_string().iter() {
    chars.push(c)
  }
  let mut last_space = -1
  for i = 0; i < chars.length(); i = i + 1 {
    if chars[i] == ' ' || chars[i] == '\t' {
      last_space = i
    }
  }
  let trig = StringBuilder()
  for i = last_space + 1; i < chars.length(); i = i + 1 {
    let c = chars[i]
    if (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') ||
      c == '_' {
      trig.write_char(c)
    }
  }
  let t = trig.to_string()
  // action 到下一个状态标记为止：交互与状态标记共存于同一 name，
  // 不截断会把 "[state:...]" 当成 action 的一部分。
  let raw_after = after.to_string()
  let a = match raw_after.find("[state:") {
    Some(i) => raw_after[0:i].to_owned().trim().to_owned()
    None => raw_after.trim().to_owned()
  }
  if t == "" || a == "" {
    return None
  }
  Some((t, a))
}

///|
/// trigger 规格 → Trigger（CLI / Agent 语法共用）。
/// 别名与 Trigger::name 保持一致；keyboard_enter 接受 key_enter 简写；
/// long_press 可带时长（"long_press:0.8"，缺省 0.5s）。
pub fn trigger_from_spec(spec : String) -> Trigger? {
  match spec {
    "tap" => Some(Tap)
    "long_press" => Some(LongPress(0.5))
    "swipe_left" => Some(SwipeLeft)
    "swipe_right" => Some(SwipeRight)
    "swipe_up" => Some(SwipeUp)
    "swipe_down" => Some(SwipeDown)
    "scroll_end" => Some(ScrollEnd)
    "key_enter" | "keyboard_enter" => Some(KeyboardEnter)
    "focus" => Some(Focus)
    "blur" => Some(Blur)
    _ =>
      // 仅 long_press 有参形态；其余带冒号的 spec 不在此接受
      match spec.find(":") {
        None => None
        Some(i) => {
          let head = spec[0:i].to_owned()
          let rest = spec[i + 1:spec.length()].to_owned()
          if head == "long_press" && rest != "" {
            let sec = parse_double(rest)
            if sec > 0.0 {
              Some(LongPress(sec))
            } else {
              None
            }
          } else {
            None
          }
        }
      }
  }
}

///|
/// flow trigger 规范化（.mbt.md flows / flow op / CLI 共用）：
/// - `tap:<node>` 原样；裸词若不在手势词表内按节点 id 兼容旧写法
///   （`<node>` → `tap:<node>`）；
/// - `swipe_left/swipe_right/swipe_up/swipe_down`、`long_press[:秒]`、
///   `scroll_end`、`keyboard_enter/key_enter` 取规范形；
/// - `focus:<node>` / `blur:<node>` 保留节点后缀；
/// - 带冒号但头不在已知触发族 → Err(unknown_trigger: …)。
pub fn normalize_flow_trigger(spec : String) -> Result[String, String] {
  let raw = spec.trim().to_owned()
  if raw == "" {
    return Err("unknown_trigger: ")
  }
  if raw.has_prefix("tap:") {
    let node = raw[4:].to_owned()
    if node == "" {
      return Err("unknown_trigger: " + raw)
    }
    return Ok(raw)
  }
  // 裸 long_press = 任意时长（flow 语义）；带秒数的走 trigger_from_spec
  if raw == "long_press" {
    return Ok(raw)
  }
  match trigger_from_spec(raw) {
    Some(t) => return Ok(t.spec())
    None => ()
  }
  match raw.find(":") {
    Some(i) => {
      let head = raw[0:i].to_owned()
      let node = raw[i + 1:raw.length()].to_owned()
      if node == "" {
        return Err("unknown_trigger: " + raw)
      }
      if head == "focus" || head == "blur" {
        return Ok(head + ":" + node)
      }
      Err("unknown_trigger: " + raw)
    }
    // 无冒号且不在手势词表：按旧写法视作节点 id（tap:<node>）
    None => Ok("tap:" + raw)
  }
}

///|
/// action 规格 → Action。规格语法与 Action::describe 的输出对称：
///   back | haptic | navigate_to:<board> | show_toast:"msg" | play_sound:<name>
///   | toggle_state:<node> | set_state:<node>:<state> | set_text:<node>:"text"
///   | submit_form:<field>,<field>…
pub fn action_from_spec(spec : String) -> Action? {
  match spec {
    "back" => Some(Back)
    "haptic" => Some(HapticFeedback)
    _ =>
      match spec.find(":") {
        None => None
        Some(i) => {
          let head = spec[0:i].to_owned()
          let rest = spec[i + 1:spec.length()].to_owned()
          match head {
            "navigate_to" =>
              if rest == "" {
                None
              } else {
                Some(NavigateTo(rest))
              }
            "show_toast" =>
              if rest == "" {
                None
              } else {
                Some(ShowToast(unquote_spec(rest)))
              }
            "play_sound" =>
              if rest == "" {
                None
              } else {
                Some(PlaySound(rest))
              }
            "submit_form" =>
              // 旧 describe 的 `[N fields]` 占位没有可执行字段——按非法
              // spec 处理（旧文档里该动效本来就未被导出，不做伪绑定）
              if rest.has_prefix("[") && rest.has_suffix(" fields]") {
                None
              } else {
                // 字段 id 列表（逗号分隔；空项忽略）。无字段 = 非法 spec。
                let ids : Array[String] = []
                for seg in rest.split(",") {
                  let id = seg.to_owned().trim().to_owned()
                  if id != "" {
                    ids.push(id)
                  }
                }
                if ids.length() == 0 {
                  None
                } else {
                  Some(SubmitForm(ids))
                }
              }
            "toggle_state" =>
              if rest == "" {
                None
              } else {
                Some(ToggleState(rest, ""))
              }
            "set_text" =>
              match rest.find(":") {
                None => None
                Some(j) => {
                  let id = rest[0:j].to_owned()
                  let txt = rest[j + 1:rest.length()].to_owned()
                  if id == "" {
                    None
                  } else {
                    Some(SetText(id, unquote_spec(txt)))
                  }
                }
              }
            "set_state" =>
              match rest.find(":") {
                None => None
                Some(j) => {
                  let id = rest[0:j].to_owned()
                  let st = rest[j + 1:rest.length()].to_owned()
                  if id == "" {
                    None
                  } else {
                    Some(SetState(id, st))
                  }
                }
              }
            _ => None
          }
        }
      }
  }
}

///|
/// 去掉规格值两端的双引号（show_toast:"msg" / set_text:n:"txt"）。
fn unquote_spec(s : String) -> String {
  if s.length() >= 2 &&
    s[0:1].to_owned() == "\"" &&
    s[s.length() - 1:s.length()].to_owned() == "\"" {
    s[1:s.length() - 1].to_owned()
  } else {
    s
  }
}

// ---------------------------------------------------------------------------
// 交互词表清单（CLI interaction-manifest / 一致性脚本的单一来源）
// ---------------------------------------------------------------------------

///|
/// 词表 manifest：triggers 为 trigger_from_spec 接受的规范名（与
/// Trigger::name 同源），actions 为 Action::kind 全集。
/// supported_in_export 表示导出运行时有对应绑定分支（由
/// scripts/check-interaction-parity.mjs 对 core/export.mbt 做文本锁步）。
pub fn interaction_manifest_json() -> String {
  let triggers : Array[String] = []
  for
    t in [
      Tap,
      LongPress(0.5),
      SwipeLeft,
      SwipeRight,
      SwipeUp,
      SwipeDown,
      ScrollEnd,
      KeyboardEnter,
      Focus,
      Blur,
    ].iter() {
    triggers.push("\"" + t.name() + "\"")
  }
  let action_list : Array[String] = []
  let actions : Array[Action] = [
    NavigateTo(""),
    Back,
    ToggleState("", ""),
    SetState("", ""),
    SetText("", ""),
    SubmitForm([]),
    ShowToast(""),
    HapticFeedback,
    PlaySound(""),
  ]
  for a in actions.iter() {
    action_list.push(
      "{\"kind\":\"" + a.kind() + "\",\"supported_in_export\":true}",
    )
  }
  "{\"ok\":true,\"version\":2,\"triggers\":[" +
  triggers.join(",") +
  "],\"actions\":[" +
  action_list.join(",") +
  "]}"
}

///|
/// 追加交互标记到节点名（幂等：同名标记不重复追加）。
///
/// 词表闸门：trigger/action 必须先通过 trigger_from_spec / action_from_spec
/// ——此前原样写标记，`nonsense:xyz` 这类非法 spec 会静默落盘，运行时才
/// 发现解析失败（写入成功、执行无效的半契约）。合法值统一规范化为
/// Trigger::name / Action::describe 形态，标记因此可稳定反解析。
pub fn Project::attach_interaction(
  self : Project,
  artboard~ : String,
  node_id~ : String,
  trigger~ : String,
  action_spec~ : String,
) -> Result[String, String] {
  let ab = match self.artboards.get(artboard) {
    Some(a) => a
    None => return Err("unknown_artboard: \{artboard}")
  }
  let node = match ab.doc.nodes.get(node_id) {
    Some(n) => n
    None => return Err("unknown_node: \{node_id}")
  }
  let parsed_trigger = match trigger_from_spec(trigger) {
    Some(t) => t
    None => return Err("unknown_trigger: " + trigger)
  }
  let parsed_action = match action_from_spec(action_spec) {
    Some(a) => a
    None => return Err("unknown_action: " + action_spec)
  }
  let trigger_name = parsed_trigger.name()
  let action_norm = parsed_action.describe()
  let marker = "⚡\{trigger_name}→\{action_norm}"
  if node.name.contains(marker) {
    return Ok(
      "{\"ok\":true,\"node\":\"\{json_escape(node_id)}\",\"unchanged\":true}",
    )
  }
  // 先清理旧标记，保证一个节点只有一个生效交互且标记不累积
  let base = strip_markers(node.name)
  let updated = if base == "" { marker } else { base + " " + marker }
  let _ = ab.doc.update_node(node_id, fn(n) { { ..n, name: updated, } })
  self.revision = self.revision + 1
  Ok(
    "{\"ok\":true,\"node\":\"\{json_escape(node_id)}\",\"trigger\":\"\{json_escape(trigger_name)}\",\"action\":\"\{json_escape(action_norm)}\"}",
  )
}

///|
/// 移除节点名的全部交互标记（保留原始名）。
pub fn Project::detach_interaction(
  self : Project,
  artboard~ : String,
  node_id~ : String,
) -> Result[String, String] {
  let ab = match self.artboards.get(artboard) {
    Some(a) => a
    None => return Err("unknown_artboard: \{artboard}")
  }
  let node = match ab.doc.nodes.get(node_id) {
    Some(n) => n
    None => return Err("unknown_node: \{node_id}")
  }
  let base = strip_markers(node.name)
  let _ = ab.doc.update_node(node_id, fn(n) { { ..n, name: base, } })
  self.revision = self.revision + 1
  Ok("{\"ok\":true,\"node\":\"\{node_id}\",\"cleared\":true}")
}

///|
/// 去掉名称里的交互标记（含 marker 与其前的分隔空格）。
pub fn strip_markers(name : String) -> String {
  let idx = name.find("⚡")
  match idx {
    None => name
    Some(i) => {
      let head = name[0:i].to_owned()
      // 修剪标记前遗留的尾随空格
      let mut end = head.length()
      while end > 0 && head[end - 1:end].to_owned() == " " {
        end = end - 1
      }
      head[0:end].to_owned()
    }
  }
}

///|
/// 结构化交互清单 v2：解析标记 → 词表化字段（供 Agent 审阅、宿主热区与
/// 一致性脚本消费）。
///
/// 每项契约：{node, name, artboard, trigger, action:{kind,params},
/// action_spec, transition, source, supported}。
/// - action.kind 为 Action::kind 的稳定标识，params 为结构化参数 JSON；
/// - action_spec 保留原始 spec 字符串（v1 读取方过渡用）；
/// - transition 暂为空串（P5 分板过渡包填充）；
/// - source = "marker" | "builtin"（返回类节点内置 tap→back 兜底）；
/// - supported = 导出运行时是否有该绑定（非 tap 标记当前不导出）。
/// 所有 id/name/trigger/参数值一律 json_escape（节点名可含字面引号）。
pub fn Project::interactions_json(
  self : Project,
  artboard~ : String,
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard: \{artboard}")
    Some(ab) => {
      let items : Array[String] = []
      for id in ab.doc.nodes.keys() {
        match ab.doc.nodes.get(id) {
          Some(n) =>
            match parse_interaction_marker(n.name) {
              Some((trig, spec)) => {
                let (kind, params, supported) = match action_from_spec(spec) {
                  Some(act) =>
                    (
                      act.kind(),
                      act.params_json(),
                      trig == "tap", // 导出运行时目前只绑 tap
                    )
                  None => ("unknown", "{}", false)
                }
                items.push(
                  "{\"node\":\"" +
                  json_escape(id) +
                  "\",\"name\":\"" +
                  json_escape(n.name) +
                  "\",\"artboard\":\"" +
                  json_escape(artboard) +
                  "\",\"trigger\":\"" +
                  json_escape(trig) +
                  "\",\"action\":{\"kind\":\"" +
                  kind +
                  "\",\"params\":" +
                  params +
                  "},\"action_spec\":\"" +
                  json_escape(spec) +
                  "\",\"transition\":\"\",\"source\":\"marker\",\"supported\":" +
                  (if supported { "true" } else { "false" }) +
                  "}",
                )
              }
              None => ()
            }
          None => ()
        }
      }
      // 内置返回热区：back-like 节点即使无 ⚡ 标记也导出（runtime 对其 tap
      // 有内置返回兜底）——宿主据此绘制热区/点击，无需各自维护启发式
      for id in ab.doc.nodes.keys() {
        match ab.doc.nodes.get(id) {
          Some(n) =>
            if !n.name.contains("⚡") && is_back_like_node(n) {
              items.push(
                "{\"node\":\"" +
                json_escape(id) +
                "\",\"name\":\"" +
                json_escape(n.name) +
                "\",\"artboard\":\"" +
                json_escape(artboard) +
                "\",\"trigger\":\"tap\",\"action\":{\"kind\":\"back\",\"params\":{}},\"action_spec\":\"back\",\"transition\":\"\",\"source\":\"builtin\",\"supported\":true}",
              )
            }
          None => ()
        }
      }
      Ok("[\{jstr12(items)}]")
    }
  }
}
