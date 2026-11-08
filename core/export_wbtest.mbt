///|
/// 交互原型导出：flows(tap:node) 与 ⚡ 词汇表合并为节点级绑定表；
/// 组件状态导出为 CSS 变体；导航栈/toast/set_text 均为数据驱动。
test "export_html：节点级交互与状态变体导出" {
  let p = Project::new()
  let _ = p.create_artboard(name="home")
  let _ = p.create_artboard(name="detail")
  let _ = p.place_component(
    artboard="home",
    component_id="button",
    instance_id="card",
    x=10.0,
    y=10.0,
  )
  let _ = p.place_component(
    artboard="home",
    component_id="button",
    instance_id="btn",
    x=10.0,
    y=60.0,
  )
  p.add_flow(from="home", to="detail", trigger="tap:card")
  let _ = p.attach_interaction(
    artboard="home",
    node_id="btn",
    trigger="tap",
    action_spec="show_toast:\"已保存\"",
  )
  let _ = p.define_component_state(
    artboard="home",
    node_id="btn",
    state_name="pressed",
    patch={ ..NodePatch::empty(), fill: Some("#0F1114"), },
  )
  let html = p.export_html()
  // navigate 绑定第 5 位 = 分板过渡（默认 push）
  let nav = "[\"home\",\"card\",\"navigate\",\"detail\",\"push\"]"
  assert_true(html.contains(nav))
  assert_true(html.contains("\"toast\""))
  assert_true(html.contains("st-pressed"))
  assert_true(html.contains("MV_STACK"))
  assert_true(html.contains("#0F1114"))
}

///|
/// 动效系统：令牌单一来源（引擎曲线，不手写贝塞尔）+ 方向感知转场 +
/// 按压反馈 + 阶梯入场 + reduced-motion + ESC 返回——精致感导出面的硬门。
test "export_html：动效令牌与交互流畅性" {
  let p = Project::new()
  let _ = p.create_artboard(name="a")
  let _ = p.create_artboard(name="b")
  let html = p.export_html()
  // 动效令牌：时长刻度 + 引擎缓动曲线
  assert_true(html.contains("--mv-dur-fast:120ms"))
  assert_true(html.contains("--mv-dur:240ms"))
  assert_true(html.contains("--mv-dur-slow:360ms"))
  assert_true(html.contains("--mv-dur-tick:180ms"))
  assert_true(html.contains("--mv-stagger:24ms"))
  assert_true(html.contains("--mv-stagger-max:168ms"))
  assert_true(html.contains("--mv-spring:cubic-bezier(0.34, 1.56, 0.64, 1)"))
  // 方向感知转场：navigate 前进 / back 反向 / tab 纯淡入；backwards 不冻结交互
  assert_true(html.contains(
    "animation:mv-board-push var(--mv-dur) var(--mv-out) backwards",
  ))
  assert_true(html.contains("--mv-dir"))
  assert_true(html.contains("show(MV_STACK[MV_STACK.length-1],false,-1)"))
  assert_true(html.contains("if(k==='navigate')show(v,true,1,tr)"))
  assert_true(html.contains("onclick=\"show('a',true,0)\""))
  // 按压反馈（spring 触感）+ 状态 fill 平滑切换
  assert_true(html.contains("g[id^=n_]:active{transform:scale(.96)}"))
  assert_true(html.contains("transition:fill var(--mv-dur) var(--mv-out)"))
  // 入场阶梯：选择器下钻到根 wrapper 内的顶层节点 g——svg 的唯一直接子 g
  // 是根 wrapper（render_svg 只对 root 调一次 render_node），旧选择器
  // >svg>g 只命中 wrapper 一层，逐节点阶梯从未生效；wrapper 自带非 g 的
  // 背景 rect 占位，按 nth-of-type 对 g 计数，不受普通子元素挤位。
  // 节拍走令牌（calc(var(--mv-stagger) × k)），第 8 个起饱和——第 9+ 个
  // 不再把 delay 复位 0（此前级联只写到 nth-of-type(8)，长列表后段抢跑）
  assert_true(html.contains(".board.active>svg>g>g{animation:mv-rise"))
  assert_true(html.contains(
    ".board.active>svg>g>g:nth-of-type(2){animation-delay:calc(var(--mv-stagger) * 1)}",
  ))
  assert_true(html.contains(
    ".board.active>svg>g>g:nth-of-type(7){animation-delay:calc(var(--mv-stagger) * 6)}",
  ))
  assert_true(html.contains(
    ".board.active>svg>g>g:nth-of-type(n+8){animation-delay:var(--mv-stagger-max)}",
  ))
  // 裸毫秒不再出现在级联里（节拍只有一个来源）
  assert_false(html.contains("animation-delay:24ms"))
  assert_false(html.contains("animation-delay:168ms"))
  assert_false(html.contains(".board.active>svg>g{animation"))
  // 阶梯 keyframes / reduced-motion / ESC 返回
  assert_true(html.contains("@keyframes mv-rise"))
  assert_true(html.contains("prefers-reduced-motion"))
  assert_true(html.contains("if(e.key==='Escape')back()"))
}

