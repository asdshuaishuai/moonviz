// ---------------------------------------------------------------------------
// 主题系统：深色/浅色/自定义一键切换，令牌级主题变体管理。
//
// 核心洞察：主题 = 同一组令牌名映射到不同的值。
// Agent 只需引用令牌（`"primary"`），切换主题时所有节点自动更新。
//
// - 预定义主题：light / dark / high_contrast / sepia / nord / sunset
// - 自动暗色：从当前主题反相推导暗色版本（RGB 通道反转，色相旋转 180°）
// - 自定义主题：Agent 给一个 partial override Map → 合并到基础主题
// - 令牌级切换：`set_token("primary", "#FF5722")` → 全局生效

// ---------------------------------------------------------------------------
// 主题定义
// ---------------------------------------------------------------------------

pub(all) struct Theme {
  name : String
  display_name : String
  tokens : DesignTokens
  is_dark : Bool
}

///|
/// 预定义主题注册表
pub fn builtin_themes() -> Array[Theme] {
  [
    Theme::light(),
    Theme::dark(),
    Theme::high_contrast(),
    Theme::sepia(),
    Theme::nord(),
    Theme::sunset(),
    Theme::apple(),
    Theme::apple_dark(),
    Theme::harmony(),
    Theme::harmony_dark(),
  ]
}

///|
/// 美学风格别名归一：Agent/宿主可用自然写法指名美学体系，归一到主题
/// 注册名（Apple HIG 与鸿蒙是一等美学，不是配色变体）。规则：
/// 1) 已注册名原样直通——apple_dark 不能被 contains("apple") 折回浅色；
/// 2) 拉丁词按整词匹配（ios 不误中 scenarios/studios）；中文按子串；
/// 3) 同名带暗色词（"苹果暗色"/"harmony dark"）直接落到暗色预设。
/// 未知名原样返回——apply_theme 报 unknown_theme，Agent 可从 list_themes 精修。
pub fn theme_alias(name : String) -> String {
  let lower = name.to_lower()
  for t in builtin_themes().iter() {
    if t.name == lower {
      return t.name
    }
  }
  let is_apple = contains_latin_word(lower, "apple") ||
    contains_latin_word(lower, "ios") ||
    contains_latin_word(lower, "hig") ||
    lower.contains("苹果")
  let is_harmony = contains_latin_word(lower, "harmony") ||
    contains_latin_word(lower, "harmonyos") ||
    contains_latin_word(lower, "huawei") ||
    lower.contains("鸿蒙") ||
    lower.contains("华为")
  let is_dark = contains_latin_word(lower, "dark") ||
    lower.contains("暗色") ||
    lower.contains("深色") ||
    lower.contains("夜间")
  if is_apple {
    if is_dark {
      "apple_dark"
    } else {
      "apple"
    }
  } else if is_harmony {
    if is_dark {
      "harmony_dark"
    } else {
      "harmony"
    }
  } else {
    name
  }
}

///|
/// 美学体系 + 明暗意图 → 注册主题名。暗色意图落到对应暗色预设
/// （apple + dark → apple_dark；非美学名或非暗色意图原样返回）。
pub fn resolve_aesthetic_theme(alias_name : String, dark_hint : Bool) -> String {
  let a = theme_alias(alias_name)
  if dark_hint && a == "apple" {
    "apple_dark"
  } else if dark_hint && a == "harmony" {
    "harmony_dark"
  } else {
    a
  }
}

// ---------------------------------------------------------------------------
// 预定义主题
// ---------------------------------------------------------------------------

///|
pub fn Theme::light() -> Theme {
  let t = DesignTokens::default()
  { name: "light", display_name: "浅色", tokens: t, is_dark: false, }
}

///|
pub fn Theme::dark() -> Theme {
  let t = DesignTokens::default()
  // 覆盖为暗色值
  t.colors.set("primary", "#A5B4FC")
  t.colors.set("primary_container", "#3B4A8C")
  t.colors.set("on_primary", "#1A1C1E")
  t.colors.set("on_secondary_container", "#E8EAF6")
  t.colors.set("secondary", "#C5CAE9")
  t.colors.set("secondary_container", "#3949AB")
  t.colors.set("text_on_primary", "#1A1C1E")
  t.colors.set("surface", "#1A1C1E")
  t.colors.set("surface_variant", "#2A2C2E")
  t.colors.set("background", "#0F1114")
  t.colors.set("error", "#CF6679")
  t.colors.set("error_container", "#5C1A1A")
  t.colors.set("success", "#81C784")
  t.colors.set("warning", "#FFB74D")
  t.colors.set("outline", "#42474F")
  t.colors.set("outline_variant", "#2A2C2E")
  t.colors.set("text_primary", "#E0E0E0")
  t.colors.set("text_secondary", "#A0A5AD")
  // text_hint 加亮一档：#6B7078 压 surface_variant 仅 2.81，
  // #989EA6 达 5.19（sv）/ 6.33（surface）
  t.colors.set("text_hint", "#989EA6")
  { name: "dark", display_name: "深色", tokens: t, is_dark: true, }
}

