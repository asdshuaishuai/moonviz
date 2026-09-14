///|
/// MoonViz MCP Server：JSON-RPC 2.0 over stdio。
///
/// 完整实现：initialize / tools/list / tools/call（含参数解析）。
///
/// 测试：
/// ```bash
/// echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"apply_template","arguments":{"template_id":"login","name":"my_login"}}}' | moon run --target native mcp
/// ```
extern "c" fn getchar() -> Int = "getchar"

///|
fn read_line() -> String {
  let bytes : Array[Int] = []
  let mut on = true
  while on {
    let c = getchar()
    if c == 10 || c == -1 {
      on = false
    } else if c == 13 {
      // 跳过 \r
    } else {
      bytes.push(c)
    }
  }
  utf8_from_bytes(bytes)
}

///|
/// stdin 是 UTF-8 字节流：逐字节收集后解码（getchar 逐字节返回，
/// 直接用 Int::to_char 会按 Latin-1 拼坏非 ASCII 文本）
fn utf8_from_bytes(bytes : Array[Int]) -> String {
  let sb = StringBuilder::new()
  let mut i = 0
  let n = bytes.length()
  while i < n {
    let b0 = bytes[i]
    if b0 < 0x80 {
      sb.write_char(Int::to_char(b0).unwrap_or('?'))
      i = i + 1
    } else if b0 < 0xE0 && i + 1 < n {
      let cp = ((b0 - 0xC0) << 6) + (bytes[i + 1] - 0x80)
      sb.write_char(Int::to_char(cp).unwrap_or('?'))
      i = i + 2
    } else if b0 < 0xF0 && i + 2 < n {
      let cp = ((b0 - 0xE0) << 12) +
        ((bytes[i + 1] - 0x80) << 6) +
        (bytes[i + 2] - 0x80)
      sb.write_char(Int::to_char(cp).unwrap_or('?'))
      i = i + 3
    } else if i + 3 < n {
      let cp = ((b0 - 0xF0) << 18) +
        ((bytes[i + 1] - 0x80) << 12) +
        ((bytes[i + 2] - 0x80) << 6) +
        (bytes[i + 3] - 0x80)
      sb.write_char(Int::to_char(cp).unwrap_or('?'))
      i = i + 4
    } else {
      i = i + 1
    }
  }
  sb.to_string()
}

///|
/// 全局项目状态（跨请求保持）
let g_project : @core.Project = @core.Project::new()

///|
fn main {
  let mut running = true
  while running {
    let line = read_line()
    if line.length() == 0 {
      running = false
    } else {
      let response = handle_request(line)
      if response != "" {
        println(response)
      }
    }
  }
}

///|
fn handle_request(line : String) -> String {
  let method = extract_json_string(line, "method")
  let id = extract_json_id(line)
  match method {
    "initialize" =>
      "{\"jsonrpc\":\"2.0\",\"id\":\{id},\"result\":{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{\"tools\":{}},\"serverInfo\":{\"name\":\"moonviz\",\"version\":\"0.1.0\"}}}"
    "notifications/initialized" => ""
    "tools/list" => {
      let tools = tools_definition()
      "{\"jsonrpc\":\"2.0\",\"id\":\{id},\"result\":{\"tools\":\{tools}}}"
    }
    "tools/call" => {
      let tool_name = extract_json_string(line, "name")
      let result = execute_tool(line, tool_name)
      // MCP 要求 text 字段是 JSON 字符串（需要转义引号）
      let escaped = json_escape_text(result)
      "{\"jsonrpc\":\"2.0\",\"id\":\{id},\"result\":{\"content\":[{\"type\":\"text\",\"text\":\"\{escaped}\"}]}}"
    }
    "ping" => "{\"jsonrpc\":\"2.0\",\"id\":\{id},\"result\":{}}"
    _ =>
      "{\"jsonrpc\":\"2.0\",\"id\":\{id},\"error\":{\"code\":-32601,\"message\":\"Method not found: \{method}\"}}"
  }
}

// ---------------------------------------------------------------------------
// 工具定义
// ---------------------------------------------------------------------------

///|
fn decode_mcp_b64(value : String) -> String {
  let decoded = try? @base64.decode(value)
  match decoded {
    Ok(bytes) => @utf8.decode_lossy(bytes)
    Err(_) => ""
  }
}

