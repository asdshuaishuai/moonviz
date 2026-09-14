// 核心行为测试：布局求解、两条路线的策略差异、补丁事务、JSON 协议。
// 运行：moon test（在 moonviz/ 目录下）

///|
test "示例登录页：栈布局求解位置正确" {
  let doc = Document::sample_login()
  let layout = solve(doc)
  assert_true(layout.failures.is_empty())
  let btn : Rect = match layout.rect_of("btn-login") {
    Some(r) => r
    None => abort("btn-login 缺失")
  }
  assert_eq(btn.x, 24.0)
  assert_eq(btn.y, 202.0)
  assert_eq(btn.width, 342.0)
  assert_eq(btn.height, 48.0)
  let t : Rect = match layout.rect_of("text-btn") {
    Some(r) => r
    None => abort("text-btn 缺失")
  }
  // 按钮 Frame：Horizontal + justify=Center + 交叉轴 CenterInParent
  assert_eq(t.x, 167.0)
  assert_eq(t.y, 205.0)
  assert_eq(t.width, 56.0)
  assert_eq(t.height, 42.0)
}

///|
test "Fill 分配：剩余主轴空间均分给 Fill 子项" {
  let doc = Document::new({ width: 300.0, height: 100.0 })
  let lay : StackLayout = {
    dir: Vertical,
    gap: 0.0,
    justify: Start,
    padding: Padding::uniform(0.0),
  }
  let _ = doc.update_node("root", fn(r) { { ..r, layout: Some(lay) } })
  let a = { ..Node::make("a", Rect), width: Fill, height: Fixed(40.0) }
  let b = { ..Node::make("b", Rect), width: Fill, height: Fill }
  let _ = doc.insert_node(a, "root")
  let _ = doc.insert_node(b, "root")
  let layout = solve(doc)
  let rb : Rect = match layout.rect_of("b") {
    Some(r) => r
    None => abort("b 缺失")
  }
  assert_eq(rb.y, 40.0)
  assert_eq(rb.height, 60.0)
  assert_eq(rb.width, 300.0)
  assert_eq(rb.x, 0.0)
}

///|
test "Agent 路线：越界补丁被硬门槛拒绝，返回结构化违规" {
  let doc = Document::sample_login()
  let p : NodePatch = { ..NodePatch::empty(), width: Some(Fixed(400.0)) }
  let patch : Patch = {
    base_revision: doc.revision,
    message: "把登录按钮宽度改成 400",
    ops: [UpdateNode("btn-login", p)],
  }
  match apply_agent_patch(doc, patch) {
    Ok(_) => assert_true(false)
    Err(HardBlock(vs)) => {
      assert_eq(vs.length(), 1)
      assert_eq(vs[0].predicate.name(), "contained_in_parent")
      assert_eq(vs[0].node_id, "btn-login")
    }
    Err(_) => assert_true(false)
  }
  // 事务性：拒绝后文档未被污染
  let layout = solve(doc)
  let btn : Rect = match layout.rect_of("btn-login") {
    Some(r) => r
    None => abort("btn-login 缺失")
  }
  assert_eq(btn.width, 342.0)
}