///|
pub fn Theme::high_contrast() -> Theme {
  let t = DesignTokens::default()
  t.colors.set("primary", "#0000EE")
  t.colors.set("on_primary", "#FFFFFF")
  t.colors.set("surface", "#FFFFFF")
  t.colors.set("surface_variant", "#F0F0F0")
  t.colors.set("background", "#FFFFFF")
  t.colors.set("error", "#CC0000")
  t.colors.set("text_primary", "#000000")
  t.colors.set("text_secondary", "#1A1A1A")
  t.colors.set("text_hint", "#333333")
  t.colors.set("outline", "#000000")
  // 补齐角色集（模板按角色取色，缺角色会以原名落盘成非法色值）：
  t.colors.set("error_container", "#FFD9D9")
  t.colors.set("on_secondary_container", "#000000")
  t.colors.set("outline_variant", "#666666")
  t.colors.set("success", "#006600")
  t.colors.set("warning", "#A85D00")
  t.colors.set("text_on_primary", "#FFFFFF")
  {
    name: "high_contrast",
    display_name: "高对比度",
    tokens: t,
    is_dark: false,
  }
}

///|
pub fn Theme::sepia() -> Theme {
  let t = DesignTokens::default()
  t.colors.set("primary", "#8D6E63")
  t.colors.set("primary_container", "#EFEBE9")
  t.colors.set("on_primary", "#FFFFFF")
  t.colors.set("secondary", "#A1887F")
  t.colors.set("secondary_container", "#EFEBE9")
  t.colors.set("surface", "#FAF6F0")
  t.colors.set("surface_variant", "#F5F0E8")
  t.colors.set("background", "#FAF6F0")
  t.colors.set("error", "#B71C1C")
  t.colors.set("text_primary", "#3E2723")
  t.colors.set("text_secondary", "#5D4037")
  t.colors.set("text_hint", "#8D6E63")
  // text_hint 加深一档：#8D6E63 压 surface_variant 仅 4.07，#7A5C50 达 5.33
  t.colors.set("text_hint", "#7A5C50")
  // outline 暖棕（第 1 轮补角色时误删，描边消费面扩大后回落 default 冷灰
  // #C8CDD6 压暖底 #FAF6F0 呈可见冷色偏色）
  t.colors.set("outline", "#BCAAA4")
  // 补齐角色集（模板按角色取色，缺角色会以原名落盘成非法色值）：
  t.colors.set("error_container", "#F3D9D2")
  t.colors.set("on_secondary_container", "#3E2723")
  t.colors.set("outline_variant", "#E3D8C8")
  t.colors.set("success", "#2E5D34")
  t.colors.set("warning", "#8A5A00")
  t.colors.set("text_on_primary", "#FFFFFF")
  { name: "sepia", display_name: "复古棕", tokens: t, is_dark: false, }
}

///|
pub fn Theme::nord() -> Theme {
  let t = DesignTokens::default()
  t.colors.set("primary", "#88C0D0")
  t.colors.set("primary_container", "#4C566A")
  t.colors.set("on_primary", "#2E3440")
  t.colors.set("on_secondary_container", "#ECEFF4")
  t.colors.set("secondary", "#81A1C1")
  t.colors.set("secondary_container", "#434C5E")
  t.colors.set("text_on_primary", "#2E3440")
  t.colors.set("surface", "#3B4252")
  t.colors.set("surface_variant", "#434C5E")
  t.colors.set("background", "#2E3440")
  // error 提亮一档：#BF616A 压 surface 仅 2.46，#E49AA2 达 4.52
  t.colors.set("error", "#E49AA2")
  t.colors.set("success", "#A3BE8C")
  t.colors.set("warning", "#EBCB8B")
  t.colors.set("outline", "#4C566A")
  t.colors.set("outline_variant", "#3B4252")
  t.colors.set("text_primary", "#ECEFF4")
  t.colors.set("text_secondary", "#D8DEE9")
  // text_hint 加亮一档：#7B88A1 压 surface_variant 仅 2.42，#B4BFD4 达 4.66
  t.colors.set("text_hint", "#B4BFD4")
  t.colors.set("error_container", "#53343A")
  { name: "nord", display_name: "Nord 极地", tokens: t, is_dark: true, }
}