///|
fn tools_definition() -> String {
  let tools : Array[String] = []
  tools.push(tool_def("list_templates", "List all available page templates"))
  tools.push(
    tool_def("list_components", "List all UI components (builtin + user) with variants"),
  )
  tools.push(
    tool_def(
      "component_compile",
      "Compile & register a user component from a .mbt.md declaration. args: source_b64",
    ),
  )
  tools.push(
    tool_def(
      "component_describe",
      "Describe a user component (params/variants/usage). args: component_id",
    ),
  )
  tools.push(
    tool_def(
      "component_export",
      "Export a user component as MCF (proprietary container). args: component_id",
    ),
  )
  tools.push(
    tool_def(
      "component_import",
      "Import an MCF container (full re-validation). args: mcf_b64",
    ),
  )
  tools.push(
    tool_def("library_snapshot", "Dump the user component library for host persistence"),
  )
  tools.push(tool_def("list_tokens", "List design tokens"))
  tools.push(tool_def("list_themes", "List available themes"))
  tools.push(tool_def("list_artboards", "List all artboards"))
  tools.push(
    tool_def("apply_template", "Apply template. args: template_id, name"),
  )
  tools.push(
    tool_def(
      "place_component", "Place component. args: artboard, component_id, instance_id, variant, x, y",
    ),
  )
  tools.push(tool_def("query_nodes", "Query nodes. args: artboard"))
  tools.push(tool_def("lint_design", "Run design lint. args: artboard"))
  tools.push(tool_def("critique", "8-principle critique. args: artboard"))
  tools.push(tool_def("benchmark", "Performance benchmark"))
  tools.push(tool_def("auto_fix", "Auto-fix violations. args: artboard"))
  tools.push(tool_def("apply_theme", "Switch theme. args: theme"))
  tools.push(tool_def("export_svg", "Export SVG. args: artboard"))
  tools.push(
    tool_def("read_mbt", "Read canonical MBT source. args: source_b64"),
  )
  tools.push(
    tool_def(
      "render_mbt", "Validate and render canonical MBT. args: source_b64",
    ),
  )
  tools.push(
    tool_def("ddp_view", "Read-only DDP viewer metadata and render contract"),
  )
  tools.push(tool_def("export_artifact", "Export MBT-derived artifact"))
  tools.push(tool_def("generate_spec", "Generate dev spec. args: artboard"))
  tools.push(tool_def("infer_page_type", "Detect page type. args: artboard"))
  tools.push(tool_def("infer_missing", "Find missing elements. args: artboard"))
  tools.push(tool_def("suggest_alignment", "Alignment hints. args: artboard"))
  tools.push(
    tool_def("extract_design_system", "Extract tokens. args: artboard"),
  )
  tools.push(
    tool_def("generate_responsive", "Generate variants. args: artboard"),
  )
  let j = join_mcp(tools)
  "[\{j}]"
}

///|
fn tool_def(name : String, desc : String) -> String {
  "{\"name\":\"\{name}\",\"description\":\"\{desc}\"}"
}

// ---------------------------------------------------------------------------
// 工具执行（真正干活）
// ---------------------------------------------------------------------------

