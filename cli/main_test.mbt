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
