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
/// 该画板是否已有 tap:<node> 导航边（内置返回绑定据此避让显式 flow）。
fn Project::has_tap_flow(
  self : Project,
  artboard : String,
  node_id : String,
) -> Bool {
  let trigger = "tap:" + node_id
  for e in self.flows.iter() {
    if e.from == artboard && e.trigger == trigger {
      return true
    }
  }
  false
}

///|
/// 分板过渡关键帧 + 覆盖规则：名字统一由 Transition::name() 生成
/// （mv-board-push / mv-board-modal_present / …），show(id,push,dir,tr)
/// 只切换 .mv-tr-<name> 类；none 只出禁动画规则、不出关键帧。
fn board_transition_css() -> String {
  let sb = StringBuilder::new()
  for t in [Push, Pop, ModalPresent, ModalDismiss, SheetPresent, Fade].iter() {
    let n = t.name()
    sb.write_string(
      "  @keyframes mv-board-" + n + "{" + board_transition_frames(t) + "}\n",
    )
    sb.write_string(
      "  .board.active.mv-tr-" +
      n +
      "{animation:mv-board-" +
      n +
      " var(--mv-dur) var(--mv-out) backwards}\n",
    )
  }
  sb.write_string("  .board.active.mv-tr-none{animation:none}\n")
  sb.to_string()
}

///|
/// 每类过渡的 from/to 帧。push/pop 保留方向感知（--mv-dir），
/// modal/sheet 用纵向位移，fade 只改透明度。
fn board_transition_frames(t : Transition) -> String {
  match t {
    Push =>
      "from{opacity:0;transform:translateX(calc(var(--mv-dir,1)*28px)) scale(.99)}to{opacity:1;transform:translateX(0) scale(1)}"
    Pop =>
      "from{opacity:0;transform:translateX(calc(var(--mv-dir,1)*-28px)) scale(.99)}to{opacity:1;transform:translateX(0) scale(1)}"
    ModalPresent =>
      "from{opacity:0;transform:translateY(28px) scale(.98)}to{opacity:1;transform:none}"
    ModalDismiss =>
      "from{opacity:0;transform:translateY(-28px) scale(.98)}to{opacity:1;transform:none}"
    SheetPresent =>
      "from{opacity:0;transform:translateY(48px)}to{opacity:1;transform:none}"
    Fade => "from{opacity:0}to{opacity:1}"
    NoTransition => ""
  }
}

///|
/// 板内节点 id → DOM id（None/未知时原样）。
fn dom_id_in(m : Map[String, String]?, id : String) -> String {
  match m {
    Some(map) =>
      match map.get(id) {
        Some(d) => d
        None => id
      }
    None => id
  }
}