///|
fn execute_tool(request_line : String, tool_name : String) -> String {
  let p = g_project
  // 从 params.arguments 中提取参数
  let artboard = extract_arg_string(request_line, "artboard")
  let template_id = extract_arg_string(request_line, "template_id")
  let name = extract_arg_string(request_line, "name")
  let component_id = extract_arg_string(request_line, "component_id")
  let instance_id = extract_arg_string(request_line, "instance_id")
  let variant = extract_arg_string(request_line, "variant")
  let theme = extract_arg_string(request_line, "theme")
  let source_b64 = extract_arg_string(request_line, "source_b64")
  let x = extract_arg_num(request_line, "x")
  let y = extract_arg_num(request_line, "y")

  match tool_name {
    "list_templates" => @core.list_templates_json()
    "list_components" => {
      let builtin = @core.list_components_json(p.components)
      let user_items : Array[String] = []
      for id in p.user_components.keys() {
        match p.user_components.get(id) {
          Some(def) => {
            let vs : Array[String] = []
            for v in def.variants.keys() {
              vs.push("\"\{v}\"")
            }
            user_items.push(
              "{\"id\":\"\{id}\",\"kind\":\"user-component\",\"category\":\"\{def.category}\",\"variants\":[\{mcp_join(vs)}],\"source\":\"user\",\"description\":\"\{@core.json_escape(def.description)}\"}",
            )
          }
          None => ()
        }
      }
      if user_items.length() == 0 {
        builtin
      } else {
        let inner = builtin.substring(start=1, end=builtin.length() - 1)
        let sep = if inner == "" { "" } else { "," }
        "[\{inner}\{sep}\{mcp_join(user_items)}]"
      }
    }
    "component_compile" => {
      if source_b64 == "" {
        return err_json("missing source_b64")
      }
      match decode_b64_text(source_b64) {
        Err(e) => err_json(e)
        Ok(text) =>
          match @decl.parse_user_component(text) {
            Err(e) => err_json(e)
            Ok(def) => {
              let probe = @core.Document::new({
                width: def.width + 400.0,
                height: def.height + 400.0,
              })
              match
                @core.place_user_component(probe, def, "__probe", dx=10.0, dy=10.0) {
                Err(e) => err_json("usercomp_probe_failed:" + e)
                Ok(_) => {
                  p.user_components.set(def.id, def)
                  "{\"ok\":true,\"component\":\"\{def.id}\",\"params_count\":\{def.params.length()}}"
                }
              }
            }
          }
      }
    }
    "component_describe" => {
      if component_id == "" {
        return err_json("missing component_id")
      }
      match p.user_components.get(component_id) {
        None => err_json("unknown_component:" + component_id)
        Some(def) => {
          let ps : Array[String] = []
          for param in def.params.iter() {
            ps.push(
              "{\"name\":\"\{param.name}\",\"kind\":\"\{param.kind}\",\"default\":\"\{@core.json_escape(param.default_value)}\"}",
            )
          }
          "{\"ok\":true,\"id\":\"\{component_id}\",\"description\":\"\{@core.json_escape(def.description)}\",\"source\":\"user\",\"params\":[\{mcp_join(ps)}]}"
        }
      }
    }
    "component_export" => {
      if component_id == "" {
        return err_json("missing component_id")
      }
      match p.user_components.get(component_id) {
        None => err_json("unknown_component:" + component_id)
        Some(def) => {
          let header = "{\"id\":\"\{component_id}\",\"format\":\"mcf-v1\"}"
          let bytes = @core.mcf_pack(header, def.source)
          "{\"ok\":true,\"component\":\"\{component_id}\",\"mcf_b64\":\"\{@base64.encode(bytes)}\"}"
        }
      }
    }
    "component_import" => {
      let mcf_b64 = extract_arg_string(request_line, "mcf_b64")
      if mcf_b64 == "" {
        return err_json("missing mcf_b64")
      }
      let bytes = @base64.decode(mcf_b64) catch {
        _ => return err_json("mcf_transport_invalid_base64")
      }
      match @core.mcf_unpack(bytes) {
        Err(e) => err_json(e)
        Ok((_, source)) =>
          match @decl.parse_user_component(source) {
            Err(e) => err_json(e)
            Ok(def) => {
              p.user_components.set(def.id, def)
              "{\"ok\":true,\"component\":\"\{def.id}\"}"
            }
          }
      }
    }
    "library_snapshot" => {
      let items : Array[String] = []
      for id in p.user_components.keys() {
        match p.user_components.get(id) {
          Some(def) => {
            items.push("{\"id\":\"\{id}\",\"source_b64\":\"\{@base64.encode(@utf8.encode(def.source))}\"}")
          }
          None => ()
        }
      }
      "{\"ok\":true,\"count\":\{items.length()},\"components\":[\{mcp_join(items)}]}"
    }
    "list_tokens" => p.tokens.to_json()
    "list_themes" => {
      let themes = @core.builtin_themes()
      let items : Array[String] = []
      for t in themes.iter() {
        items.push(
          "{\"name\":\"\{t.name}\",\"display\":\"\{t.display_name}\",\"is_dark\":\{t.is_dark}}",
        )
      }
      let j = join_mcp(items)
      "[\{j}]"
    }
    "list_artboards" => p.list_artboards_json()
    "apply_template" => {
      if template_id == "" {
        return err_json("missing template_id")
      }
      let ab_name = if artboard != "" {
        artboard
      } else if name != "" {
        name
      } else {
        template_id
      }
      match p.apply_template(template_id~, name=ab_name) {
        Ok(id) => "{\"ok\":true,\"artboard\":\"\{id}\"}"
        Err(e) => err_json(e)
      }
    }
    "place_component" => {
      if artboard == "" || component_id == "" || instance_id == "" {
        return err_json("missing artboard/component_id/instance_id")
      }
      match
        p.place_component(
          artboard~,
          component_id~,
          instance_id~,
          variant~,
          x~,
          y~,
        ) {
        Ok(msg) => "{\"ok\":true,\"result\":\"\{msg}\"}"
        Err(e) => err_json(e)
      }
    }
    "query_nodes" => {
      if artboard == "" {
        return err_json("missing artboard")
      }
      match p.query_nodes(artboard~) {
        Ok(json) => json
        Err(e) => err_json(e)
      }
    }
    "lint_design" => {
      if artboard == "" {
        return err_json("missing artboard")
      }
      match p.lint(artboard~) {
        Ok(json) => json
        Err(e) => err_json(e)
      }
    }
    "critique" => {
      if artboard == "" {
        return err_json("missing artboard")
      }
      match p.critique(artboard~) {
        Ok(json) => json
        Err(e) => err_json(e)
      }
    }
    "benchmark" => p.benchmark().to_json()
    "auto_fix" => {
      if artboard == "" {
        return err_json("missing artboard")
      }
      match p.auto_fix(artboard~) {
        Ok(json) => json
        Err(e) => err_json(e)
      }
    }
    "apply_theme" => {
      if theme == "" {
        return err_json("missing theme")
      }
      match p.apply_theme(theme) {
        Ok(json) => json
        Err(e) => err_json(e)
      }
    }
    "export_svg" => {
      if artboard == "" {
        return err_json("missing artboard")
      }
      match p.export_svg(artboard~) {
        Ok(svg) => {
          let len = svg.length().to_string()
          "{\"ok\":true,\"svg_length\":\{len},\"preview\":\"\{svg.substring(start=0, end=100)}...\"}"
        }
        Err(e) => err_json(e)
      }
    }
    "read_mbt" =>
      if source_b64 == "" {
        "{\"error\":\"source_b64_required\"}"
      } else {
        match @decl.load_mbt_project(decode_mcp_b64(source_b64)) {
          Ok(doc) =>
            "{\"ok\":true,\"mbt\":\"" +
            json_escape_text(doc.document.source) +
            "\"}"
          Err(e) => "{\"error\":\"" + json_escape_text(e) + "\"}"
        }
      }
    "render_mbt" =>
      if source_b64 == "" {
        "{\"error\":\"source_b64_required\"}"
      } else {
        match @decl.load_mbt_project(decode_mcp_b64(source_b64)) {
          Ok(doc) => doc.render_json()
          Err(e) => "{\"error\":\"" + json_escape_text(e) + "\"}"
        }
      }
    "ddp_view" =>
      "{\"ok\":true,\"read_only\":true,\"mutations\":false,\"codec\":\"engine\"}"
    "export_artifact" => p.export_artifact(agent_id="mcp")
    "generate_spec" => {
      if artboard == "" {
        return err_json("missing artboard")
      }
      match p.generate_spec(artboard~) {
        Ok(spec) => {
          let len = spec.length().to_string()
          "{\"ok\":true,\"spec_length\":\{len}}"
        }
        Err(e) => err_json(e)
      }
    }
    "infer_page_type" => {
      if artboard == "" {
        return err_json("missing artboard")
      }
      match p.infer_page_type(artboard~) {
        Ok(json) => json
        Err(e) => err_json(e)
      }
    }
    "infer_missing" => {
      if artboard == "" {
        return err_json("missing artboard")
      }
      match p.infer_missing(artboard~) {
        Ok(json) => json
        Err(e) => err_json(e)
      }
    }
    "suggest_alignment" => {
      if artboard == "" {
        return err_json("missing artboard")
      }
      match p.suggest_alignment(artboard~) {
        Ok(json) => json
        Err(e) => err_json(e)
      }
    }
    "extract_design_system" => {
      if artboard == "" {
        return err_json("missing artboard")
      }
      match p.extract_design_system(artboard~) {
        Ok(ds) => ds.to_json()
        Err(e) => err_json(e)
      }
    }
    "generate_responsive" => {
      if artboard == "" {
        return err_json("missing artboard")
      }
      match p.generate_responsive(artboard~) {
        Ok(json) => json
        Err(e) => err_json(e)
      }
    }
    _ => err_json("unknown_tool: " + tool_name)
  }
}

