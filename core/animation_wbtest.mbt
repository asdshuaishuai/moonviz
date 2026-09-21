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
