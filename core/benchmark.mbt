///|
/// 性能基准引擎：节点数 / 布局求解复杂度 / 渲染开销 / 内存估算。
///
/// Agent 生成设计后需要知道"这个设计跑得动吗？"
/// 引擎通过**复杂度分析**（而非平台相关的 wall-clock 计时）给出：
/// - 节点统计：总数 / 最大深度 / 平均子节点
/// - 布局复杂度：栈布局数 / Fill 节点数 / Hug 节点数（高开销）
/// - 渲染开销：SVG 输出长度 / 文字节点占比
/// - 内存估算：基于节点数和文本量的近似值
/// - 性能反模式检测：节点过多 / 嵌套过深 / Fill 过多
/// - 优化建议：合并节点 / 减少嵌套 / 用 Fixed 替代 Fill

// ---------------------------------------------------------------------------
// 基准数据
// ---------------------------------------------------------------------------

pub(all) struct ArtboardBenchmark {
  artboard : String
  node_count : Int
  max_depth : Int
  avg_children : Double
  stack_layout_count : Int
  fill_node_count : Int
  hug_node_count : Int
  text_node_count : Int
  total_text_length : Int
  svg_output_length : Int
  layout_complexity : Int // 相对复杂度（操作计数）
  render_complexity : Int // 渲染复杂度（字节量）
  memory_estimate_bytes : Int // 内存估算
  antipatterns : Array[String]
  score : Int // 0-100（越高越好）
}

///|
pub(all) struct ProjectBenchmark {
  artboards : Array[ArtboardBenchmark]
  total_nodes : Int
  total_memory : Int
  avg_score : Double
  grade : String // "A" | "B" | "C" | "D"
}

// ---------------------------------------------------------------------------
// 单画板基准
// ---------------------------------------------------------------------------

///|
pub fn Project::benchmark_artboard(
  self : Project,
  artboard~ : String,
) -> Result[ArtboardBenchmark, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard")
    Some(ab) => {
      let doc = ab.doc
      let layout = solve(doc)
      let svg = render_svg(doc)

      // 统计节点
      let node_count = doc.nodes.size() - 1 // 减 root
      let mut max_depth = 0
      let mut total_children = 0
      let mut parent_count = 0
      let mut stack_count = 0
      let mut fill_count = 0
      let mut hug_count = 0
      let mut text_count = 0
      let mut text_length = 0

      for id in doc.nodes.keys() {
        match doc.nodes.get(id) {
          Some(n) => {
            // 深度计算
            let depth = compute_depth(doc, id)
            if depth > max_depth {
              max_depth = depth
            }
            // 子节点
            if n.children.length() > 0 {
              parent_count = parent_count + 1
              total_children = total_children + n.children.length()
            }
            // 布局统计
            match n.layout {
              Some(_) => stack_count = stack_count + 1
              None => ()
            }
            // 尺寸规格
            match n.width {
              Fill => fill_count = fill_count + 1
              Hug => hug_count = hug_count + 1
              _ => ()
            }
            // 文字
            if n.text != "" {
              text_count = text_count + 1
              text_length = text_length + n.text.length()
            }
          }
          None => ()
        }
      }

      let avg_children = if parent_count > 0 {
        total_children.to_double() / parent_count.to_double()
      } else {
        0.0
      }

      // 复杂度估算
      // 布局：每个节点 1 次求解 + Fill 额外 2 次 + Hug 额外 3 次
      let layout_complexity = node_count +
        fill_count * 2 +
        hug_count * 3 +
        stack_count * node_count / 4

      // 渲染复杂度：SVG 字节数
      let render_complexity = svg.length()

      // 内存估算：每节点约 200 字节 + 文本
      let memory = node_count * 200 + text_length * 2

      // 反模式检测
      let antipatterns : Array[String] = []
      if node_count > 100 {
        antipatterns.push(
          "too_many_nodes: \{node_count} > 100，考虑拆分画板",
        )
      }
      if max_depth > 8 {
        antipatterns.push("too_deep: 深度 \{max_depth} > 8，扁平化嵌套")
      }
      if fill_count > 30 {
        antipatterns.push(
          "excessive_fill: \{fill_count} 个 Fill 节点，考虑用 Fixed 减少求解开销",
        )
      }
      if hug_count > 20 {
        antipatterns.push(
          "excessive_hug: \{hug_count} 个 Hug 节点（最贵），用 Fixed 替代",
        )
      }
      if avg_children > 15 {
        antipatterns.push(
          "wide_node: 平均 \{avg_children.to_int()} 个子节点，考虑分组",
        )
      }

      // 评分
      let node_score = if node_count <= 30 {
        30
      } else if node_count <= 60 {
        25
      } else if node_count <= 100 {
        15
      } else {
        5
      }
      let depth_score = if max_depth <= 4 {
        25
      } else if max_depth <= 6 {
        20
      } else if max_depth <= 8 {
        12
      } else {
        5
      }
      let fill_score = if fill_count <= 10 {
        25
      } else if fill_count <= 20 {
        18
      } else if fill_count <= 30 {
        10
      } else {
        3
      }
      let hug_score = if hug_count <= 5 {
        20
      } else if hug_count <= 10 {
        15
      } else if hug_count <= 20 {
        8
      } else {
        3
      }
      let score = node_score + depth_score + fill_score + hug_score

      Ok({
        artboard,
        node_count,
        max_depth,
        avg_children,
        stack_layout_count: stack_count,
        fill_node_count: fill_count,
        hug_node_count: hug_count,
        text_node_count: text_count,
        total_text_length: text_length,
        svg_output_length: render_complexity,
        layout_complexity,
        render_complexity,
        memory_estimate_bytes: memory,
        antipatterns,
        score,
      })
    }
  }
}

