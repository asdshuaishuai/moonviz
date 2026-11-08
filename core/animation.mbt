///|
/// 属性动画系统：原型需要动效——属性插值 / 缓动函数 / 时间线编排。
///
/// Agent 定义关键帧动画（"按钮按下时缩小到 0.95 再弹回"），
/// 引擎生成 CSS animation 或直接驱动运行时插值。
///
/// - Keyframe：某时刻某属性的值
/// - Easing：缓动函数（linear / ease-in / ease-out / spring / bounce）
/// - Timeline：多条动画的编排（并行 / 顺序 / 延迟）

// ---------------------------------------------------------------------------
// 缓动函数
// ---------------------------------------------------------------------------

pub(all) enum Easing {
  Linear
  EaseIn
  EaseOut
  EaseInOut
  Spring(Double) // 弹性系数
  Bounce
  None // 无缓动（瞬跳）
}

///|
pub fn Easing::name(self : Easing) -> String {
  match self {
    Linear => "linear"
    EaseIn => "ease-in"
    EaseOut => "ease-out"
    EaseInOut => "ease-in-out"
    Spring(_) => "spring"
    Bounce => "bounce"
    None => "none"
  }
}

///|
/// CSS cubic-bezier 等价（用于导出）
pub fn Easing::css_value(self : Easing) -> String {
  match self {
    Linear => "linear"
    EaseIn => "cubic-bezier(0.4, 0, 1, 1)"
    EaseOut => "cubic-bezier(0, 0, 0.2, 1)"
    EaseInOut => "cubic-bezier(0.4, 0, 0.2, 1)"
    Spring(k) => "cubic-bezier(0.34, 1.56, 0.64, 1)" // 近似 spring
    Bounce => "cubic-bezier(0.68, -0.55, 0.265, 1.55)"
    None => "steps(1, end)"
  }
}

// ---------------------------------------------------------------------------
// 动效令牌：时长刻度 + 引擎曲线的 CSS 注出（精致感的节拍单一来源）
// ---------------------------------------------------------------------------

///|
/// 动效时长刻度（ms）。导出 HTML 与一切宿主共用同一套节拍：
/// 即时反馈 120 / 微反馈 180 / 标准转场 240 / 强调慢速 360。
pub const MOTION_FAST : Int = 120

///|
pub const MOTION_BASE : Int = 240

///|
pub const MOTION_SLOW : Int = 360

///|
/// 微反馈时长（ms）：文字更新 tick 一类"被看见但不打断"的反馈，
/// 落在即时与标准转场之间。
pub const MOTION_TICK : Int = 180

///|
/// 入场阶梯步进（ms）：画板顶层节点依次浮现的节拍。
pub const MOTION_STAGGER : Int = 24

///|
/// 阶梯递增级数：第 2 个到第 MOTION_STAGGER_STEPS 个节点逐级递增，
/// 之后饱和（不递增、也不复位）。
pub const MOTION_STAGGER_STEPS : Int = 8

///|
/// 阶梯饱和延迟（ms）= (级数-1) × 步进：第 8 个起恒为 168ms。
/// 此前导出层只写到 nth-of-type(8)，第 9 个起 delay 复位 0——长列表
/// 后段节点抢跑，入场节拍整体断阶。
pub const MOTION_STAGGER_MAX : Int = (MOTION_STAGGER_STEPS - 1) * MOTION_STAGGER