///|
/// HTML 属性值转义：双引号内联属性安全面（& < > "）。画板 id/名称是
/// Agent 可控文本（duplicate 的 new_name 可含 <b>/引号），裸插进
/// id="tab-..." 会生成真实子元素并截断标签文本；浏览器解析回原文后
/// 与 onclick 的 js_string_escape 串一致，getElementById 两侧匹配。
fn html_attr_escape(s : String) -> String {
  let sb = StringBuilder::new()
  for c in s.iter() {
    match c {
      '&' => sb.write_string("&amp;")
      '<' => sb.write_string("&lt;")
      '>' => sb.write_string("&gt;")
      '"' => sb.write_string("&quot;")
      _ => sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
/// CSS 标识符转义（与导出 JS 侧 cssEsc 的 fallback 同语义）：非
/// [A-Za-z0-9_-] 且 < U+00A0 的字符写成 `\` + 小写 hex + 尾空格。
/// 转义只作用于「选择器字面」，DOM 类名/元素 id 原文不变，与 JS 侧
/// classList.add('st-'+原文)/getElementById(原文) 天然一致。状态名与
/// DOM id 是 Agent 可控文本，裸插 `<` 会截断 <style> 块（</style> 提前
/// 闭合整页样式）并破坏选择器语法。
fn css_ident_escape(s : String) -> String {
  let sb = StringBuilder::new()
  for c in s.iter() {
    let code = c.to_int()
    let safe = (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122) ||
      (code >= 48 && code <= 57) ||
      code == 45 ||
      code == 95 ||
      code >= 160
    if safe {
      sb.write_char(c)
    } else {
      sb.write_string("\\" + int_to_hex(code) + " ")
    }
  }
  sb.to_string()
}

///|
/// html lang 白名单清洗（只留 ASCII 字母与 '-'，空则 zh）：lang 是可选
/// 入参，必须防止属性注入。
fn sanitize_lang(lang : String) -> String {
  let sb = StringBuilder::new()
  for c in lang.iter() {
    let code = c.to_int()
    if (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122) ||
      code == 45 {
      sb.write_char(c)
    }
  }
  let out = sb.to_string()
  if out == "" {
    "zh"
  } else {
    out
  }
}

///|
/// 交互节点的无障碍标签：原样名（去标记）→ 文本 → 组件名 → id。
/// 主图标按钮等无文字节点由组件名兜底，role=button 时不至于无名。
fn a11y_label(n : Node) -> String {
  let base = strip_all_markers(n.name)
  if base != "" && base != n.id {
    base
  } else if n.text.trim() != "" {
    n.text.trim().to_string()
  } else if n.component != "" {
    n.component
  } else {
    n.id
  }
}

///|
/// 导出为自包含 HTML（SVG 内嵌 + 画板切换 + 导航流模拟）。
///
/// 视觉语言（Apple HIG / HarmonyOS 共识）：chrome 全部由主题令牌派生为
/// CSS 变量（--mv-bg/--mv-surface/--mv-primary…），换主题即换整页气质；
/// 吸顶 tab 用 Vibrancy 磨砂材质（backdrop-filter），画板是设备感圆角
/// 屏幕（分层柔阴影 + hairline），页面按安全区留呼吸边距，窄屏自适应缩放。
/// 交互：可交互节点挂 mv-live（Hover Lift + 指针 + 键盘 Enter/Space 可达），
/// 非交互节点不再伪装可点（cursor 只给 mv-live）。
pub fn Project::export_html(
  self : Project,
  lang? : String = "zh",
) -> String {
  let sb = StringBuilder::new()
  // 节点 DOM id 唯一化：跨板重复的节点 id（duplicate_artboard）在后者加
  // __dupN 后缀——节点 g id 不做全局重命名，首个出现保持 #n_<id> 契约；
  // 每个板一张 raw→dom 映射，MV_ACT/状态/动效选择器统一走它。
  let dom_ids : Map[String, Map[String, String]] = Map::new()
  let seen_ids : Map[String, Bool] = Map::new()
  for ab_id in self.artboards.keys() {
    match self.artboards.get(ab_id) {
      None => ()
      Some(ab) => {
        let m : Map[String, String] = Map::new()
        for nid in ab.doc.nodes.keys() {
          let mut dom = nid
          let mut n = 1
          while seen_ids.contains(dom) {
            n = n + 1
            dom = nid + "__dup" + n.to_string()
          }
          seen_ids.set(dom, true)
          m.set(nid, dom)
        }
        dom_ids.set(ab_id, m)
      }
    }
  }
  // 主题令牌 → chrome 色板（单一来源：tokens，不再硬编码深底）
  let c_bg = self.tokens.resolve_color("background")
  let c_fg = self.tokens.resolve_color("text_primary")
  let c_surface = self.tokens.resolve_color("surface")
  let c_primary = self.tokens.resolve_color("primary")
  let c_on_primary = self.tokens.resolve_color("on_primary")
  let c_muted = self.tokens.resolve_color("text_secondary")
  let c_line = self.tokens.resolve_color("outline_variant")
  let scheme = if norm_is_hex6(c_bg) && norm_luminance(c_bg) < 0.18 {
    "dark"
  } else {
    "light"
  }
  sb.write_string(
    "<!DOCTYPE html>\n<html lang=\"" +
    sanitize_lang(lang) +
    "\">\n<head>\n<meta charset=\"UTF-8\">\n",
  )
  sb.write_string(
    "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1,viewport-fit=cover\">\n",
  )
  // color-scheme 随主题明暗：浏览器控件/滚动条与原型同调，不闪白/闪黑；
  // theme-color 让移动端浏览器地址栏与画布底同色（H5 沉浸感）
  sb.write_string("<meta name=\"color-scheme\" content=\"\{scheme}\">\n")
  sb.write_string("<meta name=\"theme-color\" content=\"\{c_bg}\">\n")
  sb.write_string("<title>MoonViz Prototype</title>\n")
  sb.write_string("<style>\n")
  // 动效令牌：时长刻度 + 引擎缓动曲线（animation.mbt 单一来源，不手写贝塞尔；
  // 项目令牌表可被 spec/主题/frontmatter 覆盖——导出面从 Project 取）
  sb.write_string("  \{self.motion_tokens_css()}\n")
  // 色彩令牌：主题 → CSS 变量（CSS 美感的单一事实源）
  sb.write_string(
    "  :root{--mv-bg:\{c_bg};--mv-fg:\{c_fg};--mv-surface:\{c_surface};--mv-primary:\{c_primary};--mv-on-primary:\{c_on_primary};--mv-muted:\{c_muted};--mv-line:\{c_line}}\n",
  )
  sb.write_string(
    "  body{margin:0;font-family:-apple-system,BlinkMacSystemFont,'SF Pro Text','HarmonyOS Sans SC','PingFang SC','Segoe UI','Noto Sans SC',Roboto,'Helvetica Neue',sans-serif;background:var(--mv-bg);color:var(--mv-fg);display:flex;flex-direction:column;align-items:center;min-height:100vh;box-sizing:border-box;padding:max(16px,env(safe-area-inset-top)) max(16px,env(safe-area-inset-right)) max(40px,env(safe-area-inset-bottom)) max(16px,env(safe-area-inset-left));-webkit-font-smoothing:antialiased;text-rendering:optimizeLegibility}\n",
  )
  // 吸顶 tab：Vibrancy 磨砂材质（半透明表面 + saturate/blur），胶囊分段
  sb.write_string(
    "  .tabs{position:sticky;top:max(8px,env(safe-area-inset-top));z-index:5;display:flex;gap:4px;padding:6px;margin:0 0 32px;flex-wrap:wrap;justify-content:center;border-radius:999px;background:color-mix(in srgb,var(--mv-surface) 72%,transparent);-webkit-backdrop-filter:saturate(180%) blur(20px);backdrop-filter:saturate(180%) blur(20px);box-shadow:0 0 0 .5px var(--mv-line),0 8px 24px rgba(0,0,0,.06)}\n",
  )
  sb.write_string(
    "  .tab{padding:7px 16px;border-radius:999px;cursor:pointer;background:transparent;color:var(--mv-muted);font-size:14px;font-weight:500;letter-spacing:-.01em;transition:background var(--mv-dur-fast) var(--mv-ease),color var(--mv-dur-fast) var(--mv-ease),border-color var(--mv-dur-fast) var(--mv-ease),box-shadow var(--mv-dur-fast) var(--mv-ease),transform var(--mv-dur-fast) var(--mv-spring)}\n",
  )
  sb.write_string(
    "  .tab:hover{transform:translateY(-1px);color:var(--mv-fg)}\n",
  )
  sb.write_string(
    "  .tab.active{background:var(--mv-primary);color:var(--mv-on-primary);box-shadow:0 2px 10px color-mix(in srgb,var(--mv-primary) 35%,transparent)}\n",
  )
  // 画板 = 设备感屏幕：大圆角 + hairline + 分层柔阴影（近/中/远三层，
  // HIG 的 elevation 不是一道硬阴影）；窄屏按 viewBox 等比缩放
  sb.write_string(
    "  .board{display:none;max-width:100%;border-radius:28px;overflow:hidden;background:var(--mv-surface);box-shadow:0 0 0 .5px var(--mv-line),0 1px 2px rgba(0,0,0,.04),0 12px 32px rgba(0,0,0,.08),0 32px 80px rgba(0,0,0,.08)}\n",
  )
  sb.write_string(
    "  .board>svg{display:block;max-width:100%;height:auto}\n",
  )
  // 画板转场：方向感知（navigate 前进 +1 / back 返回 -1 / tab 纯淡入 0），
  // fill 用 backwards——结束后把 transform 交还给按压反馈，不冻结交互。
  // 每类过渡一份 keyframes（名字由 Transition::name() 生成）；无边/无类
  // 走默认 push，mv-tr-none 显式禁用动画。
  sb.write_string(
    "  .board.active{display:block;animation:mv-board-push var(--mv-dur) var(--mv-out) backwards}\n",
  )
  sb.write_string(board_transition_css())
  // 入场阶梯：画板顶层节点依次浮现（步进与饱和上限都来自 animation.mbt 的
  // 动效令牌，导出层不写死毫秒；第 8 个起饱和，长列表后段不抢跑）。
  // svg 的唯一直接子 g 是根 wrapper（render_svg 只对 root 调一次 render_node，
  // 节点 g 全嵌其内）——选择器下钻一层 >g>g 对准顶层节点；wrapper 自带一个
  // 非 g 的背景 rect 占位，故按 nth-of-type 对 g 计数，不受普通子元素挤位
  sb.write_string(
    "  .board.active>svg>g>g{animation:mv-rise var(--mv-dur) var(--mv-out) backwards}\n",
  )
  sb.write_string(motion_stagger_css(".board.active>svg>g>g", indent="  "))
  sb.write_string(
    "  @keyframes mv-rise{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:none}}\n",
  )
  sb.write_string(
    "  .flow{padding:12px;font-size:12px;color:var(--mv-muted);text-align:center}\n" +
    // 按压反馈：spring 回弹 + fill-box 居中缩放（SVG 节点的触感来源）；
    // 状态多态的 fill 切换走引擎缓动——状态切换不再生硬跳变。
    // 指针只给可交互节点（mv-live，由交互绑定表在 JS 侧挂类）——非交互
    // 节点不伪装可点；Hover Lift（namethatui 词汇）只在真实悬停设备上生效，
    // 规则排在 :active 之前，按下时 scale 覆盖上浮
    "  g[id^=n_]{transform-box:fill-box;transform-origin:center;transition:transform var(--mv-dur-fast) var(--mv-spring),filter var(--mv-dur) var(--mv-out)}\n" +
    "  g.mv-live{cursor:pointer}\n" +
    "  @media (hover:hover){g.mv-live:hover{transform:translateY(-2px);filter:drop-shadow(0 6px 12px rgba(0,0,0,.10))}}\n" +
    // 按压反馈只给可交互节点；不再用 g.mv-live:focus{outline:none} 压掉
    // 全局 :focus-visible 焦点环（键盘可达性此前被这条覆盖）
    "  g.mv-live:active{transform:scale(.96)}\n" +
    "  g.mv-live:focus-visible{filter:drop-shadow(0 0 0 var(--mv-primary)) drop-shadow(0 0 3px var(--mv-primary))}\n" +
    "  g[id^=n_] rect,g[id^=n_] text{transition:fill var(--mv-dur) var(--mv-out)}\n" +
    // toast：HUD 反相胶囊（前景色作底 + 磨砂），明暗主题自动反相
    "  #mv-toast{position:fixed;left:50%;bottom:max(10%,env(safe-area-inset-bottom));transform:translateX(-50%) translateY(20px);background:color-mix(in srgb,var(--mv-fg) 88%,transparent);color:var(--mv-bg);-webkit-backdrop-filter:blur(12px);backdrop-filter:blur(12px);padding:10px 22px;border-radius:99px;font-size:14px;font-weight:500;opacity:0;transition:opacity var(--mv-dur) var(--mv-out),transform var(--mv-dur) var(--mv-spring);pointer-events:none;z-index:9}\n" +
    "  #mv-toast.show{opacity:1;transform:translateX(-50%) translateY(0)}\n" +
    // 无障碍：系统开启减弱动态效果时全部动效关闭（精致感不含强制动）
    "  @media (prefers-reduced-motion:reduce){*,*::before,*::after{animation:none!important;transition:none!important}}\n" +
    // 无障碍精致：键盘焦点可见（主题主色）
    "  :focus-visible{outline:2px solid var(--mv-primary);outline-offset:2px}\n" +
    // 入场淡入 + 状态切换 pop + 文字更新 tick（时长全部走动效令牌，导出层
    // 不再写死 .36s/.24s/.18s；reduced-motion 全覆盖）
    "  @keyframes mv-boot{from{opacity:0}to{opacity:1}}\n" +
    "  body{animation:mv-boot var(--mv-dur-slow) var(--mv-out) backwards}\n" +
    "  @keyframes mv-pop{0%{transform:scale(1)}45%{transform:scale(1.035)}100%{transform:scale(1)}}\n" +
    "  .mv-pop{animation:mv-pop var(--mv-dur) var(--mv-spring)}\n" +
    "  @keyframes mv-tick{from{opacity:.25;transform:translateY(3px)}to{opacity:1;transform:none}}\n" +
    "  .mv-tick{animation:mv-tick var(--mv-dur-tick) var(--mv-out)}\n",
  )
  // 节点级开场动效（NodeStyle.motion）：@keyframes 每预设一份（去重），
  // 节点规则按 #n_<id> 挂 var(--mv-dur)——节拍走令牌，声明面在 .mbt.md。
  let used_presets : Array[String] = []
  for ab_id in self.artboards.keys() {
    match self.artboards.get(ab_id) {
      None => ()
      Some(ab) =>
        for nid in ab.doc.nodes.keys() {
          match ab.doc.nodes.get(nid) {
            Some(n) =>
              if n.style.motion != "" {
                let mut seen = false
                for p in used_presets.iter() {
                  if p == n.style.motion {
                    seen = true
                  }
                }
                if !seen {
                  used_presets.push(n.style.motion)
                }
              }
            None => ()
          }
        }
    }
  }
  for preset in used_presets.iter() {
    sb.write_string(node_motion_keyframes_css(preset, indent="  "))
  }
  for ab_id in self.artboards.keys() {
    match self.artboards.get(ab_id) {
      None => ()
      Some(ab) =>
        for nid in ab.doc.nodes.keys() {
          match ab.doc.nodes.get(nid) {
            Some(n) =>
              if n.style.motion != "" {
                // DOM id 是 Agent 可控文本，选择器面过 CSS 标识符转义
                //（DOM id 原文由 render_svg 的 id 属性保持，两侧匹配）
                sb.write_string(
                  node_motion_rule_css(
                    css_ident_escape(dom_id_in(dom_ids.get(ab_id), nid)),
                    n.style.motion,
                    indent="  ",
                  ),
                )
              }
            None => ()
          }
        }
    }
  }
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
            // 状态变体选择器跟随节点 DOM id（重复板后缀）；dom 与状态名
            // 都过 CSS 标识符转义——类名字面（JS classList.add）保持原文，
            // 转义只在选择器面，两侧匹配
            let dom = match self.find_node_artboard(node_id) {
              Some(aid) => dom_id_in(dom_ids.get(aid), node_id)
              None => node_id
            }
            let sel =
              "g#n_" + css_ident_escape(dom) + ".st-" + css_ident_escape(state_name)
            sb.write_string("  \{sel} rect,\{sel} text{\{decl}}\n")
          }
        }
        None => ()
      }
    }
  }
  sb.write_string("</style>\n</head>\n<body>\n")
  // Tab 栏
  sb.write_string("<div class=\"tabs\" role=\"tablist\">\n")
  for id in self.artboards.keys() {
    match self.artboards.get(id) {
      Some(ab) => {
        // onclick 的 id 落在单引号 JS 字符串里，走 js_string_escape；
        // DOM id 属性与标签文本走 html_attr_escape/xml_escape——id/名称
        // 是 Agent 可控文本，裸插会让 <b> 变成真实元素并截断标签文本。
        // 浏览器把转义实体解析回原文后与 JS 侧的串一致，getElementById
        // ('tab-'+id) 两侧匹配。aria-selected 初始 false，show() 切换时
        // 同步（读屏器可感知选中板，WAI-ARIA tabs 模式）。
        let js_id = js_string_escape(id)
        let esc_id = html_attr_escape(id)
        sb.write_string(
          "  <div class=\"tab\" role=\"tab\" tabindex=\"0\" aria-selected=\"false\" aria-controls=\"board-\{esc_id}\" onclick=\"show('\{js_id}',true,0)\" onkeydown=\"if(event.key==='Enter'||event.key===' '){event.preventDefault();show('\{js_id}',true,0)}\" id=\"tab-\{esc_id}\">\{xml_escape(ab.name)}</div>\n",
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
        // 画布底 = background 令牌（tinted 画布），卡面 = surface 白卡浮起
        // ——iOS 分组语义/HarmonyOS 分层：canvas 永远比卡片低一档明度
        let svg = render_svg(
          ab.doc,
          surface=self.tokens.resolve_color("background"),
          frame=self.tokens.resolve_color("outline"),
          // 多板同页：filter id 按画板命名空间化，避免 e1/fx_ 重复串台
          filter_ns=id,
          // 重复板节点 id 加 __dupN 后缀，保证同页 DOM id 唯一
          node_ids=dom_ids.get(id),
        )
        sb.write_string(
          "<div class=\"board\" role=\"tabpanel\" id=\"board-\{html_attr_escape(id)}\" style=\"width:\{ab.width.to_int()}px\">\n",
        )
        sb.write_string(svg)
        sb.write_string("\n</div>\n")
      }
      None => ()
    }
  }
  // JS
  // toast = 状态播报区：role=status + aria-live=polite，读屏器可感知
  sb.write_string(
    "<div id=\"mv-toast\" role=\"status\" aria-live=\"polite\"></div>\n",
  )
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
    // ghost flow（目标画板不存在）不写进绑定表：show() 有存在性兜底，
    // 但过滤后 MV_ACT 不会给幽灵目标挂热区，也避免无效导航噪声
    if node != "" && self.artboards.contains(e.to) {
      // 第 5 位 = 该边的分板过渡（FlowEdge.transition；默认 push）
      let dmap = dom_ids.get(e.from)
      acts.push(
        "[\"" +
        js_string_escape(e.from) +
        "\",\"" +
        js_string_escape(dom_id_in(dmap, node)) +
        "\",\"navigate\",\"" +
        js_string_escape(e.to) +
        "\",\"" +
        js_string_escape(e.transition) +
        "\"]",
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
                        // 只为存在的目标挂 navigate（ghost 目标不写绑定）
                        if self.artboards.contains(t) {
                          acts.push(
                            "[\"\{js_string_escape(ab_id)}\",\"\{js_string_escape(dom_id_in(dom_ids.get(ab_id), nid))}\",\"navigate\",\"\{js_string_escape(t)}\",\"\"]",
                          )
                        }
                      Some(Back) =>
                        acts.push(
                          "[\"\{js_string_escape(ab_id)}\",\"\{js_string_escape(dom_id_in(dom_ids.get(ab_id), nid))}\",\"back\",\"\"]",
                        )
                      Some(ShowToast(msg)) =>
                        acts.push(
                          "[\"\{js_string_escape(ab_id)}\",\"\{js_string_escape(dom_id_in(dom_ids.get(ab_id), nid))}\",\"toast\",\"\{js_string_escape(msg)}\"]",
                        )
                      Some(HapticFeedback) =>
                        acts.push(
                          "[\"\{js_string_escape(ab_id)}\",\"\{js_string_escape(dom_id_in(dom_ids.get(ab_id), nid))}\",\"haptic\",\"\"]",
                        )
      Some(PlaySound(name)) =>
        acts.push(
          "[\"\{js_string_escape(ab_id)}\",\"\{js_string_escape(dom_id_in(dom_ids.get(ab_id), nid))}\",\"play_sound\",\"\{js_string_escape(name)}\"]",
        )
                      Some(SetState(id2, st)) =>
                        acts.push(
                          "[\"\{js_string_escape(ab_id)}\",\"\{js_string_escape(dom_id_in(dom_ids.get(ab_id), nid))}\",\"set_state\",\"\{js_string_escape(dom_id_in(dom_ids.get(ab_id), id2))}:\{js_string_escape(st)}\"]",
                        )
                      Some(ToggleState(id2, _)) =>
                        acts.push(
                          "[\"\{js_string_escape(ab_id)}\",\"\{js_string_escape(dom_id_in(dom_ids.get(ab_id), nid))}\",\"toggle_state\",\"\{js_string_escape(dom_id_in(dom_ids.get(ab_id), id2))}\"]",
                        )
                      Some(SetText(id2, txt)) =>
                        acts.push(
                          "[\"\{js_string_escape(ab_id)}\",\"\{js_string_escape(dom_id_in(dom_ids.get(ab_id), nid))}\",\"set_text\",\"\{js_string_escape(dom_id_in(dom_ids.get(ab_id), id2))}:\{js_string_escape(txt)}\"]",
                        )
                      Some(SubmitForm(ids)) => {
                        // 绑定表携带真实字段 id 列表（此前该动作在导出
                        // switch 落 `_ => ()` 被静默丢弃）
                        let fields = ids.join(",")
                        acts.push(
                          "[\"" +
                          js_string_escape(ab_id) +
                          "\",\"" +
                          js_string_escape(dom_id_in(dom_ids.get(ab_id), nid)) +
                          "\",\"submit_form\",\"" +
                          js_string_escape(fields) +
                          "\"]",
                        )
                      }
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
  // 内置返回兜底：back-like 节点且无 flow/marker 时绑定 back——runtime 的
  // tap 解析链有同一兜底，导出面此前缺这一支，返回按钮点了没反应。
  // 普通节点不误绑（只认 is_back_like_node）。
  for ab_id in self.artboards.keys() {
    match self.artboards.get(ab_id) {
      None => ()
      Some(ab) =>
        for nid in ab.doc.nodes.keys() {
          match ab.doc.nodes.get(nid) {
            Some(n) =>
              if !n.name.contains("⚡") &&
                !self.has_tap_flow(ab_id, nid) &&
                is_back_like_node(n) {
                acts.push(
                  "[\"" +
                  js_string_escape(ab_id) +
                  "\",\"" +
                  js_string_escape(dom_id_in(dom_ids.get(ab_id), nid)) +
                  "\",\"back\",\"\"]",
                )
              }
            None => ()
          }
        }
    }
  }
  // 状态名清单：toggle 恢复到第一个非 default 状态
  let state_defs : Array[String] = []
  for node_id in self.node_states.keys() {
    match self.node_states.get(node_id) {
      Some(def) => {
        // 状态名逐个过 js_string_escape（MV_STATES 内嵌 <script>，含
        // </script> 的合法状态名会提前闭合脚本、整页 JS 解析失败）；
        // 逗号不转义——JS 侧 split(',') 按逗号拆状态清单，语义不变
        let names : Array[String] = []
        for st in def.states.keys() {
          if st != "default" {
            names.push(js_string_escape(st))
          }
        }
        if names.length() > 0 {
          let joined = names.join(",")
          // 键用节点 DOM id（重复板后缀），与映射后的 toggle_state 参数一致
          let dom = match self.find_node_artboard(node_id) {
            Some(aid) => dom_id_in(dom_ids.get(aid), node_id)
            None => node_id
          }
          state_defs.push("\"\{js_string_escape(dom)}\":\"\{joined}\"")
        }
      }
      None => ()
    }
  }
  let states_js = state_defs.join(",")
  sb.write_string("const MV_STATES={\{states_js}};\n")
  // 无障碍标签表：交互节点挂 role=button 时补 aria-label（无文字节点
  // 由组件名兜底并去标记）；键与 MV_ACT 的 <画板>|<DOM id> 一致。
  let label_defs : Array[String] = []
  for ab_id in self.artboards.keys() {
    match self.artboards.get(ab_id) {
      None => ()
      Some(ab) =>
        for nid in ab.doc.nodes.keys() {
          match ab.doc.nodes.get(nid) {
            Some(n) => {
              let dom = dom_id_in(dom_ids.get(ab_id), nid)
              label_defs.push(
                "\"" +
                js_string_escape(ab_id + "|" + dom) +
                "\":\"" +
                js_string_escape(a11y_label(n)) +
                "\"",
              )
            }
            None => ()
          }
        }
    }
  }
  sb.write_string("const MV_LABELS={\{label_defs.join(",")}};\n")
  let acts_js = acts.join(",")
  sb.write_string("const MV_ACT=[\{acts_js}];\n")
  sb.write_string(
    // 减弱动态偏好同时约束 JS 侧滚动行为（CSS 只关动画/过渡）
    "const MV_STACK=[];const cur=()=>MV_STACK[MV_STACK.length-1];const RM=!!(window.matchMedia&&matchMedia('(prefers-reduced-motion: reduce)').matches);\n",
  )
  // CSS 选择器转义：画板/节点 id 是 Agent 可控文本（duplicate 的 new_name
  // 可含单引号），裸拼 '#board-'+id 会让 querySelector 抛 SyntaxError 并
  // 中断整页脚本——所有 querySelector 一律走 cssEsc（CSS.escape 优先）。
  sb.write_string(
    "const cssEsc=v=>(window.CSS&&CSS.escape)?CSS.escape(String(v)):String(v).replace(/[^a-zA-Z0-9_\\u00A0-\\uFFFF-]/g,c=>'\\\\'+c.codePointAt(0).toString(16)+' ');\n",
  )
  // show 先确认目标板存在再改导航栈/active：ghost 目标不回滚时会把
  // 当前板摘掉导致白屏（此前先 push、后查 b）。
  sb.write_string(
    "function show(id,push=true,dir=1,tr=''){const b=document.getElementById('board-'+id);if(!b){toast('页面不存在: '+id);return}if(push&&cur()!==id)MV_STACK.push(id);b.style.setProperty('--mv-dir',dir);['push','pop','modal_present','modal_dismiss','sheet_present','fade','none'].forEach(t=>b.classList.remove('mv-tr-'+t));if(tr)b.classList.add('mv-tr-'+tr);void b.offsetWidth;document.querySelectorAll('.tab').forEach(t=>{t.classList.remove('active');t.setAttribute('aria-selected','false')});document.querySelectorAll('.board').forEach(x=>x.classList.remove('active'));const tb=document.getElementById('tab-'+id);if(tb){tb.classList.add('active');tb.setAttribute('aria-selected','true')}b.classList.add('active');window.scrollTo({top:0,behavior:RM?'auto':'smooth'})}\n",
  )
  sb.write_string(
    "function back(){if(MV_STACK.length>1){MV_STACK.pop();show(MV_STACK[MV_STACK.length-1],false,-1)}}\n",
  )
  sb.write_string(
    "let mvTimer;function toast(m){const t=document.getElementById('mv-toast');t.textContent=m;t.classList.add('show');clearTimeout(mvTimer);mvTimer=setTimeout(()=>t.classList.remove('show'),1800)}\n",
  )
  sb.write_string(
    "function setState(b,n,st,on=true){const el=document.querySelector('#board-'+cssEsc(b)+' #n_'+cssEsc(n));if(!el)return;[...el.classList].filter(c=>c.startsWith('st-')).forEach(c=>el.classList.remove(c));if(on&&st)el.classList.add('st-'+st);el.classList.remove('mv-pop');void el.getBoundingClientRect();el.classList.add('mv-pop');el.addEventListener('animationend',()=>el.classList.remove('mv-pop'),{once:true})}\n",
  )
  sb.write_string(
    "MV_ACT.forEach(([b,n,k,v,tr])=>{const el=document.querySelector('#board-'+cssEsc(b)+' #n_'+cssEsc(n));if(!el)return;if(!el.classList.contains('mv-live')){el.classList.add('mv-live');el.setAttribute('tabindex','0');el.setAttribute('role','button');const lbl=MV_LABELS[b+'|'+n];if(lbl)el.setAttribute('aria-label',lbl);el.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();el.dispatchEvent(new MouseEvent('click',{bubbles:true}))}})}el.addEventListener('click',ev=>{ev.stopPropagation();if(k==='navigate')show(v,true,1,tr);else if(k==='back')back();else if(k==='toast')toast(v);else if(k==='haptic'){if(navigator.vibrate)navigator.vibrate(12);toast('📳 触觉反馈')}else if(k==='play_sound')toast('🔊 '+v);else if(k==='set_state'){const i=v.substring(0,v.indexOf(':')),s=v.substring(v.indexOf(':')+1);setState(b,i,s)}else if(k==='toggle_state'){const el2=document.querySelector('#board-'+cssEsc(b)+' #n_'+cssEsc(v));const on=el2&&[...el2.classList].some(c=>c.startsWith('st-'));setState(b,v,'',false);if(!on&&MV_STATES[v])setState(b,v,MV_STATES[v].split(',')[0])}else if(k==='set_text'){const i=v.substring(0,v.indexOf(':')),s=v.substring(v.indexOf(':')+1);const t=document.querySelector('#board-'+cssEsc(b)+' #n_'+cssEsc(i)+' text');if(t){t.textContent=s;t.classList.remove('mv-tick');void t.getBoundingClientRect();t.classList.add('mv-tick');t.addEventListener('animationend',()=>t.classList.remove('mv-tick'),{once:true})}}else if(k==='submit_form'){const ids=v?v.split(','):[];toast('📨 已提交 '+ids.length+' 项')}})});\n",
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
            "\{pad}<span style={{\{full_style}}}>\{jsx_text_escape(n.text)}</span>\n",
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
/// JSX 文本内容转义：& < > { } 按实体转义，防止文本字面量破坏标签/表达式结构
fn jsx_text_escape(s : String) -> String {
  let sb = StringBuilder::new()
  for c in s.iter() {
    match c {
      '&' => sb.write_string("&amp;")
      '<' => sb.write_string("&lt;")
      '>' => sb.write_string("&gt;")
      '{' => sb.write_string("&#123;")
      '}' => sb.write_string("&#125;")
      _ => sb.write_char(c)
    }
  }
  sb.to_string()
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
