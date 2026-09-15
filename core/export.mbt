/// 导出管道：从 Project 生成可直接使用的代码/原型。
///
/// - export_html：自包含交互式 HTML 原型（无依赖，可直接打开）
/// - export_react：React TSX 组件桩（内联样式，可直接放进 Next.js）
/// - export_tailwind：Tailwind CSS class 映射（可组合进现有项目）

// ---------------------------------------------------------------------------
// HTML 原型导出
// ---------------------------------------------------------------------------

///|
/// 导出为自包含 HTML（SVG 内嵌 + 画板切换 + 导航流模拟）
pub fn Project::export_html(self : Project) -> String {
  let sb = StringBuilder::new()
  sb.write_string(
    "<!DOCTYPE html>\n<html lang=\"zh\">\n<head>\n<meta charset=\"UTF-8\">\n",
  )
  sb.write_string(
    "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">\n",
  )
  sb.write_string("<title>MoonViz Prototype</title>\n")
  sb.write_string("<style>\n")
  sb.write_string(
    "  body{margin:0;font-family:-apple-system,sans-serif;background:#1a1c1e;color:#e0e0e0;display:flex;flex-direction:column;align-items:center;min-height:100vh}\n",
  )
  sb.write_string("  .tabs{display:flex;gap:8px;padding:12px;flex-wrap:wrap}\n")
  sb.write_string(
    "  .tab{padding:8px 16px;border-radius:8px;cursor:pointer;background:#2a2c2e;border:1px solid #42474f;font-size:14px}\n",
  )
  sb.write_string("  .tab.active{background:#4B6BFB;color:#fff}\n")
  sb.write_string(
    "  .board{display:none;padding:16px;border-radius:16px;box-shadow:0 4px 20px rgba(0,0,0,.3)}\n",
  )
  sb.write_string("  .board.active{display:block;background:#fff}\n")
  sb.write_string(
    "  .flow{padding:12px;font-size:12px;color:#9098a1;text-align:center}\n" +
    "  g[id^=n_]{cursor:pointer}\n" +
    "  #mv-toast{position:fixed;left:50%;bottom:10%;transform:translateX(-50%) translateY(20px);background:rgba(20,22,26,.92);color:#fff;padding:10px 22px;border-radius:99px;font-size:14px;opacity:0;transition:all .25s ease;pointer-events:none;z-index:9}\n" +
    "  #mv-toast.show{opacity:1;transform:translateX(-50%) translateY(0)}\n" +
    "  .board{transition:opacity .18s ease}\n",
  )
  // 状态多态 CSS：每个非 default 状态生成一份视觉覆盖（fill/text_color/
  // font_size）。SVG 表现属性可被 CSS 覆盖，g[#n_x] 挂 .st-<state> 类切换。
  for node_id in self.node_states.keys() {
    let def = match self.node_states.get(node_id) {
      Some(d) => d
      None => continue
    }
    for state_name in def.states.keys() {
      if state_name == "default" {
        continue
      }
      match def.states.get(state_name) {
        Some(patch) => {
          let rules : Array[String] = []
          match patch.fill {
            Some(f) =>
              rules.push(
                "fill:\{self.tokens.resolve_color(f)}",
              )
            None => ()
          }
          match patch.text_color {
            Some(c) =>
              rules.push(
                "fill:\{self.tokens.resolve_color(c)}",
              )
            None => ()
          }
          match patch.font_size {
            Some(fs) => rules.push("font-size:\{fs}px")
            None => ()
          }
          if rules.length() > 0 {
            let decl = rules.join(";")
            let sel = "g#n_" + node_id + ".st-" + state_name
            sb.write_string("  \{sel} rect,\{sel} text{\{decl}}\n")
          }
        }
        None => ()
      }
    }
  }
  sb.write_string("</style>\n</head>\n<body>\n")
  // Tab 栏
  sb.write_string("<div class=\"tabs\">\n")
  for id in self.artboards.keys() {
    match self.artboards.get(id) {
      Some(ab) =>
        sb.write_string(
          "  <div class=\"tab\" onclick=\"show('\{id}')\" id=\"tab-\{id}\">\{ab.name}</div>\n",
        )
      None => ()
    }
  }
  sb.write_string("</div>\n")
  // 画板内容
  for id in self.artboards.keys() {
    match self.artboards.get(id) {
      Some(ab) => {
        let svg = render_svg(
          ab.doc,
          surface=self.tokens.resolve_color("surface"),
          frame=self.tokens.resolve_color("outline"),
        )
        sb.write_string(
          "<div class=\"board\" id=\"board-\{id}\" style=\"width:\{ab.width.to_int()}px\">\n",
        )
        sb.write_string(svg)
        sb.write_string("\n</div>\n")
      }
      None => ()
    }
  }
  // JS
  sb.write_string("<div id=\"mv-toast\"></div>\n")
  sb.write_string("<script>\n")
  // 交互数据表：[画板, 节点, 动作, 参数]。flows 的 tap:node 前缀与
  // ⚡trigger→action 词汇表在导出层合并为同一张绑定表。
  let acts : Array[String] = []
  for e in self.flows.iter() {
    let node = if e.trigger.length() > 4 && e.trigger.substring(start=0, end=4) == "tap:" {
      e.trigger.substring(start=4)
    } else {
      ""
    }
    if node != "" {
      acts.push(
        "[\"\{json_escape(e.from)}\",\"\{json_escape(node)}\",\"navigate\",\"\{json_escape(e.to)}\"]",
      )
    }
  }
  for ab_id in self.artboards.keys() {
    match self.artboards.get(ab_id) {
      Some(ab) =>
        for nid in ab.doc.nodes.keys() {
          match ab.doc.nodes.get(nid) {
            Some(n) =>
              match parse_interaction_marker(n.name) {
                Some((trig, spec)) => {
                  if trig == "tap" {
                    match action_from_spec(spec) {
                      Some(NavigateTo(t)) =>
                        acts.push(
                          "[\"\{json_escape(ab_id)}\",\"\{json_escape(nid)}\",\"navigate\",\"\{json_escape(t)}\"]",
                        )
                      Some(Back) =>
                        acts.push(
                          "[\"\{json_escape(ab_id)}\",\"\{json_escape(nid)}\",\"back\",\"\"]",
                        )
                      Some(ShowToast(msg)) =>
                        acts.push(
                          "[\"\{json_escape(ab_id)}\",\"\{json_escape(nid)}\",\"toast\",\"\{json_escape(msg)}\"]",
                        )
                      Some(SetState(id2, st)) =>
                        acts.push(
                          "[\"\{json_escape(ab_id)}\",\"\{json_escape(nid)}\",\"set_state\",\"\{json_escape(id2)}:\{json_escape(st)}\"]",
                        )
                      Some(ToggleState(id2, _)) =>
                        acts.push(
                          "[\"\{json_escape(ab_id)}\",\"\{json_escape(nid)}\",\"toggle_state\",\"\{json_escape(id2)}\"]",
                        )
                      Some(SetText(id2, txt)) =>
                        acts.push(
                          "[\"\{json_escape(id2)}\",\"\{json_escape(nid)}\",\"set_text\",\"\{json_escape(id2)}:\{json_escape(txt)}\"]",
                        )
                      _ => ()
                    }
                  }
                }
                None => ()
              }
            None => ()
          }
        }
      None => ()
    }
  }
  // 状态名清单：toggle 恢复到第一个非 default 状态
  let state_defs : Array[String] = []
  for node_id in self.node_states.keys() {
    match self.node_states.get(node_id) {
      Some(def) => {
        let names : Array[String] = []
        for st in def.states.keys() {
          if st != "default" {
            names.push(st)
          }
        }
        if names.length() > 0 {
          let joined = names.join(",")
          state_defs.push(
            "\"\{json_escape(node_id)}\":\"\{joined}\"",
          )
        }
      }
      None => ()
    }
  }
  let states_js = state_defs.join(",")
  sb.write_string("const MV_STATES={\{states_js}};\n")
  let acts_js = acts.join(",")
  sb.write_string("const MV_ACT=[\{acts_js}];\n")
  sb.write_string(
    "const MV_STACK=[];const cur=()=>MV_STACK[MV_STACK.length-1];\n",
  )
  sb.write_string(
    "function show(id,push=true){if(push&&cur()!==id)MV_STACK.push(id);document.querySelectorAll('.tab').forEach(t=>t.classList.remove('active'));document.querySelectorAll('.board').forEach(b=>b.classList.remove('active'));document.getElementById('tab-'+id)?.classList.add('active');document.getElementById('board-'+id)?.classList.add('active')}\n",
  )
  sb.write_string(
    "function back(){if(MV_STACK.length>1){MV_STACK.pop();show(MV_STACK[MV_STACK.length-1],false)}}\n",
  )
  sb.write_string(
    "let mvTimer;function toast(m){const t=document.getElementById('mv-toast');t.textContent=m;t.classList.add('show');clearTimeout(mvTimer);mvTimer=setTimeout(()=>t.classList.remove('show'),1800)}\n",
  )
  sb.write_string(
    "function setState(b,n,st,on=true){const el=document.querySelector('#board-'+b+' #n_'+n);if(!el)return;[...el.classList].filter(c=>c.startsWith('st-')).forEach(c=>el.classList.remove(c));if(on&&st)el.classList.add('st-'+st)}\n",
  )
  sb.write_string(
    "MV_ACT.forEach(([b,n,k,v])=>{const el=document.querySelector('#board-'+b+' #n_'+n);if(!el)return;el.addEventListener('click',ev=>{ev.stopPropagation();if(k==='navigate')show(v);else if(k==='back')back();else if(k==='toast')toast(v);else if(k==='set_state'){const i=v.substring(0,v.indexOf(':')),s=v.substring(v.indexOf(':')+1);setState(b,i,s)}else if(k==='toggle_state'){const el2=document.querySelector('#board-'+b+' #n_'+v);const on=el2&&[...el2.classList].some(c=>c.startsWith('st-'));setState(b,v,'',false);if(!on&&MV_STATES[v])setState(b,v,MV_STATES[v].split(',')[0])}else if(k==='set_text'){const i=v.substring(0,v.indexOf(':')),s=v.substring(v.indexOf(':')+1);const t=document.querySelector('#board-'+b+' #n_'+i+' text');if(t)t.textContent=s}})});\n",
  )
  // 默认显示第一个（show 已由上方带导航栈的版本定义）
  let first : String? = None
  for id in self.artboards.keys() {
    match first {
      None => sb.write_string("show('\{id}')\n")
      Some(_) => ()
    }
  }
  sb.write_string("</script>\n</body>\n</html>")
  sb.to_string()
}