///|
/// 动效令牌 CSS（:root 变量）：时长刻度 + 阶梯节拍 + 引擎缓动曲线
/// （cubic-bezier 等价式）。曲线一律出自 Easing::css_value——导出原型、
/// 宿主、运行时共用同一来源，不允许各处手写贝塞尔（节拍/手感漂移是
/// 精致感的第一杀手）。
///
/// 刻度从 DesignTokens.motion 读取（spec/theme/frontmatter `tokens:` 的
/// 覆盖在这里生效）；缺表项回退 MOTION_* 常量。
pub fn motion_tokens_css_for(tokens : DesignTokens) -> String {
  let fast = motion_ms(tokens, "fast", MOTION_FAST)
  let base = motion_ms(tokens, "base", MOTION_BASE)
  let slow = motion_ms(tokens, "slow", MOTION_SLOW)
  let tick = motion_ms(tokens, "tick", MOTION_TICK)
  let stagger = motion_ms(tokens, "stagger", MOTION_STAGGER)
  let stagger_max = motion_ms(tokens, "stagger_max", MOTION_STAGGER_MAX)
  ":root{--mv-dur-fast:\{fast}ms;--mv-dur:\{base}ms;--mv-dur-slow:\{slow}ms;--mv-dur-tick:\{tick}ms;--mv-stagger:\{stagger}ms;--mv-stagger-max:\{stagger_max}ms;--mv-ease:\{Easing::css_value(EaseInOut)};--mv-out:\{Easing::css_value(EaseOut)};--mv-spring:\{Easing::css_value(Spring(1.0))}}"
}

///|
/// 默认令牌表的动效 CSS（无项目上下文时的等价入口）。
pub fn motion_tokens_css() -> String {
  motion_tokens_css_for(DesignTokens::default())
}

///|
/// 项目级动效令牌 CSS：导出面与 wasm 快照的唯一取值入口。
pub fn Project::motion_tokens_css(self : Project) -> String {
  motion_tokens_css_for(self.tokens)
}

///|
/// 令牌表中的毫秒刻度；缺项/非正值回退内置常量（0 时长会让动画瞬跳）。
fn motion_ms(tokens : DesignTokens, key : String, fallback : Int) -> Int {
  match tokens.resolve_motion(key) {
    Some(v) => if v > 0.0 { v.to_int() } else { fallback }
    None => fallback
  }
}

///|
/// 入场阶梯规则：第 2 到第 MOTION_STAGGER_STEPS-1 个节点按
/// `calc(var(--mv-stagger) * k)` 逐级递增，第 MOTION_STAGGER_STEPS 个起
/// 饱和到 `var(--mv-stagger-max)`。
///
/// 用 CSS 变量 + calc 而不是把毫秒写死：节拍与饱和上限只有
/// motion_tokens_css 一个来源，改刻度不必回来同步导出层。
/// base 为节点选择器前缀，indent 为每条规则行首缩进（导出 CSS 排版）。
pub fn motion_stagger_css(base : String, indent? : String = "") -> String {
  let sb = StringBuilder::new()
  let mut i = 2
  while i < MOTION_STAGGER_STEPS {
    let k = (i - 1).to_string()
    sb.write_string(
      indent +
      base +
      ":nth-of-type(\{i}){animation-delay:calc(var(--mv-stagger) * \{k})}\n",
    )
    i = i + 1
  }
  sb.write_string(
    indent +
    base +
    ":nth-of-type(n+\{MOTION_STAGGER_STEPS}){animation-delay:var(--mv-stagger-max)}\n",
  )
  sb.to_string()
}

///|
/// 数值插值：根据缓动函数计算 t 时刻的值
pub fn interpolate(
  start : Double,
  end : Double,
  t : Double,
  easing : Easing,
) -> Double {
  let clamped_t = if t < 0.0 { 0.0 } else if t > 1.0 { 1.0 } else { t }
  let eased = match easing {
    Linear => clamped_t
    EaseIn => clamped_t * clamped_t
    EaseOut => 1.0 - (1.0 - clamped_t) * (1.0 - clamped_t)
    EaseInOut =>
      if clamped_t < 0.5 {
        2.0 * clamped_t * clamped_t
      } else {
        1.0 - 2.0 * (1.0 - clamped_t) * (1.0 - clamped_t)
      }
    Spring(k) => {
      // 简化弹簧：sin 衰减
      let freq = if k > 0.0 { k * 10.0 } else { 10.0 }
      let decay = 1.0 / (1.0 + freq * clamped_t)
      clamped_t + decay * (clamped_t * clamped_t - clamped_t) * 0.5
    }
    Bounce =>
      // 简化弹跳
      if clamped_t < 0.5 {
        2.0 * clamped_t * clamped_t
      } else {
        1.0 - (1.0 - clamped_t) * (1.0 - clamped_t) * 4.0 * 0.5
      }
    None => if clamped_t >= 1.0 { 1.0 } else { 0.0 }
  }
  start + (end - start) * eased
}

