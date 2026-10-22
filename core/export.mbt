/// 导出管道：从 Project 生成可直接使用的代码/原型。
///
/// - export_html：自包含交互式 HTML 原型（无依赖，可直接打开）
/// - export_react：React TSX 组件桩（内联样式，可直接放进 Next.js）
/// - export_tailwind：Tailwind CSS class 映射（可组合进现有项目）

// ---------------------------------------------------------------------------
// HTML 原型导出
// ---------------------------------------------------------------------------

///|
/// 入场画板推断：导航流的天然起点——没有被任何 flow 指向的画板；并列/成环
/// 时按确定性 tie-break 取最小 id（String < 为长度优先的 shortlex，非纯
/// 字典序）。登录→首页型原型因此开在登录页，不再随
/// Map 遍历序漂移到任意画板（精致感缺陷：开屏即错页）。
fn Project::infer_entry(self : Project) -> String {
  let targets : Map[String, Bool] = {}
  for e in self.flows.iter() {
    targets.set(e.to, true)
  }
  let mut best = ""
  for id in self.artboards.keys() {
    if !targets.contains(id) && (best == "" || id < best) {
      best = id
    }
  }
  if best == "" {
    for id in self.artboards.keys() {
      if best == "" || id < best {
        best = id
      }
    }
  }
  best
}

