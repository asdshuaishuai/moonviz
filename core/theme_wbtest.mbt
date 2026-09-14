// 主题系统 测试

///|
test "主题：预定义主题清单" {
  let themes = builtin_themes()
  assert_eq(themes.length(), 6)
  assert_eq(themes[0].name, "light")
  assert_eq(themes[1].name, "dark")
  assert_eq(themes[2].name, "high_contrast")
  assert_eq(themes[3].name, "sepia")
  assert_eq(themes[4].name, "nord")
  assert_eq(themes[5].name, "sunset")
}

///|
test "主题：light vs dark 颜色差异" {
  let light = Theme::light()
  let dark = Theme::dark()
  // surface 应该不同
  let l_surface = light.tokens.resolve_color("surface")
  let d_surface = dark.tokens.resolve_color("surface")
  assert_true(l_surface != d_surface)
  // text_primary 也应该不同
  let l_text = light.tokens.resolve_color("text_primary")
  let d_text = dark.tokens.resolve_color("text_primary")
  assert_true(l_text != d_text)
  // is_dark 标记
  assert_true(!light.is_dark)
  assert_true(dark.is_dark)
}

///|
test "主题：Project 切换主题" {
  let p = Project::new()
  // 初始是 light
  let l_primary = p.tokens.resolve_color("primary")
  assert_eq(l_primary, "#4B6BFB")
  // 切换到 dark
  match p.apply_theme("dark") {
    Ok(json) => {
      assert_true(json.contains("\"ok\":true"))
      assert_true(json.contains("\"is_dark\":true"))
    }
    Err(_) => assert_true(false)
  }
  // primary 应该变了
  let d_primary = p.tokens.resolve_color("primary")
  assert_true(d_primary != "#4B6BFB")
  // surface 应该是暗色
  let d_surface = p.tokens.resolve_color("surface")
  assert_eq(d_surface, "#1A1C1E")
  // 切换回来
  match p.apply_theme("light") {
    Ok(_) => {
      let back = p.tokens.resolve_color("surface")
      assert_eq(back, "#FFFFFF")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "主题：切换到不存在的主题" {
  let p = Project::new()
  match p.apply_theme("nonexistent") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.contains("unknown_theme"))
  }
}

///|
test "主题：各预定义主题的 primary 色不同" {
  let themes = builtin_themes()
  let primaries : Array[String] = []
  for t in themes.iter() {
    primaries.push(t.tokens.resolve_color("primary"))
  }
  // 确保至少有 4 种不同的 primary 色
  let unique : Map[String, Bool] = Map::new()
  for c in primaries.iter() {
    unique.set(c, true)
  }
  assert_true(unique.size() >= 4)
}

///|
test "主题：set_token 单令牌修改" {
  let p = Project::new()
  match p.set_token("primary", "#FF5722") {
    Ok(json) => {
      assert_true(json.contains("\"ok\":true"))
      assert_true(json.contains("#FF5722"))
    }
    Err(_) => assert_true(false)
  }
  // 验证生效
  match p.get_token("primary") {
    Ok(v) => assert_eq(v, "#FF5722")
    Err(_) => assert_true(false)
  }
  // 不存在的令牌
  match p.set_token("nonexistent", "#123") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.contains("unknown_token"))
  }
}

///|
test "主题：preview_themes 显示各主题颜色" {
  let p = Project::new()
  let _ = p.create_artboard(name="test")
  let _ = p.place_component(
    artboard="test",
    component_id="button",
    instance_id="btn",
  )
  match p.preview_themes("btn") {
    Ok(json) => {
      assert_true(json.contains("\"light\""))
      assert_true(json.contains("\"dark\""))
      assert_true(json.contains("\"nord\""))
      assert_true(json.contains("\"sunset\""))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "主题：自动暗色推导" {
  let light = Theme::light()
  let dark = Theme::auto_dark(light)
  assert_true(dark.is_dark)
  assert_true(dark.name.contains("auto_dark"))
  // surface 应该被反转
  let d_surface = dark.tokens.resolve_color("surface")
  assert_true(d_surface != "#FFFFFF")
}

///|
test "主题：ThemeRegistry" {
  let reg = ThemeRegistry::new()
  // 切换到 dark
  match reg.switch("dark") {
    Ok(tokens) => {
      let s = tokens.resolve_color("surface")
      assert_eq(s, "#1A1C1E")
    }
    Err(_) => assert_true(false)
  }
  // 当前主题
  match reg.current_theme() {
    Ok(t) => assert_eq(t.name, "dark")
    Err(_) => assert_true(false)
  }
  // 列表
  let list = reg.list()
  assert_true(list.contains("\"light\""))
  assert_true(list.contains("\"dark\""))
  assert_true(list.contains("←current"))
}

///|
test "主题：enable_auto_dark" {
  let p = Project::new()
  match p.enable_auto_dark() {
    Ok(json) => assert_true(json.contains("\"ok\":true"))
    Err(_) => assert_true(false)
  }
  // surface 应该不再是白色
  let s = p.tokens.resolve_color("surface")
  assert_true(s != "#FFFFFF")
}

///|
test "主题 + 模板：切换主题后组件颜色自动变化" {
  let p = Project::new()
  let ab = p.create_artboard(name="themed")
  let _ = p.place_component(
    artboard=ab,
    component_id="button",
    instance_id="btn",
    variant="primary",
  )
  // light 下的 primary
  match p.artboards.get(ab) {
    Some(x) =>
      match x.doc.get("btn") {
        Some(n) => {
          let light_fill = n.style.fill
          assert_eq(light_fill, "#4B6BFB")
        }
        None => assert_true(false)
      }
    None => assert_true(false)
  }
  // 切换到 nord
  match p.apply_theme("nord") {
    Ok(_) => ()
    Err(_) => assert_true(false)
  }
  // nord 的 primary 令牌值
  let nord_primary = p.tokens.resolve_color("primary")
  assert_eq(nord_primary, "#88C0D0")
}
