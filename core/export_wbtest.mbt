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
  // 背景 rect 占位，按 nth-of-type 对 g 计数，不受普通子元素挤位
  assert_true(html.contains(".board.active>svg>g>g{animation:mv-rise"))
  assert_true(html.contains(
    ".board.active>svg>g>g:nth-of-type(2){animation-delay:24ms}",
  ))
  assert_true(html.contains(
    ".board.active>svg>g>g:nth-of-type(8){animation-delay:168ms}",
  ))
  assert_false(html.contains(".board.active>svg>g{animation"))
  // 阶梯 keyframes / reduced-motion / ESC 返回
  assert_true(html.contains("@keyframes mv-rise"))
  assert_true(html.contains("prefers-reduced-motion"))
  assert_true(html.contains("if(e.key==='Escape')back()"))
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