// ---------------------------------------------------------------------------
// 可动画属性
// ---------------------------------------------------------------------------

///|
pub(all) enum AnimatableProperty {
  AnimFill(String) // 颜色
  AnimOpacity(Double) // 透明度
  AnimX(Double) // X 位置
  AnimY(Double) // Y 位置
  AnimWidth(Double) // 宽度
  AnimHeight(Double) // 高度
  AnimRadius(Double) // 圆角
  AnimFontSize(Double) // 字号
}

///|
pub fn AnimatableProperty::name(self : AnimatableProperty) -> String {
  match self {
    AnimFill(_) => "fill"
    AnimOpacity(_) => "opacity"
    AnimX(_) => "x"
    AnimY(_) => "y"
    AnimWidth(_) => "width"
    AnimHeight(_) => "height"
    AnimRadius(_) => "border-radius"
    AnimFontSize(_) => "font-size"
  }
}

///|
/// 属性值的数值表示（用于插值；颜色返回 -1 表示不支持数值插值）
pub fn AnimatableProperty::to_double(self : AnimatableProperty) -> Double {
  match self {
    AnimFill(_) => -1.0 // 颜色不能直接数值插值
    AnimOpacity(v) => v
    AnimX(v) => v
    AnimY(v) => v
    AnimWidth(v) => v
    AnimHeight(v) => v
    AnimRadius(v) => v
    AnimFontSize(v) => v
  }
}

// ---------------------------------------------------------------------------
// 关键帧
// ---------------------------------------------------------------------------

///|
pub(all) struct Keyframe {
  time : Double // 秒
  properties : Array[AnimatableProperty]
}

///|
pub(all) struct AnimationClip {
  node_id : String
  keyframes : Array[Keyframe]
  mut easing : Easing
  mut duration : Double
  mut delay : Double
}

///|
pub fn AnimationClip::new(node_id : String) -> AnimationClip {
  { node_id, keyframes: [], easing: EaseOut, duration: 0.3, delay: 0.0, }
}

///|
pub fn AnimationClip::add_keyframe(
  self : AnimationClip,
  time : Double,
  props : Array[AnimatableProperty],
) -> Unit {
  self.keyframes.push({ time, properties: props, })
}

// ---------------------------------------------------------------------------
// 时间线（编排多条动画）
// ---------------------------------------------------------------------------

///|
pub(all) struct Timeline {
  clips : Array[AnimationClip]
  mut total_duration : Double
}

///|
pub fn Timeline::new() -> Timeline {
  { clips: [], total_duration: 0.0, }
}

///|
pub fn Timeline::add(self : Timeline, clip : AnimationClip) -> Unit {
  let end = clip.delay + clip.duration
  if end > self.total_duration {
    self.total_duration = end
  }
  self.clips.push(clip)
}

///|
/// 并行添加（同时开始）
pub fn Timeline::add_parallel(
  self : Timeline,
  clips : Array[AnimationClip],
) -> Unit {
  for c in clips.iter() {
    self.add(c)
  }
}

///|
/// 顺序添加（依次执行）
pub fn Timeline::add_sequence(
  self : Timeline,
  clips : Array[AnimationClip],
) -> Unit {
  let mut offset = self.total_duration
  for c in clips.iter() {
    let adjusted : AnimationClip = { ..c, delay: offset, }
    self.add(adjusted)
    offset = offset + c.duration
  }
}

