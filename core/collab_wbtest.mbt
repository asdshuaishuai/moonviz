///|
/// collab 边界入口：文本规格 → 合并结果。
test "collab：merge_sessions_from_spec 无冲突自动合并" {
  let json = merge_sessions_from_spec("1 a=fill:btn:#000:#111 b=gap:btn:8:16")
  assert_true(json.contains("\"ok\":true"))
  assert_true(json.contains("\"sessions\":2"))
  assert_true(json.contains("\"merges\":["))
  assert_true(json.contains("\"conflicts\":0"))
}

///|
test "collab：同节点同字段不同值 → 冲突检出" {
  let json = merge_sessions_from_spec("1 a=fill:btn:#000:#111 b=fill:btn:#000:#222")
  assert_true(json.contains("\"ok\":true"))
  assert_true(json.contains("conflicts"))
}

///|
test "collab：非法规格返回错误信封" {
  assert_true(merge_sessions_from_spec("garbage").contains("\"error\""))
  assert_true(merge_sessions_from_spec("1 a=bogus:1:2 b=gap:btn:8:16").contains("collab_spec_bad_op"))
  // 只有一个 agent 段（词数 < 3）→ 用法错误
  assert_true(merge_sessions_from_spec("1 onlyone=x").contains("collab_spec_usage"))
}

// 多 Agent 协作系统测试

///|
test "协作：无冲突合并（不同节点）" {
  let ours = AgentSession::new("agent_a", 1)
  let theirs = AgentSession::new("agent_b", 1)
  // A 改 login_btn 的颜色
  ours.add_op(OpSetFill("login_btn", "#4B6BFB", "#FF0000"))
  // B 改 signup_btn 的位置
  theirs.add_op(OpSetPosition("signup_btn", 24.0, 100.0, 400.0, 450.0))
  let result = merge_sessions(ours, theirs)
  assert_true(result.clean) // 不同节点，不冲突
  assert_eq(result.conflicts.length(), 0)
  assert_eq(result.total_ops_ours, 1)
  assert_eq(result.total_ops_theirs, 1)
}

///|
test "协作：同节点同字段冲突" {
  let ours = AgentSession::new("agent_a", 1)
  let theirs = AgentSession::new("agent_b", 1)
  // A 和 B 都改 login_btn 的颜色，但值不同
  ours.add_op(OpSetFill("login_btn", "#4B6BFB", "#FF0000"))
  theirs.add_op(OpSetFill("login_btn", "#4B6BFB", "#00FF00"))
  let result = merge_sessions(ours, theirs)
  assert_true(!result.clean) // 有冲突
  assert_eq(result.conflicts.length(), 1)
  assert_eq(result.conflicts[0].node_id, "login_btn")
  assert_eq(result.conflicts[0].field, "fill")
  // JSON 包含冲突详情
  let json = result.to_json()
  assert_true(json.contains("\"clean\":false"))
  assert_true(json.contains("\"conflicts\":1"))
  assert_true(json.contains("login_btn"))
}

///|
test "协作：同节点同字段但值相同（幂等）" {
  let ours = AgentSession::new("agent_a", 1)
  let theirs = AgentSession::new("agent_b", 1)
  // A 和 B 改了相同的值
  ours.add_op(OpSetFill("login_btn", "#4B6BFB", "#FF0000"))
  theirs.add_op(OpSetFill("login_btn", "#4B6BFB", "#FF0000"))
  let result = merge_sessions(ours, theirs)
  assert_true(result.clean) // 值相同，自动解决
  assert_eq(result.auto_resolved, 1)
}

///|
test "协作：同节点不同字段（可并行）" {
  let ours = AgentSession::new("agent_a", 1)
  let theirs = AgentSession::new("agent_b", 1)
  // A 改颜色，B 改位置 → 不同字段，不冲突
  ours.add_op(OpSetFill("login_btn", "#4B6BFB", "#FF0000"))
  theirs.add_op(OpSetPosition("login_btn", 24.0, 100.0, 400.0, 450.0))
  let result = merge_sessions(ours, theirs)
  assert_true(result.clean)
}

