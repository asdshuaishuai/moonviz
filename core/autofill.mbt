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
      Some(("body_text", "加载中…", cw, 20.0, "#6B7280", false))
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
  let page_type = extract_field(missing_json, "page_type")
  // 解析缺失元素清单（element 字段；与 infer_missing 的 JSON 形状耦合，
  // 单一事实源在 infer_missing——这里只消费）。扫描限定在 "missing":[ … ]
  // 数组片段内：裸扫整个信封的话，信封其他字段一旦也带 element 键就会
  // 静默重复收集，放大放置冲突。
  let elements = parse_missing_envelope(missing_json)
  // 内容底缘（确定性放置光标）+ 现有内容矩形表（锚定占用检查用）
  let layout = solve(ab.doc)
  let mut bottom = 0.0
  let mut app_bar_bottom = -1.0
  let occupied : Array[Rect] = []
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
            occupied.push(r)
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
      None => skipped.push(af_skip_json(element, "state_semantics_not_placeable"))
      Some(recipe) => {
        let (component, text, node_w, node_h, color, anchor_top) = recipe
        let node_id = element
        // 同 id 预检：place_component 的根路径会丢弃 insert_node 的重复 id
        // 失败（返回值未消费），既有节点随后被 edit_node 静默改写——用户
        // 数据破坏 + 假成功报告。命中即跳过，绝不覆盖既有内容。
        if ab.doc.has(node_id) {
          skipped.push(af_skip_json(element, "id_taken"))
          continue
        }
        // search_bar 等锚定元素语义位置在 app_bar 之下；锚定前先查带区
        // 占用——候选矩形与既有内容（或本轮已放置节点）相交即退回底缘
        // 光标。锚定是语义偏好，不是插队许可：硬塞进占用带区会触发
        // auto_fix 的下移级联，把既有内容推挤改写。
        let mut y = y_cursor
        let mut anchored_rect : Rect? = None
        if anchor_top && app_bar_bottom >= 0.0 {
          let cand = Rect::new(24.0, app_bar_bottom + 12.0, node_w, node_h)
          let mut taken = false
          for r in occupied.iter() {
            if cand.intersects(r) {
              taken = true
              break
            }
          }
          if !taken {
            y = cand.y
            anchored_rect = Some(cand)
          }
        }
        // 画布高度钳制：底缘光标越过画布（近满页）时节点会落到画布外，
        // 而 fix_overflow 对负剩余空间保持原尺寸、清偿不动——如实跳过，
        // 不制造永久视觉债。
        if y + node_h > ab.height {
          skipped.push(af_skip_json(element, "no_room"))
          continue
        }
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
          match anchored_rect {
            // 锚定放置注册占用（防后续锚定元素同带区叠放），但**不推进**
            // 底缘光标——锚定 y 在内容带中部，推进会让后续物化节点落进
            // 既有内容里
            Some(r) => occupied.push(r)
            // 只有底缘光标放置才推进光标
            None => y_cursor = y + node_h + 16.0
          }
        } else {
          skipped.push(af_skip_json(element, "place_failed"))
        }
      }
    }
  }
  // issue #25-B4：空壳 mock 容器先物化真实样例数据，再走清偿
  let mock_rows = match self.materialize_mock_data(artboard=artboard) {
    Ok(n) => n
    Err(_) => 0
  }
  // 清偿：新节点与既有内容的重叠/溢出/触控规范归 auto_fix
  let autofix_json = match self.auto_fix(artboard=artboard) {
    Ok(json) => json
    Err(_) => "{\"fixes\":0}"
  }
  // 顶层 ok 如实采纳 autofix 结果：清偿不动（remaining > 0）时不再谎报成功
  let autofix_ok = !autofix_json.contains("\"ok\":false")
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
  let pj = placed.join(",")
  let sj = skipped.join(",")
  Ok(
    "{\"ok\":\{autofix_ok},\"op\":\"autofill\",\"artboard\":\"\{json_escape(artboard)}\",\"page_type\":\"\{page_type}\",\"placed_count\":\{placed.length()},\"placed\":[\{pj}],\"skipped\":[\{sj}],\"autofix\":\{autofix_json},\"missing_count_after\":\{after_count},\"mock_rows\":\{mock_rows}}",
  )
}

///|
/// 从 infer_missing 信封提取缺失元素清单：先截取 "missing":[ … ] 数组
/// 片段再扫描 element——信封其他字段里的同名键不参与（CORE-4）
fn parse_missing_envelope(json : String) -> Array[String] {
  parse_missing_elements(missing_array_scope(json))
}

///|
/// 截取信封里 "missing":[ … ] 的数组内容片段（不含方括号）；数组缺席或
/// 为空返回 ""。闭合按当前 infer_missing 的扁平条目形状取首个 `]`——
/// 条目的 suggestion 文案不含括号。
fn missing_array_scope(json : String) -> String {
  match json.find("\"missing\":[") {
    Some(i) => {
      let rest = json.substring(start=i + "\"missing\":[".length())
      match rest.find("]") {
        Some(j) => rest.substring(start=0, end=j).to_string()
        None => ""
      }
    }
    None => ""
  }
}

