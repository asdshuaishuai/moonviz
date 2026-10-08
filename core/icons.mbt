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
    // ---- R2 前半（25→60）：常见 UI 语义补齐，同风格 mono stroke ----
    "arrow-up" => Some(
      "M12 19V5M5 12l7-7 7 7"
    )
    "arrow-down" => Some(
      "M12 5v14M19 12l-7 7-7-7"
    )
    "arrow-left" => Some(
      "M19 12H5M12 19l-7-7 7-7"
    )
    "arrow-right" => Some(
      "M5 12h14M12 5l7 7-7 7"
    )
    "chevron-up" => Some(
      "M6 15l6-6 6 6"
    )
    "external-link" => Some(
      "M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6M15 3h6v6M10 14L21 3"
    )
    "filter" => Some(
      "M21 4H3l7.5 8.5V19l4 2.5v-9z"
    )
    "grid" => Some(
      "M3 3h7v7H3zM14 3h7v7h-7zM14 14h7v7h-7zM3 14h7v7H3z"
    )
    "list" => Some(
      "M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01"
    )
    "more-horizontal" => Some(
      "M12 12h.01M19 12h.01M5 12h.01"
    )
    "play" => Some(
      "M6 3l14 9-14 9V3z"
    )
    "refresh" => Some(
      "M20.5 4v5h-5M3.5 20v-5h5M5 9a7.5 7.5 0 0 1 12.6-3.4L20.5 9M19 15a7.5 7.5 0 0 1-12.6 3.4L3.5 15"
    )
    "share" => Some(
      "M4 12v7a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-7M16 6l-4-4-4 4M12 2v13"
    )
    "volume" => Some(
      "M11 5L6 9H2v6h4l5 4V5zM15.5 8.5a5 5 0 0 1 0 7"
    )
    "wifi" => Some(
      "M2 9a15 15 0 0 1 20 0M5 12.5a10.5 10.5 0 0 1 14 0M8.5 16a6 6 0 0 1 7 0M12 19.5h.01"
    )
    "battery" => Some(
      "M2 8h17v8H2zM22.5 11v2"
    )
    "bluetooth" => Some(
      "M7 7l10 10L12 22V2l5 5L7 17"
    )
    "camera" => Some(
      "M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h3l2-3h6l2 3h3a2 2 0 0 1 2 2zM12 17a4 4 0 1 0 0-8 4 4 0 0 0 0 8z"
    )
    "code" => Some(
      "M16 18l6-6-6-6M8 6l-6 6 6 6"
    )
    "copy" => Some(
      "M9 9h11v11H9zM5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"
    )
    "file" => Some(
      "M13 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9zM13 2v7h7"
    )
    "folder" => Some(
      "M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"
    )
    "globe" => Some(
      "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18ZM3 12h18M12 3a13.5 13.5 0 0 1 0 18M12 3a13.5 13.5 0 0 0 0 18"
    )
    "info" => Some(
      "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18ZM12 8h.01M12 11v6"
    )
    "maximize" => Some(
      "M8 3H5a2 2 0 0 0-2 2v3M16 3h3a2 2 0 0 1 2 2v3M21 16v3a2 2 0 0 1-2 2h-3M3 16v3a2 2 0 0 0 2 2h3"
    )
    "minimize" => Some(
      "M8 3v3a2 2 0 0 1-2 2H3M21 8h-3a2 2 0 0 1-2-2V3M3 16h3a2 2 0 0 1 2 2v3M16 21v-3a2 2 0 0 1 2-2h3"
    )
    "moon" => Some(
      "M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"
    )
    "pin" => Some(
      "M12 21s-7-5.4-7-11a7 7 0 0 1 14 0c0 5.6-7 11-7 11zM12 12.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z"
    )
    "save" => Some(
      "M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2zM17 21v-8H7v8M7 3v5h8"
    )
    "search-x" => Some(
      "M10.5 17a6.5 6.5 0 1 0 0-13 6.5 6.5 0 0 0 0 13ZM20 20l-4.5-4.5M17 7l5 5M22 7l-5 5"
    )
    "sun" => Some(
      "M12 16.5a4.5 4.5 0 1 0 0-9 4.5 4.5 0 0 0 0 9ZM12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41"
    )
    "tag" => Some(
      "M20.6 13.4l-7.2 7.2a2 2 0 0 1-2.8 0L3 13V3h10l7.6 7.6a2 2 0 0 1 0 2.8zM7.5 7.5h.01"
    )
    "link" => Some(
      "M10 13a5 5 0 0 0 7.5.5l3-3a5 5 0 0 0-7-7l-1.7 1.7M14 11a5 5 0 0 0-7.5-.5l-3 3a5 5 0 0 0 7 7l1.7-1.7"
    )
    "mic" => Some(
      "M12 15a3.5 3.5 0 0 0 3.5-3.5v-5a3.5 3.5 0 0 0-7 0v5A3.5 3.5 0 0 0 12 15zM19 11.5a7 7 0 0 1-14 0M12 18.5V22M8.5 22h7"
    )
    "send" => Some(
      "M22 2L11 13M22 2l-7 20-4-9-9-4z"
    )
    _ => None
  }
}

///|
/// 已注册图标名清单（字典/校验用；保持字母序便于人读）。
pub fn icon_names() -> Array[String] {
  [
    "arrow-down", "arrow-left", "arrow-right", "arrow-up", "battery", "bell",
    "bluetooth", "calendar", "camera", "check", "chevron-down", "chevron-left",
    "chevron-right", "chevron-up", "clock", "close", "code", "copy", "download",
    "edit", "external-link", "eye", "file", "filter", "folder", "globe", "grid",
    "heart", "home", "image", "info", "link", "list", "lock", "mail", "maximize",
    "menu", "mic", "minimize", "minus", "moon", "more-horizontal", "pin", "play",
    "plus", "refresh", "save", "search", "search-x", "send", "settings", "share",
    "star", "sun", "tag", "trash", "upload", "user", "volume", "wifi",
  ]
}