///|
test "协作：删除 vs 修改冲突" {
  let ours = AgentSession::new("agent_a", 1)
  let theirs = AgentSession::new("agent_b", 1)
  // A 删除节点，B 修改它
  ours.add_op(OpDelete("old_card"))
  theirs.add_op(OpSetRadius("old_card", 8.0, 16.0))
  let result = merge_sessions(ours, theirs)
  assert_true(!result.clean)
  assert_eq(result.conflicts.length(), 1)
  assert_true(result.conflicts[0].suggestion.contains("删除"))
}

///|
test "协作：双方都删除（幂等）" {
  let ours = AgentSession::new("agent_a", 1)
  let theirs = AgentSession::new("agent_b", 1)
  ours.add_op(OpDelete("temp_node"))
  theirs.add_op(OpDelete("temp_node"))
  let result = merge_sessions(ours, theirs)
  assert_true(result.clean)
  assert_eq(result.auto_resolved, 1)
}

///|
test "协作：OT 插入索引变换" {
  // A 在 index 3 插入，B 在 index 5 插入
  let adjusted = transform_insert_index(5, 3, 2000.0, 1000.0)
  assert_eq(adjusted, 6) // B 在前面插了，A 的 index 后移
  // A 在前，不受影响
  let unchanged = transform_insert_index(2, 5, 1000.0, 2000.0)
  assert_eq(unchanged, 2)
  // 同位置，A 时间戳在前
  let same_pos = transform_insert_index(3, 3, 1000.0, 2000.0)
  assert_eq(same_pos, 3) // A 先到，保持原位
  // 同位置，B 时间戳在前
  let bumped = transform_insert_index(3, 3, 2000.0, 1000.0)
  assert_eq(bumped, 4) // B 先到，A 后移
}

///|
test "协作管理器：多 Agent 汇总" {
  let cm = CollabManager::new(1)
  let a = cm.join("agent_a")
  let b = cm.join("agent_b")
  let c = cm.join("agent_c")
  // 各 Agent 做不同的操作
  a.add_op(OpSetFill("btn1", "#4B6BFB", "#FF0000"))
  b.add_op(OpSetPosition("input1", 0.0, 50.0, 0.0, 100.0))
  c.add_op(OpSetText("label1", "old", "new"))
  // 合并
  let results = cm.merge_all()
  assert_eq(results.length(), 3) // 3 对合并
  // 无冲突（不同节点）
  assert_eq(cm.total_conflicts(), 0)
  // 状态
  let status = cm.status()
  assert_true(status.contains("agent_a"))
  assert_true(status.contains("agent_b"))
  assert_true(status.contains("agent_c"))
  assert_true(status.contains("0")) // 0 conflicts
}

///|
test "协作管理器：冲突检测" {
  let cm = CollabManager::new(1)
  let a = cm.join("agent_a")
  let b = cm.join("agent_b")
  // 两个 Agent 都改同一节点的颜色
  a.add_op(OpSetFill("header", "#111111", "#FF0000"))
  b.add_op(OpSetFill("header", "#111111", "#00FF00"))
  let conflicts = cm.total_conflicts()
  assert_eq(conflicts, 1)
  let status = cm.status()
  assert_true(status.contains("1")) // 1 conflict
}

///|
test "Agent 会话摘要" {
  let s = AgentSession::new("designer_bot", 5)
  s.add_op(OpSetFill("btn", "#4B6BFB", "#FF0000"))
  s.add_op(OpSetPosition("card", 0.0, 100.0, 0.0, 200.0))
  let summary = s.summary()
  assert_true(summary.contains("designer_bot"))
  assert_true(summary.contains("rev5"))
  assert_true(summary.contains("fill btn"))
  assert_true(summary.contains("pos card"))
}

///|
test "冲突自动解决" {
  let ours = AgentSession::new("a", 1)
  let theirs = AgentSession::new("b", 1)
  ours.add_op(OpSetFill("btn", "#4B6BFB", "#FF0000"))
  theirs.add_op(OpSetFill("btn", "#4B6BFB", "#00FF00"))
  let result = merge_sessions(ours, theirs)
  assert_true(!result.clean)
  // 自动解决后变 clean
  let resolved = result.auto_resolve(strategy="ours")
  assert_true(resolved.clean)
  assert_eq(resolved.auto_resolved, 1)
}