// ---------------------------------------------------------------------------
// CSS 动画导出
// ---------------------------------------------------------------------------

///|
/// 单个裁剪 → @keyframes 文本（Timeline::to_css 与节点级 motion 共用）。
///
/// 位移分量合并为单条 transform：同帧 AnimX+AnimY 各写一条会互相覆盖
/// （CSS 声明级覆盖），位移只剩后写的轴。颜色帧写 SVG 的 fill
/// （background-color 对 SVG 图形不生效）。
fn write_clip_keyframes(
  sb : StringBuilder,
  anim_name : String,
  clip : AnimationClip,
  indent? : String = "",
) -> Unit {
  sb.write_string(indent + "@keyframes " + anim_name + " {\n")
  for kf in clip.keyframes.iter() {
    let pct = if clip.duration > 0.0 {
      (kf.time / clip.duration * 100.0).to_int().to_string()
    } else {
      "0"
    }
    sb.write_string(indent + "  " + pct + "% {\n")
    let moves : Array[String] = []
    for prop in kf.properties.iter() {
      match prop {
        AnimX(v) => moves.push("translateX(\{v.to_int()}px)")
        AnimY(v) => moves.push("translateY(\{v.to_int()}px)")
        _ => ()
      }
    }
    if moves.length() > 0 {
      sb.write_string(indent + "    transform: " + moves.join(" ") + ";\n")
    }
    for prop in kf.properties.iter() {
      match prop {
        AnimFill(hex) => sb.write_string(indent + "    fill: " + hex + ";\n")
        AnimOpacity(v) => {
          let vs = v.to_string()
          sb.write_string(indent + "    opacity: " + vs + ";\n")
        }
        AnimWidth(v) => {
          let vs = v.to_int().to_string()
          sb.write_string(indent + "    width: " + vs + "px;\n")
        }
        AnimHeight(v) => {
          let vs = v.to_int().to_string()
          sb.write_string(indent + "    height: " + vs + "px;\n")
        }
        AnimRadius(v) => {
          let vs = v.to_int().to_string()
          sb.write_string(indent + "    border-radius: " + vs + "px;\n")
        }
        AnimFontSize(v) => {
          let vs = v.to_int().to_string()
          sb.write_string(indent + "    font-size: " + vs + "px;\n")
        }
        _ => () // AnimX/AnimY 已在上方合并
      }
    }
    sb.write_string(indent + "  }\n")
  }
  sb.write_string(indent + "}\n\n")
}

///|
/// 生成 CSS @keyframes + animation 属性。
///
/// target 选择器对齐 SVG DOM 的实际 id（render_svg 写 `id="n_<id>"`）——
/// 此前输出 `#<id>`，落到导出原型上永远匹配不到节点，anim-css 生成的
/// CSS 是死代码。
pub fn Timeline::to_css(self : Timeline) -> String {
  let sb = StringBuilder::new()
  for i in 0..<self.clips.length() {
    let clip = self.clips[i]
    let anim_name = "anim_" + clip.node_id + "_" + i.to_string()
    write_clip_keyframes(sb, anim_name, clip)
    let dur_ms = (clip.duration * 1000.0).to_int().to_string()
    let delay_ms = (clip.delay * 1000.0).to_int().to_string()
    let easing = clip.easing.css_value()
    sb.write_string(
      "#n_" +
      clip.node_id +
      " {\n  animation: " +
      anim_name +
      " " +
      dur_ms +
      "ms " +
      easing +
      " " +
      delay_ms +
      "ms forwards;\n}\n\n",
    )
  }
  sb.to_string()
}

// ---------------------------------------------------------------------------
// 节点级 motion：声明面（NodeStyle.motion）→ 导出 CSS
// ---------------------------------------------------------------------------