///|
pub fn Theme::sunset() -> Theme {
  let t = DesignTokens::default()
  // 逐档 WCAG 校准（美学第一要素同款口径）：
  // - primary #FF7043 白字仅 2.74，加深到深橙 #BF360C（5.6）——浅橙留给
  //   secondary/primary_container 做暖色点缀，主操作仍可读；
  // - success #43A047 压米色底仅 3.1，#2E7D32 达 4.83/4.68；
  // - text_hint #8D6E63 压 surface_variant 仅 3.94，#75593F 达 5.5。
  t.colors.set("primary", "#BF360C")
  t.colors.set("primary_container", "#FBE9E7")
  t.colors.set("on_primary", "#FFFFFF")
  t.colors.set("secondary", "#FF8A65")
  t.colors.set("secondary_container", "#FBE9E7")
  t.colors.set("surface", "#FFF8E1")
  t.colors.set("surface_variant", "#FFECB3")
  t.colors.set("background", "#FFF3E0")
  t.colors.set("error", "#D32F2F")
  t.colors.set("success", "#2E7D32")
  // warning 加深一档：#FB8C00 白字仅 2.37，#B25A00 达 4.82（浅橙留给
  // secondary 做暖色点缀）
  t.colors.set("warning", "#B25A00")
  t.colors.set("outline", "#FFCC80")
  t.colors.set("text_primary", "#3E2723")
  t.colors.set("text_secondary", "#5D4037")
  t.colors.set("text_hint", "#75593F")
  // 补齐角色集（模板按角色取色，缺角色会以原名落盘成非法色值）：
  t.colors.set("error_container", "#FFE0D3")
  t.colors.set("on_secondary_container", "#4E2A18")
  t.colors.set("outline_variant", "#F2DCC0")
  t.colors.set("text_on_primary", "#FFFFFF")
  { name: "sunset", display_name: "落日暖", tokens: t, is_dark: false, }
}

// ---------------------------------------------------------------------------
// 美学体系预设（第一要素）：Apple HIG 与 HarmonyOS NEXT 的官方色板翻译。
//
// 与既有「配色主题」不同档：这两族自带完整的组件美学约定（tinted 分层底、
// hairline 分割、胶囊控件、语义色口径），主题切换即整套气质落地。色值不是
// 原样照抄，而是逐档 WCAG 校准（实测 ≥4.5:1，big-ok 档 ≥3.0）：
// - apple 主色取 Apple 营销蓝的加深档 #0068D6（原版 #007AFF 白字 4.02 不达
//   正文档，按钮是白字主面必须过 4.5）；暗色 #409CFF 原版 #0A84FF 同理。
// - harmony 主色 #0A59F7 原生达标（白字 5.55）；暗色 #5291FF 配深字 #06142B
//   （6.0），浮起面对暗面 ≥4.7。
// - text_secondary/hint 全部调深一档：iOS #8E8E93 在 tinted 底上 3.4x，
//   兑换成 #66666B / #66717D 才能过 4.5（可读性硬标准对全部主题生效）。
// - 分层底严格按官方口径：iOS systemGroupedBackground #F2F2F7（画布）、
//   secondarySystemGroupedBackground #FFFFFF（卡面）；鸿蒙 #F1F3F5 / #FFFFFF。
// ---------------------------------------------------------------------------

///|
/// Apple HIG 浅色（iOS systemGroupedBackground 分层 + SF 语义色）
pub fn Theme::apple() -> Theme {
  let t = DesignTokens::default()
  t.colors.set("primary", "#0068D6")
  t.colors.set("primary_container", "#D9EBFF")
  t.colors.set("on_primary", "#FFFFFF")
  t.colors.set("on_secondary_container", "#1D1D1F")
  t.colors.set("secondary", "#5856D6")
  t.colors.set("secondary_container", "#E9E9EE")
  t.colors.set("text_on_primary", "#FFFFFF")
  t.colors.set("surface", "#FFFFFF")
  t.colors.set("surface_variant", "#EDEDF2")
  t.colors.set("background", "#F2F2F7")
  t.colors.set("error", "#D70015")
  t.colors.set("error_container", "#FFE0DE")
  // success 加深一档：#248A3D 压白 4.40 / 压画布 3.94，#217F38 达 5.05/4.53
  t.colors.set("success", "#217F38")
  t.colors.set("warning", "#C93400")
  t.colors.set("outline", "#C6C6C8")
  t.colors.set("outline_variant", "#E5E5EA")
  t.colors.set("text_primary", "#1D1D1F")
  t.colors.set("text_secondary", "#66666B")
  // text_hint 加深一档：#667078 压 surface_variant 仅 4.33，#616A72 达 4.72
  t.colors.set("text_hint", "#616A72")
  { name: "apple", display_name: "Apple HIG", tokens: t, is_dark: false, }
}

