///|
/// 组件规范（1.0 规范性强化）：弱模型最常产出「能用但不精致」的文档，三类根因：
/// 1. 操作组件宽高刚好卡住文案——没有留白概念，框贴着字
/// 2. 圆角体系混乱——按钮族该「方正圆润」（8px 档）却给 0，或全宽条带圆角顶出屏幕边缘
/// 3. 全宽条/全宽列表该直角却带圆角
///
/// 定位：**指导与规范，不做硬门**。偏差记入 critique 第 9 维（norms，给 Agent
/// 事后反馈），auto_fix 一键修复（审查-修复循环的执行手）——不改双门语义，
/// 存量文档不产生新视觉债。

///|
/// 操作组件族：承载短文案、点击即动作。文案与边缘必须有留白。
pub fn norm_is_action_component(component : String) -> Bool {
  component == "button" ||
  component == "chip" ||
  component == "tag" ||
  component == "fab"
}

///|
/// 方正圆润族：默认 8px 圆角档（avatar 999 正圆、全宽条 0 不在此列）
pub fn norm_is_rounded_component(component : String) -> Bool {
  component == "button" ||
  component == "chip" ||
  component == "tag" ||
  component == "select" ||
  component == "search_bar" ||
  component == "fab"
}

///|
/// 全宽顶边/底边条与全宽行：占满画板宽度时应当直角（圆角会顶出屏幕边缘）
pub fn norm_is_full_bleed_component(component : String) -> Bool {
  component == "app_bar" ||
  component == "tab_bar" ||
  component == "list_item" ||
  component == "divider"
}

///|
/// 横向留白下限（左右各 12）：与 svg.mbt 渲染层 text pad 同值
pub const NORM_TEXT_PAD_X : Double = 12.0

///|
/// 纵向留白下限（上下各 10）
pub const NORM_TEXT_PAD_Y : Double = 10.0

///|
/// 方正圆润圆角档：按钮族默认 8px
pub const NORM_RADIUS_BASE : Double = 8.0

///|
/// 组件规范一句话（list_components 随条目下发——Agent 选组件时即可见规范，
/// 不必等 critique 事后纠正）。返回 None 的组件不下发该字段。
pub fn component_norm(id : String) -> String? {
  match id {
    "button" =>
      Some(
        "宽 ≥ 文案宽+24（左右各留 12），高 36~48，圆角 8；别让框刚好卡住文字",
      )
    "fab" => Some("56×56，圆角 16；单屏只放一个主操作")
    "chip" => Some("高 28~32，左右留白 ≥10，圆角取 高/2（胶囊）或 8")
    "tag" => Some("高 22~26，左右留白 ≥8，圆角 4~6")
    "select" => Some("高 40~44，圆角 8，右侧留 24 放箭头")
    "search_bar" => Some("高 36~44，圆角取 高/2（胶囊）或 10")
    "list_item" => Some("高 56~76；全宽直角（radius 0），内缩卡片式才用圆角 10~12")
    "app_bar" => Some("全宽顶边条：高 44~56，圆角 0")
    "tab_bar" => Some("全宽底边条：高 56~64，圆角 0")
    "avatar" => Some("正圆：radius 999，常用 40/48/56")
    "divider" => Some("全宽 1px，圆角 0")
    _ => None
  }
}

///|
/// 检测组件规范偏差，返回人可读问题清单（critique 第 9 维 norms）。
/// 每条自带建议尺寸——Agent 读到就能改，不必自己换算。
/// 上限 8 条，控制报告体积（deepDesign 侧检视结果有 12KB 截断）。
pub fn norm_issues(doc : Document, layout : SolvedLayout) -> Array[String] {
  let issues : Array[String] = []
  let root_w = match layout.rect_of(doc.root_id) {
    Some(r) => r.width
    None => 0.0
  }
  for id in doc.nodes.keys() {
    if issues.length() >= 8 {
      break
    }
    match doc.nodes.get(id) {
      None => ()
      Some(n) =>
        match layout.rect_of(id) {
          None => ()
          Some(r) => {
            // 1) 操作组件：文案必须与边缘留白
            if norm_is_action_component(n.component) && n.text.length() > 0 {
              let ts = text_intrinsic(
                n.text,
                n.style.font_size,
                line_height=n.style.line_height,
              )
              let need_w = ts.width + NORM_TEXT_PAD_X * 2.0
              let need_h = n.style.font_size + NORM_TEXT_PAD_Y * 2.0
              if r.width < need_w - 0.5 || r.height < need_h - 0.5 {
                // 问题串会进 critique 的 JSON——用「」不用英文引号，避免破坏 JSON 结构
                issues.push(
                  "\{id}（\{n.component}「\{n.text}」）现 \{r.width.to_int()}×\{r.height.to_int()}，文案需 ≥\{need_w.to_int()}×\{need_h.to_int()}（左右各留 12）",
                )
                continue
              }
            }
            // 2) 方正圆润族：圆角低于 8px 档（或超出 高/2 变畸形）
            if norm_is_rounded_component(n.component) &&
              n.style.corner_radius < 999.0 {
              let r_cap = r.height / 2.0
              let r_now = n.style.corner_radius
              if r_now < NORM_RADIUS_BASE - 0.5 && NORM_RADIUS_BASE <= r_cap {
                issues.push(
                  "\{id}(\{n.component}) 圆角 \{r_now.to_int()} 低于方正圆润档 → radius 8",
                )
                continue
              }
              if r_now > r_cap + 0.5 {
                issues.push(
                  "\{id}(\{n.component}) 圆角 \{r_now.to_int()} 超出 高/2=\{r_cap.to_int()} → radius \{r_cap.to_int()}",
                )
                continue
              }
            }
            // 3) 全宽条/全宽行：占满画板宽度却带圆角
            if norm_is_full_bleed_component(n.component) &&
              n.style.corner_radius > 0.5 &&
              root_w > 0.0 &&
              r.width >= root_w - 0.5 {
              issues.push(
                "\{id}(\{n.component}) 全宽 \{r.width.to_int()} 带圆角 \{n.style.corner_radius.to_int()} 顶出边缘 → radius 0",
              )
              continue
            }
          }
        }
    }
  }
  issues
}

