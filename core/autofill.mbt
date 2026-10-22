// 缺失元素一键补缺（missing → autofill 闭环）。
//
// generate/autofix 的报告（infer_missing）告诉 Agent "还缺什么"——本模块把
// 报告变成行动：按页面类型把缺失元素物化为真实节点（组件 + 语义文本）。
// 闭环性质：补缺物料的文本（"忘记密码？""记住我""刷新"）恰好满足检测器的
// 关键词判据——补完后再跑 infer_missing 归零，天然幂等。
//
// 放置策略（确定性）：新节点堆叠在当前内容底缘之下（16px 步进、24px 边距），
// search_bar 锚定 app_bar 之下（语义位置优先）；与既有内容的重叠交由
// auto_fix 的重叠/溢出清偿处理——布局归引擎，与本仓库生成式哲学一致。

///|
/// 缺失元素 → 物化配方。element 与 infer_missing 的 element 字段一一对应。
fn autofill_recipe(
  element : String,
  content_w : Double,
) -> (String, String, Double, Double, String, Bool)? {
  let cw = if content_w < 100.0 { 342.0 } else { content_w }
  match element {
    // auth：密码框下方的右对齐链接 + 底部注册链接 + 记住我
    "forgot_password" =>
      Some(("body_text", "忘记密码？", cw, 20.0, "#4B6BFB", true))
    "signup_link" =>
      Some(("body_text", "没有账号？立即注册", cw, 20.0, "#4B6BFB", false))
    "remember_me" =>
      Some(("checkbox", "记住我", 160.0, 44.0, "#111111", false))
    // dashboard / list / profile / settings 操作
    "refresh" => Some(("button", "刷新", 120.0, 44.0, "", false))
    "filter" => Some(("button", "筛选", 120.0, 44.0, "", false))
    "edit_profile" => Some(("button", "编辑资料", 160.0, 44.0, "", false))
    "logout" => Some(("button", "退出登录", cw, 48.0, "", false))
    // list 顶部搜索（语义位置：调用方锚定 app_bar 之下）
    "search_bar" => Some(("text_input", "搜索", cw, 44.0, "", true))
    // 通用加载状态（灰字，弱存在感）
    "loading_state" =>
      Some(("body_text", "加载中…", cw, 20.0, "#9098A1", false))
    // missing_validation（error_states）是状态语义，不是可放置节点——
    // 由组件状态多态（define_component_state）承载，本配方跳过
    _ => None
  }
}

