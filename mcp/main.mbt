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

/// 设计版本历史（会话级）：history_init 后随 commit/checkout/undo/redo 演进。
let g_history : @ref.Ref[@core.DesignHistory?] = @ref.Ref::new(None)
let g_history_board : @ref.Ref[String] = @ref.Ref::new("")

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
      "{\"jsonrpc\":\"2.0\",\"id\":\{id},\"result\":{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{\"tools\":{}},\"serverInfo\":{\"name\":\"moonviz\",\"version\":\"\{@core.ENGINE_VERSION}\"}}}"
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
  // 工具能力字典的单一事实源在 core/agent_api.mbt：name/description/
  // inputSchema（真实参数 schema）由此生成，CLI `list-tools` 与
  // 落地项目的 moonviz-tools.json 同源。
  @core.list_tools_json()
}

///|

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
  let token = extract_arg_string(request_line, "token")
  let value = extract_arg_string(request_line, "value")
  let source_b64 = extract_arg_string(request_line, "source_b64")
  let x = extract_arg_num(request_line, "x")
  let y = extract_arg_num(request_line, "y")
  let w = extract_arg_num(request_line, "w")
  let h = extract_arg_num(request_line, "h")
  let node_id = extract_arg_string(request_line, "node_id")
  let new_id = extract_arg_string(request_line, "new_id")
  let mode = extract_arg_string(request_line, "mode")
  let nodes_arg = extract_arg_string(request_line, "nodes")
  let trigger = extract_arg_string(request_line, "trigger")
  let action_spec = extract_arg_string(request_line, "action_spec")
  let state_name = extract_arg_string(request_line, "state_name")
  let width = extract_arg_num(request_line, "width")
  let height = extract_arg_num(request_line, "height")

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
              p.user_components.set(def.id, def)
              "{\"ok\":true,\"component\":\"\{@core.json_escape(def.id)}\",\"params_count\":\{def.params.length()}}"
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
              "{\"name\":\"\{@core.json_escape(param.name)}\",\"kind\":\"\{param.kind}\",\"default\":\"\{@core.json_escape(param.default_value)}\"}",
            )
          }
          let vs : Array[String] = []
          for v in def.variants.keys() {
            vs.push("\"\{v}\"")
          }
          let kvs : Array[String] = []
          for param in def.params.iter() {
            kvs.push("\{param.name}=<\{param.kind}>")
          }
          let kv_sb = StringBuilder::new()
          let mut first_kv = true
          for kv in kvs.iter() {
            if first_kv == false {
              kv_sb.write_string(" ")
            }
            first_kv = false
            kv_sb.write_string(kv)
          }
          let kv_j = if kvs.length() > 0 { " " + kv_sb.to_string() } else { "" }
          let usage = "place <artboard> \{component_id} <instance_id> [variant] [x] [y] [w] [h]\{kv_j}"
          "{\"ok\":true,\"id\":\"\{@core.json_escape(component_id)}\",\"description\":\"\{@core.json_escape(def.description)}\",\"source\":\"user\",\"size\":\"\{def.width}x\{def.height}\",\"params\":[\{mcp_join(ps)}],\"variants\":[\{mcp_join(vs)}],\"usage\":\"\{@core.json_escape(usage)}\"}"
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
          // header 构造收敛到 core（与 CLI 同一 schema）
          match @core.mcf_pack(@core.mcf_header_json(def), def.source) {
            Err(e) => err_json(e)
            Ok(bytes) => "{\"ok\":true,\"component\":\"\{@core.json_escape(component_id)}\",\"mcf_b64\":\"\{@base64.encode(bytes)}\"}"
          }
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
        Ok((header, source)) =>
          match @decl.parse_user_component(source) {
            Err(e) => err_json(e)
            Ok(def) => {
              p.user_components.set(def.id, def)
              "{\"ok\":true,\"component\":\"\{@core.json_escape(def.id)}\",\"header\":\{@core.json_escape(header)}"
            }
          }
      }
    }
    "library_snapshot" => {
      let items : Array[String] = []
      for id in p.user_components.keys() {
        match p.user_components.get(id) {
          Some(def) => {
            items.push("{\"id\":\"\{@core.json_escape(id)}\",\"source_b64\":\"\{@base64.encode(@utf8.encode(def.source))}\"}")
          }
          None => ()
        }
      }
      "{\"ok\":true,\"op\":\"library-snapshot\",\"count\":\{items.length()},\"components\":[\{mcp_join(items)}]}"
    }
    "component_delete" => {
      if component_id == "" {
        return err_json("missing component_id")
      }
      if p.user_components.contains(component_id) == false {
        return err_json("unknown_component:" + component_id)
      }
      p.user_components.remove(component_id)
      "{\"ok\":true,\"op\":\"component-delete\",\"component\":\"\{@core.json_escape(component_id)}\"}"
    }
    "library_restore" => {
      let source_b64s = extract_arg_string(request_line, "source_b64s")
      if source_b64s == "" {
        return err_json("missing source_b64s")
      }
      let mut ok_count = 0
      let mut first_error = ""
      for part_view in source_b64s.split(" ") {
        let part = part_view.to_string()
        if part == "" {
          continue
        }
        match decode_b64_text(part) {
          Err(e) => {
            if first_error == "" {
              first_error = e
            }
          }
          Ok(text) =>
            match @decl.parse_user_component(text) {
              Err(e) => {
                if first_error == "" {
                  first_error = e
                }
              }
              Ok(def) => {
                p.user_components.set(def.id, def)
                ok_count = ok_count + 1
              }
            }
        }
      }
      if first_error != "" {
        return err_json("library_restore_partial:\{ok_count}:" + first_error)
      }
      "{\"ok\":true,\"op\":\"library-restore\",\"count\":\{ok_count}}"
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
      let j = mcp_join(items)
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
      // 用户组件参数槽：arguments.args = "k=v k=v ..."（空格分隔）
      let kv : Map[String, String] = Map::new()
      let raw_args = extract_arg_string(request_line, "args")
      if raw_args != "" {
        for part_view in raw_args.split(" ") {
          let part = part_view.to_string()
          if part == "" {
            continue
          }
          match part.find("=") {
            None => return err_json("place_invalid_arg:" + part)
            Some(pos) => {
              let k = part.substring(start=0, end=pos)
              let v = @decl.unescape_value(part.substring(start=pos + 1))
              if k != "" {
                kv.set(k, v)
              }
            }
          }
        }
      }
      match
        p.place_component(
          artboard~,
          component_id~,
          instance_id~,
          variant~,
          x~,
          y~,
          w~,
          h~,
          args=kv,
        ) {
        Ok(msg) => "{\"ok\":true,\"result\":\"\{@core.json_escape(msg)}\"}"
        Err(e) => err_json(e)
      }
    }
    "variants" => {
      let action = extract_arg_string(request_line, "action")
      match action {
        "fork" => {
          if artboard == "" {
            return err_json("missing artboard (base)")
          }
          let names_arg = extract_arg_string(request_line, "names")
          if names_arg == "" {
            return err_json("missing names (comma-separated)")
          }
          let names : Array[String] = []
          for part_view in names_arg.split(",") {
            let t = part_view.to_string()
            if t != "" {
              names.push(t)
            }
          }
          match p.fork_variants(base=artboard, names~) {
            Ok(json) => json
            Err(e) => err_json(e)
          }
        }
        "score" => p.score_variants()
        "merge" => {
          let source = extract_arg_string(request_line, "source")
          let target = extract_arg_string(request_line, "target")
          if source == "" || target == "" {
            return err_json("missing source/target")
          }
          match p.merge_variant(source~, target~) {
            Ok(json) => json
            Err(e) => err_json(e)
          }
        }
        _ => err_json("unknown_action: fork | score | merge")
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
    "set_token" => {
      if token == "" || value == "" {
        return err_json("missing token or value")
      }
      match p.set_token(token, value) {
        Ok(json) => json
        Err(e) => err_json(e)
      }
    }
    "export_html" => {
      let html = p.export_html()
      let len = html.length().to_string()
      "{\"ok\":true,\"html_length\":\{len},\"preview\":\"\{html.substring(start=0, end=120)}...\"}"
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
    "list_ops" => @core.list_ops_json()
    "animation_presets" => @core.animation_presets_json()
    "history" => {
      let cmd = extract_arg_string(request_line, "command")
      if cmd == "" {
        return err_json("missing command (init|commit|log|undo|redo|checkout|diff)")
      }
      match cmd {
        "init" =>
          match g_project.artboards.get(artboard) {
            None => err_json("unknown_artboard: " + artboard)
            Some(ab) => {
              // 允许 rebind：换目标画板即重置历史（与 CLI 语义对齐）
              g_history.val = Some(@core.DesignHistory::new(ab.doc.clone()))
              g_history_board.val = artboard
              "{\"ok\":true,\"op\":\"history-init\",\"artboard\":\"\{artboard}\"}"
            }
          }
        "commit" =>
          match g_history.val {
            None => err_json("history_not_initialized")
            Some(h) =>
              match g_project.artboards.get(artboard) {
                None => err_json("unknown_artboard: " + artboard)
                Some(ab) => {
                  let msg = extract_arg_string(request_line, "message")
                  let m = if msg == "" { "commit" } else { msg }
                  let _ = h.commit("mcp", m, [], ab.doc.clone())
                  "{\"ok\":true,\"op\":\"history-commit\",\"rev\":\{h.rev()},\"message\":\"\{@core.json_escape(m)}\"}"
                }
              }
          }
        "log" =>
          match g_history.val {
            None => err_json("history_not_initialized")
            Some(h) =>
              "{\"ok\":true,\"op\":\"history-log\",\"rev\":\{h.rev()},\"log\":\"\{@core.json_escape(h.log())}\"}"
          }
        "undo" | "redo" | "checkout" =>
          match g_history.val {
            None => err_json("history_not_initialized")
            Some(h) => {
              let want = extract_arg_string(request_line, "rev")
              let doc = if cmd == "undo" {
                h.undo()
              } else if cmd == "redo" {
                h.redo()
              } else {
                match mcp_parse_rev(want) {
                  Some(v) => h.checkout(v)
                  None => return err_json("bad_revision")
                }
              }
              match doc {
                Err(e) => err_json(e)
                Ok(d) => {
                  let target = g_history_board.val
                  match g_project.set_artboard_doc(artboard=target, d) {
                    Err(e) => err_json(e)
                    Ok(_) =>
                      "{\"ok\":true,\"op\":\"history-\{cmd}\",\"rev\":\{h.rev()},\"artboard\":\"\{target}\"}"
                  }
                }
              }
            }
          }
        "diff" =>
          match g_history.val {
            None => err_json("history_not_initialized")
            Some(h) => {
              let a = mcp_parse_rev(extract_arg_string(request_line, "from"))
              let b = mcp_parse_rev(extract_arg_string(request_line, "to"))
              match (a, b) {
                (Some(x), Some(y)) =>
                  match h.diff(x, y) {
                    Err(e) => err_json(e)
                    Ok(json) =>
                      "{\"ok\":true,\"op\":\"history-diff\",\"from\":\{x},\"to\":\{y},\"diff\":\{json}}"
                  }
                _ => err_json("usage: history diff <from> <to>")
              }
            }
          }
        _ => err_json("unknown history command: " + cmd)
      }
    }
    "protest" => {
      if artboard == "" {
        return err_json("missing artboard")
      }
      let script = extract_arg_string(request_line, "script")
      if script == "" {
        return err_json("missing script (tap:x:y>board; back>board; noviol; render)")
      }
      @core.run_protest_script(p, artboard, script)
    }
    "animation_css" => {
      if node_id == "" {
        return err_json("missing node_id")
      }
      let preset = extract_arg_string(request_line, "preset")
      if preset == "" {
        return err_json("missing preset (press/fade_in/slide_in_right/modal_present/shake/pop)")
      }
      @core.animation_css(node_id, preset)
    }
    "collab_merge" => {
      let spec = extract_arg_string(request_line, "spec")
      if spec == "" {
        return err_json("missing spec: <base_rev> <agent>=<op>[+op...] ...")
      }
      @core.merge_sessions_from_spec(spec)
    }
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
    // ---- 节点编辑与结构操作 ----
    "update_node" => {
      if artboard == "" || node_id == "" {
        return err_json("missing artboard/node_id")
      }
      let raw = extract_arg_string(request_line, "args")
      if raw == "" {
        return err_json("missing args (space-separated k=v)")
      }
      let kvs : Array[(String, String)] = []
      for part_view in raw.split(" ") {
        let part = part_view.to_string()
        if part == "" {
          continue
        }
        match part.find("=") {
          None => return err_json("update_invalid_arg:" + part)
          Some(pos) => {
            let k = part.substring(start=0, end=pos)
            let v = @decl.unescape_value(part.substring(start=pos + 1))
            if k != "" {
              kvs.push((k, v))
            }
          }
        }
      }
      if kvs.length() == 0 {
        return err_json("no k=v pairs")
      }
      match p.edit_node(artboard~, node_id~, kvs~) {
        Ok(json) => json
        Err(e) => err_json(e)
      }
    }
    "move_node" => {
      if artboard == "" || node_id == "" {
        return err_json("missing artboard/node_id")
      }
      match p.move_node(artboard~, node_id~, x~, y~) {
        Ok(json) => json
        Err(e) => err_json(e)
      }
    }
    "group_nodes" => {
      if artboard == "" || new_id == "" || nodes_arg == "" {
        return err_json("missing artboard/new_id/nodes")
      }
      let ids : Array[String] = []
      for v in nodes_arg.split(",") {
        let t = v.to_string().trim().to_string()
        if t != "" {
          ids.push(t)
        }
      }
      if ids.length() < 2 {
        return err_json("need_two_nodes")
      }
      match p.group_nodes(artboard~, node_ids=ids, group_id=new_id) {
        Ok(json) => json
        Err(e) => err_json(e)
      }
    }
    "ungroup_node" => {
      if artboard == "" || node_id == "" {
        return err_json("missing artboard/node_id")
      }
      match p.ungroup_node(artboard~, group_id=node_id) {
        Ok(json) => json
        Err(e) => err_json(e)
      }
    }
    "align_nodes" => {
      if artboard == "" || mode == "" || nodes_arg == "" {
        return err_json("missing artboard/mode/nodes")
      }
      let ids : Array[String] = []
      for v in nodes_arg.split(",") {
        let t = v.to_string().trim().to_string()
        if t != "" {
          ids.push(t)
        }
      }
      if ids.length() < 2 {
        return err_json("need_two_nodes")
      }
      match p.align_nodes(artboard~, mode~, node_ids=ids) {
        Ok(json) => json
        Err(e) => err_json(e)
      }
    }
    "resize_canvas" => {
      if artboard == "" {
        return err_json("missing artboard")
      }
      match p.resize_canvas(artboard~, width~, height~) {
        Ok(json) => json
        Err(e) => err_json(e)
      }
    }
    "restyle_component" => {
      if artboard == "" || component_id == "" {
        return err_json("missing artboard/component_id")
      }
      let raw = extract_arg_string(request_line, "args")
      let kvs : Array[(String, String)] = []
      for part_view in raw.split(" ") {
        let part = part_view.to_string()
        if part == "" {
          continue
        }
        match part.find("=") {
          None => return err_json("restyle_invalid_arg:" + part)
          Some(pos) => {
            let k = part.substring(start=0, end=pos)
            let v = @decl.unescape_value(part.substring(start=pos + 1))
            if k != "" {
              kvs.push((k, v))
            }
          }
        }
      }
      if kvs.length() == 0 {
        return err_json("missing args (space-separated k=v)")
      }
      match p.restyle_component(artboard~, component_id~, kvs~) {
        Ok(json) => json
        Err(e) => err_json(e)
      }
    }
    // ---- 交互 ----
    "interact" => {
      if artboard == "" || node_id == "" || trigger == "" || action_spec == "" {
        return err_json("missing artboard/node_id/trigger/action_spec")
      }
      match p.attach_interaction(artboard~, node_id~, trigger~, action_spec~) {
        Ok(json) => json
        Err(e) => err_json(e)
      }
    }
    "uninteract" => {
      if artboard == "" || node_id == "" {
        return err_json("missing artboard/node_id")
      }
      match p.detach_interaction(artboard~, node_id~) {
        Ok(json) => json
        Err(e) => err_json(e)
      }
    }
    "interactions" => {
      if artboard == "" {
        return err_json("missing artboard")
      }
      match p.interactions_json(artboard~) {
        Ok(json) => json
        Err(e) => err_json(e)
      }
    }
    // ---- 组件状态 ----
    "define_state" => {
      if artboard == "" || node_id == "" || state_name == "" {
        return err_json("missing artboard/node_id/state_name")
      }
      let raw = extract_arg_string(request_line, "args")
      let mut fill : String? = None
      let mut text_color : String? = None
      let mut stroke : String? = None
      let mut text : String? = None
      let mut radius : Double? = None
      let mut font_size : Double? = None
      for part_view in raw.split(" ") {
        let part = part_view.to_string()
        if part == "" {
          continue
        }
        match part.find("=") {
          None => ()
          Some(pos) => {
            let k = part.substring(start=0, end=pos)
            let v = @decl.unescape_value(part.substring(start=pos + 1))
            let d = @core.parse_double(v)
            match k {
              "fill" => fill = Some(v)
              "text_color" => text_color = Some(v)
              "stroke" => stroke = Some(v)
              "text" => text = Some(v)
              "radius" => radius = Some(d)
              "font_size" => font_size = Some(d)
              _ => ()
            }
          }
        }
      }
      let patch : @core.NodePatch = {
        ..@core.NodePatch::empty(),
        fill,
        text_color,
        stroke,
        text,
        corner_radius: radius,
        font_size,
      }
      match p.define_component_state(artboard~, node_id~, state_name~, patch~) {
        Ok(json) => json
        Err(e) => err_json(e)
      }
    }
    "set_state" => {
      if node_id == "" || state_name == "" {
        return err_json("missing node_id/state_name")
      }
      let toggle = extract_arg_string(request_line, "toggle") == "true"
      match p.set_node_state(node_id~, state_name~, toggle~) {
        Ok(json) => json
        Err(e) => err_json(e)
      }
    }
    "list_states" => {
      if artboard == "" {
        return err_json("missing artboard")
      }
      match p.node_states_json(artboard~) {
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
/// 定位 params.arguments 对象体起点（容忍 "arguments":{ 与 "arguments": { 两种写法）。
/// 固定模式会让冒号后带空格的请求全部解析失败（表现为参数 missing）。
fn find_arguments_body(line : String) -> Int? {
  let key = "\"arguments\":"
  match line.find(key) {
    None => None
    Some(i) => {
      let mut j = i + key.length()
      while j < line.length() && line.get_char(j) == Some(' ') {
        j = j + 1
      }
      if line.get_char(j) == Some('{') {
        Some(j + 1)
      } else {
        None
      }
    }
  }
}

///|
/// 从 JSON-RPC params.arguments 中提取字符串参数
/// 输入行形如: {"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"apply_template","arguments":{"template_id":"login"}}}
fn extract_arg_string(line : String, key : String) -> String {
  // 先定位 "arguments":{ ... }
  let args_idx = match find_arguments_body(line) {
    Some(i) => i
    None => return ""
  }
  let args_body = line.substring(start=args_idx)
  // 在 arguments 对象内查找 key（同样容忍 "key": "value" 的空格写法）
  let pattern = "\"" + key + "\":"
  match args_body.find(pattern) {
    Some(idx) => {
      let mut start = idx + pattern.length()
      while start < args_body.length() && args_body.get_char(start) == Some(' ') {
        start = start + 1
      }
      if args_body.get_char(start) != Some('"') {
        return ""
      }
      let rest = args_body.substring(start=start + 1)
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
  let args_idx = match find_arguments_body(line) {
    Some(i) => i
    None => return 0.0
  }
  let args_body = line.substring(start=args_idx)
  let pattern = "\"" + key + "\":"
  match args_body.find(pattern) {
    Some(idx) => {
      let mut start = idx + pattern.length()
      // 容忍 "key": 123 的空格写法（否则首个字符是空格，数字解析直接为 0）
      while start < args_body.length() && args_body.get_char(start) == Some(' ') {
        start = start + 1
      }
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
  // 容忍 "key":"v" 与 "key": "v" 两种写法：多数 JSON 客户端会在冒号后加空格，
  // 固定无空格模式会让 method/name 解析为空（表现为 Method not found）。
  let pattern = "\"" + key + "\":"
  match json.find(pattern) {
    Some(idx) => {
      let mut start = idx + pattern.length()
      while start < json.length() && json.get_char(start) == Some(' ') {
        start = start + 1
      }
      if json.get_char(start) != Some('"') {
        return ""
      }
      let rest = json.substring(start=start + 1)
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
    _ => return Err("mbt_transport_invalid_base64")
  }
  Ok(@utf8.decode(bytes) catch { _ => return Err("mbt_transport_invalid_utf8") })
}

///|
fn mcp_parse_rev(text : String) -> Int? {
  let t = text.trim().to_string()
  if t.length() == 0 {
    return None
  }
  let mut v = 0
  let mut i = 0
  while i < t.length() {
    let c = t.substring(start=i, end=i + 1)
    let d = "0123456789".find(c)
    match d {
      None => return None
      Some(x) => v = v * 10 + x
    }
    i = i + 1
  }
  Some(v)
}
