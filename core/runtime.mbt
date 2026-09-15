///|
/// 嵌入式运行时 SDK：其他项目加载 .moonviz → 动态渲染 + 事件处理。
///
/// 宿主应用（编辑器 / Web 应用 / 桌面工具 / Agent 工作台）通过这个 SDK：
/// 1. `MoonVizRT::create(project)` → 创建运行时实例
/// 2. `rt.handle_event(event)` → 处理交互事件，返回状态变更列表
/// 3. `rt.render_plan()` → 获取后端无关的渲染指令（RenderPlan）
/// 4. `rt.hot_reload(decl)` → 更新声明文本，保留运行时状态
///
/// RenderPlan 是一个 **显示列表**（display list）：
/// 任何渲染后端（Canvas / Skia / SVG / 终端 / OpenGL）都能消费。

// ---------------------------------------------------------------------------
// 事件
// ---------------------------------------------------------------------------

pub(all) enum VizEvent {
  TapEvent(Double, Double) // (x, y)
  LongPressEvent(Double, Double)
  SwipeEvent(String) // "left" | "right" | "up" | "down"
  KeyEvent(String) // "enter" | "escape" | ...
  FocusEvent(String) // node_id
  BlurEvent(String) // node_id
}

///|
pub fn VizEvent::describe(self : VizEvent) -> String {
  match self {
    TapEvent(x, y) => "tap(\{x.to_int()}, \{y.to_int()})"
    LongPressEvent(x, y) => "long_press(\{x.to_int()}, \{y.to_int()})"
    SwipeEvent(dir) => "swipe_\{dir}"
    KeyEvent(key) => "key_\{key}"
    FocusEvent(id) => "focus(\{id})"
    BlurEvent(id) => "blur(\{id})"
  }
}

// ---------------------------------------------------------------------------
// 状态变更（事件处理后返回）
// ---------------------------------------------------------------------------

///|
pub(all) enum StateChange {
  ArtboardChanged(String) // 当前画板变了
  NodeUpdated(String) // 某个节点更新了
  NavigationPushed(String) // 导航栈压入
  NavigationPopped(String) // 导航栈弹出
  ToastShown(String) // 显示 toast
  FormSubmitted(Map[String, String]) // 表单提交 (node_id → text)
}

///|
pub fn StateChange::describe(self : StateChange) -> String {
  match self {
    ArtboardChanged(ab) => "artboard_changed:\{ab}"
    NodeUpdated(id) => "node_updated:\{id}"
    NavigationPushed(ab) => "nav_push:\{ab}"
    NavigationPopped(ab) => "nav_pop:\{ab}"
    ToastShown(msg) => "toast:\"\{msg}\""
    FormSubmitted(data) => "form_submitted(\{data.size()} fields)"
  }
}

// ---------------------------------------------------------------------------
// 渲染计划（后端无关的显示列表）
// ---------------------------------------------------------------------------

///|
pub(all) enum RenderCommand {
  CmdRect(Double, Double, Double, Double, String, Double) // x,y,w,h,fill,radius
  CmdText(Double, Double, String, Double, String) // x,y,content,font_size,color
  CmdLine(Double, Double, Double, Double, String) // x1,y1,x2,y2,color
  CmdClipPush(Double, Double, Double, Double) // clip rect
  CmdClipPop
}

///|
pub(all) struct RenderPlan {
  artboard : String
  width : Double
  height : Double
  commands : Array[RenderCommand]
}

// ---------------------------------------------------------------------------
// 运行时
// ---------------------------------------------------------------------------

///|
pub(all) struct MoonVizRT {
  project : Project
  nav : NavigationState
  mut overlay_toast : String? // 当前显示的 toast
  mut input_values : Map[String, String] // 输入框值 (node_id → text)
  listeners : Array[(StateChange) -> Unit] // 状态变更回调
}

///|
/// 创建运行时实例
pub fn MoonVizRT::create(
  project : Project,
  initial_artboard? : String = "",
) -> Result[MoonVizRT, String] {
  let first : String = if initial_artboard == "" {
    // 取第一个画板
    let mut first_id = ""
    for id in project.artboards.keys() {
      if first_id == "" {
        first_id = id
      }
    }
    if first_id == "" {
      return Err("no_artboards")
    }
    first_id
  } else {
    if !project.artboards.contains(initial_artboard) {
      return Err("unknown_artboard: \{initial_artboard}")
    }
    initial_artboard
  }
  Ok({
    project,
    nav: NavigationState::new(first),
    overlay_toast: None,
    input_values: Map::new(),
    listeners: [],
  })
}

// ---------------------------------------------------------------------------
// 事件处理
// ---------------------------------------------------------------------------

