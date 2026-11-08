///|
/// animation 边界入口：预设清单 + CSS 生成。
test "animation：presets 清单含 6 个预设" {
  let json = animation_presets_json()
  assert_true(json.contains("\"press\""))
  assert_true(json.contains("\"pop\""))
  assert_true(json.contains("\"fade_in\""))
}

///|
test "animation：animation_css 生成合法 CSS 信封" {
  let json = animation_css("title", "fade_in")
  assert_true(json.contains("\"ok\":true"))
  assert_true(json.contains("@keyframes") || json.contains("animation"))
  assert_true(json.contains("title"))
  let bad = animation_css("title", "nope")
  assert_true(bad.contains("unknown_preset"))
}

///|
/// 选择器对齐 SVG DOM 的实际 id（render_svg 写 id="n_<id>"）：此前 to_css
/// 输出 #<id>，落到导出原型上永远匹配不到节点，anim-css 生成的是死代码。
test "animation：to_css 选择器对齐 n_ 前缀" {
  let tl = Timeline::new()
  tl.add(fade_in_animation("title"))
  let css = tl.to_css()
  assert_true(css.contains("#n_title"))
  assert_false(css.contains("#title {"))
}

///|
/// 颜色帧写 SVG 的 fill：节点是 <g>/<rect>，CSS background-color 对 SVG
/// 图形不生效（此前 AnimFill 注出 background-color，颜色动画从未生效）。
test "animation：AnimFill 输出 SVG fill 声明" {
  let clip = AnimationClip::new("title")
  clip.add_keyframe(0.0, [AnimFill("#FF0000")])
  clip.add_keyframe(0.3, [AnimFill("#00FF00")])
  let tl = Timeline::new()
  tl.add(clip)
  let css = tl.to_css()
  assert_true(css.contains("fill: #FF0000"))
  assert_false(css.contains("background-color"))
}

///|
/// 同帧 X+Y 合并为单条 transform：两条 transform 声明会互相覆盖
/// （CSS 声明级覆盖），位移只剩后写的轴——此前 AnimX+AnimY 同帧只能动一个轴。
test "animation：同帧 X+Y 合并为单条 transform" {
  let clip = AnimationClip::new("title")
  clip.add_keyframe(0.0, [AnimX(10.0), AnimY(20.0)])
  let tl = Timeline::new()
  tl.add(clip)
  let css = tl.to_css()
  assert_true(css.contains("transform: translateX(10px) translateY(20px);"))
  assert_eq(count_occurrences(css, "transform:"), 1)
}