// ---------------------------------------------------------------------------
// React 组件桩导出
// ---------------------------------------------------------------------------

///|
/// 导出为 React TSX 组件桩（每个画板一个组件，内联样式）
pub fn Project::export_react(self : Project) -> String {
  let sb = StringBuilder::new()
  sb.write_string("// Auto-generated by MoonViz Agent Engine\n")
  sb.write_string("// 每个 Artboard 映射为一个 React 组件\n\n")
  for id in self.artboards.keys() {
    match self.artboards.get(id) {
      Some(ab) => {
        let comp_name = to_pascal_case(ab.name)
        sb.write_string("export function \{comp_name}() {\n")
        sb.write_string("  return (\n")
        // 生成 JSX 树
        let layout = solve(ab.doc)
        write_react_node(sb, ab.doc, ab.doc.root_id, layout, 2)
        sb.write_string("  )\n}\n\n")
      }
      None => ()
    }
  }
  // 导航流映射
  if self.flows.length() > 0 {
    sb.write_string("// Navigation flows:\n")
    for e in self.flows.iter() {
      sb.write_string(
        "// \{to_pascal_case(e.from)} -> \{to_pascal_case(e.to)} (trigger: \{e.trigger})\n",
      )
    }
  }
  sb.to_string()
}

///|
fn write_react_node(
  sb : StringBuilder,
  doc : Document,
  id : String,
  layout : SolvedLayout,
  indent : Int,
) -> Unit {
  let pad = repeat_str("  ", indent)
  match (doc.nodes.get(id), layout.rect_of(id)) {
    (Some(n), Some(r)) => {
      let style = "position:'absolute',left:\{r.x.to_int()},top:\{r.y.to_int()},width:\{r.width.to_int()},height:\{r.height.to_int()}"
      let extra_style = react_style(n)
      let full_style = if extra_style != "" {
        "\{style},\{extra_style}"
      } else {
        style
      }
      match n.kind {
        Text =>
          sb.write_string(
            "\{pad}<span style={{\{full_style}}}\{n.text}</span>\n",
          )
        _ =>
          if n.children.length() == 0 {
            sb.write_string(
              "\{pad}<div data-id=\"\{n.id}\" style={{\{full_style}}} />\n",
            )
          } else {
            sb.write_string(
              "\{pad}<div data-id=\"\{n.id}\" style={{\{full_style}}}>\n",
            )
            for cid in n.children.iter() {
              write_react_node(sb, doc, cid, layout, indent + 1)
            }
            sb.write_string("\{pad}</div>\n")
          }
      }
    }
    _ => ()
  }
}

