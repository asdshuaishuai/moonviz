// 性能基准引擎 测试

///|
test "基准：单画板 benchmark" {
  let p = Project::new()
  let _ = p.apply_template(template_id="login")
  match p.benchmark_artboard(artboard="login") {
    Ok(b) => {
      assert_true(b.node_count > 0)
      assert_true(b.max_depth >= 1)
      assert_true(b.score > 0)
      assert_true(b.score <= 100)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "基准：项目级 benchmark" {
  let p = Project::new()
  let _ = p.apply_template(template_id="login")
  let _ = p.apply_template(template_id="dashboard")
  let result = p.benchmark()
  assert_true(result.artboards.length() >= 2)
  assert_true(result.total_nodes > 0)
  assert_true(result.avg_score > 0.0)
  assert_true(result.grade.length() == 1) // "A" | "B" | "C" | "D"
}

///|
test "基准：节点统计" {
  let p = Project::new()
  let _ = p.apply_template(template_id="login")
  match p.benchmark_artboard(artboard="login") {
    Ok(b) => {
      // 登录模板应有多个节点
      assert_true(b.node_count >= 5)
      // 应有文本节点
      assert_true(b.text_node_count >= 1)
      // 应有总文本长度
      assert_true(b.total_text_length > 0)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "基准：性能评分" {
  let p = Project::new()
  let _ = p.apply_template(template_id="login")
  match p.benchmark_artboard(artboard="login") {
    Ok(b) =>
      // 评分应在合理范围
      assert_true(b.score >= 0 && b.score <= 100)
    Err(_) => assert_true(false)
  }
}

///|
test "基准：反模式检测" {
  let p = Project::new()
  let ab = p.create_artboard(name="antipattern_test", width=390.0, height=844.0)
  // 放很多组件触发 too_many_nodes
  for i in 0..<120 {
    let id = "node_" + i.to_string()
    let _ = p.place_component(
      artboard=ab,
      component_id="divider",
      instance_id=id,
    )
  }
  match p.benchmark_artboard(artboard=ab) {
    Ok(b) => {
      // 120 个节点应该触发 too_many_nodes
      assert_true(b.antipatterns.length() > 0)
      let has_too_many = b.antipatterns
        .iter()
        .any(fn(a) { a.contains("too_many_nodes") })
      assert_true(has_too_many)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "基准：JSON 输出" {
  let p = Project::new()
  let _ = p.apply_template(template_id="login")
  match p.benchmark_artboard(artboard="login") {
    Ok(b) => {
      let json = b.to_json()
      assert_true(json.contains("\"nodes\""))
      assert_true(json.contains("\"depth\""))
      assert_true(json.contains("\"score\""))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "基准：项目 JSON" {
  let p = Project::new()
  let _ = p.apply_template(template_id="login")
  let result = p.benchmark()
  let json = result.to_json()
  assert_true(json.contains("\"total_nodes\""))
  assert_true(json.contains("\"grade\""))
  assert_true(json.contains("\"avg_score\""))
}

///|
test "基准：优化建议" {
  let p = Project::new()
  let _ = p.apply_template(template_id="login")
  match p.suggest_optimizations(artboard="login") {
    Ok(json) =>
      // 模板设计合理，可能没有优化建议
      assert_true(json.contains("\"optimizations\""))
    Err(_) => assert_true(false)
  }
}

///|
test "基准：报告输出" {
  let p = Project::new()
  let _ = p.apply_template(template_id="dashboard")
  let result = p.benchmark()
  let report = result.report()
  assert_true(report.contains("Performance Benchmark Report"))
  assert_true(report.contains("Overall:"))
  assert_true(report.contains("Total nodes:"))
}

///|
test "Agent 全流程：设计→基准→优化建议→报告" {
  let p = Project::new()
  let ab = match p.apply_template(template_id="dashboard") {
    Ok(id) => id
    Err(_) => {
      assert_true(false)
      return
    }
  }
  // 基准
  match p.benchmark_artboard(artboard=ab) {
    Ok(b) => {
      assert_true(b.node_count > 0)
      assert_true(b.layout_complexity > 0)
      assert_true(b.render_complexity > 0)
    }
    Err(_) => assert_true(false)
  }
  // 优化建议
  let _ = p.suggest_optimizations(artboard=ab)
  // 项目级
  let proj_bench = p.benchmark()
  let _ = proj_bench.report()
  let _ = proj_bench.to_json()
}