///|
test "人类路线：同样的重叠状态，人类软提示可合并，Agent 被拒" {
  let doc = Document::new({ width: 390.0, height: 844.0 })
  let a = {
    ..Node::make("a", Rect),
    width: Fixed(100.0),
    height: Fixed(40.0),
    x: Fixed(10.0),
    y: Fixed(10.0),
  }
  let b = {
    ..Node::make("b", Rect),
    width: Fixed(100.0),
    height: Fixed(40.0),
    x: Fixed(50.0),
    y: Fixed(30.0),
  }
  let _ = doc.insert_node(a, "root")
  let _ = doc.insert_node(b, "root")
  // 当前状态即违规：1 条 no_sibling_overlap（绝对定位容器不做包含检查）
  let vs = validate(doc)
  assert_eq(vs.length(), 1)
  assert_eq(vs[0].predicate.name(), "no_sibling_overlap")
  // 人类提交仍被允许，违规作为“视觉债”随合并记录进 journal
  let patch : Patch = {
    base_revision: doc.revision,
    message: "拖动 b",
    ops: [],
  }
  match apply_human_op(doc, patch) {
    Ok(debt) => {
      assert_eq(debt.length(), 1)
      assert_eq(doc.revision, 2)
      assert_eq(doc.journal.length(), 1)
      assert_eq(doc.journal[0].source.name(), "human")
    }
    Err(_) => assert_true(false)
  }
  // Agent 对同样的状态提交任何补丁都会被硬门槛拒绝
  let patch2 : Patch = {
    base_revision: doc.revision,
    message: "agent 空补丁",
    ops: [],
  }
  match apply_agent_patch(doc, patch2) {
    Err(HardBlock(_)) => assert_true(true)
    _ => assert_true(false)
  }
  // Agent 的正确姿势：连同视觉债一起修复 → 通过
  let fix : NodePatch = { ..NodePatch::empty(), x: Some(Fixed(200.0)) }
  let patch3 : Patch = {
    base_revision: doc.revision,
    message: "把 b 移开，消除重叠",
    ops: [UpdateNode("b", fix)],
  }
  match apply_agent_patch(doc, patch3) {
    Ok(_) => {
      assert_eq(validate(doc).length(), 0)
      assert_eq(doc.revision, 3)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "revision 乐观锁：过期补丁被拒绝并携带当前值" {
  let doc = Document::sample_login()
  let p1 : Patch = {
    base_revision: doc.revision,
    message: "第一次",
    ops: [],
  }
  let _ = apply_human_op(doc, p1)
  let stale : Patch = { base_revision: 1, message: "过期补丁", ops: [] }
  match apply_agent_patch(doc, stale) {
    Err(StaleBase(2)) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "补丁错误：目标节点不存在 / 删除根节点" {
  let doc = Document::sample_login()
  let p : NodePatch = { ..NodePatch::empty(), text: Some("x") }
  let patch : Patch = {
    base_revision: doc.revision,
    message: "改不存在的节点",
    ops: [UpdateNode("nope", p)],
  }
  match apply_agent_patch(doc, patch) {
    Err(UnknownNode("nope")) => assert_true(true)
    _ => assert_true(false)
  }
  let patch2 : Patch = {
    base_revision: doc.revision,
    message: "删除根节点",
    ops: [DeleteNode("root")],
  }
  match apply_agent_patch(doc, patch2) {
    Err(HierarchyError(_)) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "MoveNode：跨容器移动后重新布局" {
  let doc = Document::sample_login()
  let panel = {
    ..Node::make("panel", Frame),
    width: Fixed(342.0),
    height: Fixed(120.0),
  }
  let _ = doc.insert_node(panel, "root")
  let patch : Patch = {
    base_revision: doc.revision,
    message: "把登录按钮移进面板",
    ops: [MoveNode("btn-login", "panel")],
  }
  match apply_agent_patch(doc, patch) {
    Ok(_) => {
      let layout = solve(doc)
      let btn : Rect = match layout.rect_of("btn-login") {
        Some(r) => r
        None => abort("btn-login 缺失")
      }
      // panel 进入根栈的第 4 位（y=202）；btn 在 panel 内绝对定位 AlignStart(0)
      assert_eq(btn.x, 24.0)
      assert_eq(btn.y, 202.0)
      assert_eq(btn.width, 342.0)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "DeleteNode：删除子树后无悬空引用" {
  let doc = Document::sample_login()
  let patch : Patch = {
    base_revision: doc.revision,
    message: "删除登录按钮",
    ops: [DeleteNode("btn-login")],
  }
  match apply_agent_patch(doc, patch) {
    Ok(_) => {
      assert_true(!doc.has("btn-login"))
      assert_true(!doc.has("text-btn"))
      assert_eq(validate(doc).length(), 0)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "结构谓词：悬空引用使人类提交也被硬阻断（结构硬，视觉软）" {
  let doc = Document::sample_login()
  // 模拟越权写入：直接破坏节点表
  let _ = doc.nodes.remove("input-user")
  let vs = validate(doc)
  let mut has_tree = false
  for v in vs.iter() {
    if v.predicate.name() == "tree_valid" {
      has_tree = true
    }
  }
  assert_true(has_tree)
  let patch : Patch = {
    base_revision: doc.revision,
    message: "任何提交",
    ops: [],
  }
  match apply_human_op(doc, patch) {
    Err(StructuralBlock(_)) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "约束无解：Fill 子项超出容器" {
  let doc = Document::new({ width: 100.0, height: 100.0 })
  let lay : StackLayout = {
    dir: Vertical,
    gap: 0.0,
    justify: Start,
    padding: Padding::uniform(0.0),
  }
  let _ = doc.update_node("root", fn(r) { { ..r, layout: Some(lay) } })
  let a = { ..Node::make("a", Rect), width: Fixed(50.0), height: Fixed(80.0) }
  let b = { ..Node::make("b", Rect), width: Fixed(50.0), height: Fixed(80.0) }
  let c = { ..Node::make("c", Rect), width: Fixed(50.0), height: Fill }
  let _ = doc.insert_node(a, "root")
  let _ = doc.insert_node(b, "root")
  let _ = doc.insert_node(c, "root")
  let vs = validate(doc)
  let mut has_solvable = false
  for v in vs.iter() {
    if v.predicate.name() == "constraint_solvable" {
      has_solvable = true
    }
  }
  assert_true(has_solvable)
}

///|
test "结构化错误 JSON：Agent 可读" {
  let doc = Document::sample_login()
  let p : NodePatch = { ..NodePatch::empty(), width: Some(Fixed(400.0)) }
  let patch : Patch = {
    base_revision: doc.revision,
    message: "越界",
    ops: [UpdateNode("btn-login", p)],
  }
  match apply_agent_patch(doc, patch) {
    Err(e) => {
      let j = e.to_json()
      assert_true(j.contains("\"error\":\"hard_block\""))
      assert_true(j.contains("\"node_id\":\"btn-login\""))
      assert_true(j.contains("\"predicate\":\"contained_in_parent\""))
    }
    Ok(_) => assert_true(false)
  }
}

///|
test "文档 JSON：规范代码表示可导出" {
  let doc = Document::sample_login()
  let j = doc.to_json()
  assert_true(j.contains("\"revision\":1"))
  assert_true(j.contains("\"kind\":\"frame\""))
  assert_true(j.contains("欢迎回来"))
  assert_true(j.contains("\"children\":["))
}

///|
test "渲染：SVG 输出包含预期形状与文本" {
  let doc = Document::sample_login()
  let svg = render_svg(doc)
  assert_true(svg.contains("<svg"))
  assert_true(svg.contains("登录"))
  assert_true(svg.contains("欢迎回来"))
  assert_true(svg.contains("#4B6BFB"))
}