///|
fn react_style(n : Node) -> String {
  let parts : Array[String] = []
  if n.style.fill != "none" && n.style.fill != "" {
    parts.push("background:'\{n.style.fill}'")
  }
  if n.style.corner_radius > 0 {
    parts.push("borderRadius:\{n.style.corner_radius.to_int()}")
  }
  if n.style.font_size != 14.0 {
    parts.push("fontSize:\{n.style.font_size.to_int()}")
  }
  if n.style.text_color != "#111111" {
    parts.push("color:'\{n.style.text_color}'")
  }
  if n.style.stroke != "none" && n.style.stroke != "" {
    parts.push("border:'1px solid \{n.style.stroke}'")
  }
  jstr8(parts, ",")
}

///|
fn jstr8(parts : Array[String], sep : String) -> String {
  let sb = StringBuilder::new()
  for i in 0..<parts.length() {
    if i > 0 {
      sb.write_string(sep)
    }
    sb.write_string(parts[i])
  }
  sb.to_string()
}

// ---------------------------------------------------------------------------
// 工具
// ---------------------------------------------------------------------------

///|
fn to_pascal_case(s : String) -> String {
  let sb = StringBuilder::new()
  let mut upper_next = true
  for c in s.iter() {
    let code = c.to_int()
    if code == 95 || code == 45 || code == 32 { // _ - space
      upper_next = true
    } else if upper_next {
      if code >= 97 && code <= 122 {
        sb.write_char(Char::from_int(code - 32))
      } else {
        sb.write_char(c)
      }
      upper_next = false
    } else {
      sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
fn repeat_str(s : String, n : Int) -> String {
  let sb = StringBuilder::new()
  for _i in 0..<n {
    sb.write_string(s)
  }
  sb.to_string()
}
