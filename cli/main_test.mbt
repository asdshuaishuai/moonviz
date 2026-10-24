/// MBT CLI 协议：完整源码是唯一输入，所有提交都返回 canonical MBT。

///|
fn cli_b64(text : String) -> String {
  @base64.encode(@utf8.encode(text))
}

///|
let cli_sample_mbt = "---\nmoonviz:\n  revision: 1\n  entry: login\n---\n\n<!-- moonviz:artboard login -->\n```mbt\nfn visual_login() -> @decl.Prototype {\n  let page = @decl.prototype(name=\"login\", width=390.0, height=844.0)\n  page.add(@decl.text(id=\"title\", content=\"Hello\", size=24.0))\n  page\n}\n```\n"

///|
test "render-mbt-b64 rebuilds the canvas from one MBT source" {
  let project = @core.Project::new()
  let result = cli_exec(project, "render-mbt-b64 " + cli_b64(cli_sample_mbt))
  assert_true(result.contains("\"ok\":true"))
  assert_true(result.contains("\"mbt\":"))
  assert_true(result.contains("\"id\":\"login\""))
  assert_true(result.contains("Hello"))
}

///|
test "human MBT operation writes canonical source before returning SVG" {
  let project = @core.Project::new()
  let result = cli_exec(
    project,
    "apply-human-mbt-op-b64 " +
    cli_b64(cli_sample_mbt) +
    " " +
    cli_b64("move login title 20 30"),
  )
  assert_true(result.contains("\"ok\":true"))
  assert_true(result.contains("x=20"))
  assert_true(result.contains("y=30"))
  assert_true(result.contains("\"mbt\":"))
}

///|
test "agent MBT operation rejects a visual violation without source result" {
  let project = @core.Project::new()
  let result = cli_exec(
    project,
    "apply-agent-mbt-op-b64 " +
    cli_b64(cli_sample_mbt) +
    " " +
    cli_b64("move login title 999 0"),
  )
  assert_true(result.contains("mbt_gate_block:login:contained_in_parent:title"))
  assert_true(!result.contains("\"mbt\":"))
}

///|
test "MBT transport rejects malformed Base64 before parsing source" {
  let project = @core.Project::new()
  let result = cli_exec(project, "render-mbt-b64 %%not-base64%%")
  assert_true(result.contains("mbt_transport_invalid_base64"))
}

///|
test "generate: one-sentence intent produces a full artboard plus report" {
  let project = @core.Project::new()
  let result = cli_exec(project, "generate 登录页")
  assert_true(result.contains("\"ok\":true"))
  assert_true(result.contains("\"template\":\"login\""))
  assert_true(result.contains("\"autofix\""))
  assert_true(result.contains("\"score\""))
  // 自定义画板名（as 尾缀）
  let named = cli_exec(project, "generate 设置页 as my_settings")
  assert_true(named.contains("\"artboard\":\"my_settings\""))
}

///|
/// generate 的 "as" 分隔符是真尾部语义：仅 "as <name>" 恰好占满行尾
/// 两个 token 时才消费。居中的 as 是意图内容，按普通词并入——此前
/// 任意位置裸 " as " 都劫持为分隔符，意图被截断且 "as" 后的 token
/// 整体丢失（"generate login as hero page" 产出画板 hero、"page" 丢失）。
test "generate: mid-intent as stays in the intent, trailing as names the artboard" {
  let project = @core.Project::new()
  // as 居中（其后还有 token）：不劫持——意图完整，画板名回落 template_id
  let mid = cli_exec(project, "generate login as hero page")
  assert_true(mid.contains("\"ok\":true"))
  assert_true(mid.contains("\"template\":\"login\""))
  assert_true(mid.contains("\"artboard\":\"login\""))
  // as 尾部：仍按声明生效
  let tail = cli_exec(project, "generate login page as hero")
  assert_true(tail.contains("\"template\":\"login\""))
  assert_true(tail.contains("\"artboard\":\"hero\""))
  // 引号意图含 as：split_cmd 还原为单 token，as 永不劫持（与 wasm 臂同构）
  let quoted = cli_exec(project, "generate \"登录页 with as badge 中间词\"")
  assert_true(quoted.contains("\"template\":\"login\""))
  assert_true(quoted.contains("\"artboard\":\"login\""))
  assert_true(!quoted.contains("\"artboard\":\"badge"))
}

