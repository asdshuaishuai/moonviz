///|
/// MoonViz 原型工作台：纯 MoonBit 可运行客户端。
///
/// 运行：moon run playground
/// 场景全部由引擎（core/decl）计算：声明渲染、Agent 硬门槛拒绝、
/// 人类视觉债放行、连同债务一起修复；末尾打印可用 SVG。
fn main {
  repl_loop()
}

///|
const MOCKUP : String = "let page = @decl.prototype(name=\"mockup\", width=390, height=844)\npage.add(@decl.rect(id=\"navbar\",x=0,y=0,width=@decl.fixed(390),height=@decl.fixed(88),fill=\"#111827\"))\npage.add(@decl.frame(id=\"hero\",y=88,width=@decl.fixed(390),height=@decl.fixed(160),fill=\"#EEF2FF\"))\npage.add_to(parent_id=\"hero\", node=@decl.rect(id=\"badge\",x=24.0,y=40.0,width=@decl.fixed(96),height=@decl.fixed(36),fill=\"#4B6BFB\",text=\"NEW\"))\npage.add(@decl.frame(id=\"card\",x=24.0,y=280.0,width=@decl.fixed(342.0),height=@decl.fixed(300.0)))\npage.add_to(parent_id=\"card\", node=@decl.rect(id=\"chip-a\",x=16.0,y=16.0,width=@decl.fixed(120),height=@decl.fixed(48),fill=\"#E0E7FF\",text=\"标签 A\"))\npage.add_to(parent_id=\"card\", node=@decl.rect(id=\"chip-b\",x=160.0,y=100.0,width=@decl.fixed(120),height=@decl.fixed(48),fill=\"#CCFBF1\",text=\"标签 B\"))\npage.add(@decl.rect(id=\"fab\",x=318.0,y=772.0,width=@decl.fixed(56),height=@decl.fixed(56),fill=\"#FF7A45\",text=\"+\"))\n"

///|
fn count_lines(s : String) -> Int {
  let mut n = 0
  for c in s.iter() {
    if c == '\n' {
      n = n + 1
    }
  }
  n
}

///|
fn replace_first(s : String, old : String, new : String) -> String {
  match s.find(old) {
    None => s
    Some(i) =>
      s.substring(start=0, end=i) + new + s.substring(start=i + old.length())
  }
}

///|
pub fn scenario_report() -> String {
  let sb = StringBuilder::new()
  sb.write_string("== MoonViz 原型工作台 \{version()} ==\n")
  sb.write_string(
    "纯 MoonBit：布局、不崩谓词、SVG、声明往返全部在 moonviz 引擎内计算。\n\n",
  )
  match @decl.parse_decl(MOCKUP) {
    Err(e) => {
      sb.write_string("[1] 解析失败（不应发生)：\{e.describe()}\n")
      return sb.to_string()
    }
    Ok(page) => {
      let violations = page.check()
      sb.write_string(
        "[1] Agent 声明 → 渲染：不崩谓词违规 \{violations.length()} 条；SVG \{count_lines(page.render())} 行（文末输出全文）\n",
      )
    }
  }
  // [2] Agent 越界：走会话协议，硬门槛整体拒绝（结构化错误 JSON）
  let overflow = replace_first(
    MOCKUP,
    "height=@decl.fixed(88)",
    "height=@decl.fixed(900)",
  )
  let resp2 = handle("render\n" + overflow)
  sb.write_string(
    "[2] 模拟 Agent 越界编辑（导航栏 88→900）→ 会话协议返回：\n    \{resp2}\n",
  )
  // [3] 人类拖拽出内容卡：结构硬 / 视觉软
  match @decl.parse_decl(MOCKUP) {
    Err(e) => sb.write_string("[3] 解析失败：\{e.describe()}\n")
    Ok(p3) => {
      let _ = p3.move_node(id="chip-b", x=160.0, y=336.0)
      let debt = p3.check()
      sb.write_string(
        "[3] 人类拖拽 chip-b 出内容卡：合并成功（人类策略：提示不阻断），视觉债 \{debt.length()} 条\n",
      )
      // [4] Agent 连同视觉债一起修复 → 通过
      let fixed_decl = replace_first(p3.to_decl_text(), "y=336", "y=100")
      match @decl.parse_decl(fixed_decl) {
        Err(e) =>
          sb.write_string("[4] 修复声明解析失败：\{e.describe()}\n")
        Ok(p4) =>
          sb.write_string(
            "[4] Agent 修复视觉债后可再提交：违规 \{p4.check().length()} 条 → 通过，画布即恢复\n",
          )
      }
    }
  }
  sb.write_string(
    "\n[5] 声明往返 parse_decl / to_decl_text：双向同步的引擎基座（文本定点可测）\n",
  )
  sb.write_string("---- [1] 的 SVG 渲染输出 ----\n")
  match @decl.parse_decl(MOCKUP) {
    Ok(page) => {
      sb.write_string(page.render())
      sb.write_string("\n---- 渲染输出结束 ----\n")
    }
    Err(e) => sb.write_string("渲染失败：\{e.describe()}\n")
  }
  sb.to_string()
}