///|
/// 节点级 motion 白名单：只放行单节点播放且不含写死几何的预设。
/// press / pop / modal_present（120×44、844px 起点一类）与
/// slide_in_right（390px 起点）在参数化前不开放——节点尺寸任意，
/// 写死几何会在不同节点上跳变。
pub fn motion_node_safe_presets() -> Array[String] {
  ["fade_in"]
}

///|
/// 校验节点级 motion：空串 = 无动画；白名单内 = Ok；
/// 已知但非节点安全 → Err(motion_preset_not_node_safe: …)；
/// 未知 → Err(unknown_motion_preset: …)。
pub fn validate_node_motion(preset : String) -> Result[String, String] {
  if preset == "" {
    return Ok("")
  }
  for p in motion_node_safe_presets().iter() {
    if p == preset {
      return Ok(preset)
    }
  }
  for p in [
    "press", "fade_in", "slide_in_right", "modal_present", "shake", "pop",
  ].iter() {
    if p == preset {
      return Err("motion_preset_not_node_safe: " + preset)
    }
  }
  Err("unknown_motion_preset: " + preset)
}

///|
/// 预设名 → 裁剪（节点级导出用；未知预设返回 None）。
fn motion_clip_for(preset : String) -> AnimationClip? {
  match preset {
    "fade_in" => Some(fade_in_animation(""))
    "slide_in_right" => Some(slide_in_right(""))
    "modal_present" => Some(modal_present(""))
    "shake" => Some(shake_animation(""))
    "pop" => Some(pop_animation(""))
    "press" => Some(press_animation(""))
    _ => None
  }
}

///|
/// 节点级 motion 的 @keyframes（每预设一份，导出层做去重）。
/// 时长/曲线不写进 keyframes：节点规则用 var(--mv-dur) 取令牌。
pub fn node_motion_keyframes_css(
  preset : String,
  indent? : String = "",
) -> String {
  match motion_clip_for(preset) {
    None => ""
    Some(clip) => {
      let sb = StringBuilder::new()
      write_clip_keyframes(sb, "mv-p-" + preset, clip, indent~)
      sb.to_string()
    }
  }
}

///|
/// 节点级 motion 的曲线引用：引擎三条曲线走 :root 令牌（--mv-out/
/// --mv-ease/--mv-spring），其余（Linear/Bounce…）用字面量 css_value。
fn easing_css_ref(easing : Easing) -> String {
  match easing {
    EaseOut => "var(--mv-out)"
    EaseInOut => "var(--mv-ease)"
    Spring(_) => "var(--mv-spring)"
    _ => easing.css_value()
  }
}

///|
/// 节点级 motion 规则：`#n_<id>{animation:mv-p-<preset> var(--mv-dur) … backwards}`。
/// 选择器对齐 render_svg 的 DOM id，节拍/曲线都走 :root 令牌
/// （spec/主题可覆盖）。
pub fn node_motion_rule_css(
  node_id : String,
  preset : String,
  indent? : String = "",
) -> String {
  match motion_clip_for(preset) {
    None => ""
    Some(clip) =>
      indent +
      "#n_" +
      node_id +
      "{animation:mv-p-" +
      preset +
      " var(--mv-dur) " +
      easing_css_ref(clip.easing) +
      " backwards}\n"
  }
}

// ---------------------------------------------------------------------------
// 常见动画预设
// ---------------------------------------------------------------------------

///|
/// 按钮按压效果：缩小到 0.95 再弹回
pub fn press_animation(node_id : String) -> AnimationClip {
  let clip = AnimationClip::new(node_id)
  clip.easing = Spring(0.5)
  clip.duration = 0.2
  clip.add_keyframe(0.0, [AnimWidth(120.0), AnimHeight(44.0)])
  clip.add_keyframe(0.1, [AnimWidth(114.0), AnimHeight(42.0)])
  clip.add_keyframe(0.2, [AnimWidth(120.0), AnimHeight(44.0)])
  clip
}