///|
/// cli_err 统一 JSON 转义：错误串携带原始用户 token，含反斜杠/引号时
/// 输出必须仍是合法 JSON（此前裸插值产出非法 JSON——python json.loads
/// 与 jq 双判非法，而同输入走 MCP 臂是合法转义输出）。精确匹配同时
/// 排除双重转义。
test "cli_err escapes backslash and quote so error output stays valid JSON" {
  let project = @core.Project::new()
  // 裸反斜杠 token（split_cmd 引号外原样保留）
  let bs = cli_exec(project, "template back\\slash my_login")
  assert_eq(bs, "{\"error\":\"unknown_template: back\\\\slash\"}")
  // 引号包裹内 \" 保留原文（反斜杠+引号双字符进入错误串）
  let q = cli_exec(project, "template \"my\\\"tab\" my_login")
  assert_eq(q, "{\"error\":\"unknown_template: my\\\\\\\"tab\"}")
}

///|
test "ops-batch: one-shot submission with breakpoint index on failure" {
  let project = @core.Project::new()
  let ok = cli_b64("create home 390 844\ncreate detail 390 844")
  let result = cli_exec(project, "ops-batch-b64 " + ok)
  assert_true(result.contains("\"ok\":true"))
  // op 用工具字典规范名 batch_apply（与 MCP 臂/list_tools 同名）
  assert_true(result.contains("\"op\":\"batch_apply\""))
  assert_true(result.contains("\"applied\":2"))
  let bad = cli_b64("create home2 390 844\nupdate home2 ghost text=x")
  let result2 = cli_exec(project, "ops-batch-b64 " + bad)
  assert_true(result2.contains("\"ok\":false"))
  assert_true(result2.contains("\"applied\":1"))
  assert_true(result2.contains("\"index\":1"))
}

///|
/// 超限拒绝：index=-1 是哨兵，不得泄进 applied（applied 语义是已应用
/// 条数，-1 是不可能值）
test "ops-batch: over-limit rejection reports applied:0 with sentinel index" {
  let project = @core.Project::new()
  let many : Array[String] = []
  let mut i = 0
  while i <= @core.OPS_BATCH_LIMIT {
    many.push("create x\{i} 100 100")
    i = i + 1
  }
  let sb = StringBuilder::new()
  let mut first = true
  for op in many.iter() {
    if first == false {
      sb.write_string("\n")
    }
    first = false
    sb.write_string(op)
  }
  let result = cli_exec(project, "ops-batch-b64 " + cli_b64(sb.to_string()))
  assert_true(result.contains("\"ok\":false"))
  assert_true(result.contains("\"applied\":0"))
  assert_true(result.contains("\"index\":-1"))
}

///|
/// help 是会话内 Agent 的发现面：SKILL.md 执行阶梯的首选入口必须在列
test "help surfaces the generative commands" {
  let help = cli_exec(@core.Project::new(), "help")
  assert_true(help.contains("generate <意图一句话> [as <name>]"))
  assert_true(help.contains("ops-batch-b64 <b64>"))
  // 组合意图通道（"+" 多段 → mode:multi）必须从 help 可发现——与
  // core/agent_api.mbt 的 generate 描述同源，SKILL.md 不再是唯一入口
  assert_true(help.contains("composite → multi-artboard"))
}

///|
/// 组合意图产物的 canonical 往返：generate(多画板+导航流) → export-mbt-agent
/// → load-mbt-b64 重载，板与流零损失——genUI 的正确性根基（会话保存/重开
/// 与 wasm canonical 交换同走此路径）。
fn unescape_json_str(s : String) -> String {
  let sb = StringBuilder::new()
  let chars = s.to_array()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '\\' && i + 1 < chars.length() {
      let c = chars[i + 1]
      if c == 'n' {
        sb.write_char('\n')
      } else if c == 'r' {
        sb.write_char('\r')
      } else if c == 't' {
        sb.write_char('\t')
      } else if c == '"' || c == '\\' || c == '/' {
        sb.write_char(c)
      } else {
        sb.write_char('\\')
        sb.write_char(c)
      }
      i = i + 2
    } else {
      sb.write_char(chars[i])
      i = i + 1
    }
  }
  sb.to_string()
}

