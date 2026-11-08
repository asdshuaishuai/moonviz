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

///|
/// 动效令牌声明面：Project::motion_tokens_css 从 DesignTokens.motion 取值，
/// 六个刻度都可被 set_token 覆盖；未知 motion.foo 报错且不落值。
test "animation：项目动效令牌覆盖六刻度" {
  let p = Project::new()
  let pairs : Array[(String, String, String)] = [
    ("fast", "100", "--mv-dur-fast:100ms"),
    ("base", "320", "--mv-dur:320ms"),
    ("slow", "480", "--mv-dur-slow:480ms"),
    ("tick", "200", "--mv-dur-tick:200ms"),
    ("stagger", "40", "--mv-stagger:40ms"),
    ("stagger_max", "280", "--mv-stagger-max:280ms"),
  ]
  for pair in pairs.iter() {
    let (key, value, _) = pair
    match p.set_token("motion." + key, value) {
      Ok(_) => ()
      Err(e) => fail("motion.\{key} 应可设置：\{e}")
    }
  }
  let css = p.motion_tokens_css()
  for pair in pairs.iter() {
    let (_, _, needle) = pair
    assert_true(css.contains(needle), msg="缺少 \{needle}：\{css}")
  }
  // 未知 key：Err 且不落值（默认表里没有 motion.foo）
  match p.set_token("motion.foo", "10") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.contains("unknown_token"))
  }
  assert_false(p.motion_tokens_css().contains("motion.foo"))
  // 非正值也拒绝（0 时长会让动画瞬跳）
  match p.set_token("motion.base", "0") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.contains("invalid_token_value"))
  }
}

///|
/// 默认令牌表 = 常量节拍：motion_tokens_css() 作为无项目上下文的入口
/// 与 MOTION_* 常量同值（既有调用方/首屏导出不吃覆盖）。
test "animation：默认动效令牌与常量同源" {
  let css = motion_tokens_css()
  assert_true(css.contains("--mv-dur-fast:\{MOTION_FAST}ms"))
  assert_true(css.contains("--mv-dur:\{MOTION_BASE}ms"))
  assert_true(css.contains("--mv-dur-slow:\{MOTION_SLOW}ms"))
  assert_true(css.contains("--mv-dur-tick:\{MOTION_TICK}ms"))
  assert_true(css.contains("--mv-stagger:\{MOTION_STAGGER}ms"))
  assert_true(css.contains("--mv-stagger-max:\{MOTION_STAGGER_MAX}ms"))
}

///|
/// 节点级 motion 白名单：fade_in 放行；press/pop/modal_present 的写死几何
/// 在参数化前不开放（明确错误码）；未知预设给 unknown_motion_preset。
test "animation：节点 motion 白名单与错误码" {
  assert_true(validate_node_motion("") == Ok(""))
  assert_true(validate_node_motion("fade_in") == Ok("fade_in"))
  for preset in ["press", "pop", "modal_present", "slide_in_right"].iter() {
    match validate_node_motion(preset) {
      Ok(_) => assert_true(false)
      Err(e) =>
        assert_true(e.contains("motion_preset_not_node_safe"), msg=preset)
    }
  }
  match validate_node_motion("nope") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.contains("unknown_motion_preset"))
  }
  // 导出片段：规则选择器对齐 DOM id，keyframes 名带 mv-p- 前缀
  assert_true(node_motion_keyframes_css("fade_in").contains("@keyframes mv-p-fade_in"))
  assert_true(
    node_motion_rule_css("hero", "fade_in").contains(
      "#n_hero{animation:mv-p-fade_in",
    ),
  )
  assert_eq(node_motion_rule_css("hero", "nope"), "")
}