///|
/// 淡入效果
pub fn fade_in_animation(
  node_id : String,
  duration? : Double = 0.3,
) -> AnimationClip {
  let clip = AnimationClip::new(node_id)
  clip.easing = EaseOut
  clip.duration = duration
  clip.add_keyframe(0.0, [AnimOpacity(0.0)])
  clip.add_keyframe(duration, [AnimOpacity(1.0)])
  clip
}

///|
/// 滑入效果（从右侧）
pub fn slide_in_right(node_id : String) -> AnimationClip {
  let clip = AnimationClip::new(node_id)
  clip.easing = EaseOut
  clip.duration = 0.3
  clip.add_keyframe(0.0, [AnimX(390.0), AnimOpacity(0.0)])
  clip.add_keyframe(0.3, [AnimX(0.0), AnimOpacity(1.0)])
  clip
}

///|
/// 弹出效果（modal）
pub fn modal_present(node_id : String) -> AnimationClip {
  let clip = AnimationClip::new(node_id)
  clip.easing = Spring(0.7)
  clip.duration = 0.35
  clip.add_keyframe(0.0, [AnimY(844.0), AnimOpacity(0.0)])
  clip.add_keyframe(0.35, [AnimY(200.0), AnimOpacity(1.0)])
  clip
}

///|
/// 抖动效果（错误提示）
pub fn shake_animation(node_id : String) -> AnimationClip {
  let clip = AnimationClip::new(node_id)
  clip.easing = EaseInOut
  clip.duration = 0.4
  clip.add_keyframe(0.0, [AnimX(0.0)])
  clip.add_keyframe(0.1, [AnimX(-10.0)])
  clip.add_keyframe(0.2, [AnimX(10.0)])
  clip.add_keyframe(0.3, [AnimX(-5.0)])
  clip.add_keyframe(0.4, [AnimX(0.0)])
  clip
}

///|
/// 缩放弹出（成功反馈）
pub fn pop_animation(node_id : String) -> AnimationClip {
  let clip = AnimationClip::new(node_id)
  clip.easing = Spring(1.0)
  clip.duration = 0.3
  clip.add_keyframe(0.0, [AnimWidth(0.0), AnimHeight(0.0)])
  clip.add_keyframe(0.2, [AnimWidth(130.0), AnimHeight(50.0)])
  clip.add_keyframe(0.3, [AnimWidth(120.0), AnimHeight(48.0)])
  clip
}

// ---------------------------------------------------------------------------
// 边界入口：预设动画 → CSS（CLI/MCP 共用）
// ---------------------------------------------------------------------------

///|
/// 预设动画清单（anim-list / animation_presets）。
pub fn animation_presets_json() -> String {
  let names = [
    "press", "fade_in", "slide_in_right", "modal_present", "shake", "pop",
  ]
  let items : Array[String] = []
  for n in names.iter() {
    items.push("\"\{n}\"")
  }
  let joined = items.join(",")
  "{\"ok\":true,\"presets\":[\{joined}]}"
}

///|
/// 按预设生成单节点 CSS 动画（anim-css / animation_css）：
/// `animation_css(node_id, preset)` → { ok, css } 完整 @keyframes + class。
pub fn animation_css(node_id : String, preset : String) -> String {
  let clip = match preset {
    "press" => Some(press_animation(node_id))
    "fade_in" => Some(fade_in_animation(node_id))
    "slide_in_right" => Some(slide_in_right(node_id))
    "modal_present" => Some(modal_present(node_id))
    "shake" => Some(shake_animation(node_id))
    "pop" => Some(pop_animation(node_id))
    _ => None
  }
  match clip {
    None =>
      "{\"ok\":false,\"error\":\"unknown_preset: \{preset}（press/fade_in/slide_in_right/modal_present/shake/pop）\"}"
    Some(c) => {
      let tl = Timeline::new()
      tl.add(c)
      "{\"ok\":true,\"node\":\"\{node_id}\",\"preset\":\"\{preset}\",\"css\":\"\{json_escape(tl.to_css())}\"}"
    }
  }
}