///|
/// Apple HIG 暗色（iOS Dark Mode 分层：#1C1C1E 底 / #2C2C2E 卡面）
pub fn Theme::apple_dark() -> Theme {
  let t = DesignTokens::default()
  t.colors.set("primary", "#409CFF")
  t.colors.set("primary_container", "#0F3A66")
  t.colors.set("on_primary", "#06142B")
  t.colors.set("on_secondary_container", "#F5F5F7")
  t.colors.set("secondary", "#8F8CF0")
  t.colors.set("secondary_container", "#3A3A3C")
  t.colors.set("text_on_primary", "#06142B")
  t.colors.set("surface", "#2C2C2E")
  t.colors.set("surface_variant", "#3A3A3C")
  t.colors.set("background", "#1C1C1E")
  t.colors.set("error", "#FF6961")
  t.colors.set("error_container", "#5C1A1A")
  t.colors.set("success", "#4CD964")
  t.colors.set("warning", "#FF9500")
  t.colors.set("outline", "#48484A")
  t.colors.set("outline_variant", "#3A3A3C")
  t.colors.set("text_primary", "#F5F5F7")
  t.colors.set("text_secondary", "#AEAEB2")
  // text_hint 加亮一档：#98989E 压 surface_variant 仅 3.96，#A6A6AB 达 4.68
  t.colors.set("text_hint", "#A6A6AB")
  {
    name: "apple_dark",
    display_name: "Apple HIG 暗色",
    tokens: t,
    is_dark: true,
  }
}

///|
/// HarmonyOS NEXT 浅色（#F1F3F5 画布 + #FFFFFF 卡面 + 鸿蒙蓝 #0A59F7）
pub fn Theme::harmony() -> Theme {
  let t = DesignTokens::default()
  t.colors.set("primary", "#0A59F7")
  t.colors.set("primary_container", "#E6EEFE")
  t.colors.set("on_primary", "#FFFFFF")
  t.colors.set("on_secondary_container", "#182431")
  t.colors.set("secondary", "#46B1E3")
  t.colors.set("secondary_container", "#EEF1F4")
  t.colors.set("text_on_primary", "#FFFFFF")
  t.colors.set("surface", "#FFFFFF")
  t.colors.set("surface_variant", "#EEF0F3")
  t.colors.set("background", "#F1F3F5")
  t.colors.set("error", "#D0340F")
  t.colors.set("error_container", "#FFE0DB")
  // success 加深一档：#3D9134 压白 3.96 / 压画布 3.56，#2F7D2A 达 5.14/4.62
  t.colors.set("success", "#2F7D2A")
  t.colors.set("warning", "#B25D00")
  t.colors.set("outline", "#D3D7DC")
  t.colors.set("outline_variant", "#E5E8EB")
  t.colors.set("text_primary", "#182431")
  t.colors.set("text_secondary", "#5A6470")
  t.colors.set("text_hint", "#5F6A76")
  { name: "harmony", display_name: "HarmonyOS", tokens: t, is_dark: false, }
}

///|
/// HarmonyOS 暗色（#1C1E21 底 / #26292D 卡面；浮起蓝 #5291FF 配深字）
pub fn Theme::harmony_dark() -> Theme {
  let t = DesignTokens::default()
  t.colors.set("primary", "#5291FF")
  t.colors.set("primary_container", "#1B2C4D")
  t.colors.set("on_primary", "#06142B")
  t.colors.set("on_secondary_container", "#E6E8EB")
  t.colors.set("secondary", "#5BB7E5")
  t.colors.set("secondary_container", "#33373C")
  t.colors.set("text_on_primary", "#06142B")
  t.colors.set("surface", "#26292D")
  t.colors.set("surface_variant", "#33373C")
  t.colors.set("background", "#1C1E21")
  t.colors.set("error", "#EA6A5A")
  t.colors.set("error_container", "#5C1A1A")
  t.colors.set("success", "#5DAA51")
  t.colors.set("warning", "#E5753A")
  t.colors.set("outline", "#454A50")
  t.colors.set("outline_variant", "#33373C")
  t.colors.set("text_primary", "#E6E8EB")
  t.colors.set("text_secondary", "#B0B8C1")
  t.colors.set("text_hint", "#9AA3AD")
  {
    name: "harmony_dark",
    display_name: "HarmonyOS 暗色",
    tokens: t,
    is_dark: true,
  }
}

