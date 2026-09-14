///|
/// 组件插槽系统：支持嵌套内容分发的组合式组件。
///
/// 这是让组件真正**可组合**的原语——像 React/Vue 的 children/slots：
/// ```jsx
/// <Card>
///   <CardHeader>Title</CardHeader>
///   <CardContent>Body</CardContent>
/// </Card>
/// ```
/// MoonViz 等价：
/// ```moonbit nocheck
/// p.place_component("card", "my_card")
/// p.fill_slot("my_card", "header", "Title")
/// p.fill_slot("my_card", "content", "Body text here")
/// ```
///
/// - 槽位定义：组件声明命名槽位
/// - 槽位填充：Agent 把内容放进指定槽位
/// - 默认内容：槽位为空时使用默认值
/// - 组合组件：槽位里可以放其他组件（递归组合）

// ---------------------------------------------------------------------------
// 槽位定义
// ---------------------------------------------------------------------------

pub(all) struct SlotDef {
  name : String // "header" / "content" / "footer"
  description : String // Agent 可读的槽位说明
  accepts : Array[String] // 接受的组件类型（空 = 任意）
  default_content : String // 默认内容（空串 = 无默认）
}

///|
pub(all) struct SlottedComponent {
  component_id : String // "card" / "list" / "form" / "modal"
  display_name : String
  slots : Array[SlotDef]
  layout : StackLayout // 槽位如何排列
  base_style : NodeStyle
}

// ---------------------------------------------------------------------------
// 内置组合式组件
// ---------------------------------------------------------------------------

///|
pub fn builtin_slotted_components() -> Map[String, SlottedComponent] {
  let m : Map[String, SlottedComponent] = Map::new()

  // ── Card：header + content + footer ──
  m.set("card", {
    component_id: "card",
    display_name: "卡片",
    slots: [
      {
        name: "header",
        description: "卡片头部（标题/头像）",
        accepts: [],
        default_content: "Title",
      },
      {
        name: "content",
        description: "卡片正文内容",
        accepts: [],
        default_content: "",
      },
      {
        name: "footer",
        description: "卡片底部（操作按钮）",
        accepts: [],
        default_content: "",
      },
    ],
    layout: {
      dir: Vertical,
      gap: 8.0,
      justify: Start,
      padding: { top: 16.0, right: 16.0, bottom: 16.0, left: 16.0 },
    },
    base_style: { ..NodeStyle::default(), fill: "#FFFFFF", corner_radius: 12.0 },
  })

  // ── List：可变数量 item 槽 ──
  m.set("list", {
    component_id: "list",
    display_name: "列表",
    slots: [
      {
        name: "header",
        description: "列表标题",
        accepts: [],
        default_content: "List",
      },
      {
        name: "item_1",
        description: "列表项 1",
        accepts: [],
        default_content: "Item 1",
      },
      {
        name: "item_2",
        description: "列表项 2",
        accepts: [],
        default_content: "Item 2",
      },
      {
        name: "item_3",
        description: "列表项 3",
        accepts: [],
        default_content: "Item 3",
      },
    ],
    layout: {
      dir: Vertical,
      gap: 4.0,
      justify: Start,
      padding: { top: 8.0, right: 8.0, bottom: 8.0, left: 8.0 },
    },
    base_style: { ..NodeStyle::default(), fill: "#FFFFFF" },
  })

  // ── Form：label + input + error ──
  m.set("form_field", {
    component_id: "form_field",
    display_name: "表单字段",
    slots: [
      {
        name: "label",
        description: "字段标签",
        accepts: [],
        default_content: "Label",
      },
      {
        name: "input",
        description: "输入框",
        accepts: ["text_input"],
        default_content: "",
      },
      {
        name: "error",
        description: "错误提示（可选）",
        accepts: [],
        default_content: "",
      },
    ],
    layout: {
      dir: Vertical,
      gap: 4.0,
      justify: Start,
      padding: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
    },
    base_style: NodeStyle::default(),
  })

  // ── Modal：title + content + actions ──
  m.set("modal", {
    component_id: "modal",
    display_name: "模态框",
    slots: [
      {
        name: "title",
        description: "弹窗标题",
        accepts: [],
        default_content: "Dialog",
      },
      {
        name: "content",
        description: "弹窗内容",
        accepts: [],
        default_content: "",
      },
      {
        name: "actions",
        description: "操作按钮区域",
        accepts: ["button"],
        default_content: "",
      },
    ],
    layout: {
      dir: Vertical,
      gap: 16.0,
      justify: Start,
      padding: { top: 24.0, right: 24.0, bottom: 24.0, left: 24.0 },
    },
    base_style: { ..NodeStyle::default(), fill: "#FFFFFF", corner_radius: 16.0 },
  })

  // ── App Bar：leading + title + trailing ──
  m.set("app_bar", {
    component_id: "app_bar",
    display_name: "应用栏",
    slots: [
      {
        name: "leading",
        description: "左侧（返回箭头/Logo）",
        accepts: [],
        default_content: "←",
      },
      {
        name: "title",
        description: "中间标题",
        accepts: [],
        default_content: "App",
      },
      {
        name: "trailing",
        description: "右侧（更多/菜单）",
        accepts: [],
        default_content: "⋮",
      },
    ],
    layout: {
      dir: Horizontal,
      gap: 12.0,
      justify: Start,
      padding: { top: 16.0, right: 16.0, bottom: 16.0, left: 16.0 },
    },
    base_style: { ..NodeStyle::default(), fill: "#FFFFFF" },
  })

  // ── Tab Bar：可变 tab 槽 ──
  m.set("tab_bar", {
    component_id: "tab_bar",
    display_name: "底部标签栏",
    slots: [
      {
        name: "tab_1",
        description: "标签 1",
        accepts: [],
        default_content: "Home",
      },
      {
        name: "tab_2",
        description: "标签 2",
        accepts: [],
        default_content: "Search",
      },
      {
        name: "tab_3",
        description: "标签 3",
        accepts: [],
        default_content: "Profile",
      },
      {
        name: "tab_4",
        description: "标签 4（可选）",
        accepts: [],
        default_content: "",
      },
    ],
    layout: {
      dir: Horizontal,
      gap: 0.0,
      justify: Start,
      padding: { top: 8.0, right: 0.0, bottom: 8.0, left: 0.0 },
    },
    base_style: { ..NodeStyle::default(), fill: "#FFFFFF" },
  })

  m
}