///|
/// 从缺失数组片段提取 element 清单（顺序保留；只消费不校验——单一
/// 事实源在 infer_missing 的 JSON 形状）
fn parse_missing_elements(scope : String) -> Array[String] {
  let elements : Array[String] = []
  let mut from = 0
  let key = "\"element\":\""
  while from + key.length() <= scope.length() {
    match scope.substring(start=from).find(key) {
      Some(rel) => {
        let i = from + rel + key.length()
        let rest = scope.substring(start=i)
        match rest.find("\"") {
          Some(j) => {
            elements.push(rest.substring(start=0, end=j).to_string())
            from = i + j
          }
          None => from = scope.length()
        }
      }
      None => from = scope.length()
    }
  }
  elements
}

///|
/// skipped 数组元素 JSON 片段：{"element":"…","reason":"…"}（element 经
/// 转义；reason 为字面枚举，不需转义）
fn af_skip_json(element : String, reason : String) -> String {
  "{\"element\":\"\{json_escape(element)}\",\"reason\":\"\{reason}\"}"
}

///|
/// issue #25-B4：页面语义 → 真实样例数据（拒绝 Item 1/项目一/占位）。
fn af_mock_samples(artboard_name : String) -> Array[(String, String)] {
  let n = artboard_name.to_lower()
  if n.contains("chat") ||
    artboard_name.contains("聊天") ||
    artboard_name.contains("消息") ||
    n.contains("message") {
    [("林小雨", "设计稿已更新，麻烦看下"), ("陈工", "评审定在明天 10:00"), ("产品群", "本周迭代范围已确认")]
  } else if n.contains("product") ||
    n.contains("order") ||
    artboard_name.contains("商品") ||
    artboard_name.contains("订单") ||
    artboard_name.contains("购物") ||
    n.contains("list") {
    [("无线降噪耳机", "¥499 · 已发货"), ("便携咖啡机", "¥299 · 待付款"), ("机械键盘 87 键", "¥359 · 已完成")]
  } else if n.contains("setting") || artboard_name.contains("设置") {
    [("通知提醒", "已开启"), ("深色模式", "跟随系统"), ("存储空间", "已用 6.4 GB")]
  } else if n.contains("contact") ||
    artboard_name.contains("通讯录") ||
    artboard_name.contains("联系人") {
    [("张伟", "产品经理"), ("李娜", "视觉设计"), ("王强", "前端开发")]
  } else if n.contains("profile") || artboard_name.contains("个人") {
    [("我的订单", "3 项进行中"), ("收货地址", "2 个地址"), ("账户与安全", "已绑定手机")]
  } else {
    [("今日概览", "3 项待处理"), ("最近更新", "登录流程优化"), ("本周计划", "组件库对齐")]
  }
}

///|
/// issue #25-B4：把空壳 mock 容器（list/table/card 无子节点无文本）物化为
/// 真实样例条目——≥2 条语义化文本（受容器高度约束），不是空壳占位。
/// 幂等：同 id 已存在则跳过；有落点则 revision +1。
pub fn Project::materialize_mock_data(
  self : Project,
  artboard~ : String,
) -> Result[Int, String] {
  let ab = match self.artboards.get(artboard) {
    None => return Err("unknown_artboard")
    Some(meta) => meta
  }
  let doc = ab.doc
  let layout = solve(doc)
  let targets : Array[String] = []
  for id in doc.nodes.keys() {
    if id == doc.root_id {
      continue
    }
    match doc.nodes.get(id) {
      None => ()
      Some(n) =>
        if qa_is_mock_container(n.component) &&
          n.children.length() == 0 &&
          n.text.length() == 0 {
          targets.push(id)
        }
    }
  }
  let samples = af_mock_samples(ab.name)
  let mut placed = 0
  for target in targets {
    let r = match layout.rect_of(target) {
      Some(v) => v
      None => Rect::new(0.0, 0.0, 0.0, 0.0)
    }
    if r.width < 80.0 || r.height < 40.0 {
      continue
    }
    let pad = 12.0
    let row_step = 56.0
    let mut max_rows = ((r.height - pad * 2.0) / row_step).to_int()
    if max_rows > 3 {
      max_rows = 3
    }
    if max_rows < 1 {
      max_rows = 1
    }
    let rows = if samples.length() < max_rows { samples.length() } else { max_rows }
    for i in 0..<rows {
      let (t1, t2) = samples[i]
      let rid = target + "_row" + i.to_string()
      if doc.has(rid) {
        continue
      }
      let text = if t2 != "" {
        t1 + " · " + t2
      } else {
        t1
      }
      let base = Node::make(rid, Rect)
      let node = {
        ..base,
        component: "list_item",
        text,
        width: Fixed(r.width - pad * 2.0),
        height: Fixed(row_step - 8.0),
        x: AlignStart(pad),
        y: AlignStart(pad + i.to_double() * row_step),
        style: { ..base.style, fill: "#FFFFFF", text_color: "#1A1C1E", font_size: 14.0 },
      }
      if doc.insert_node(node, target) {
        placed = placed + 1
      }
    }
  }
  if placed > 0 {
    self.revision = self.revision + 1
  }
  Ok(placed)
}