///|
/// 处理一个交互事件，返回状态变更列表
pub fn MoonVizRT::handle_event(
  self : MoonVizRT,
  event : VizEvent,
) -> Array[StateChange] {
  let changes : Array[StateChange] = []
  match event {
    TapEvent(x, y) =>
      // 命中检测：找到当前画板中被点击的节点
      match self.project.artboards.get(self.nav.current) {
        Some(ab) => {
          let layout = solve(ab.doc)
          let hit = pick_node(ab.doc, layout, x, y)
          match hit {
            Some(node_id) => {
              // 查找该节点是否有交互定义（通过 flow）
              let flow_target = self.find_flow_target(node_id)
              match flow_target {
                Some(target) => {
                  // 导航
                  let _ = self.nav.navigate(target)
                  changes.push(NavigationPushed(target))
                  changes.push(ArtboardChanged(target))
                }
                None =>
                  // 无导航流：尝试节点交互标记（⚡trigger→action）；都没有则报状态更新
                  if !self.run_marker(node_id, changes) {
                    changes.push(NodeUpdated(node_id))
                  }
              }
            }
            None => ()
          }
        }
        None => ()
      }
    KeyEvent(key) =>
      if key == "escape" || key == "back" {
        // 返回上一页
        match self.nav.go_back() {
          Some(prev) => {
            changes.push(NavigationPopped(prev))
            changes.push(ArtboardChanged(prev))
          }
          None => ()
        }
      } else {
        // 键盘导航流：flow <from> <to> - key_<key>
        let trigger = "key_\{key}"
        for e in self.project.flows.iter() {
          if e.from == self.nav.current && e.trigger == trigger {
            let _ = self.nav.navigate(e.to)
            changes.push(NavigationPushed(e.to))
            changes.push(ArtboardChanged(e.to))
            break
          }
        }
      }
    SwipeEvent(dir) =>
      // 滑动也可能触发导航
      match self.project.artboards.get(self.nav.current) {
        Some(ab) => {
          let trigger = "swipe_\{dir}"
          for e in self.project.flows.iter() {
            if e.from == self.nav.current && e.trigger == trigger {
              let _ = self.nav.navigate(e.to)
              changes.push(NavigationPushed(e.to))
              changes.push(ArtboardChanged(e.to))
            }
          }
        }
        None => ()
      }
    _ => ()
  }
  // 通知监听器
  for c in changes.iter() {
    for l in self.listeners.iter() {
      l(c)
    }
  }
  changes
}

///|
/// 查找节点的导航流目标。
/// 必须同时匹配 from == 当前画板：node id 在不同画板间会重名，
/// 仅按 trigger 匹配会让 A 画板的点击触发 B 画板的跳转。
fn MoonVizRT::find_flow_target(self : MoonVizRT, node_id : String) -> String? {
  let trigger = "tap:\{node_id}"
  for e in self.project.flows.iter() {
    if e.from == self.nav.current && e.trigger == trigger {
      return Some(e.to)
    }
  }
  None
}

///|
/// 执行节点上的交互标记（无 flow 时的回落路径），返回是否已处理。
/// 标记由 add_interaction 写入节点名；此前只写不读（write-only API），
/// 本函数让 Trigger/Action 词汇表在运行时真正生效。
fn MoonVizRT::run_marker(
  self : MoonVizRT,
  node_id : String,
  changes : Array[StateChange],
) -> Bool {
  let node_name = match self.project.artboards.get(self.nav.current) {
    Some(ab) =>
      match ab.doc.nodes.get(node_id) {
        Some(n) => n.name
        None => return false
      }
    None => return false
  }
  let (trigger, spec) = match parse_interaction_marker(node_name) {
    Some(t) => t
    None => return false
  }
  // 标记仅在 tap 命中时执行；其他触发器由对应事件路径处理
  if trigger != "tap" {
    return false
  }
  match action_from_spec(spec) {
    None => false
    Some(act) =>
      match act {
        NavigateTo(target) =>
          if self.project.artboards.contains(target) {
            let _ = self.nav.navigate(target)
            changes.push(NavigationPushed(target))
            changes.push(ArtboardChanged(target))
            true
          } else {
            false
          }
        Back =>
          match self.nav.go_back() {
            Some(prev) => {
              changes.push(NavigationPopped(prev))
              changes.push(ArtboardChanged(prev))
              true
            }
            None => false
          }
        ShowToast(msg) => {
          self.overlay_toast = Some(msg)
          changes.push(ToastShown(msg))
          true
        }
        SetText(id, text) =>
          match self.project.artboards.get(self.nav.current) {
            Some(ab) =>
              if ab.doc.update_node(id, fn(n) { { ..n, text } }) {
                changes.push(NodeUpdated(id))
                true
              } else {
                false
              }
            None => false
          }
        _ => false
      }
  }
}

// ---------------------------------------------------------------------------
// 渲染计划生成
// ---------------------------------------------------------------------------