///|
/// 动效单一来源：boot/pop/tick 三处微动效全部引用 motion_tokens_css 的
/// 时长变量，导出层不再写死秒数（此前 .36s/.24s/.18s 三处裸时长，
/// 调刻度要回来同步三遍）。tick 与阶梯步进/饱和上限也只在令牌里定义一次。
test "export_html：微动效时长全部引用令牌" {
  let tokens = motion_tokens_css()
  assert_true(tokens.contains("--mv-dur-tick:180ms"))
  assert_true(tokens.contains("--mv-stagger:24ms"))
  assert_true(tokens.contains("--mv-stagger-max:168ms"))
  let p = Project::new()
  let _ = p.create_artboard(name="a")
  let html = p.export_html()
  assert_true(html.contains("body{animation:mv-boot var(--mv-dur-slow)"))
  assert_true(html.contains(".mv-pop{animation:mv-pop var(--mv-dur)"))
  assert_true(html.contains(".mv-tick{animation:mv-tick var(--mv-dur-tick)"))
  // 旧的裸秒数彻底消失（时长只有一个来源）
  assert_false(html.contains(".36s"))
  assert_false(html.contains(".24s"))
  assert_false(html.contains(".18s"))
}

///|
/// 开屏页 = 导航流天然起点：未被任何 flow 指向的画板（login→home 型原型
/// 开在登录页），不随 Map 遍历序漂移。
test "export_html：入场画板推断" {
  let p = Project::new()
  let _ = p.create_artboard(name="z_login")
  let _ = p.create_artboard(name="a_home")
  let _ = p.create_artboard(name="m_prof")
  p.add_flow(from="z_login", to="a_home", trigger="tap:btn")
  p.add_flow(from="a_home", to="m_prof", trigger="tap:card")
  let html = p.export_html()
  // a_home/m_prof 都被指向；唯一天然起点是 z_login（字典序并非最小，
  // 证明这是流推断而非排序巧合）。断言锚在自成一行的 boot 调用上——
  // tab 的 onclick 会为每个画板都产出同形字符串。
  assert_true(html.contains("\nshow('z_login',true,0)\n"))
  assert_false(html.contains("\nshow('a_home',true,0)\n"))
}

