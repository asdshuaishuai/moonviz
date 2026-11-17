// ---------------------------------------------------------------------------
// issue #25 / #26：交互与内容完整性 QA（critique 并入 norms 维度，软路径）
//
// 与 norms 的分工：norms 管视觉工艺（留白/圆角/触控/对比度），本模块管
// 「原型可交互性」——可交互组件必须有去向、内容不能是占位空壳、组件必须
// 来自组件库。冲突类（同一节点多 flow / 可点热区相交）另行走 AgentGate
// 硬门（qa_agent_conflicts），检测项与硬门共用同一判据。
// ---------------------------------------------------------------------------

///|
/// 可交互族组件（无 flow/交互标记时必须报告）。
pub fn qa_is_interactive_component(c : String) -> Bool {
  c == "button" ||
  c == "chip" ||
  c == "fab" ||
  c == "tab_bar" ||
  c == "list_item"
}

///|
/// 占位符残留判定（issue #25-B5）：TBD/TODO/Lorem/xxx/Item 1/项目一/示例文本/占位。
pub fn qa_is_placeholder_text(t : String) -> Bool {
  let s = t.trim().to_lower()
  if s == "" {
    return false
  }
  s.contains("tbd") ||
  s.contains("todo") ||
  s.contains("lorem") ||
  s.contains("xxx") ||
  s.contains("item 1") ||
  s.contains("项目一") ||
  s.contains("示例文本") ||
  s.contains("占位")
}

///|
/// mock 容器族：空壳（无子节点、无文本）视为缺示例数据。
pub fn qa_is_mock_container(c : String) -> Bool {
  c == "list_item" || c == "table" || c == "card"
}

///|
/// 组件必须来自组件库（builtin 或用户组件注册表）。
pub fn Project::qa_component_known(self : Project, c : String) -> Bool {
  // 结构组件（画布 frame / 弹性留白 spacer）与空名不算「非组件库组件」
  // ——泛型容器合法。
  if c == "frame" || c == "spacer" || c == "" {
    return true
  }
  if self.components.contains(c) {
    return true
  }
  self.user_components.contains(c)
}

///|
/// 交互去向判定（issue #25-A1）：flow tap:<id> / 名字里的交互标记（⚡ 或
/// [state:）/ 返回类节点（内置返回兜底）都算有去向。
pub fn Project::qa_is_bound(
  self : Project,
  artboard : String,
  n : Node,
) -> Bool {
  if is_back_like_node(n) {
    return true
  }
  if n.name.contains("⚡") || n.name.contains("[state:") {
    return true
  }
  for f in self.flows.iter() {
    if f.from == artboard && f.trigger == "tap:" + n.id {
      return true
    }
  }
  false
}

///|
/// critique 第 9 维追加项（issue #25/#26 软路径检测）：
/// 1) 可交互组件无去向（无 flow/标记/返回兜底）
/// 2) 占位符残留文本
/// 3) 空壳 list/table/card（无示例条目）
/// 4) 非组件库组件（generic_node 当组件用）
pub fn Project::qa_issues(self : Project, artboard~ : String) -> Array[String] {
  let issues : Array[String] = []
  // issue #24 要求 2：spec 组件白名单/禁用项的整篇检视并入 QA
  for v in self.design_spec_component_violations(artboard~).iter() {
    if issues.length() >= 12 {
      break
    }
    issues.push(v)
  }
  match self.artboards.get(artboard) {
    None => ()
    Some(ab) =>
      for id in ab.doc.nodes.keys() {
        if issues.length() >= 8 {
          break
        }
        // 画布 root 是结构节点，不参与交互/内容 QA
        if id == ab.doc.root_id {
          continue
        }
        match ab.doc.nodes.get(id) {
          None => ()
          Some(n) => {
            if qa_is_interactive_component(n.component) &&
              !self.qa_is_bound(artboard, n) {
              issues.push(
                "\{json_escape(id)}（\{n.component}）可交互组件无去向：无 flow/交互标记、非返回类 → 绑 flow 或改非交互组件（critique 检测项）",
              )
              continue
            }
            if qa_is_placeholder_text(n.text) {
              issues.push(
                "\{json_escape(id)}（\{n.component}）占位符残留：\{json_escape(n.text)} → 换语义化真实示例",
              )
              continue
            }
            if qa_is_mock_container(n.component) &&
              n.children.length() == 0 &&
              n.text.length() == 0 {
              issues.push(
                "\{json_escape(id)}（\{n.component}）空壳容器无示例条目 → 填 ≥2 条语义示例或改 empty_state 变体",
              )
              continue
            }
            if !self.qa_component_known(n.component) {
              issues.push(
                "\{json_escape(id)} 使用非组件库组件「\{n.component}」→ 换注册表组件（generic_node 仅可用于纯容器/装饰）",
              )
            }
          }
        }
      }
  }
  issues
}

