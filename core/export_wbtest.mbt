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
  let nav = "[\"home\",\"card\",\"navigate\",\"detail\"]"
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
    "animation:mv-board-in var(--mv-dur) var(--mv-out) backwards",
  ))
  assert_true(html.contains("--mv-dir"))
  assert_true(html.contains("show(MV_STACK[MV_STACK.length-1],false,-1)"))
  assert_true(html.contains("if(k==='navigate')show(v,true,1)"))
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