///|
/// 注入封堵：duplicate 的 new_name 原样成为画板 id，可含单引号/尖括号——
/// boot 与 tab onclick 都落在单引号 JS 字符串，须转义后注出，否则整个
/// <script> 解析失败、原型交互全哑。
test "export_html：单引号/尖括号画板 id 的脚本注入封堵" {
  let p = Project::new()
  let _ = p.create_artboard(name="login")
  let _ = p.duplicate_artboard(src="login", new_name="ab'cd")
  let html = p.export_html()
  // 单引号转义为 \'；boot 调用锚在自成一行的形态上（tab onclick 不换行）
  assert_true(html.contains("\nshow('ab\\'cd',true,0)\n"))
  assert_false(html.contains("show('ab'cd"))
  assert_true(html.contains("onclick=\"show('ab\\'cd',true,0)\""))
  // 尖括号一律 \x3c，</script> 无法再从字符串内提前闭合脚本
  let _ = p.duplicate_artboard(src="login", new_name="x</script>y")
  let html2 = p.export_html()
  assert_true(html2.contains("show('x\\x3c/script>y',true,0)"))
  assert_false(html2.contains("show('x</script>y'"))
  // 脚本尾部完好：boot 行（并列候选的 shortlex 最小是 ab'cd）后紧跟闭合标签
  assert_true(html2.contains("\nshow('ab\\'cd',true,0)\n</script>"))
}

///|
/// 并列 tie-break：无 flow 可达时全部画板皆为候选，取确定性最小 id。
/// String < 是长度优先的 shortlex——zz 短于 aaa，boot 因此开在 zz 而非 aaa。
test "export_html：并列候选 shortlex tie-break" {
  let p = Project::new()
  let _ = p.create_artboard(name="zz")
  let _ = p.create_artboard(name="aaa")
  let html = p.export_html()
  assert_true(html.contains("\nshow('zz',true,0)\n"))
  assert_false(html.contains("\nshow('aaa',true,0)\n"))
}

///|
/// 交互动画与精致化：haptic/play_sound 动作进绑定表（此前导出面静默
/// 丢弃）、set_text tick / setState pop / boot 淡入、字体栈、color-scheme、
/// focus-visible 无障碍。
test "export_html：交互动画与精致化断言" {
  let p = Project::new()
  let _ = p.create_artboard(name="home")
  let _ = p.place_component(
    artboard="home",
    component_id="button",
    instance_id="btn",
    x=10.0,
    y=10.0,
  )
  let _ = p.attach_interaction(
    artboard="home",
    node_id="btn",
    trigger="tap",
    action_spec="haptic",
  )
  let html = p.export_html()
  // haptic 动作进绑定表并在运行时反馈：支持振动的设备真振（navigator.vibrate，
  // 安卓生效 / iOS 静默忽略），再给可见 toast 兜底
  assert_true(html.contains("\"haptic\""))
  assert_true(
    html.contains(
      "else if(k==='haptic'){if(navigator.vibrate)navigator.vibrate(12);toast('📳 触觉反馈')}",
    ),
  )
  // 微动效三件套
  assert_true(html.contains("@keyframes mv-pop"))
  assert_true(html.contains("@keyframes mv-tick"))
  assert_true(html.contains("@keyframes mv-boot"))
  assert_true(html.contains("el.classList.add('mv-pop')"))
  assert_true(html.contains("t.classList.add('mv-tick')"))
  // UI 精致化：字体栈 / color-scheme / focus-visible
  assert_true(html.contains("PingFang SC"))
  assert_true(html.contains("color-scheme"))
  assert_true(html.contains(":focus-visible{outline:2px solid"))
}

///|
/// SetText 绑定的画板字段回归锚：第一个字段必须是 ab_id（画板），
/// 不是 id2（目标节点）——此前错用 id2 使 set_text 绑定指向
/// #board-<目标节点>，导出原型的 set_text 交互从未生效过。
test "export_html：set_text 绑定的画板字段回归锚" {
  let p = Project::new()
  let _ = p.create_artboard(name="home")
  let _ = p.place_component(
    artboard="home",
    component_id="button",
    instance_id="btn_set",
    x=10.0,
    y=10.0,
  )
  let _ = p.attach_interaction(
    artboard="home",
    node_id="btn_set",
    trigger="tap",
    action_spec="set_text:welcome:已更新",
  )
  let html = p.export_html()
  assert_true(html.contains("[\"home\",\"btn_set\",\"set_text\""))
  assert_false(html.contains("[\"welcome\",\"btn_set\""))
}