// ---------------------------------------------------------------------------
// issue #25-A3 / #26-A3：交互冲突硬门（AgentGate）
// ---------------------------------------------------------------------------

///|
/// AgentGate 冲突判定（issue #25-A3 / #26-A3）：
/// 1) 同一节点多条 tap flow → interaction_conflict
/// 2) 两个可点热区（被 tap flow 绑定的容器）包围盒相交且无父子包含 → hotzone_overlap
/// 任一命中即 Err("mbt_gate_block:<板>:<类>:<定位>")，由门路径拒绝。
pub fn Project::qa_agent_conflicts(self : Project) -> Result[Unit, String] {
  for artboard_id in self.artboards.keys() {
    match self.artboards.get(artboard_id) {
      None => ()
      Some(ab) => {
        let tap_counts : Map[String, Int32] = Map([])
        for f in self.flows.iter() {
          if f.from == artboard_id &&
            f.trigger.length() > 4 &&
            f.trigger.has_prefix("tap:") {
            let nid = f.trigger[4:].to_owned()
            let c = match tap_counts.get(nid) {
              Some(v) => v
              None => 0
            }
            tap_counts.set(nid, c + 1)
          }
        }
        for nid in tap_counts.keys() {
          match tap_counts.get(nid) {
            Some(c) =>
              if c > 1 {
                return Err(
                  "mbt_gate_block:" +
                  artboard_id +
                  ":interaction_conflict:" +
                  nid,
                )
              }
            None => ()
          }
        }
        let targets : Array[String] = []
        for k in tap_counts.keys() {
          targets.push(k)
        }
        let layout = solve(ab.doc)
        for i in 0..<targets.length() {
          let j_start = i + 1
          for j in j_start..<targets.length() {
            let ra = layout.rect_of(targets[i])
            let rb = layout.rect_of(targets[j])
            match (ra, rb) {
              (Some(a), Some(b)) =>
                // 父子包含豁免（is_descendant 双向）+ 包含关系矩形豁免；
                // 两个可点区正相交即冲突（几何谓词复用 geom.mbt）
                if !(is_descendant(ab.doc, targets[i], targets[j]) ||
                  is_descendant(ab.doc, targets[j], targets[i])) &&
                  !a.contains_rect(b) &&
                  !b.contains_rect(a) &&
                  a.intersects(b) {
                  return Err(
                    "mbt_gate_block:" +
                    artboard_id +
                    ":hotzone_overlap:" +
                    targets[i] +
                    ":" +
                    targets[j],
                  )
                }
              _ => ()
            }
          }
        }
      }
    }
  }
  Ok(())
}

///|
/// issue #25-B4（规则化）：mock 数据缺口——只报告「哪个容器缺样例 / 哪段文本是
/// 占位符」，不做任何内容内置。真实样例内容由 Agent（LLM）按语义自行填写；
/// 引擎只保证规则可测（空壳 = 无子节点无文本；占位词表见 qa_is_placeholder_text）。
pub fn Project::mock_data_gaps(
  self : Project,
  artboard~ : String,
) -> Array[String] {
  let gaps : Array[String] = []
  match self.artboards.get(artboard) {
    None => ()
    Some(ab) =>
      for id in ab.doc.nodes.keys() {
        if id == ab.doc.root_id {
          continue
        }
        match ab.doc.nodes.get(id) {
          None => ()
          Some(n) =>
            if qa_is_placeholder_text(n.text) {
              gaps.push(id)
            } else if qa_is_mock_container(n.component) &&
              n.children.length() == 0 &&
              n.text.length() == 0 {
              gaps.push(id)
            }
        }
      }
  }
  gaps
}