///|
/// 组合式组件清单 JSON（Agent 发现用）
pub fn list_slotted_json() -> String {
  let m = builtin_slotted_components()
  let parts : Array[String] = []
  for id in m.keys() {
    match m.get(id) {
      Some(c) => {
        let slots : Array[String] = []
        for s in c.slots.iter() {
          slots.push("\"" + s.name + "\"")
        }
        let sj = jstr22(slots)
        parts.push(
          "{\"id\":\"\{c.component_id}\",\"name\":\"\{c.display_name}\",\"slots\":[\{sj}]}",
        )
      }
      None => ()
    }
  }
  let j = jstr22(parts)
  "[\{j}]"
}

// ---------------------------------------------------------------------------
// Project 集成：放置组合式组件并填充槽位
// ---------------------------------------------------------------------------

///|
/// 放置组合式组件（自动创建槽位子节点）
pub fn Project::place_slotted(
  self : Project,
  artboard~ : String,
  component_id~ : String,
  instance_id~ : String,
  x? : Double = 0.0,
  y? : Double = 0.0,
) -> Result[String, String] {
  let slot_comps = builtin_slotted_components()
  match slot_comps.get(component_id) {
    None => Err("unknown_slotted_component: " + component_id)
    Some(sc) =>
      match self.artboards.get(artboard) {
        None => Err("unknown_artboard")
        Some(ab) => {
          // 创建父容器
          let layout = solve(ab.doc)
          let root_w = match layout.rect_of("root") {
            Some(r) => r.width
            None => 390.0
          }
          let parent = {
            ..Node::make(instance_id, Frame),
            name: sc.display_name,
            width: Fixed(root_w - 48.0),
            height: Hug,
            x: AlignStart(x),
            y: AlignStart(y),
            layout: Some(sc.layout),
            style: sc.base_style,
            component: sc.component_id,
          }
          match ab.doc.insert_node(parent, "root") {
            true => {
              // 为每个槽位创建子节点（含默认内容）
              let slot_ids : Array[String] = []
              for slot in sc.slots.iter() {
                let slot_node_id = instance_id + "_" + slot.name
                let content = if slot.default_content != "" {
                  slot.default_content
                } else {
                  ""
                }
                let slot_node = {
                  ..Node::make(slot_node_id, Text),
                  name: slot.name,
                  text: content,
                  width: Fill,
                  height: Hug,
                  x: AlignStart(0.0),
                  y: AlignStart(0.0),
                  style: {
                    ..NodeStyle::default(),
                    font_size: if slot.name == "title" || slot.name == "header" {
                      18.0
                    } else {
                      14.0
                    },
                  },
                  component: "slot_" + slot.name,
                }
                let _ = ab.doc.insert_node(slot_node, instance_id)
                slot_ids.push(slot_node_id)
              }
              let sj = jstr22(slot_ids)
              Ok(
                "{\"ok\":true,\"instance\":\"\{instance_id}\",\"slots\":\{sc.slots.length()},\"slot_nodes\":[\{sj}]}",
              )
            }
            false => Err("insert_failed")
          }
        }
      }
  }
}

