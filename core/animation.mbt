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
  { node_id, keyframes: [], easing: EaseOut, duration: 0.3, delay: 0.0 }
}

///|
pub fn AnimationClip::add_keyframe(
  self : AnimationClip,
  time : Double,
  props : Array[AnimatableProperty],
) -> Unit {
  self.keyframes.push({ time, properties: props })
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
  { clips: [], total_duration: 0.0 }
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
    let adjusted : AnimationClip = { ..c, delay: offset }
    self.add(adjusted)
    offset = offset + c.duration
  }
}

// ---------------------------------------------------------------------------
// CSS 动画导出
// ---------------------------------------------------------------------------

///|
/// 生成 CSS @keyframes + animation 属性
pub fn Timeline::to_css(self : Timeline) -> String {
  let sb = StringBuilder::new()
  for i in 0..<self.clips.length() {
    let clip = self.clips[i]
    let nid = clip.node_id
    let idx = i.to_string()
    let anim_name = "anim_" + nid + "_" + idx
    sb.write_string("@keyframes " + anim_name + " {\n")
    for kf in clip.keyframes.iter() {
      let pct = if clip.duration > 0.0 {
        (kf.time / clip.duration * 100.0).to_int().to_string()
      } else {
        "0"
      }
      sb.write_string("  " + pct + "% {\n")
      for prop in kf.properties.iter() {
        match prop {
          AnimFill(hex) =>
            sb.write_string("    background-color: " + hex + ";\n")
          AnimOpacity(v) => {
            let vs = v.to_string()
            sb.write_string("    opacity: " + vs + ";\n")
          }
          AnimX(v) => {
            let vs = v.to_int().to_string()
            sb.write_string("    transform: translateX(" + vs + "px);\n")
          }
          AnimY(v) => {
            let vs = v.to_int().to_string()
            sb.write_string("    transform: translateY(" + vs + "px);\n")
          }
          AnimWidth(v) => {
            let vs = v.to_int().to_string()
            sb.write_string("    width: " + vs + "px;\n")
          }
          AnimHeight(v) => {
            let vs = v.to_int().to_string()
            sb.write_string("    height: " + vs + "px;\n")
          }
          AnimRadius(v) => {
            let vs = v.to_int().to_string()
            sb.write_string("    border-radius: " + vs + "px;\n")
          }
          AnimFontSize(v) => {
            let vs = v.to_int().to_string()
            sb.write_string("    font-size: " + vs + "px;\n")
          }
        }
      }
      sb.write_string("  }\n")
    }
    sb.write_string("}\n\n")
    let dur_ms = (clip.duration * 1000.0).to_int().to_string()
    let delay_ms = (clip.delay * 1000.0).to_int().to_string()
    let easing = clip.easing.css_value()
    sb.write_string(
      "#" +
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
