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
    SubmitForm(ids) => "submit_form:[\{ids.length()} fields]"
    ShowToast(msg) => "show_toast:\"\{msg}\""
    HapticFeedback => "haptic"
    PlaySound(name) => "play_sound:\{name}"
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

// ---------------------------------------------------------------------------
// 交互定义
// ---------------------------------------------------------------------------

///|
pub(all) struct InteractionDef {
  node_id : String // 触发交互的节点
  trigger : Trigger // 触发条件
  action : Action // 执行动作
  transition : Transition // 页面转场方式
}

///|
/// 组件多态（同一组件的不同视觉状态）
pub(all) struct ComponentStateDef {
  node_id : String
  states : Map[String, NodePatch] // "default" → base, "pressed" → darker fill...
  current : String
}

// ---------------------------------------------------------------------------
// 交互注册与管理
// ---------------------------------------------------------------------------

///|
/// 为节点添加交互定义
pub fn Project::add_interaction(
  self : Project,
  artboard~ : String,
  node_id~ : String,
  trigger~ : Trigger,
  action~ : Action,
  transition? : Transition = Push,
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard")
    Some(ab) => {
      if !ab.doc.has(node_id) {
        return Err("unknown_node: \{node_id}")
      }
      let inter : InteractionDef = { node_id, trigger, action, transition }
      match ab.doc.nodes.get(node_id) {
        Some(n) => {
          // 把交互信息序列化到节点的 metadata（v1：存 text 前缀标记）
          let marker = "⚡\{trigger.name()}→\{action.describe()}"
          let _ = ab.doc.update_node(node_id, fn(x) {
            { ..x, name: "\{x.name} \{marker}" }
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
/// 为组件定义多态状态
pub fn Project::define_component_state(
  self : Project,
  artboard~ : String,
  node_id~ : String,
  state_name~ : String,
  patch~ : NodePatch,
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard")
    Some(ab) => {
      if !ab.doc.has(node_id) {
        return Err("unknown_node: \{node_id}")
      }
      // v1: 将状态信息编码到节点名（简化存储）
      let marker = "[state:\{state_name}]"
      let _ = ab.doc.update_node(node_id, fn(x) {
        { ..x, name: "\{x.name}\{marker}" }
      })
      Ok("{\"ok\":true,\"state\":\"\{node_id}:\{state_name}\"}")
    }
    None => Err("unknown_artboard")
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
  { stack: [initial], current: initial }
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
              items.push(
                "{\"node\":\"\{id}\",\"name\":\"\{n.name}\",\"artboard\":\"\{artboard}\"}",
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
  let sb = StringBuilder::new()
  for i in 0..<parts.length() {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string(parts[i])
  }
  sb.to_string()
}