///|
/// 填充槽位内容
pub fn Project::fill_slot(
  self : Project,
  artboard~ : String,
  instance_id~ : String,
  slot_name~ : String,
  content~ : String,
) -> Result[String, String] {
  let slot_node_id = instance_id + "_" + slot_name
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard")
    Some(ab) => {
      if !ab.doc.has(slot_node_id) {
        return Err("slot_not_found: " + slot_node_id)
      }
      let _ = ab.doc.update_node(slot_node_id, fn(n) { { ..n, text: content } })
      Ok("{\"ok\":true,\"slot\":\"\{slot_name}\",\"content\":\"\{content}\"}")
    }
  }
}

///|
/// 获取槽位当前内容
pub fn Project::get_slot(
  self : Project,
  artboard~ : String,
  instance_id~ : String,
  slot_name~ : String,
) -> Result[String, String] {
  let slot_node_id = instance_id + "_" + slot_name
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard")
    Some(ab) =>
      match ab.doc.get(slot_node_id) {
        Some(n) => Ok(n.text)
        None => Err("slot_not_found")
      }
  }
}

///|
/// 列出实例的所有槽位及其内容
pub fn Project::list_slots(
  self : Project,
  artboard~ : String,
  instance_id~ : String,
) -> Result[String, String] {
  let slot_comps = builtin_slotted_components()
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard")
    Some(ab) => {
      // 找到组件类型
      let comp_type = match ab.doc.get(instance_id) {
        Some(n) => n.component
        None => return Err("instance_not_found")
      }
      match slot_comps.get(comp_type) {
        None => Err("not_a_slotted_component")
        Some(sc) => {
          let slots : Array[String] = []
          for slot in sc.slots.iter() {
            let slot_id = instance_id + "_" + slot.name
            let content = match ab.doc.get(slot_id) {
              Some(n) => n.text
              None => ""
            }
            slots.push(
              "{\"name\":\"\{slot.name}\",\"content\":\"\{content}\",\"description\":\"\{slot.description}\"}",
            )
          }
          let j = jstr22(slots)
          Ok("[\{j}]")
        }
      }
    }
  }
}

///|
/// 向槽位中放入另一个组件（递归组合）
pub fn Project::fill_slot_with_component(
  self : Project,
  artboard~ : String,
  instance_id~ : String,
  slot_name~ : String,
  child_component~ : String,
  child_id~ : String,
) -> Result[String, String] {
  let slot_node_id = instance_id + "_" + slot_name
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard")
    Some(ab) => {
      if !ab.doc.has(slot_node_id) {
        return Err("slot_not_found")
      }
      // 在槽位节点内放置子组件
      let comps = builtin_components()
      match comps.get(child_component) {
        Some(def) => {
          let node = instantiate_component(def, child_id, tokens=self.tokens)
          let placed = {
            ..node,
            width: Fill,
            x: AlignStart(0.0),
            y: AlignStart(0.0),
          }
          match ab.doc.insert_node(placed, slot_node_id) {
            true =>
              Ok(
                "{\"ok\":true,\"slot\":\"\{slot_name}\",\"component\":\"\{child_component}\",\"id\":\"\{child_id}\"}",
              )
            false => Err("insert_failed")
          }
        }
        None => Err("unknown_component: " + child_component)
      }
    }
  }
}

///|
fn jstr22(parts : Array[String]) -> String {
  let sb = StringBuilder::new()
  for i in 0..<parts.length() {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string(parts[i])
  }
  sb.to_string()
}