///|
/// spec.motion → 动效令牌：apply_design_spec 落值后，令牌入口与导出 HTML
/// 同时生效（spec 是节拍的第一权威，导出层不写死毫秒）。
test "export_html：spec.motion 覆盖动效刻度" {
  let p = Project::new()
  let ab = p.create_artboard(name="home")
  match
    p.apply_design_spec(
      artboard=ab,
      spec="{\"v\":1,\"motion\":{\"base\":320,\"tick\":200}}",
    ) {
    Ok(_) => ()
    Err(e) => fail("spec 应用失败：\{e}")
  }
  assert_true(p.motion_tokens_css().contains("--mv-dur:320ms"))
  assert_true(p.motion_tokens_css().contains("--mv-dur-tick:200ms"))
  let html = p.export_html()
  assert_true(html.contains("--mv-dur:320ms"))
  assert_true(html.contains("--mv-dur-tick:200ms"))
}

///|
/// 节点级 motion 导出：#n_<id> 规则 + mv-p-<preset> keyframes；节拍在规则里
/// 走 var(--mv-dur)，未设置 motion 的节点不产出任何动画规则。
test "export_html：节点 motion 导出规则与 keyframes" {
  let p = Project::new()
  let _ = p.create_artboard(name="home")
  let _ = p.place_component(
    artboard="home",
    component_id="button",
    instance_id="hero",
    x=10.0,
    y=10.0,
  )
  match p.artboards.get("home") {
    Some(ab) => {
      let _ = ab.doc.update_node("hero", fn(n) {
        { ..n, style: { ..n.style, motion: "fade_in", }, }
      })
    }
    None => assert_true(false)
  }
  let html = p.export_html()
  assert_true(html.contains("@keyframes mv-p-fade_in"))
  assert_true(html.contains(
    "#n_hero{animation:mv-p-fade_in var(--mv-dur) var(--mv-out) backwards}",
  ))
  assert_false(html.contains("#n_other{animation:mv-p-"))
}

///|
/// submit_form 导出绑定：绑定表携带真实字段 id 列表（此前导出 switch 的
/// `_ => ()` 把该动作静默丢弃），JS 侧有 submit_form 处理器。
test "export_html：submit_form 绑定携带字段 id 列表" {
  let p = Project::new()
  let ab = p.create_artboard(name="home")
  let _ = p.place_component(
    artboard="home",
    component_id="text_input",
    instance_id="email",
    x=20.0,
    y=80.0,
  )
  let _ = p.place_component(
    artboard="home",
    component_id="text_input",
    instance_id="pwd",
    x=20.0,
    y=140.0,
  )
  let _ = p.place_component(
    artboard="home",
    component_id="button",
    instance_id="submit",
    x=20.0,
    y=220.0,
  )
  match
    p.attach_interaction(
      artboard=ab,
      node_id="submit",
      trigger="tap",
      action_spec="submit_form:email,pwd",
    ) {
    Ok(_) => ()
    Err(e) => fail("submit_form 注册失败：\{e}")
  }
  let html = p.export_html()
  assert_true(html.contains("[\"home\",\"submit\",\"submit_form\",\"email,pwd\"]"))
  // 不再出现 describe 的字段数占位
  assert_false(html.contains("fields]"))
  assert_true(html.contains("k==='submit_form'"))
}

