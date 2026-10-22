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
}