///|
/// 规范修复：与 norm_issues 同一判据，直接改文档并返回修复明细
/// （JSON 片段，格式与 autofix 的 fix_* 家族一致）。
pub fn norm_fix_pass(
  doc : Document,
  layout : SolvedLayout,
) -> Array[String] {
  let fixes : Array[String] = []
  let root_w = match layout.rect_of(doc.root_id) {
    Some(r) => r.width
    None => 0.0
  }
  for id in doc.nodes.keys() {
    match doc.nodes.get(id) {
      None => ()
      Some(n) =>
        match layout.rect_of(id) {
          None => ()
          Some(r) => {
            let mut new_w = r.width
            let mut new_h = r.height
            let mut new_r = n.style.corner_radius
            let mut why = ""
            // 1) 操作组件放大到文案 + 留白（Fill 宽不动——它由父容器决定）
            if norm_is_action_component(n.component) && n.text.length() > 0 {
              let ts = text_intrinsic(
                n.text,
                n.style.font_size,
                line_height=n.style.line_height,
              )
              let need_w = ts.width + NORM_TEXT_PAD_X * 2.0
              let need_h = n.style.font_size + NORM_TEXT_PAD_Y * 2.0
              let w_fixed = match n.width {
                Fixed(_) => true
                _ => false
              }
              if r.width < need_w - 0.5 && w_fixed {
                new_w = need_w
                why = "文案留白"
              }
              if r.height < need_h - 0.5 {
                new_h = need_h
                why = "文案留白"
              }
            }
            // 2) 圆角归档：方正圆润族抬到 8（不超过 高/2）；超 高/2 的收到 高/2
            if norm_is_rounded_component(n.component) &&
              n.style.corner_radius < 999.0 {
              let r_cap = new_h / 2.0
              let r_now = n.style.corner_radius
              if r_now < NORM_RADIUS_BASE - 0.5 && NORM_RADIUS_BASE <= r_cap {
                new_r = NORM_RADIUS_BASE
                if why == "" { why = "圆角归档 8" }
              } else if r_now > r_cap + 0.5 {
                new_r = r_cap
                if why == "" { why = "圆角收敛到 高/2" }
              }
            }
            // 3) 全宽条去圆角
            if norm_is_full_bleed_component(n.component) &&
              n.style.corner_radius > 0.5 &&
              root_w > 0.0 &&
              r.width >= root_w - 0.5 {
              new_r = 0.0
              why = "全宽条直角"
            }
            let changed = (new_w != r.width && new_w > 0.0) ||
              (new_h != r.height && new_h > 0.0) ||
              new_r != n.style.corner_radius
            if changed && why != "" {
              let _ = doc.update_node(id, fn(x) {
                {
                  ..x,
                  width: Fixed(new_w),
                  height: Fixed(new_h),
                  style: { ..x.style, corner_radius: new_r },
                }
              })
              fixes.push(
                "{\"node\":\"\{id}\",\"action\":\"component_norm\",\"why\":\"\{why}\",\"before\":\"\{r.width.to_int()}×\{r.height.to_int()} r\{n.style.corner_radius.to_int()}\",\"after\":\"\{new_w.to_int()}×\{new_h.to_int()} r\{new_r.to_int()}\"}",
              )
            }
          }
        }
    }
  }
  fixes
}