///|
/// 分板过渡单一来源：FlowEdge.transition 决定导出关键帧与 navigate 绑定；
/// 默认 push 不写 frontmatter 但仍走 mv-board-push；none 显式禁用动画。
test "export_html：分板过渡按 FlowEdge.transition 出关键帧与绑定" {
  let p = Project::new()
  let _ = p.create_artboard(name="a")
  let _ = p.create_artboard(name="b")
  let _ = p.create_artboard(name="c")
  let _ = p.place_component(
    artboard="a",
    component_id="button",
    instance_id="go",
  )
  let _ = p.place_component(
    artboard="a",
    component_id="button",
    instance_id="plain",
  )
  let _ = p.place_component(
    artboard="a",
    component_id="button",
    instance_id="skip",
  )
  p.add_flow(from="a", to="b", trigger="tap:go", transition="modal_present")
  p.add_flow(from="a", to="c", trigger="tap:plain")
  p.add_flow(from="a", to="c", trigger="tap:skip", transition="none")
  let html = p.export_html()
  // 每个 Transition::name() 一份关键帧 + 类覆盖；none 只出禁用规则
  assert_true(html.contains("@keyframes mv-board-modal_present"))
  assert_true(html.contains("@keyframes mv-board-push"))
  assert_true(html.contains("@keyframes mv-board-fade"))
  assert_true(html.contains(
    ".board.active.mv-tr-modal_present{animation:mv-board-modal_present",
  ))
  assert_true(html.contains(".board.active.mv-tr-none{animation:none}"))
  // show 四参 + 绑定表第 5 位携带该边过渡
  assert_true(html.contains("show(id,push=true,dir=1,tr='')"))
  assert_true(html.contains("[\"a\",\"go\",\"navigate\",\"b\",\"modal_present\"]"))
  assert_true(html.contains("[\"a\",\"plain\",\"navigate\",\"c\",\"push\"]"))
  assert_true(html.contains("[\"a\",\"skip\",\"navigate\",\"c\",\"none\"]"))
}

// ---------------------------------------------------------------------------
// 导出正确性（P6）：选择器转义 / ghost 导航 / 返回兜底 / filter 命名空间
// ---------------------------------------------------------------------------

