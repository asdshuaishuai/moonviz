// 设计标注 + 属性动画 测试

// ── 设计标注 ──

///|
test "标注：生成 Spec 文档" {
  let p = Project::new()
  let _ = p.apply_template(template_id="login")
  match p.generate_spec(artboard="login") {
    Ok(spec) => {
      assert_true(spec.contains("# Design Spec"))
      assert_true(spec.contains("## Components"))
      assert_true(spec.contains("## Colors"))
      assert_true(spec.contains("## Typography"))
      assert_true(spec.contains("## Spacing"))
      assert_true(spec.contains("## Layout"))
      assert_true(spec.contains("## CSS Custom Properties"))
      assert_true(spec.contains("--color-primary"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "标注：Spec JSON（机器可读）" {
  let p = Project::new()
  let _ = p.create_artboard(name="spec_test")
  let _ = p.place_component(
    artboard="spec_test",
    component_id="button",
    instance_id="btn1",
  )
  match p.spec_json(artboard="spec_test") {
    Ok(json) => {
      assert_true(json.contains("\"btn1\""))
      assert_true(json.contains("\"component\":\"button\""))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "标注：颜色令牌匹配" {
  let p = Project::new()
  let _ = p.apply_template(template_id="login")
  match p.generate_spec(artboard="login") {
    Ok(spec) =>
      // primary 色应被标注为令牌
      assert_true(spec.contains("`primary`") || spec.contains("custom"))
    Err(_) => assert_true(false)
  }
}

// ── 属性动画 ──

///|
test "动画：缓动函数插值" {
  // linear: t=0.5 → 0.5
  let lin = interpolate(0.0, 1.0, 0.5, Linear)
  assert_true(lin > 0.45 && lin < 0.55)
  // ease-in: t=0.5 → < 0.5（先慢后快）
  let ein = interpolate(0.0, 1.0, 0.5, EaseIn)
  assert_true(ein < 0.5)
  // ease-out: t=0.5 → > 0.5（先快后慢）
  let eout = interpolate(0.0, 1.0, 0.5, EaseOut)
  assert_true(eout > 0.5)
  // 边界
  let t0 = interpolate(10.0, 20.0, 0.0, Linear)
  assert_eq(t0, 10.0)
  let t1 = interpolate(10.0, 20.0, 1.0, Linear)
  assert_eq(t1, 20.0)
  // 越界 clamp
  let tc = interpolate(0.0, 100.0, 1.5, Linear)
  assert_eq(tc, 100.0)
}

///|
test "动画：CSS 缓动值" {
  assert_eq(Linear.css_value(), "linear")
  assert_eq(EaseIn.css_value(), "cubic-bezier(0.4, 0, 1, 1)")
  assert_eq(EaseOut.css_value(), "cubic-bezier(0, 0, 0.2, 1)")
}

///|
test "动画：AnimationClip 构建" {
  let clip = AnimationClip::new("my_btn")
  clip.easing = Spring(0.5)
  clip.duration = 0.3
  clip.add_keyframe(0.0, [AnimOpacity(0.0)])
  clip.add_keyframe(0.3, [AnimOpacity(1.0)])
  assert_eq(clip.node_id, "my_btn")
  assert_eq(clip.keyframes.length(), 2)
  assert_eq(clip.duration, 0.3)
}

///|
test "动画：Timeline 编排" {
  let tl = Timeline::new()
  let clip1 = fade_in_animation("title")
  let clip2 = slide_in_right("card")
  tl.add(clip1)
  tl.add(clip2)
  assert_eq(tl.clips.length(), 2)
  assert_true(tl.total_duration > 0.0)
}

///|
test "动画：Timeline 顺序编排" {
  let tl = Timeline::new()
  let clip1 = fade_in_animation("a")
  let clip2 = fade_in_animation("b")
  let clips : Array[AnimationClip] = [clip1, clip2]
  tl.add_sequence(clips)
  // 两个动画应按顺序执行
  assert_eq(tl.clips.length(), 2)
  assert_true(tl.clips[1].delay > 0.0) // 第二个有延迟
}

///|
test "动画：生成 CSS" {
  let tl = Timeline::new()
  let clip = press_animation("submit_btn")
  tl.add(clip)
  let css = tl.to_css()
  assert_true(css.contains("@keyframes"))
  assert_true(css.contains("submit_btn"))
  assert_true(css.contains("animation:"))
  assert_true(css.contains("forwards"))
}

///|
test "动画预设：fade_in / slide_in / modal / shake / pop" {
  let fade = fade_in_animation("el1")
  assert_eq(fade.node_id, "el1")
  assert_true(fade.duration > 0.0)
  let slide = slide_in_right("el2")
  assert_true(slide.keyframes.length() >= 2)
  let modal = modal_present("el3")
  assert_true(modal.easing is Spring(_))
  let shake = shake_animation("el4")
  assert_true(shake.keyframes.length() >= 4)
  let pop = pop_animation("el5")
  assert_true(pop.duration > 0.0)
}

///|
test "Agent 全流程：设计→标注→动画→Spec+CSS 输出" {
  let p = Project::new()
  let ab = match p.apply_template(template_id="login") {
    Ok(id) => id
    Err(_) => {
      assert_true(false)
      return
    }
  }
  // 生成标注
  match p.generate_spec(artboard=ab) {
    Ok(spec) => assert_true(spec.contains("Design Spec"))
    Err(_) => assert_true(false)
  }
  // 构建动画
  let tl = Timeline::new()
  tl.add(fade_in_animation("welcome_title"))
  tl.add(slide_in_right("email_input"))
  tl.add(press_animation("login_btn"))
  tl.add_sequence([modal_present("signup_modal"), shake_animation("error_msg")])
  // CSS 输出
  let css = tl.to_css()
  assert_true(css.contains("welcome_title"))
  assert_true(css.contains("email_input"))
  assert_true(css.contains("login_btn"))
  // Spec JSON
  match p.spec_json(artboard=ab) {
    Ok(json) => assert_true(json.length() > 10)
    Err(_) => assert_true(false)
  }
}
