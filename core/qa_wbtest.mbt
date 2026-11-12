// issue #25 / #26 回归锚：交互 QA 软检测 + AgentGate 冲突硬门。

///|
test "qa：可交互组件无去向被报，绑 flow 后消失（issue #25-A1）" {
  let p = Project::new()
  let _ = p.create_artboard(name="qa_a", width=390.0, height=400.0)
  let _ = p.create_artboard(name="qa_b", width=390.0, height=400.0)
  let _ = p.place_component(
    artboard="qa_a",
    component_id="button",
    instance_id="go_btn",
    x=20.0,
    y=20.0,
  )
  let issues1 = p.qa_issues(artboard="qa_a")
  let mut joined1 = ""
  for s in issues1.iter() {
    joined1 = joined1 + s + "\n"
  }
  assert_true(
    joined1.contains("go_btn"),
    msg="未绑按钮必须被报：\{joined1}",
  )
  assert_true(
    joined1.contains("无去向"),
    msg="报告必须说明无去向：\{joined1}",
  )
  // 绑定 flow 后不再报
  let _ = apply_operation(p, "flow qa_a qa_b go_btn")
  let issues2 = p.qa_issues(artboard="qa_a")
  let mut joined2 = ""
  for s in issues2.iter() {
    joined2 = joined2 + s + "\n"
  }
  assert_true(
    !joined2.contains("go_btn"),
    msg="已绑按钮不应再报：\{joined2}",
  )
}

///|
test "qa：占位符残留与空壳容器被报（issue #25-B4/B5）" {
  let p = Project::new()
  let _ = p.create_artboard(name="qa_c", width=390.0, height=400.0)
  let _ = p.place_component(
    artboard="qa_c",
    component_id="heading",
    instance_id="ph_title",
    x=20.0,
    y=20.0,
  )
  let _ = apply_operation(p, "update qa_c ph_title text=占位标题")
  let _ = p.place_component(
    artboard="qa_c",
    component_id="card",
    instance_id="empty_card",
    x=20.0,
    y=80.0,
    w=200.0,
    h=100.0,
  )
  let issues = p.qa_issues(artboard="qa_c")
  let mut joined = ""
  for s in issues.iter() {
    joined = joined + s + "\n"
  }
  assert_true(
    joined.contains("ph_title"),
    msg="占位符文本必须被报：\{joined}",
  )
  assert_true(
    joined.contains("empty_card"),
    msg="空壳容器必须被报：\{joined}",
  )
}

///|
test "qa：非组件库组件被报（issue #26-B5）" {
  let p = Project::new()
  let _ = p.create_artboard(name="qa_x", width=390.0, height=400.0)
  match p.artboards.get("qa_x") {
    None => assert_true(false)
    Some(ab) => {
      let node = {
        ..Node::make("bogus", Rect),
        component: "widget-x",
        width: Fixed(100.0),
        height: Fixed(40.0),
      }
      let _ = ab.doc.insert_node(node, "root")
      let issues = p.qa_issues(artboard="qa_x")
      let mut joined = ""
      for s in issues.iter() {
        joined = joined + s + "\n"
      }
      assert_true(
        joined.contains("非组件库组件"),
        msg="非库组件必须被报：\{joined}",
      )
      assert_true(
        joined.contains("widget-x"),
        msg="报告必须点名组件：\{joined}",
      )
    }
  }
}

///|
test "qa：同一节点多条 flow → AgentGate 冲突定位（issue #25-A3）" {
  let p = Project::new()
  let _ = p.create_artboard(name="qa_d", width=390.0, height=400.0)
  let _ = p.create_artboard(name="qa_e", width=390.0, height=400.0)
  let _ = p.place_component(
    artboard="qa_d",
    component_id="button",
    instance_id="dup_btn",
    x=20.0,
    y=20.0,
  )
  let _ = apply_operation(p, "flow qa_d qa_e dup_btn")
  let _ = apply_operation(p, "flow qa_d qa_d dup_btn")
  match p.qa_agent_conflicts() {
    Ok(_) => assert_true(false, msg="同一节点多条 flow 必须判冲突")
    Err(e) =>
      assert_true(
        e.contains("interaction_conflict") && e.contains("dup_btn"),
        msg="冲突必须给出定位：\{e}",
      )
  }
}

///|
test "qa：可点热区相交 → hotzone_overlap 定位（issue #26-A3）" {
  let p = Project::new()
  let _ = p.create_artboard(name="qa_f", width=390.0, height=400.0)
  let _ = p.create_artboard(name="qa_g", width=390.0, height=400.0)
  let _ = p.place_component(
    artboard="qa_f",
    component_id="button",
    instance_id="btn1",
    x=20.0,
    y=20.0,
  )
  let _ = p.place_component(
    artboard="qa_f",
    component_id="button",
    instance_id="btn2",
    x=30.0,
    y=30.0,
  )
  let _ = apply_operation(p, "flow qa_f qa_g btn1")
  let _ = apply_operation(p, "flow qa_f qa_g btn2")
  match p.qa_agent_conflicts() {
    Ok(_) => assert_true(false, msg="可点热区相交必须判冲突")
    Err(e) =>
      assert_true(
        e.contains("hotzone_overlap"),
        msg="热区冲突必须给出定位：\{e}",
      )
  }
}