// ---------------------------------------------------------------------------
// 自动暗色推导
// ---------------------------------------------------------------------------

///|
/// 从主题自动生成暗色版本（RGB 通道反转——即色相旋转 180°，非保留色相的
/// 亮度反演；HSL 语义的反转需要感知色相空间，v1 不引入）
pub fn Theme::auto_dark(base : Theme) -> Theme {
  let dark_tokens = base.tokens
  // 反转每个颜色令牌的亮度
  for key in dark_tokens.colors.keys() {
    match dark_tokens.colors.get(key) {
      Some(hex) => {
        let inverted = invert_luminance(hex)
        dark_tokens.colors.set(key, inverted)
      }
      None => ()
    }
  }
  {
    name: base.name + "_auto_dark",
    display_name: base.display_name + "（暗色）",
    tokens: dark_tokens,
    is_dark: true,
  }
}

///|
/// RGB 三通道反转（255-v）：视觉上是色相旋转 180° 的反相，不是 HSL 意义
/// 的「保色相反亮度」——命名沿用历史，语义以此注释为准
fn invert_luminance(hex : String) -> String {
  let (r, g, b) = parse_rgb5(hex)
  // 反转 RGB
  let nr = 255 - r
  let ng = 255 - g
  let nb = 255 - b
  // 转回 hex
  to_hex(nr, ng, nb)
}

///|
fn parse_rgb5(hex : String) -> (Int, Int, Int) {
  let body = if hex.length() > 0 && hex.get_char(0) == Some('#') {
    hex.substring(start=1)
  } else {
    hex
  }
  if body.length() < 6 {
    return (0, 0, 0)
  }
  (hv5(body, 0), hv5(body, 2), hv5(body, 4))
}

///|
fn hv5(s : String, offset : Int) -> Int {
  if s.length() < offset + 2 {
    return 0
  }
  let hi = hd5(s.get_char(offset))
  let lo = hd5(s.get_char(offset + 1))
  hi * 16 + lo
}

///|
fn hd5(c : Char?) -> Int {
  match c {
    Some(ch) => {
      let code = ch.to_int()
      if code >= 48 && code <= 57 {
        code - 48
      } else if code >= 97 && code <= 102 {
        code - 87
      } else if code >= 65 && code <= 70 {
        code - 55
      } else {
        0
      }
    }
    None => 0
  }
}

///|
fn to_hex(r : Int, g : Int, b : Int) -> String {
  // 转为 hex
  "#" + int_to_hex(r) + int_to_hex(g) + int_to_hex(b)
}

///|
fn int_to_hex(v : Int) -> String {
  // Int::to_char 返回 Char?，直接 .to_string() 会产出 "Some(c)" 形态的垃圾
  // 十六进制——用 Char::from_int 构造（与 json.mbt write_c0_u_escape 同款）
  let hi = v / 16
  let lo = v % 16
  let sb = StringBuilder::new()
  sb.write_char(Char::from_int(if hi < 10 { hi + 48 } else { hi + 87 }))
  sb.write_char(Char::from_int(if lo < 10 { lo + 48 } else { lo + 87 }))
  sb.to_string()
}

// ---------------------------------------------------------------------------
// Project 集成：主题切换
// ---------------------------------------------------------------------------

///|
/// 应用主题到项目（更新令牌表并重新解析所有节点颜色）
pub fn Project::apply_theme(
  self : Project,
  theme_name : String,
) -> Result[String, String] {
  // 美学别名先归一（ios/苹果/鸿蒙/harmonyos → apple/harmony）
  let theme_name = theme_alias(theme_name)
  let themes = builtin_themes()
  let mut found : Theme? = None
  for i in 0..<themes.length() {
    if themes[i].name == theme_name {
      found = Some(themes[i])
      break
    }
  }
  match found {
    Some(theme) => {
      let prior = self.tokens_snapshot()
      self.tokens = theme.tokens
      // 主题切换保留自定义令牌覆盖：tokens: 段是设计者明确意图，
      // 换主题只换未覆盖的角色
      match self.token_overrides {
        Some(ov) =>
          for role in ov.keys() {
            match ov.get(role) {
              Some(v) => self.tokens.colors.set(role, v)
              None => ()
            }
          }
        None => ()
      }
      self.active_theme = theme_name
      let changed = self.recolor_with(theme.tokens, prior=Some(prior))
      let is_dark = if theme.is_dark { "true" } else { "false" }
      Ok(
        "{\"ok\":true,\"theme\":\"\{theme_name}\",\"is_dark\":\{is_dark},\"recolored\":\{changed}}",
      )
    }
    None => Err("unknown_theme: " + theme_name)
  }
}