///|
fn err_json(msg : String) -> String {
  let escaped = json_escape_text(msg)
  "{\"error\":\"\{escaped}\"}"
}

// ---------------------------------------------------------------------------
// JSON 参数解析
// ---------------------------------------------------------------------------

///|
/// 从 JSON-RPC params.arguments 中提取字符串参数
/// 输入行形如: {"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"apply_template","arguments":{"template_id":"login"}}}
fn extract_arg_string(line : String, key : String) -> String {
  // 先定位 "arguments":{ ... }
  let args_idx = match line.find("\"arguments\":{") {
    Some(i) => i + 13
    None => return ""
  }
  let args_body = line.substring(start=args_idx)
  // 在 arguments 对象内查找 key
  let pattern = "\"" + key + "\":\""
  match args_body.find(pattern) {
    Some(idx) => {
      let start = idx + pattern.length()
      let rest = args_body.substring(start~)
      match rest.find("\"") {
        Some(end) => rest.substring(start=0, end~)
        None => ""
      }
    }
    None => ""
  }
}

///|
/// 从 params.arguments 中提取数值参数
fn extract_arg_num(line : String, key : String) -> Double {
  let args_idx = match line.find("\"arguments\":{") {
    Some(i) => i + 13
    None => return 0.0
  }
  let args_body = line.substring(start=args_idx)
  let pattern = "\"" + key + "\":"
  match args_body.find(pattern) {
    Some(idx) => {
      let start = idx + pattern.length()
      let rest = args_body.substring(start~)
      let mut result = 0.0
      let mut frac = 0.1
      let mut has_dot = false
      for c in rest.iter() {
        let code = c.to_int()
        if code >= 48 && code <= 57 {
          let d = (code - 48).to_double()
          if has_dot {
            result = result + d * frac
            frac = frac * 0.1
          } else {
            result = result * 10.0 + d
          }
        } else if c == '.' && !has_dot {
          has_dot = true
        } else {
          break
        }
      }
      result
    }
    None => 0.0
  }
}