///|
/// 导出面的 JS 字符串转义（仅 export 层收口，不动 core/json.mbt 的
/// json_escape——那是 JSON 协议语义）：boot/tab onclick 落在单引号 JS
/// 字符串、MV_ACT/MV_STATES 落在双引号 JS 字符串，且全部内嵌在 <script>
/// 里。duplicate 的 new_name 原样成为画板 id，可含单引号/尖括号——
/// json_escape 不转义单引号，裸插会让整个脚本解析失败、原型交互全哑。
/// 引号/反斜杠/'<'/C0 控制符统一转成 JS 转义序列；'<' 一律 \x3c，
/// 顺带封死 </script> 从字符串内提前闭合（含大小写变体）。
fn js_string_escape(s : String) -> String {
  let sb = StringBuilder::new()
  for c in s.iter() {
    match c {
      '"' => sb.write_string("\\x22")
      '\'' => sb.write_string("\\'")
      '\\' => sb.write_string("\\\\")
      '<' => sb.write_string("\\x3c")
      '\n' => sb.write_string("\\n")
      '\r' => sb.write_string("\\r")
      '\t' => sb.write_string("\\t")
      _ => {
        let code = c.to_int()
        if code < 32 {
          // 其余 C0 控制符：\u00xx（编码尾段与 json_escape 共用）
          write_c0_u_escape(sb, code)
        } else {
          sb.write_char(c)
        }
      }
    }
  }
  sb.to_string()
}

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
  // 动效令牌：时长刻度 + 引擎缓动曲线（animation.mbt 单一来源，不手写贝塞尔）
  sb.write_string("  \{motion_tokens_css()}\n")
  sb.write_string(
    "  body{margin:0;font-family:-apple-system,sans-serif;background:#1a1c1e;color:#e0e0e0;display:flex;flex-direction:column;align-items:center;min-height:100vh}\n",
  )
  sb.write_string("  .tabs{display:flex;gap:8px;padding:12px;flex-wrap:wrap}\n")
  sb.write_string(
    "  .tab{padding:8px 16px;border-radius:8px;cursor:pointer;background:#2a2c2e;border:1px solid #42474f;font-size:14px;transition:background var(--mv-dur-fast) var(--mv-ease),color var(--mv-dur-fast) var(--mv-ease),border-color var(--mv-dur-fast) var(--mv-ease),box-shadow var(--mv-dur-fast) var(--mv-ease),transform var(--mv-dur-fast) var(--mv-spring)}\n",
  )
  sb.write_string("  .tab:hover{transform:translateY(-1px)}\n")
  sb.write_string(
    "  .tab.active{background:#4B6BFB;color:#fff;border-color:#4B6BFB;box-shadow:0 2px 10px rgba(75,107,251,.35)}\n",
  )
  sb.write_string(
    "  .board{display:none;padding:16px;border-radius:16px;box-shadow:0 4px 20px rgba(0,0,0,.3)}\n",
  )
  // 画板转场：方向感知（navigate 前进 +1 / back 返回 -1 / tab 纯淡入 0），
  // fill 用 backwards——结束后把 transform 交还按压反馈，不冻结交互
  sb.write_string(
    "  .board.active{display:block;background:#fff;animation:mv-board-in var(--mv-dur) var(--mv-out) backwards}\n",
  )
  sb.write_string(
    "  @keyframes mv-board-in{from{opacity:0;transform:translateX(calc(var(--mv-dir,1)*28px)) scale(.99)}to{opacity:1;transform:translateX(0) scale(1)}}\n",
  )
  // 入场阶梯：画板顶层节点依次浮现（24ms 步进，前 8 个后同步），克制不抢戏。
  // svg 的唯一直接子 g 是根 wrapper（render_svg 只对 root 调一次 render_node，
  // 节点 g 全嵌其内）——选择器下钻一层 >g>g 对准顶层节点；wrapper 自带一个
  // 非 g 的背景 rect 占位，故按 nth-of-type 对 g 计数，不受普通子元素挤位
  sb.write_string(
    "  .board.active>svg>g>g{animation:mv-rise var(--mv-dur) var(--mv-out) backwards}\n" +
    "  .board.active>svg>g>g:nth-of-type(2){animation-delay:24ms}\n" +
    "  .board.active>svg>g>g:nth-of-type(3){animation-delay:48ms}\n" +
    "  .board.active>svg>g>g:nth-of-type(4){animation-delay:72ms}\n" +
    "  .board.active>svg>g>g:nth-of-type(5){animation-delay:96ms}\n" +
    "  .board.active>svg>g>g:nth-of-type(6){animation-delay:120ms}\n" +
    "  .board.active>svg>g>g:nth-of-type(7){animation-delay:144ms}\n" +
    "  .board.active>svg>g>g:nth-of-type(8){animation-delay:168ms}\n" +
    "  @keyframes mv-rise{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:none}}\n",
  )
  sb.write_string(
    "  .flow{padding:12px;font-size:12px;color:#9098a1;text-align:center}\n" +
    // 按压反馈：spring 回弹 + fill-box 居中缩放（SVG 节点的触感来源）；
    // 状态多态的 fill 切换走引擎缓动——状态切换不再生硬跳变
    "  g[id^=n_]{cursor:pointer;transform-box:fill-box;transform-origin:center;transition:transform var(--mv-dur-fast) var(--mv-spring)}\n" +
    "  g[id^=n_]:active{transform:scale(.96)}\n" +
    "  g[id^=n_] rect,g[id^=n_] text{transition:fill var(--mv-dur) var(--mv-out)}\n" +
    "  #mv-toast{position:fixed;left:50%;bottom:10%;transform:translateX(-50%) translateY(20px);background:rgba(20,22,26,.92);color:#fff;padding:10px 22px;border-radius:99px;font-size:14px;opacity:0;transition:opacity var(--mv-dur) var(--mv-out),transform var(--mv-dur) var(--mv-spring);pointer-events:none;z-index:9}\n" +
    "  #mv-toast.show{opacity:1;transform:translateX(-50%) translateY(0)}\n" +
    // 无障碍：系统开启减弱动态效果时全部动效关闭（精致感不含强制动）
    "  @media (prefers-reduced-motion:reduce){*,*::before,*::after{animation:none!important;transition:none!important}}\n",
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
            Some(f) => rules.push("fill:\{self.tokens.resolve_color(f)}")
            None => ()
          }
          match patch.text_color {
            Some(c) => rules.push("fill:\{self.tokens.resolve_color(c)}")
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
      Some(ab) => {
        // onclick 的 id 落在单引号 JS 字符串里，必须转义；DOM id 属性保持
        // 原样——getElementById('tab-'+id) 按 JS 解析后的串查 DOM，两侧一致
        let js_id = js_string_escape(id)
        sb.write_string(
          "  <div class=\"tab\" onclick=\"show('\{js_id}',true,0)\" id=\"tab-\{id}\">\{ab.name}</div>\n",
        )
      }
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
    let node = if e.trigger.length() > 4 &&
      e.trigger.substring(start=0, end=4) == "tap:" {
      e.trigger.substring(start=4)
    } else {
      ""
    }
    if node != "" {
      acts.push(
        "[\"\{js_string_escape(e.from)}\",\"\{js_string_escape(node)}\",\"navigate\",\"\{js_string_escape(e.to)}\"]",
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
                Some((trig, spec)) =>
                  if trig == "tap" {
                    match action_from_spec(spec) {
                      Some(NavigateTo(t)) =>
                        acts.push(
                          "[\"\{js_string_escape(ab_id)}\",\"\{js_string_escape(nid)}\",\"navigate\",\"\{js_string_escape(t)}\"]",
                        )
                      Some(Back) =>
                        acts.push(
                          "[\"\{js_string_escape(ab_id)}\",\"\{js_string_escape(nid)}\",\"back\",\"\"]",
                        )
                      Some(ShowToast(msg)) =>
                        acts.push(
                          "[\"\{js_string_escape(ab_id)}\",\"\{js_string_escape(nid)}\",\"toast\",\"\{js_string_escape(msg)}\"]",
                        )
                      Some(SetState(id2, st)) =>
                        acts.push(
                          "[\"\{js_string_escape(ab_id)}\",\"\{js_string_escape(nid)}\",\"set_state\",\"\{js_string_escape(id2)}:\{js_string_escape(st)}\"]",
                        )
                      Some(ToggleState(id2, _)) =>
                        acts.push(
                          "[\"\{js_string_escape(ab_id)}\",\"\{js_string_escape(nid)}\",\"toggle_state\",\"\{js_string_escape(id2)}\"]",
                        )
                      Some(SetText(id2, txt)) =>
                        acts.push(
                          "[\"\{js_string_escape(id2)}\",\"\{js_string_escape(nid)}\",\"set_text\",\"\{js_string_escape(id2)}:\{js_string_escape(txt)}\"]",
                        )
                      _ => ()
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
          state_defs.push("\"\{js_string_escape(node_id)}\":\"\{joined}\"")
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
    "function show(id,push=true,dir=1){if(push&&cur()!==id)MV_STACK.push(id);const b=document.getElementById('board-'+id);if(b){b.style.setProperty('--mv-dir',dir);void b.offsetWidth}document.querySelectorAll('.tab').forEach(t=>t.classList.remove('active'));document.querySelectorAll('.board').forEach(x=>x.classList.remove('active'));document.getElementById('tab-'+id)?.classList.add('active');b?.classList.add('active');window.scrollTo({top:0,behavior:'smooth'})}\n",
  )
  sb.write_string(
    "function back(){if(MV_STACK.length>1){MV_STACK.pop();show(MV_STACK[MV_STACK.length-1],false,-1)}}\n",
  )
  sb.write_string(
    "let mvTimer;function toast(m){const t=document.getElementById('mv-toast');t.textContent=m;t.classList.add('show');clearTimeout(mvTimer);mvTimer=setTimeout(()=>t.classList.remove('show'),1800)}\n",
  )
  sb.write_string(
    "function setState(b,n,st,on=true){const el=document.querySelector('#board-'+b+' #n_'+n);if(!el)return;[...el.classList].filter(c=>c.startsWith('st-')).forEach(c=>el.classList.remove(c));if(on&&st)el.classList.add('st-'+st)}\n",
  )
  sb.write_string(
    "MV_ACT.forEach(([b,n,k,v])=>{const el=document.querySelector('#board-'+b+' #n_'+n);if(!el)return;el.addEventListener('click',ev=>{ev.stopPropagation();if(k==='navigate')show(v,true,1);else if(k==='back')back();else if(k==='toast')toast(v);else if(k==='set_state'){const i=v.substring(0,v.indexOf(':')),s=v.substring(v.indexOf(':')+1);setState(b,i,s)}else if(k==='toggle_state'){const el2=document.querySelector('#board-'+b+' #n_'+v);const on=el2&&[...el2.classList].some(c=>c.startsWith('st-'));setState(b,v,'',false);if(!on&&MV_STATES[v])setState(b,v,MV_STATES[v].split(',')[0])}else if(k==='set_text'){const i=v.substring(0,v.indexOf(':')),s=v.substring(v.indexOf(':')+1);const t=document.querySelector('#board-'+b+' #n_'+i+' text');if(t)t.textContent=s}})});\n",
  )
  // 键盘返回：ESC = back()（与引擎内置返回导航语义对齐）
  sb.write_string(
    "document.addEventListener('keydown',e=>{if(e.key==='Escape')back()});\n",
  )
  // 默认显示第一个（show 已由上方带导航栈的版本定义）
  let first : String? = None
  let entry = self.infer_entry()
  for id in self.artboards.keys() {
    match first {
      None => if id == entry {
        sb.write_string("show('\{js_string_escape(id)}',true,0)\n")
      }
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