///|
/// text_color 语境的角色分级（小者优先）：文字位置的十六进制值优先按
/// 文字角色解释——#1A1C1E 出现在文字上应视为 light.text_primary 而不是
/// dark.surface，否则 nord 等深色主题会得到「深字压深底」。
fn role_rank_for_text(role : String) -> Int {
  if role_has_prefix(role, "text_") {
    1
  } else if role_has_prefix(role, "on_") {
    2
  } else if role == "surface" ||
    role == "surface_variant" ||
    role == "background" {
    3
  } else if role_has_suffix(role, "_container") {
    4
  } else if role == "primary" || role == "secondary" {
    5
  } else if role_has_prefix(role, "outline") {
    6
  } else {
    7
  }
}

///|
/// text 语境（彩色底变体）：primary/secondary 底上的文字几乎总是
/// on_primary/on_secondary 语义——#FFFFFF 出现在按钮上应还原成
/// on_primary 而不是 surface，否则深色主题往返后按钮文字错位成
/// text_primary 的深色值。
fn role_rank_for_text_on(role : String) -> Int {
  if role_has_prefix(role, "on_") {
    1
  } else if role_has_prefix(role, "text_") {
    2
  } else {
    role_rank_for_text(role)
  }
}

///|
/// fill 语境的角色分级：底/容器优先，文字角色殿后（同一字面量被用作
/// 面色时几乎总是 surface/container 语义）。
fn role_rank_for_fill(role : String) -> Int {
  if role == "surface" ||
    role == "surface_variant" ||
    role == "background" {
    1
  } else if role_has_suffix(role, "_container") {
    2
  } else if role == "primary" || role == "secondary" {
    3
  } else if role_has_prefix(role, "outline") {
    4
  } else if role_has_prefix(role, "text_") {
    5
  } else if role_has_prefix(role, "on_") {
    6
  } else {
    7
  }
}

///|
fn role_has_prefix(s : String, prefix : String) -> Bool {
  s.length() >= prefix.length() &&
  s.substring(start=0, end=prefix.length()) == prefix
}

///|
fn role_has_suffix(s : String, suffix : String) -> Bool {
  s.length() >= suffix.length() &&
  s.substring(start=s.length() - suffix.length()) == suffix
}