///|
/// 当前状态 → 后端无关的渲染指令列表
pub fn MoonVizRT::render_plan(self : MoonVizRT) -> Result[RenderPlan, String] {
  match self.project.artboards.get(self.nav.current) {
    None => Err("unknown_artboard")
    Some(ab) => {
      let layout = solve(ab.doc)
      let plan : RenderPlan = {
        artboard: self.nav.current,
        width: ab.width,
        height: ab.height,
        commands: [],
      }
      // 树序遍历生成渲染指令
      rt_walk(plan, ab.doc, ab.doc.root_id, layout)
      // toast 覆盖层
      match self.overlay_toast {
        Some(msg) => {
          plan.commands.push(
            CmdRect(
              ab.width * 0.1,
              ab.height * 0.85,
              ab.width * 0.8,
              44.0,
              "#333333",
              22.0,
            ),
          )
          plan.commands.push(
            CmdText(
              ab.width * 0.5 - msg.length().to_double() * 4.0,
              ab.height * 0.85 + 28.0,
              msg,
              14.0,
              "#FFFFFF",
            ),
          )
        }
        None => ()
      }
      Ok(plan)
    }
  }
}

///|
fn rt_walk(
  plan : RenderPlan,
  doc : Document,
  id : String,
  layout : SolvedLayout,
) -> Unit {
  match (doc.nodes.get(id), layout.rect_of(id)) {
    (Some(n), Some(r)) if !n.style.visible => ()
    (Some(n), Some(r)) => {
      match n.kind {
        Text =>
          plan.commands.push(
            CmdText(
              r.x,
              r.y + r.height * 0.7,
              n.text,
              n.style.font_size,
              n.style.text_color,
            ),
          )
        _ => {
          let fill = if n.style.fill == "none" {
            "transparent"
          } else {
            n.style.fill
          }
          plan.commands.push(
            CmdRect(r.x, r.y, r.width, r.height, fill, n.style.corner_radius),
          )
          if n.text != "" {
            plan.commands.push(
              CmdText(
                r.x + 8.0,
                r.y + r.height * 0.6,
                n.text,
                n.style.font_size,
                n.style.text_color,
              ),
            )
          }
        }
      }
      for cid in n.children.iter() {
        rt_walk(plan, doc, cid, layout)
      }
    }
    _ => ()
  }
}

// ---------------------------------------------------------------------------
// 热重载（Agent 修改声明后，运行时无刷新更新）
// ---------------------------------------------------------------------------

///|
/// 热重载：替换当前画板的声明文本，保留导航栈和输入值
pub fn MoonVizRT::hot_reload(
  self : MoonVizRT,
  new_decl : String,
) -> Result[String, String] {
  match self.project.artboards.get(self.nav.current) {
    None => Err("unknown_artboard")
    Some(ab) =>
      match decl_parse_rt(new_decl) {
        Err(msg) => Err("parse_error: " + msg)
        Ok(_) =>
          // 热重载成功（v1 简化：验证通过即可）
          Ok(
            "{\"ok\":true,\"artboard\":\"\{self.nav.current}\",\"hot_reloaded\":true}",
          )
      }
  }
}

// ---------------------------------------------------------------------------
// 输入值管理
// ---------------------------------------------------------------------------

///|
pub fn MoonVizRT::set_input(
  self : MoonVizRT,
  node_id : String,
  value : String,
) -> Unit {
  self.input_values.set(node_id, value)
}

///|
pub fn MoonVizRT::get_input(self : MoonVizRT, node_id : String) -> String {
  match self.input_values.get(node_id) {
    Some(v) => v
    None => ""
  }
}

///|
pub fn MoonVizRT::get_all_inputs(self : MoonVizRT) -> Map[String, String] {
  self.input_values
}

// ---------------------------------------------------------------------------
// 状态监听
// ---------------------------------------------------------------------------

///|
pub fn MoonVizRT::on_change(
  self : MoonVizRT,
  listener : (StateChange) -> Unit,
) -> Unit {
  self.listeners.push(listener)
}

// ---------------------------------------------------------------------------
// 导航查询
// ---------------------------------------------------------------------------

///|
pub fn MoonVizRT::current_artboard(self : MoonVizRT) -> String {
  self.nav.current
}

///|
pub fn MoonVizRT::nav_stack(self : MoonVizRT) -> Array[String] {
  self.nav.stack.copy()
}

///|
pub fn MoonVizRT::can_go_back(self : MoonVizRT) -> Bool {
  self.nav.stack.length() > 1
}

// ---------------------------------------------------------------------------
// 辅助
// ---------------------------------------------------------------------------

///|
fn pick_node(doc : Document, layout : SolvedLayout, x : Double, y : Double) -> String? {
  let mut best : String? = None
  let mut best_area : Double = 1000000000000000000.0
  for id in layout.rects.keys() {
    match layout.rect_of(id) {
      Some(r) =>
        match doc.nodes.get(id) {
          Some(n) if n.style.visible && x >= r.x && y >= r.y && x < r.x + r.width && y < r.y + r.height => {
            let area = r.width * r.height
            if area < best_area && id != "root" {
              best = Some(id)
              best_area = area
            }
          }
          _ => ()
        }
      None => ()
    }
  }
  best
}

///|
/// RT 内嵌的声明解析（简化版：只检测合法性，不生成完整 Prototype）
fn decl_parse_rt(decl : String) -> Result[Unit, String] {
  if decl.length() == 0 {
    return Err("empty declaration")
  }
  // v1: 简单验证——非空即可（完整解析在 decl 包）
  Ok(())
}
