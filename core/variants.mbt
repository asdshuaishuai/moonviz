///|
/// 变体探索：Agent 并行尝试多个设计方案，评审后选最优。
///
/// 设计师的工作流是"做几版然后挑最好的"。
/// Agent 的等价体验：`fork_variants(project, base, ["v1","v2","v3"])`
/// → 引擎为每个变体创建独立的画板分支
/// → Agent 分别修改每个变体
/// → `score_variants(project)` 对所有变体跑 lint + 谓词 + 对齐建议
/// → Agent 据此选出最优方案并合并
pub(all) struct VariantScore {
  artboard : String
  violations : Int // 不崩谓词违规数
  lint_issues : Int // 设计 lint 问题数
  alignment_hints : Int // 对齐建议数
  node_count : Int
  score : Int // 综合评分（越高越好）
}

///|
/// 从基础画板 fork 出多个变体
pub fn Project::fork_variants(
  self : Project,
  base~ : String,
  names~ : Array[String],
) -> Result[String, String] {
  match self.artboards.get(base) {
    None => Err("unknown_artboard: \{base}")
    Some(base_ab) => {
      let created : Array[String] = []
      for name in names.iter() {
        let id = self.create_artboard(
          name~,
          width=base_ab.width,
          height=base_ab.height,
        )
        // 复制所有节点
        match self.artboards.get(id) {
          Some(new_ab) =>
            for cid in base_ab.doc.nodes.keys() {
              if cid != "root" {
                match base_ab.doc.nodes.get(cid) {
                  Some(n) => {
                    let _ = new_ab.doc.insert_node(
                      { ..n, children: [] },
                      "root",
                    )
                    // 重建子关系
                    match base_ab.doc.nodes.get(cid) {
                      Some(src) => {
                        let _ = new_ab.doc.update_node(cid, fn(x) {
                          { ..x, children: src.children.copy() }
                        })
                      }
                      None => ()
                    }
                  }
                  None => ()
                }
              }
            }
          None => ()
        }
        created.push("\"\{id}\"")
      }
      let j = jstr11(created)
      Ok("{\"ok\":true,\"base\":\"\{base}\",\"variants\":[\{j}]}")
    }
  }
}

///|
/// 对所有画板评分（ violations 越少越好）
pub fn Project::score_variants(self : Project) -> String {
  let scores : Array[String] = []
  for id in self.artboards.keys() {
    match self.artboards.get(id) {
      Some(ab) => {
        let violations = validate(ab.doc).length()
        let lint_count = match self.lint(artboard=id) {
          Ok(json) => count_occurrences(json, "\"severity\"")
          Err(_) => 0
        }
        let align_count = match self.suggest_alignment(artboard=id) {
          Ok(json) => count_occurrences(json, "\"type\"")
          Err(_) => 0
        }
        let nodes = ab.doc.nodes.size() - 1 // 减 root
        // 评分：节点多（丰富）+ 违规少 + lint 少 = 高分
        let score = nodes * 10 -
          violations * 50 -
          lint_count * 10 -
          align_count * 5
        scores.push(
          "{\"artboard\":\"\{id}\",\"violations\":\{violations},\"lint\":\{lint_count},\"alignment_hints\":\{align_count},\"nodes\":\{nodes},\"score\":\{score}}",
        )
      }
      None => ()
    }
  }
  let j = jstr11(scores)
  "[\{j}]"
}

///|
/// 合并变体：把源画板的内容替换到目标画板
pub fn Project::merge_variant(
  self : Project,
  source~ : String,
  target~ : String,
) -> Result[String, String] {
  match (self.artboards.get(source), self.artboards.get(target)) {
    (Some(src), Some(tgt)) => {
      // 清空目标
      tgt.doc.nodes = Map::new()
      tgt.doc.root_id = "root"
      // 复制源
      let root_node = match src.doc.nodes.get(src.doc.root_id) {
        Some(r) => { ..r, children: r.children.copy() }
        None => Node::make("root", Frame)
      }
      tgt.doc.nodes.set("root", root_node)
      for id in src.doc.nodes.keys() {
        if id != "root" {
          match src.doc.nodes.get(id) {
            Some(n) =>
              tgt.doc.nodes.set(id, { ..n, children: n.children.copy() })
            None => ()
          }
        }
      }
      self.revision = self.revision + 1
      Ok("{\"ok\":true,\"merged\":\"\{source}\" → \"\{target}\"}")
    }
    _ => Err("unknown_artboard")
  }
}

///|
fn count_occurrences(s : String, sub : String) -> Int {
  let mut count = 0
  let mut pos = 0
  let sub_len = sub.length()
  while pos < s.length() {
    match s.substring(start=pos).find(sub) {
      Some(idx) => {
        count = count + 1
        pos = pos + idx + sub_len
      }
      None => break
    }
  }
  count
}

///|
fn jstr11(parts : Array[String]) -> String {
  let sb = StringBuilder::new()
  for i in 0..<parts.length() {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string(parts[i])
  }
  sb.to_string()
}