///|
/// 角色重着色：模板/画布把令牌值写成字面量（fill="#4B6BFB"），仅换
/// tokens 表对已落盘的颜色无效。按默认调色板建立「字面量 → 角色」反查表，
/// 把匹配的 fill/text_color 重写为新主题的角色值——变更写回 .mbt.md，
/// 保持唯一事实源语义。
fn Project::recolor_with(
  self : Project,
  target : DesignTokens,
  prior? : DesignTokens? = None,
) -> Int {
  // 字面量 → 角色：以「全部内置主题 ∪ 默认」的调色板并集反查。
  // 操作路径每条命令都从 canonical MBT 重建 Project（tokens 恒为默认），
  // 仅按当前/默认反查会让「nord → light」无从映射——并集保证任一主题的
  // 字面量都能反查到角色，主题切换无状态可逆。
  // 字面量 → 候选角色集合。同一字面量在不同主题里可能是不同角色
  // （#1A1C1E 既是 light.text_primary 也是 dark.surface）——不能取
  // 「最后写入」那个，按使用处（fill / text_color）的角色类分级选义。
  let lit_roles : Map[String, Map[String, Bool]] = Map::new()
  let remember = fn(lit : String, role : String) {
    match lit_roles.get(lit) {
      Some(set) => set.set(role, true)
      None => {
        let set : Map[String, Bool] = Map::new()
        set.set(role, true)
        lit_roles.set(lit, set)
      }
    }
  }
  let palettes : Array[DesignTokens] = [DesignTokens::default()]
  for theme in builtin_themes().iter() {
    palettes.push(theme.tokens)
  }
  match prior {
    Some(p) => palettes.push(p)
    None => ()
  }
  for palette in palettes {
    for role in palette.colors.keys() {
      match palette.colors.get(role) {
        Some(v) => remember(v, role)
        None => ()
      }
    }
  }
  // 引擎默认文字色 #111111（node/decl 出厂值）语义上就是 text_primary
  remember("#111111", "text_primary")
  // 历史默认主色 #4B6BFB（WCAG 校准前的存量文档/模板字面量）仍按 primary
  // 反查——默认调色板已换成校准值 #4361EE，老字面量不丢映射
  remember("#4B6BFB", "primary")
  let pick = fn(lit : String, rank : (String) -> Int) -> String? {
    match lit_roles.get(lit) {
      None => None
      Some(set) => {
        let mut best : String? = None
        let mut best_rank = 99
        for role in set.keys() {
          let r = rank(role)
          // 严格小于 + 角色名字典序决胜：与 Map 迭代顺序无关，结果确定
          if r < best_rank || (r == best_rank && best is Some(b) && role < b) {
            best = Some(role)
            best_rank = r
          }
        }
        best
      }
    }
  }
  let mut changed = 0
  for ab_id in self.artboards.keys() {
    let ab = match self.artboards.get(ab_id) {
      Some(a) => a
      None => continue
    }
    for nid in ab.doc.nodes.keys() {
      let _ = ab.doc.update_node(nid, fn(n) {
        let mut node = n
        match pick(n.style.fill, role_rank_for_fill) {
          Some(role) =>
            match target.colors.get(role) {
              Some(v) => {
                if v != n.style.fill {
                  changed = changed + 1
                }
                node = { ..node, style: { ..node.style, fill: v, }, }
              }
              None => ()
            }
          None => ()
        }
        // 文字角色按所在底色判别：primary/secondary 实底上的文字优先
        // on_*（按钮），secondary_container 底上的文字优先 on_secondary_
        // container（chip/次级按钮的目录口径——字典序会让 on_primary 抢占
        // 同分，必须按底色上下文显式指定），透明底/容器上的文字优先
        // text_*（正文/输入框）
        let fill_role = pick(node.style.fill, role_rank_for_fill)
        let text_rank : (String) -> Int = match fill_role {
          Some("secondary_container") =>
            fn(role : String) -> Int {
              if role == "on_secondary_container" {
                1
              } else if role_has_prefix(role, "on_") ||
                role_has_prefix(role, "text_") {
                2
              } else {
                role_rank_for_text(role) + 2
              }
            }
          Some(r) =>
            if r == "primary" || r == "secondary" {
              role_rank_for_text_on
            } else {
              role_rank_for_text
            }
          None => role_rank_for_text
        }
        match pick(n.style.text_color, text_rank) {
          Some(role) =>
            match target.colors.get(role) {
              Some(v) => {
                if v != n.style.text_color {
                  changed = changed + 1
                }
                node = { ..node, style: { ..node.style, text_color: v, }, }
              }
              None => ()
            }
          None => ()
        }
        node
      })
    }
  }
  if changed > 0 {
    self.revision = self.revision + 1
  }
  changed
}

///|
/// 令牌表深快照：recolor 反查需要「变更前」的字面量→角色来源，
/// 自定义值（set_token 产物）不在任何内置调色板里。
fn Project::tokens_snapshot(self : Project) -> DesignTokens {
  let colors : Map[String, String] = Map::new()
  for role in self.tokens.colors.keys() {
    match self.tokens.colors.get(role) {
      Some(v) => colors.set(role, v)
      None => ()
    }
  }
  { ..self.tokens, colors, }
}

///|
/// 加载路径恢复主题：只切换 tokens 与 active_theme，不做角色重着色——
/// canonical MBT 里的节点颜色已是主题字面量，重着色属于 apply_theme 的
/// 职责，重复执行会把已是目标色的节点原样重写（幂等但徒增 revision）。
pub fn Project::set_theme_tokens(self : Project, theme_name : String) -> Unit {
  for theme in builtin_themes().iter() {
    if theme.name == theme_name {
      self.tokens = theme.tokens
      self.active_theme = theme.name
      return
    }
  }
}

