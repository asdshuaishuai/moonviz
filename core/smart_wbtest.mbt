// 设计智能 + 血缘追踪 + 原型测试

///|
test "设计智能：推断页面类型" {
  let p = Project::new()
  // 登录页（有多个输入框 + 按钮）
  let _ = p.apply_template(template_id="login")
  match p.infer_page_type(artboard="login") {
    Ok(json) => assert_true(json.contains("\"auth\""))
    Err(_) => assert_true(false)
  }
  // 仪表盘
  let _ = p.apply_template(template_id="dashboard")
  match p.infer_page_type(artboard="dashboard") {
    Ok(json) => assert_true(json.contains("\"dashboard\""))
    Err(_) => assert_true(false)
  }
}

///|
test "设计智能：推断缺失元素" {
  let p = Project::new()
  let _ = p.apply_template(template_id="login")
  match p.infer_missing(artboard="login") {
    Ok(json) => {
      assert_true(json.contains("\"page_type\""))
      assert_true(json.contains("\"missing_count\""))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "设计智能：改进建议 + 质量评分" {
  let p = Project::new()
  let _ = p.apply_template(template_id="dashboard")
  // 改进建议
  match p.suggest_improvements(artboard="dashboard") {
    Ok(json) => assert_true(json.contains("\"suggestions\""))
    Err(_) => assert_true(false)
  }
  // 质量评分
  match p.design_quality_score(artboard="dashboard") {
    Ok(json) => {
      assert_true(json.contains("\"total\""))
      assert_true(json.contains("\"grade\""))
      assert_true(json.contains("\"hierarchy\""))
      assert_true(json.contains("\"stability\""))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "血缘追踪：令牌使用" {
  let p = Project::new()
  let _ = p.apply_template(template_id="login")
  match p.token_lineage(token_name="primary") {
    Ok(json) => {
      assert_true(json.contains("\"primary\""))
      assert_true(json.contains("\"usage_count\""))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "血缘追踪：组件实例" {
  let p = Project::new()
  let _ = p.apply_template(template_id="login")
  match p.component_lineage(component_id="button") {
    Ok(json) => {
      assert_true(json.contains("\"button\""))
      assert_true(json.contains("\"instance_count\""))
      assert_true(json.contains("\"login_btn\""))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "设计系统审计" {
  let p = Project::new()
  let _ = p.apply_template(template_id="login")
  let audit = p.audit_design_system()
  assert_true(audit.contains("\"total_issues\""))
}

///|
test "原型测试：导航断言" {
  let p = Project::new()
  let _ = p.create_artboard(name="login", width=390.0, height=844.0)
  let _ = p.create_artboard(name="home", width=390.0, height=844.0)
  let _ = p.place_component(
    artboard="login",
    component_id="button",
    instance_id="go_btn",
    x=100.0,
    y=400.0,
  )
  p.add_flow(from="login", to="home", trigger="tap:go_btn")

  match ProtoTest::create(p, initial="login") {
    Ok(pt) => {
      // 点击按钮应导航到 home
      assert_true(pt.tap_and_expect_navigate(160.0, 422.0, "home"))
      // 返回应回到 login
      assert_true(pt.back_and_expect("login"))
      // 渲染应可执行
      assert_true(pt.expect_renderable())
      // 测试结果
      let result = pt.result()
      assert_true(result.contains("\"PASS\""))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "原型测试：输入断言" {
  let p = Project::new()
  let _ = p.create_artboard(name="form")
  let _ = p.place_component(
    artboard="form",
    component_id="text_input",
    instance_id="email",
  )

  match ProtoTest::create(p, initial="form") {
    Ok(pt) => {
      assert_true(pt.set_input_and_expect("email", "test@example.com"))
      assert_true(pt.expect_no_violations())
      assert_true(pt.is_pass())
    }
    Err(_) => assert_true(false)
  }
}

///|
test "Agent 超级工作流：模板→智能分析→血缘→测试→导出" {
  let p = Project::new()

  // 1) 创建设计
  let login = match p.apply_template(template_id="login") {
    Ok(id) => id
    Err(_) => {
      assert_true(false)
      return
    }
  }

  // 2) 页面类型推断
  let _ = p.infer_page_type(artboard=login)

  // 3) 缺失元素检测
  let _ = p.infer_missing(artboard=login)

  // 4) 改进建议
  let _ = p.suggest_improvements(artboard=login)

  // 5) 质量评分
  let _ = p.design_quality_score(artboard=login)

  // 6) 令牌血缘
  let _ = p.token_lineage(token_name="primary")

  // 7) 组件血缘
  let _ = p.component_lineage(component_id="button")

  // 8) 设计系统审计
  let _ = p.audit_design_system()

  // 9) 原型测试
  match ProtoTest::create(p, initial=login) {
    Ok(pt) => {
      let _ = pt.expect_renderable()
      let _ = pt.result()
    }
    Err(_) => ()
  }

  // 10) 导出
  let artifact = p.export_artifact(
    agent_id="super-agent",
    context="Full workflow test",
  )
  assert_true(artifact.contains("super-agent"))
  let html = p.export_html()
  assert_true(html.contains(login))
}
