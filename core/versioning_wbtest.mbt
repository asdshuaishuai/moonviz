// 设计版本控制 + AI 设计批评 测试

///|
test "版本控制：创建 / 提交 / 历史日志" {
  let doc = Document::sample_login()
  let h = DesignHistory::new(doc)
  assert_eq(h.rev(), 0)

  // 提交一个变更
  let ops : Array[DesignOp] = [OpSetFill("btn-login", "#4B6BFB", "#FF0000")]
  let rev1 = h.commit("agent_a", "改按钮颜色为红色", ops, doc)
  assert_eq(rev1, 1)
  assert_eq(h.rev(), 1)

  // 再提交一个
  let ops2 : Array[DesignOp] = [OpSetGap("root", 16.0, 24.0)]
  let _ = h.commit("agent_b", "增大间距", ops2, doc)
  assert_eq(h.rev(), 2)

  // 历史日志
  let log = h.log()
  assert_true(log.contains("rev2"))
  assert_true(log.contains("rev1"))
  assert_true(log.contains("agent_a"))
  assert_true(log.contains("agent_b"))
  assert_true(log.contains("改按钮颜色"))
  assert_true(log.contains("增大间距"))
}

///|
test "版本控制：时间旅行 checkout" {
  let doc = Document::sample_login()
  let h = DesignHistory::new(doc)
  // 提交两个版本
  let _ = h.commit("a", "v1", [], doc)
  let _ = h.commit("b", "v2", [], doc)
  // checkout 到版本 0
  match h.checkout(0) {
    Ok(d) => assert_true(d.nodes.size() > 0)
    Err(_) => assert_true(false)
  }
  // checkout 到不存在的版本
  match h.checkout(99) {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.contains("not_found"))
  }
}

///|
test "版本控制：undo / redo" {
  let doc = Document::sample_login()
  let h = DesignHistory::new(doc)
  let _ = h.commit("a", "first", [], doc)
  let _ = h.commit("b", "second", [], doc)
  assert_eq(h.rev(), 2)
  // undo → 回到 rev 1
  match h.undo() {
    Ok(_) => assert_eq(h.rev(), 1)
    Err(_) => assert_true(false)
  }
  // redo → 回到 rev 2
  match h.redo() {
    Ok(_) => assert_eq(h.rev(), 2)
    Err(_) => assert_true(false)
  }
  // redo 到头了
  match h.redo() {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.contains("nothing_to_redo"))
  }
}

///|
test "版本控制：变更回放" {
  let doc = Document::sample_login()
  let h = DesignHistory::new(doc)
  let ops1 : Array[DesignOp] = [OpSetFill("btn", "#4B6BFB", "#FF0000")]
  let ops2 : Array[DesignOp] = [OpSetText("label", "old", "new")]
  let _ = h.commit("a", "改颜色", ops1, doc)
  let _ = h.commit("b", "改文字", ops2, doc)
  // 回放 rev 0 → rev 2
  match h.replay(0, 2) {
    Ok(json) => {
      assert_true(json.contains("\"total_ops\":2"))
      assert_true(json.contains("fill btn"))
      assert_true(json.contains("text label"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "版本控制：分支" {
  let doc = Document::sample_login()
  let h = DesignHistory::new(doc)
  let _ = h.commit("a", "main work", [], doc)
  // 从 rev 1 创建分支
  match h.branch(1, "experiment") {
    Ok(d) => assert_true(d.nodes.size() > 0)
    Err(_) => assert_true(false)
  }
  assert_eq(h.branch_name, "experiment")
}

///|
test "版本控制：版本间 diff" {
  let doc1 = Document::sample_login()
  let doc2 = Document::sample_login()
  let _ = doc2.update_node("btn-login", fn(n) {
    { ..n, style: { ..n.style, fill: "#FF0000" } }
  })
  let h = DesignHistory::new(doc1)
  let _ = h.commit("a", "change color", [], doc2)
  match h.diff(0, 1) {
    Ok(json) => assert_true(json.contains("restyled") || json.contains("fill"))
    Err(_) => assert_true(false)
  }
}

///|
test "AI 设计批评：8 项原则评审" {
  let p = Project::new()
  let _ = p.apply_template(template_id="login")
  match p.critique(artboard="login") {
    Ok(json) => {
      assert_true(json.contains("visual_hierarchy"))
      assert_true(json.contains("proximity"))
      assert_true(json.contains("alignment"))
      assert_true(json.contains("consistency"))
      assert_true(json.contains("whitespace"))
      assert_true(json.contains("balance"))
      assert_true(json.contains("focus"))
      assert_true(json.contains("rhythm"))
      assert_true(json.contains("\"score\""))
      assert_true(json.contains("\"verdict\""))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "AI 设计批评：摘要评分" {
  let p = Project::new()
  let _ = p.apply_template(template_id="dashboard")
  match p.critique_summary(artboard="dashboard") {
    Ok(s) => assert_true(s.contains("Design Critique"))
    Err(_) => assert_true(false)
  }
}

///|
test "Agent 全流程：设计→批评→版本控制→回放" {
  let p = Project::new()
  // 创建设计
  let ab = match p.apply_template(template_id="login") {
    Ok(id) => id
    Err(_) => {
      assert_true(false)
      return
    }
  }
  // 批评
  let _ = p.critique(artboard=ab)
  let _ = p.critique_summary(artboard=ab)
  // 版本控制
  let doc = match p.artboards.get(ab) {
    Some(x) => x.doc
    None => return
  }
  let h = DesignHistory::new(doc)
  let ops : Array[DesignOp] = [OpSetFill("login_btn", "#4B6BFB", "#4B6BFB")]
  let rev = h.commit("critic_agent", "优化按钮颜色", ops, doc)
  assert_eq(rev, 1)
  // 历史
  let log = h.log()
  assert_true(log.contains("critic_agent"))
  // 回放
  match h.replay(0, 1) {
    Ok(json) => assert_true(json.contains("fill login_btn"))
    Err(_) => assert_true(false)
  }
}