///|
/// 修改单个令牌值（全局生效）。
///
/// "全局生效"必须包含两件事，只改内存 tokens 表对已落盘的字面量无效：
/// 1. 记录自定义覆盖（token_overrides），随 canonical MBT frontmatter
///    `tokens:` 段往返——否则下一条命令从文本重建时覆盖即丢失；
/// 2. 立即重着色：旧值字面量 → 角色 → 新值，与 apply_theme 同一反查
///    表，因此同样可逆（换回原值即恢复）。
pub fn Project::set_token(
  self : Project,
  token_name : String,
  value : String,
) -> Result[String, String] {
  if !self.tokens.colors.contains(token_name) {
    return Err("unknown_token: " + token_name)
  }
  let prior = self.tokens_snapshot()
  let previous = match self.tokens.colors.get(token_name) {
    Some(v) => v
    None => ""
  }
  self.tokens.colors.set(token_name, value)
  if self.token_overrides is None {
    self.token_overrides = Some(Map::new())
  }
  match self.token_overrides {
    Some(ov) => ov.set(token_name, value)
    None => ()
  }
  // recolor_with 在 changed>0 时已 +1；值未变化的重复 set（load 路径）
  // 不会虚涨 revision。
  // envelope 合法性红线：value 是 Agent 可控文本，含引号/反斜杠时裸拼
  // 会产出非法 JSON（与 fill_slot 同类事故面）——统一过 json_escape
  let changed = self.recolor_with(self.tokens, prior=Some(prior))
  Ok(
    "{\"ok\":true,\"token\":\"\{token_name}\",\"old\":\"\{json_escape(previous)}\",\"value\":\"\{json_escape(value)}\",\"recolored\":\{changed}}",
  )
}

///|
/// 获取令牌当前值
pub fn Project::get_token(
  self : Project,
  token_name : String,
) -> Result[String, String] {
  match self.tokens.colors.get(token_name) {
    Some(v) => Ok(v)
    None => Err("unknown_token: " + token_name)
  }
}

///|
/// 预览节点在各主题下的颜色：按默认调色板把节点 fill 反查为角色，再逐
/// 主题取该角色的值（找不到节点或角色时回退 primary）——与 README
/// 「preview the node under each theme」的承诺一致，而非无视 node_id 的
/// 全局 primary 表。
pub fn Project::preview_themes(
  self : Project,
  node_id : String,
) -> Result[String, String] {
  let mut role = "primary"
  for ab_id in self.artboards.keys() {
    match self.artboards.get(ab_id) {
      Some(ab) =>
        match ab.doc.get(node_id) {
          Some(n) => {
            let d = DesignTokens::default()
            for r in d.colors.keys() {
              match d.colors.get(r) {
                Some(v) => if v == n.style.fill {
                  role = r
                }
                None => ()
              }
            }
          }
          None => ()
        }
      None => ()
    }
  }
  let results : Array[String] = []
  for theme in builtin_themes().iter() {
    let color = theme.tokens.resolve_color(role)
    results.push(
      "{\"theme\":\"\{theme.name}\",\"display\":\"\{theme.display_name}\",\"role\":\"\{role}\",\"color\":\"\{color}\"}",
    )
  }
  let j = jstr21(results)
  Ok("[\{j}]")
}

///|
/// 自动生成当前主题的暗色版本并应用。
///
/// 从 active_theme 对应主题推导（而非恒从 light），并与 apply_theme/set_token
/// 对齐状态三元组：tokens / active_theme / token_overrides——派生主题的全部
/// 角色值记入 token_overrides，随 canonical MBT frontmatter `tokens:` 段往返，
/// 节点字面量经 recolor_with 重着色，保持状态与 canonical 一致。
pub fn Project::enable_auto_dark(self : Project) -> Result[String, String] {
  let mut base : Theme? = None
  for theme in builtin_themes().iter() {
    if theme.name == self.active_theme {
      base = Some(theme)
      break
    }
  }
  let current = match base {
    Some(t) => t
    None => Theme::light()
  }
  let dark = Theme::auto_dark(current)
  let prior = self.tokens_snapshot()
  self.tokens = dark.tokens
  // 派生主题的整个令牌面即本次覆盖意图：整体记入 token_overrides
  let ov : Map[String, String] = Map::new()
  for role in dark.tokens.colors.keys() {
    match dark.tokens.colors.get(role) {
      Some(v) => ov.set(role, v)
      None => ()
    }
  }
  self.token_overrides = Some(ov)
  self.active_theme = dark.name
  let changed = self.recolor_with(dark.tokens, prior=Some(prior))
  Ok(
    "{\"ok\":true,\"theme\":\"\{dark.name}\",\"original\":\"\{current.name}\",\"recolored\":\{changed}}",
  )
}

///|
fn jstr21(parts : Array[String]) -> String {
  let sb = StringBuilder::new()
  for i in 0..<parts.length() {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string(parts[i])
  }
  sb.to_string()
}