///|
fn find_from(s : String, needle : String, from : Int) -> Int? {
  let n = needle.length()
  let mut i = from
  while i + n <= s.length() {
    if s.substring(start=i, end=i + n) == needle {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
/// 子串出现次数（boot show 行 / transition 行等断言用）。
fn count_needle(s : String, needle : String) -> Int {
  let mut count = 0
  let mut idx = 0
  while true {
    match find_from(s, needle, idx) {
      None => break
      Some(pos) => {
        count = count + 1
        idx = pos + needle.length()
      }
    }
  }
  count
}

///|
/// 收集 `marker` 之后到下一个双引号的属性值（filter id / board id 等）。
fn collect_attr_values(s : String, marker : String) -> Array[String] {
  let out : Array[String] = []
  let mut idx = 0
  while true {
    match find_from(s, marker, idx) {
      None => break
      Some(pos) => {
        let start = pos + marker.length()
        let rest = s.substring(start=start)
        match rest.find("\"") {
          None => break
          Some(e) => {
            out.push(rest.substring(start=0, end=e))
            idx = start + e + 1
          }
        }
      }
    }
  }
  out
}

///|
/// ① 选择器转义：ab'cd 这类 Agent 可控画板 id 不得裸拼进 querySelector；
/// 所有 MV_ACT/setState 选择器走 cssEsc（CSS.escape 优先）。
test "export_html：CSS.escape 防 id 注入（ab'cd 画板）" {
  let p = Project::new()
  let _ = p.create_artboard(name="login")
  let _ = p.place_component(
    artboard="login",
    component_id="button",
    instance_id="cta",
  )
  let _ = p.duplicate_artboard(src="login", new_name="ab'cd")
  match
    p.attach_interaction(
      artboard="ab'cd",
      node_id="cta",
      trigger="tap",
      action_spec="show_toast:\"hi\"",
    ) {
    Ok(_) => ()
    Err(e) => fail("引号画板交互注册失败：\{e}")
  }
  let html = p.export_html()
  assert_true(html.contains("cssEsc"))
  assert_true(html.contains("CSS.escape"))
  assert_true(html.contains("'#board-'+cssEsc(b)+' #n_'+cssEsc(n)"))
  assert_true(html.contains("'#board-'+cssEsc(b)+' #n_'+cssEsc(i)+' text'"))
  // 选择器路径不再出现裸拼的 #board-ab'cd 字面量
  assert_false(html.contains("#board-ab'cd"))
  // DOM id 仍按原名存在（id 属性不需要 CSS 转义）
  assert_true(html.contains("id=\"board-ab'cd\""))
}

///|
/// ② ghost flow：目标板不存在时不写 navigate 绑定；show() 先查板再改栈，
/// 目标不存在保留当前板并 toast。
test "export_html：ghost flow 过滤与 show 存在性兜底" {
  let p = Project::new()
  let _ = p.create_artboard(name="a")
  let _ = p.create_artboard(name="b")
  let _ = p.place_component(
    artboard="a",
    component_id="button",
    instance_id="go",
  )
  let _ = p.place_component(
    artboard="a",
    component_id="button",
    instance_id="ok",
  )
  p.add_flow(from="a", to="ghost", trigger="tap:go")
  p.add_flow(from="a", to="b", trigger="tap:ok")
  let html = p.export_html()
  assert_false(html.contains("\"navigate\",\"ghost\""))
  assert_true(html.contains("\"navigate\",\"b\""))
  // show 先取板再改栈：不存在直接 toast 返回
  assert_true(html.contains("if(!b){toast('页面不存在: '+id);return}"))
  assert_true(html.contains("const b=document.getElementById('board-'+id);if(!b)"))
  // boot 只对一个板 show；ghost 不在 boot/绑定里
  assert_true(html.contains("\nshow('a',true,0)\n"))
  assert_false(html.contains("\nshow('ghost'"))
  // .board.active 计数：boot show 行恰好 1 条（ghost 不会被激活）
  assert_eq(count_needle(html, "\nshow("), 1)
}

///|
/// ③ 内置返回绑定：back-like 节点无 flow/marker 时写 back；普通节点、
/// 已有 marker 或显式 flow 的节点都不重复绑定。
test "export_html：返回类节点内置 back 绑定" {
  let p = Project::new()
  let home = p.create_artboard(name="home")
  let _ = p.create_artboard(name="home2")
  let _ = p.place_component(
    artboard=home,
    component_id="button",
    instance_id="back_btn",
  )
  let _ = p.place_component(
    artboard=home,
    component_id="button",
    instance_id="cta",
  )
  let _ = p.place_component(
    artboard=home,
    component_id="button",
    instance_id="back_marked",
  )
  let _ = p.place_component(
    artboard=home,
    component_id="button",
    instance_id="back_flow",
  )
  let _ = p.attach_interaction(
    artboard=home,
    node_id="back_marked",
    trigger="tap",
    action_spec="show_toast:\"x\"",
  )
  p.add_flow(from=home, to="home2", trigger="tap:back_flow")
  let html = p.export_html()
  assert_true(html.contains("[\"home\",\"back_btn\",\"back\",\"\"]"))
  assert_false(html.contains("[\"home\",\"cta\",\"back\""))
  assert_false(html.contains("[\"home\",\"back_marked\",\"back\""))
  assert_false(html.contains("[\"home\",\"back_flow\",\"back\""))
}

///|
/// ④ filter id 按画板命名空间化：duplicate 后 e1/fx_/blur_ 不再全局重复；
/// 节点 g id 不做全局重命名（保持 #n_ 契约）。
test "export_html：filter id 按画板命名空间唯一" {
  let p = Project::new()
  let _ = p.create_artboard(name="login")
  let _ = p.place_component(
    artboard="login",
    component_id="card",
    instance_id="card",
  )
  match p.artboards.get("login") {
    Some(ab) => {
      let _ = ab.doc.update_node("card", fn(n) {
        { ..n, style: { ..n.style, shadow: "e2", }, }
      })
    }
    None => assert_true(false)
  }
  let _ = p.duplicate_artboard(src="login", new_name="login2")
  let html = p.export_html()
  let filter_ids = collect_attr_values(html, "filter id=\"")
  assert_true(filter_ids.length() >= 6, msg="两板各 3 个 elevation filter")
  let seen : Map[String, Bool] = Map::new()
  let mut dup = 0
  for fid in filter_ids.iter() {
    if seen.contains(fid) {
      dup = dup + 1
    } else {
      seen.set(fid, true)
    }
  }
  assert_eq(dup, 0, msg="filter id 必须全局唯一")
  assert_true(seen.contains("e1_login"))
  assert_true(seen.contains("e1_login2"))
  assert_false(seen.contains("e1"))
  assert_true(html.contains("filter=\"url(#e2_login)\""))
  assert_true(html.contains("filter=\"url(#e2_login2)\""))
  // 节点 g id 保持 #n_<id>（不随画板改名）
  assert_true(html.contains("id=\"n_card\""))
  assert_false(html.contains("id=\"n_card_login\""))
}

///|
/// ⑤ 对抗性画板 id：a-b 与 a_b 经可逆 svg_ns_tag 编码后命名空间不同，
/// 同页 filter id 不再碰撞（此前的有损清洗会把两者都映射成 a_b）。
test "export_html：对抗性画板 id 的 filter 命名空间不碰撞" {
  let p = Project::new()
  let _ = p.create_artboard(name="t")
  let _ = p.duplicate_artboard(src="t", new_name="a-b")
  let _ = p.duplicate_artboard(src="t", new_name="a_b")
  let html = p.export_html()
  let filter_ids = collect_attr_values(html, "filter id=\"")
  assert_true(filter_ids.length() >= 9, msg="三块板各有 e1/e2/e3")
  let seen : Map[String, Bool] = Map::new()
  let mut dup = 0
  for fid in filter_ids.iter() {
    if seen.contains(fid) {
      dup = dup + 1
    } else {
      seen.set(fid, true)
    }
  }
  assert_eq(dup, 0, msg="a-b 与 a_b 必须映射到不同命名空间")
  assert_true(seen.contains("e1_a_2d_b"), msg="'-' 编码为 _2d_")
  assert_true(seen.contains("e1_a__b"), msg="'_' 编码为 __（不是 _5f_）")
}

///|
/// ⑥ 节点 g id 唯一化：duplicate 板的重复节点 id 加 __dupN 后缀，且
/// MV_ACT 绑定必须引用实际存在的 DOM id（不能 raw/suffixed 错配）。
test "export_html：重复画板节点 g id 加 __dupN 且绑定一致" {
  let p = Project::new()
  let _ = p.create_artboard(name="login")
  let _ = p.place_component(
    artboard="login",
    component_id="button",
    instance_id="card",
  )
  let _ = p.duplicate_artboard(src="login", new_name="login2")
  let _ = p.attach_interaction(
    artboard="login2",
    node_id="card",
    trigger="tap",
    action_spec="show_toast:\"hi\"",
  )
  let html = p.export_html()
  let node_ids = collect_attr_values(html, "id=\"n_")
  assert_true(node_ids.length() >= 4, msg="两板各 root+card")
  let seen : Map[String, Bool] = Map::new()
  let mut dup = 0
  for nid in node_ids.iter() {
    if seen.contains(nid) {
      dup = dup + 1
    } else {
      seen.set(nid, true)
    }
  }
  assert_eq(dup, 0, msg="节点 g id 必须全局唯一")
  assert_eq(count_needle(html, "id=\"n_card\""), 1)
  assert_eq(count_needle(html, "id=\"n_card__dup2\""), 1)
  // 绑定只引用实际存在的 DOM id：raw 或 __dup2 恰好一种
  let has_raw = html.contains("[\"login2\",\"card\",\"toast\"")
  let has_dup = html.contains("[\"login2\",\"card__dup2\",\"toast\"")
  assert_true(has_raw != has_dup, msg="MV_ACT 绑定必须与 DOM id 同形")
}