// ---------------------------------------------------------------------------
// 项目级基准
// ---------------------------------------------------------------------------

///|
pub fn Project::benchmark(self : Project) -> ProjectBenchmark {
  let benchmarks : Array[ArtboardBenchmark] = []
  let mut total_nodes = 0
  let mut total_memory = 0
  let mut total_score = 0

  for id in self.artboards.keys() {
    match self.benchmark_artboard(artboard=id) {
      Ok(b) => {
        total_nodes = total_nodes + b.node_count
        total_memory = total_memory + b.memory_estimate_bytes
        total_score = total_score + b.score
        benchmarks.push(b)
      }
      Err(_) => ()
    }
  }

  let avg = if benchmarks.length() > 0 {
    total_score.to_double() / benchmarks.length().to_double()
  } else {
    0.0
  }
  let grade = if avg >= 85 {
    "A"
  } else if avg >= 65 {
    "B"
  } else if avg >= 45 {
    "C"
  } else {
    "D"
  }

  { artboards: benchmarks, total_nodes, total_memory, avg_score: avg, grade }
}

// ---------------------------------------------------------------------------
// 报告生成
// ---------------------------------------------------------------------------

///|
pub fn ArtboardBenchmark::to_json(self : ArtboardBenchmark) -> String {
  let sb = StringBuilder::new()
  sb.write_string("{\"artboard\":\"\{self.artboard}\"")
  sb.write_string(",\"nodes\":\{self.node_count}")
  sb.write_string(",\"depth\":\{self.max_depth}")
  let ac = self.avg_children.to_string()
  sb.write_string(",\"avg_children\":\{ac}")
  sb.write_string(",\"fill\":\{self.fill_node_count}")
  sb.write_string(",\"hug\":\{self.hug_node_count}")
  sb.write_string(",\"layout_ops\":\{self.layout_complexity}")
  sb.write_string(",\"svg_bytes\":\{self.render_complexity}")
  let mem = self.memory_estimate_bytes.to_string()
  sb.write_string(",\"memory\":\{mem}")
  sb.write_string(",\"score\":\{self.score}")
  sb.write_string(",\"antipatterns\":\{self.antipatterns.length()}")
  sb.write_string("}")
  sb.to_string()
}