///|
fn envelope_mbt(envelope : String) -> String {
  let key = "\"mbt\":\""
  let i = match envelope.find(key) {
    Some(x) => x + key.length()
    None => return ""
  }
  let rest = envelope.substring(start=i)
  let sb = StringBuilder::new()
  let chars = rest.to_array()
  let mut j = 0
  while j < chars.length() {
    if chars[j] == '\\' && j + 1 < chars.length() {
      sb.write_char('\\')
      sb.write_char(chars[j + 1])
      j = j + 2
    } else if chars[j] == '"' {
      break
    } else {
      sb.write_char(chars[j])
      j = j + 1
    }
  }
  unescape_json_str(sb.to_string())
}

///|
test "组合意图产物 canonical 往返：双板与导航流零损失" {
  let p = @core.Project::new()
  let gen = cli_exec(p, "generate 登录+注册")
  assert_true(gen.contains("\"mode\":\"multi\""))
  let exp = cli_exec(p, "export-mbt-agent")
  let mbt = envelope_mbt(exp)
  assert_true(mbt.contains("moonviz:artboard login"))
  assert_true(mbt.contains("moonviz:artboard signup"))
  // 重载到全新会话
  let p2 = @core.Project::new()
  let loaded = cli_exec(p2, "load-mbt-b64 " + cli_b64(mbt))
  assert_true(loaded.contains("\"ok\":true"), msg="canonical 重载应成功: \{loaded}")
  let list = cli_exec(p2, "list")
  assert_true(list.contains("\"id\":\"login\"") && list.contains("\"id\":\"signup\""))
  let flows = cli_exec(p2, "flows")
  assert_true(flows.contains("\"from\":\"login\",\"to\":\"signup\""))
  assert_true(flows.contains("tap:signup_btn"))
}

///|
/// 用户组件声明样例（plain 名字：含 param + 两变体，供 MCF 往返）
let cli_sample_component = "---\ncomponent:\n  id: badge\n  description: mini badge\n  params:\n    - name: label\n      kind: text\n      default: Hi\n  variants:\n    - name: default\n    - name: big\n      label: BIG\n---\n\n<!-- moonviz:artboard badge -->\n```mbt\nfn visual_badge() -> @decl.Prototype {\n  let page = @decl.prototype(name=\"badge\", width=64.0, height=32.0)\n  page.add(@decl.text(id=\"cap\", content=\"${label}\", size=12.0))\n  page\n}\n```\n"

///|
/// 含引号的组件 id / 变体名（解析器仅 strip_quotes，允许任意文本）
let cli_quoted_component = "---\ncomponent:\n  id: \"a\"b\"\n  description: quoted name\n  variants:\n    - name: pri\"mary\n---\n\n<!-- moonviz:artboard a\"b -->\n```mbt\nfn visual_q() -> @decl.Prototype {\n  let page = @decl.prototype(name=\"quoted\", width=64.0, height=32.0)\n  page.add(@decl.text(id=\"cap\", content=\"hi\", size=12.0))\n  page\n}\n```\n"

///|
/// 从信封里抽 b64 字段值（base64 无引号/转义，找到闭引号即值尾）
fn envelope_b64(envelope : String, key : String) -> String {
  let k = "\"" + key + "\":\""
  let i = match envelope.find(k) {
    Some(x) => x + k.length()
    None => return ""
  }
  let rest = envelope.substring(start=i)
  match rest.find("\"") {
    Some(end) => rest.substring(start=0, end~)
    None => ""
  }
}

