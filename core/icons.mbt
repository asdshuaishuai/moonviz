/// 内置图标注册表（1.0 M1.5 R2）：mono stroke 风格，24×24 网格。
///
/// 设计约定：
/// - 单路径 `d`，fill=none、stroke 沿用节点文字色（对比度由渲染层保证）
/// - stroke-width 2 / round cap / round join（渲染层统一施加）
/// - 图标名 = 语义名（user/mail/lock/search/star...），未知名返回 None
///
/// 单一事实源：本函数是 icon 名→路径的唯一映射；组件与模板经
/// `update <ab> <node> icon=<name>` 或 place args 消费，不自带路径。
pub fn icon_path(name : String) -> String? {
  match name {
    "user" => Some(
      "M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8Zm-7 8a7 7 0 0 1 14 0"
    )
    "mail" => Some(
      "M3 6h18v12H3zM3 7l9 6 9-6"
    )
    "lock" => Some(
      "M6 11h12v9H6zM9 11V7a3 3 0 0 1 6 0v4"
    )
    "search" => Some(
      "M10.5 17a6.5 6.5 0 1 0 0-13 6.5 6.5 0 0 0 0 13ZM20 20l-4.5-4.5"
    )
    "star" => Some(
      "M12 3l2.7 5.8 6.3.8-4.6 4.4 1.2 6.2-5.6-3-5.6 3 1.2-6.2L3 9.6l6.3-.8z"
    )
    "heart" => Some(
      "M12 20S4 14.5 4 9.2C4 6.3 6.2 4.5 8.5 4.5c1.5 0 2.8.8 3.5 2 .7-1.2 2-2 3.5-2C17.8 4.5 20 6.3 20 9.2 20 14.5 12 20 12 20Z"
    )
    "settings" => Some(
      "M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6Zm8-3a8 8 0 0 0-.2-1.6l2-1.6-2-3.4-2.4 1a8 8 0 0 0-2.8-1.6L14.2 2H9.8l-.4 2.6a8 8 0 0 0-2.8 1.6l-2.4-1-2 3.4 2 1.6A8 8 0 0 0 4 12"
    )
    "home" => Some(
      "M4 11l8-7 8 7v9h-6v-6h-4v6H4z"
    )
    "plus" => Some(
      "M12 5v14M5 12h14"
    )
    "minus" => Some(
      "M5 12h14"
    )
    "check" => Some(
      "M5 13l4.5 4.5L19 7"
    )
    "close" => Some(
      "M6 6l12 12M18 6L6 18"
    )
    "chevron-down" => Some(
      "M6 9l6 6 6-6"
    )
    "chevron-left" => Some(
      "M15 6l-6 6 6 6"
    )
    "chevron-right" => Some(
      "M9 6l6 6-6 6"
    )
    "calendar" => Some(
      "M4 7h16v13H4zM8 3v5M16 3v5M4 11h16"
    )
    "clock" => Some(
      "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18ZM12 7v5l3.5 2"
    )
    "bell" => Some(
      "M6 17h12l-1.5-2.5V10a4.5 4.5 0 0 0-9 0v4.5zM10.5 20a1.8 1.8 0 0 0 3 0"
    )
    "trash" => Some(
      "M4 7h16M9 7V4h6v3M7 7l1 13h8l1-13M10 11v5M14 11v5"
    )
    "edit" => Some(
      "M4 20h4L20 8l-4-4L4 16zM14 6l4 4"
    )
    "download" => Some(
      "M12 4v11M7 11l5 5 5-5M5 20h14"
    )
    "upload" => Some(
      "M12 20V9M7 13l5-5 5 5M5 4h14"
    )
    "eye" => Some(
      "M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12ZM12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z"
    )
    "menu" => Some(
      "M4 6h16M4 12h16M4 18h16"
    )
    "image" => Some(
      "M4 5h16v14H4zM8.5 10.5a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3ZM5 18l5-5 3.5 3.5L17 13l3 3"
    )
    _ => None
  }
}

///|
/// 已注册图标名清单（字典/校验用；保持字母序便于人读）。
pub fn icon_names() -> Array[String] {
  [
    "bell", "calendar", "check", "chevron-down", "chevron-left", "chevron-right",
    "clock", "close", "download", "edit", "eye", "heart", "home", "image", "lock",
    "mail", "menu", "minus", "plus", "search", "settings", "star", "trash",
    "upload", "user",
  ]
}
