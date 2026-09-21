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
