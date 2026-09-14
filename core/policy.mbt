///|
/// 合并门槛：两条路线对同一组谓词采用不同策略（docs/04 的策略矩阵）。
///
/// - HumanGate：结构谓词硬阻断（编辑器交互保证极少触发），视觉谓词软提示。
/// - AgentGate：全部硬阻断——任何违规都整体拒绝补丁。
pub(all) enum Gate {
  HumanGate
  AgentGate
}

///|
pub(all) enum GateDecision {
  /// 允许合并；携带的违规即“视觉债”（人类路线的常见形态）
  Allow(Array[Violation])
  /// 拒绝合并；只携带阻断性违规
  Reject(Array[Violation])
}

///|
pub fn decide(gate : Gate, violations : Array[Violation]) -> GateDecision {
  let blocking : Array[Violation] = Array::new()
  for v in violations.iter() {
    let blocks : Bool = match gate {
      AgentGate => true
      HumanGate => v.predicate.is_structural()
    }
    if blocks {
      blocking.push(v)
    }
  }
  if blocking.is_empty() {
    Allow(violations)
  } else {
    Reject(blocking)
  }
}