///|
/// 一键补缺：infer_missing → 逐元素物化 → auto_fix 清偿重叠/溢出 →
/// 报告（placed/skipped/补后缺失数）。报告驱动、可重入：报告里的每个
/// 可物化元素都落地后，后续 infer_missing 对该画板归零。
pub fn Project::autofill_missing(
  self : Project,
  artboard~ : String,
) -> Result[String, String] {
  let ab = match self.artboards.get(artboard) {
    None => return Err("unknown_artboard")
    Some(meta) => meta
  }
  let missing_json = match self.infer_missing(artboard=artboard) {
    Ok(j) => j
    Err(e) => return Err(e)
  }
  // 解析缺失元素清单（element 字段；与 infer_missing 的 JSON 形状耦合，
  // 单一事实源在 infer_missing——这里只消费）
  let elements : Array[String] = []
  let page_type = match missing_json.find("\"page_type\":\"") {
    Some(i) => {
      let rest = missing_json.substring(start=i + 13)
      match rest.find("\"") {
        Some(j) => rest.substring(start=0, end=j).to_string()
        None => ""
      }
    }
    None => ""
  }
  let mut from = 0
  let key = "\"element\":\""
  while from + key.length() <= missing_json.length() {
    match missing_json.substring(start=from).find(key) {
      Some(rel) => {
        let i = from + rel + key.length()
        let rest = missing_json.substring(start=i)
        match rest.find("\"") {
          Some(j) => {
            elements.push(rest.substring(start=0, end=j).to_string())
            from = i + j
          }
          None => from = missing_json.length()
        }
      }
      None => from = missing_json.length()
    }
  }
  // 内容底缘（确定性放置光标）
  let layout = solve(ab.doc)
  let mut bottom = 0.0
  let mut app_bar_bottom = -1.0
  for id in ab.doc.nodes.keys() {
    match ab.doc.nodes.get(id) {
      Some(n) => {
        // root 是全画布 wrapper——计入会把放置光标顶到画布外（844+16），
        // 物化节点全部越界；底缘只看真实内容节点
        if id == "root" {
          continue
        }
        match layout.rect_of(id) {
          Some(r) => {
            if r.y + r.height > bottom {
              bottom = r.y + r.height
            }
            if n.component == "app_bar" && r.y + r.height > app_bar_bottom {
              app_bar_bottom = r.y + r.height
            }
          }
          None => ()
        }
      }
      None => ()
    }
  }
  let w = ab.width
  let content_w = w - 48.0
  let placed : Array[String] = []
  let skipped : Array[String] = []
  let mut y_cursor = bottom + 16.0
  for element in elements.iter() {
    match autofill_recipe(element, content_w) {
      None =>
        skipped.push(
          "{\"element\":\"" +
          json_escape(element) +
          "\",\"reason\":\"state_semantics_not_placeable\"}",
        )
      Some(recipe) => {
        let (component, text, node_w, node_h, color, anchor_top) = recipe
        // search_bar 锚定 app_bar 之下（语义位置）；其余走底缘光标
        let y = if anchor_top && app_bar_bottom >= 0.0 {
          app_bar_bottom + 12.0
        } else {
          y_cursor
        }
        let node_id = element
        let placed_ok = match
          self.place_component(
            artboard=artboard,
            component_id=component,
            instance_id=node_id,
            x=24.0,
            y=y,
            w=node_w,
            h=node_h,
          ) {
          Err(_) => false
          Ok(_) => true
        }
        if placed_ok {
          if text != "" {
            let _ = self.edit_node(
              artboard=artboard,
              node_id=node_id,
              kvs=[("text", text)],
            )
          }
          if color != "" {
            let kv = if component == "body_text" {
              [("text_color", color)]
            } else {
              [("fill", color)]
            }
            let _ = self.edit_node(artboard=artboard, node_id=node_id, kvs=kv)
          }
          placed.push(
            "{\"element\":\"" +
            json_escape(element) +
            "\",\"node\":\"" +
            json_escape(node_id) +
            "\",\"component\":\"" +
            component +
            "\",\"y\":" +
            y.to_string() +
            "}",
          )
          y_cursor = y + node_h + 16.0
        } else {
          skipped.push(
            "{\"element\":\"" +
            json_escape(element) +
            "\",\"reason\":\"place_failed\"}",
          )
        }
      }
    }
  }
  // 清偿：新节点与既有内容的重叠/溢出/触控规范归 auto_fix
  let autofix_json = match self.auto_fix(artboard=artboard) {
    Ok(json) => json
    Err(_) => "{\"fixes\":0}"
  }
  let after = match self.infer_missing(artboard=artboard) {
    Ok(j) => j
    Err(e) => return Err(e)
  }
  let after_count = match after.find("\"missing_count\":") {
    Some(i) => {
      let rest = after.substring(start=i + 16)
      let mut j = 0
      while j < rest.length() {
        match rest.get_char(j) {
          Some(c) => if c >= '0' && c <= '9' { j = j + 1 } else { break }
          None => break
        }
      }
      rest.substring(start=0, end=j).to_string()
    }
    None => "?"
  }
  let pj = af_join(placed)
  let sj = af_join(skipped)
  Ok(
    "{\"ok\":true,\"op\":\"autofill\",\"artboard\":\"\{json_escape(artboard)}\",\"page_type\":\"\{page_type}\",\"placed_count\":\{placed.length()},\"placed\":[\{pj}],\"skipped\":[\{sj}],\"autofix\":\{autofix_json},\"missing_count_after\":\{after_count}}",
  )
}

///|
fn af_join(parts : Array[String]) -> String {
  let sb = StringBuilder::new()
  for i in 0..<parts.length() {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string(parts[i])
  }
  sb.to_string()
}