///|
/// component-import 成功信封契约：header 由 mcf_header_json 产出（已是
/// 合法 JSON 对象文本），必须原样对象嵌入、信封以 }} 收尾，且 header.id
/// 与组件 id 一致。此前 header 值被 json_escape 后未加引号嵌入且信封缺
/// 收尾 } ——每次导入成功都返回非法 JSON。
test "component-import 成功信封合法：header 对象嵌入且 id 与组件一致" {
  let p = @core.Project::new()
  let comp = cli_exec(p, "component-compile-b64 " + cli_b64(cli_sample_component))
  assert_true(comp.contains("\"ok\":true"), msg="compile 应成功: \{comp}")
  let exp = cli_exec(p, "component-export badge")
  let mcf = envelope_b64(exp, "mcf_b64")
  assert_true(mcf.length() > 0, msg="export 应产出 mcf_b64: \{exp}")
  // 全新会话导入（完整重验收管线）
  let p2 = @core.Project::new()
  let imp = cli_exec(p2, "component-import " + mcf)
  assert_true(imp.contains("\"ok\":true"), msg="import 应成功: \{imp}")
  assert_true(imp.contains("\"header\":{\"id\":\"badge\""), msg=imp)
  assert_true(imp.has_suffix("}}"), msg=imp)
  let desc = cli_exec(p2, "component-describe badge")
  assert_true(desc.contains("\"id\":\"badge\""), msg=desc)
}

///|
/// set-state 文法 <node> <state_name> [toggle]：最小合法形式此前被
/// <4 双重 off-by-one 拒之门外，toggle 尾缀（parts[4]）永远打不开。
test "set-state 最小形式生效且 toggle 尾缀可开" {
  let p = @core.Project::new()
  let ab = cli_exec(p, "create home 390 844")
  assert_true(ab.contains("\"ok\":true"), msg=ab)
  let placed = cli_exec(p, "place home button btn1 - 10 10")
  assert_true(placed.contains("\"ok\":true"), msg=placed)
  let st = cli_exec(p, "state home btn1 pressed fill=#FF0000")
  assert_true(st.contains("\"ok\":true"), msg=st)
  // 最小形式：直接激活
  let set1 = cli_exec(p, "set-state btn1 pressed")
  assert_true(set1.contains("\"current\":\"pressed\""), msg=set1)
  // toggle 尾缀：当前已是 pressed → 切回 default
  let set2 = cli_exec(p, "set-state btn1 pressed toggle")
  assert_true(set2.contains("\"current\":\"default\""), msg=set2)
}

///|
/// 含引号组件名/变体名：信封层必须转义成合法 JSON（此前 param.name/
/// param.kind/variant 裸插值产出非法 JSON——"component":"a"b"）。
test "含引号组件名：compile 与 list-components 信封仍合法" {
  let p = @core.Project::new()
  let comp = cli_exec(p, "component-compile-b64 " + cli_b64(cli_quoted_component))
  assert_true(comp.contains("\"ok\":true"), msg="compile 应成功: \{comp}")
  assert_true(comp.contains("\"component\":\"a\\\"b\""), msg=comp)
  assert_true(comp.contains("\"variants\":[\"pri\\\"mary\"]"), msg=comp)
  let list = cli_exec(p, "list-components")
  assert_true(list.contains("\"id\":\"a\\\"b\""), msg=list)
  assert_true(list.contains("\"variants\":[\"pri\\\"mary\"]"), msg=list)
}

///|
/// unflow CLI 臂（F52）：op_entries 注册表宣告自己是 CLI op 面，Agent 按
/// list-ops 逐字发命令——此前 27 条 mutating op 唯独 unflow 缺臂回
/// unknown_command。与 flow 臂对称：建边→删除→边消失，重复删除报错。
test "unflow 从 CLI 行协议删除单条导航边" {
  let p = @core.Project::new()
  let ab = cli_exec(p, "create home 390 844")
  assert_true(ab.contains("\"ok\":true"), msg=ab)
  let ab2 = cli_exec(p, "create detail 390 844")
  assert_true(ab2.contains("\"ok\":true"), msg=ab2)
  let flow = cli_exec(p, "flow home detail go_btn")
  assert_true(flow.contains("\"ok\":true"), msg=flow)
  let un = cli_exec(p, "unflow home detail go_btn")
  assert_true(un.contains("\"ok\":true"), msg=un)
  let flows = cli_exec(p, "flows")
  assert_true(!flows.contains("tap:go_btn"), msg=flows)
  // 不存在的边：报错（与 ops 注册表 unflow 语义一致）
  let again = cli_exec(p, "unflow home detail go_btn")
  assert_true(again.contains("\"error\""), msg=again)
}