///|
pub fn ProjectBenchmark::to_json(self : ProjectBenchmark) -> String {
  let sb = StringBuilder::new()
  sb.write_string("{\"total_nodes\":\{self.total_nodes}")
  sb.write_string(",\"total_memory\":\{self.total_memory}")
  let avg = self.avg_score.to_string()
  sb.write_string(",\"avg_score\":\{avg}")
  sb.write_string(",\"grade\":\"\{self.grade}\"")
  sb.write_string(",\"artboards\":[")
  for i in 0..<self.artboards.length() {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string(self.artboards[i].to_json())
  }
  sb.write_string("]}")
  sb.to_string()
}

///|
/// 人类可读报告
pub fn ProjectBenchmark::report(self : ProjectBenchmark) -> String {
  let sb = StringBuilder::new()
  sb.write_string("Performance Benchmark Report\n")
  sb.write_string("============================\n\n")
  let tn = self.total_nodes.to_string()
  let tm = self.total_memory.to_string()
  let avg = self.avg_score.to_string()
  sb.write_string("Overall: \{self.grade} (\{avg}/100)\n")
  sb.write_string("Total nodes: \{tn}\n")
  sb.write_string("Est. memory: \{tm} bytes\n\n")
  for b in self.artboards.iter() {
    sb.write_string(
      "  [\{b.artboard}] \{b.node_count} nodes, depth \{b.max_depth}",
    )
    sb.write_string(", \{b.fill_node_count} Fill, \{b.hug_node_count} Hug")
    sb.write_string(", score \{b.score}/100\n")
    if b.antipatterns.length() > 0 {
      for a in b.antipatterns.iter() {
        sb.write_string("    ⚠ \{a}\n")
      }
    }
  }
  sb.to_string()
}

///|
/// 优化建议
pub fn Project::suggest_optimizations(
  self : Project,
  artboard~ : String,
) -> Result[String, String] {
  match self.benchmark_artboard(artboard~) {
    Err(e) => Err(e)
    Ok(b) => {
      let suggestions : Array[String] = []
      if b.node_count > 60 {
        suggestions.push(
          "{\"type\":\"split\",\"description\":\"节点较多（\{b.node_count}），考虑拆分为多个画板或使用组件复用\"}",
        )
      }
      if b.max_depth > 6 {
        suggestions.push(
          "{\"type\":\"flatten\",\"description\":\"嵌套过深（\{b.max_depth} 层），减少不必要的容器层级\"}",
        )
      }
      if b.fill_node_count > 15 {
        suggestions.push(
          "{\"type\":\"reduce_fill\",\"description\":\"Fill 节点 \{b.fill_node_count} 个，固定尺寸可减少布局求解\"}",
        )
      }
      if b.hug_node_count > 8 {
        suggestions.push(
          "{\"type\":\"reduce_hug\",\"description\":\"Hug 节点 \{b.hug_node_count} 个（最高开销），改用 Fixed 尺寸\"}",
        )
      }
      if suggestions.length() == 0 {
        Ok("{\"optimizations\":0,\"message\":\"性能良好，无需优化\"}")
      } else {
        let j = jstr23(suggestions)
        Ok("{\"optimizations\":\{suggestions.length()},\"detail\":\{j}}")
      }
    }
  }
}

// ---------------------------------------------------------------------------
// 辅助
// ---------------------------------------------------------------------------

///|
fn compute_depth(doc : Document, id : String) -> Int {
  let mut depth = 0
  let mut cur : String? = Some(id)
  let mut running = true
  let mut counter = 0
  while running && counter < 100 {
    counter = counter + 1
    match cur {
      Some(cid) =>
        match doc.find_parent(cid) {
          Some(pid) => {
            depth = depth + 1
            cur = Some(pid)
          }
          None => running = false
        }
      None => running = false
    }
  }
  depth
}

///|
fn jstr23(parts : Array[String]) -> String {
  let sb = StringBuilder::new()
  for i in 0..<parts.length() {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string(parts[i])
  }
  sb.to_string()
}