// ---------------------------------------------------------------------------
// 通用 JSON 辅助
// ---------------------------------------------------------------------------

///|
fn extract_json_string(json : String, key : String) -> String {
  let pattern = "\"" + key + "\":\""
  match json.find(pattern) {
    Some(idx) => {
      let start = idx + pattern.length()
      let rest = json.substring(start~)
      match rest.find("\"") {
        Some(end) => rest.substring(start=0, end~)
        None => ""
      }
    }
    None => ""
  }
}

///|
fn extract_json_id(json : String) -> String {
  match json.find("\"id\":") {
    Some(idx) => {
      let start = idx + 5
      let rest = json.substring(start~)
      let mut i = 0
      while i < rest.length() && rest.get_char(i) == Some(' ') {
        i = i + 1
      }
      let digits = rest.substring(start=i)
      let mut result = ""
      for c in digits.iter() {
        let code = c.to_int()
        if (code >= 48 && code <= 57) || c == '-' {
          result = result + c.to_string()
        } else {
          break
        }
      }
      if result == "" {
        "0"
      } else {
        result
      }
    }
    None => "0"
  }
}

///|
fn json_escape_text(s : String) -> String {
  let sb = StringBuilder::new()
  for c in s.iter() {
    match c {
      '"' => sb.write_string("\\\"")
      '\\' => sb.write_string("\\\\")
      '\n' => sb.write_string("\\n")
      _ => sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
fn replace_underscores(s : String) -> String {
  let sb = StringBuilder::new()
  for c in s.iter() {
    if c == '_' {
      sb.write_char('-')
    } else {
      sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
fn join_mcp(parts : Array[String]) -> String {
  let sb = StringBuilder::new()
  for i in 0..<parts.length() {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string(parts[i])
  }
  sb.to_string()
}


///|
fn mcp_join(items : Array[String]) -> String {
  let sb = StringBuilder::new()
  let mut first = true
  for item in items.iter() {
    if first == false {
      sb.write_string(",")
    }
    first = false
    sb.write_string(item)
  }
  sb.to_string()
}

///|
fn decode_b64_text(payload : String) -> Result[String, String] {
  let bytes = @base64.decode(payload) catch {
    _ => return Err("transport_invalid_base64")
  }
  Ok(@utf8.decode(bytes) catch { _ => return Err("transport_invalid_utf8") })
}
