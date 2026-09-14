///|
/// MoonViz CLI：Agent 命令行接口。
///
/// 用法（stdin 逐行命令，输出 JSON）：
/// ```bash
/// echo "list-templates" | moon run --target native cli
/// echo "create login" | moon run --target native cli
/// echo "place login button submit primary 24 400" | moon run --target native cli
/// echo "lint login" | moon run --target native cli
/// ```
///
/// Agent（或 shell 脚本）可以管道组合多个命令。
extern "c" fn getchar() -> Int = "getchar"

///|
fn read_line() -> String {
  let bytes : Array[Int] = []
  let mut on = true
  while on {
    let c = getchar()
    if c == 10 {
      on = false
    } else if c == -1 {
      // stdin EOF：直接返回退出哨兵，避免主循环对空行无限自旋。
      if bytes.length() == 0 {
        return ":exit"
      }
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
fn main {
  let p = @core.Project::new()
  let mut running = true
  println("{\"moonviz\":\"cli\",\"version\":\"0.1.0\"}")
  while running {
    let line = read_line()
    // read_line 在 stdin EOF 时返回 ":exit" 哨兵；用户命令 "exit"/"quit"
    // 则由 cli_exec 返回同一哨兵。两条退出路径都必须在这里终止主循环。
    if line == ":exit" {
      running = false
    } else {
      let output = cli_exec(p, line)
      if output == ":exit" {
        running = false
      } else {
        println(output)
      }
    }
  }
}

///|
/// 将一行 Base64 传输载荷严格还原为 UTF-8 MBT 源码。
///
/// CLI 是换行分帧协议，完整 `.mbt.md` 必须经 Base64 传输；这只是传输编码，
/// 不是 DDP 格式，也不是另一份事实源。
fn decode_mbt_b64(payload : String) -> Result[String, String] {
  let bytes = @base64.decode(payload) catch {
    _ => return Err("mbt_transport_invalid_base64")
  }
  let text = @utf8.decode(bytes) catch {
    _ => return Err("mbt_transport_invalid_utf8")
  }
  Ok(text)
}

///|
fn encode_mbt_b64(text : String) -> String {
  @base64.encode(@utf8.encode(text))
}

///|
/// 判断操作是否为引擎修复（还债）操作。
fn mbt_op_is_fix(operation : String) -> Bool {
  mbt_has_cmd_prefix(operation, "fix")
}

///|
/// fix 的还债语义需要前缀匹配："fix"、"fix <artboard>"。
fn mbt_has_cmd_prefix(operation : String, prefix : String) -> Bool {
  let op = mbt_trim_ws(operation)
  if op == prefix {
    return true
  }
  let head = prefix + " "
  op.length() > head.length() && op.substring(start=0, end=head.length()) == head
}

///|
/// 去除首尾空白（CLI 操作行可能带换行）。
fn mbt_trim_ws(s : String) -> String {
  let ws = [" ", "\t", "\n", "\r"]
  let mut start = 0
  let mut ended = s.length()
  let mut trimming = true
  while trimming && start < ended {
    let c = s.substring(start=start, end=start + 1)
    if ws.contains(c) {
      start = start + 1
    } else {
      trimming = false
    }
  }
  let mut trimming2 = true
  while trimming2 && ended > start {
    let c = s.substring(start=ended - 1, end=ended)
    if ws.contains(c) {
      ended = ended - 1
    } else {
      trimming2 = false
    }
  }
  s.substring(start=start, end=ended)
}

///|
/// 全项目谓词违规总数（跨画板求和）。
fn project_total_violations(project : @core.Project) -> Int {
  let mut total = 0
  for id in project.artboards.keys() {
    match project.artboards.get(id) {
      Some(artboard) => total = total + @core.validate(artboard.doc).length()
      None => ()
    }
  }
  total
}

///|
/// 对由 MBT 重新构建的临时 Project 执行一个人类或 Agent 操作。
///
/// 这个函数不负责持久化。调用方随后必须经 commit_and_render() 把变更写成
/// canonical MBT，再从 MBT 重建画布，避免 Project/命令日志成为第二事实源。
fn apply_mbt_operation(
  project : @core.Project,
  operation : String,
) -> Result[Unit, String] {
  let parts = split_cmd(operation)
  if parts.length() == 0 {
    return Err("mbt_operation_empty")
  }
  match parts[0] {
    "move" =>
      if parts.length() < 5 {
        Err("mbt_operation_usage:move <artboard> <node> <x> <y>")
      } else {
        match
          project.move_node(
            artboard=parts[1],
            node_id=parts[2],
            x=parse_d(parts[3]),
            y=parse_d(parts[4]),
          ) {
          Ok(_) => Ok(())
          Err(error) => Err(error)
        }
      }
    "update" =>
      if parts.length() < 4 {
        Err("mbt_operation_usage:update <artboard> <node> k=v")
      } else {
        let kvs : Array[(String, String)] = []
        let mut i = 3
        while i < parts.length() {
          let kv = parts[i]
          let eq = index_of_str(kv, "=")
          if eq > 0 {
            kvs.push(
              (
                kv.substring(start=0, end=eq),
                @decl.unescape_value(kv.substring(start=eq + 1)),
              ),
            )
          }
          i = i + 1
        }
        match project.edit_node(artboard=parts[1], node_id=parts[2], kvs~) {
          Ok(_) => Ok(())
          Err(error) => Err(error)
        }
      }
    "delete" =>
      if parts.length() < 3 {
        Err("mbt_operation_usage:delete <artboard> <node>")
      } else {
        match project.delete_node(artboard=parts[1], node_id=parts[2]) {
          Ok(_) => Ok(())
          Err(error) => Err(error)
        }
      }
    "copy" =>
      if parts.length() < 4 {
        Err("mbt_operation_usage:copy <artboard> <node> <new_id> [dx] [dy]")
      } else {
        let dx = if parts.length() >= 5 { parse_d(parts[4]) } else { 24.0 }
        let dy = if parts.length() >= 6 { parse_d(parts[5]) } else { 24.0 }
        match
          project.copy_node(
            artboard=parts[1],
            node_id=parts[2],
            new_id=parts[3],
            dx~,
            dy~,
          ) {
          Ok(_) => Ok(())
          Err(error) => Err(error)
          }
      }
    "duplicate" =>
      if parts.length() < 3 {
        Err("mbt_operation_usage:duplicate <artboard> <new_name>")
      } else {
        match project.duplicate_artboard(src=parts[1], new_name=parts[2]) {
          Ok(_) => Ok(())
          Err(error) => Err(error)
        }
      }
    "delete-artboard" =>
      if parts.length() < 2 {
        Err("mbt_operation_usage:delete-artboard <artboard>")
      } else {
        match project.delete_artboard(id=parts[1]) {
          Ok(_) => Ok(())
          Err(error) => Err(error)
        }
      }
    "reorder" =>
      if parts.length() < 4 {
        Err("mbt_operation_usage:reorder <artboard> <node> front|back|up|down")
      } else {
        match
          project.reorder_node(
            artboard=parts[1],
            node_id=parts[2],
            order=parts[3],
          ) {
          Ok(_) => Ok(())
          Err(error) => Err(error)
        }
      }
    "flip" =>
      if parts.length() < 4 {
        Err("mbt_operation_usage:flip <artboard> <node> h|v|both|none")
      } else {
        match
          project.flip_node(artboard=parts[1], node_id=parts[2], axis=parts[3]) {
          Ok(_) => Ok(())
          Err(error) => Err(error)
        }
      }
    "create" =>
      if parts.length() < 2 {
        Err("mbt_operation_usage:create <name> [width] [height]")
      } else {
        let width = if parts.length() >= 3 { parse_d(parts[2]) } else { 390.0 }
        let height = if parts.length() >= 4 { parse_d(parts[3]) } else { 844.0 }
        let _ = project.create_artboard(name=parts[1], width~, height~)
        Ok(())
      }
    "template" =>
      if parts.length() < 3 {
        Err("mbt_operation_usage:template <template> <name> [width] [height]")
      } else {
        let width = if parts.length() >= 4 { parse_d(parts[3]) } else { 0.0 }
        let height = if parts.length() >= 5 { parse_d(parts[4]) } else { 0.0 }
        match
          project.apply_template(
            template_id=parts[1],
            name=parts[2],
            width~,
            height~,
          ) {
          Ok(_) => Ok(())
          Err(error) => Err(error)
        }
      }
    "place" =>
      if parts.length() < 4 {
        Err(
          "mbt_operation_usage:place <artboard> <component> <id> [variant] [x] [y]",
        )
      } else {
        let variant = if parts.length() >= 5 && parts[4] != "-" {
          parts[4]
        } else {
          ""
        }
        let x = if parts.length() >= 6 { parse_d(parts[5]) } else { 0.0 }
        let y = if parts.length() >= 7 { parse_d(parts[6]) } else { 0.0 }
        // 与 cli_exec 的 place 保持一致：尾部 k=v 对为用户组件参数槽
        let kv : Map[String, String] = Map::new()
        let mut kv_error = ""
        for i = 7; i < parts.length(); i = i + 1 {
          match parts[i].find("=") {
            None =>
              if kv_error == "" {
                kv_error = "place_invalid_arg:" + parts[i]
              }
            Some(pos) => {
              let k = parts[i].substring(start=0, end=pos)
              // k=v 值反转义（与 update 路径一致，兑现 split_cmd 注释协议）
              let v = @decl.unescape_value(parts[i].substring(start=pos + 1))
              if k != "" {
                kv.set(k, v)
              }
            }
          }
        }
        if kv_error != "" {
          Err(kv_error)
        } else {
          match
            project.place_component(
              artboard=parts[1],
              component_id=parts[2],
              instance_id=parts[3],
              variant~,
              x~,
              y~,
              args=kv,
            ) {
            Ok(_) => Ok(())
            Err(error) => Err(error)
          }
        }
      }
    "flow" =>
      if parts.length() < 4 {
        Err("mbt_operation_usage:flow <from> <to> <node>")
      } else {
        project.add_flow(from=parts[1], to=parts[2], trigger="tap:" + parts[3])
        project.revision = project.revision + 1
        Ok(())
      }
    "theme" =>
      if parts.length() < 2 {
        Err("mbt_operation_usage:theme <name>")
      } else {
        match project.apply_theme(parts[1]) {
          Ok(_) => Ok(())
          Err(error) => Err(error)
        }
      }
    "fix" =>
      if parts.length() < 2 {
        Err("mbt_operation_usage:fix <artboard>")
      } else {
        match project.auto_fix(artboard=parts[1]) {
          Ok(_) => Ok(())
          Err(error) => Err(error)
        }
      }
    _ => Err("mbt_operation_unsupported:" + parts[0])
  }
}

///|
/// 执行一条 CLI 命令，返回 JSON 结果
pub fn cli_exec(p : @core.Project, line : String) -> String {
  let parts = split_cmd(line)
  if parts.length() == 0 {
    return ""
  }
  match parts[0] {
    "help" => cli_help()
    "list-templates" => @core.list_templates_json()
    "component-compile-b64" => cmd_component_compile(p, parts)
    "component-describe" => cmd_component_describe(p, parts)
    "component-delete" => cmd_component_delete(p, parts)
    "component-export" => cmd_component_export(p, parts)
    "component-import" => cmd_component_import(p, parts)
    "library-snapshot" => cmd_library_snapshot(p)
    "library-restore-b64" => cmd_library_restore(p, parts)
    "list-components" => {
      // 合并视图：内置 + 用户自定义（同权，source 标注来源）
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
              "{\"id\":\"\{@core.json_escape(id)}\",\"kind\":\"user-component\",\"category\":\"\{def.category}\",\"variants\":[\{join_arr(vs)}],\"source\":\"user\",\"description\":\"\{@core.json_escape(def.description)}\"}",
            )
          }
          None => ()
        }
      }
      if user_items.length() == 0 {
        builtin
      } else {
        // builtin 是 [ ... ]：剥掉首尾括号拼接
        let inner = builtin.substring(start=1, end=builtin.length() - 1)
        let sep = if inner == "" { "" } else { "," }
        "[\{inner}\{sep}\{join_arr(user_items)}]"
      }
    }
    "list-tools" => @core.list_tools_json()
    "list-tokens" => p.tokens.to_json()
    "list-themes" => {
      let themes = @core.builtin_themes()
      let items : Array[String] = []
      for t in themes.iter() {
        items.push("\"" + t.name + "\"")
      }
      let j = join_arr(items)
      "[\{j}]"
    }
    "render-mbt-b64" =>
      if parts.length() < 2 {
        cli_err("usage: render-mbt-b64 <utf8_base64_mbt>")
      } else {
        match decode_mbt_b64(parts[1]) {
          Err(error) => cli_err(error)
          Ok(text) =>
            match @decl.load_mbt_project(text) {
              Err(error) => cli_err(error)
              Ok(model) => model.render_json()
            }
        }
      }
    "validate-mbt-b64" =>
      if parts.length() < 2 {
        cli_err("usage: validate-mbt-b64 <utf8_base64_mbt>")
      } else {
        match decode_mbt_b64(parts[1]) {
          Err(error) => cli_err(error)
          Ok(text) =>
            match @decl.load_mbt_project(text) {
              Err(error) => cli_err(error)
              Ok(model) => {
                let entry = @core.json_escape(model.entry)
                let block_kinds = model.document.block_kind_counts()
                "{\"ok\":true,\"entry\":\"\{entry}\",\"revision\":\{model.project.revision},\"blockKinds\":\{block_kinds}}"
              }
            }
        }
      }
    "canonical-mbt-b64" =>
      if parts.length() < 2 {
        cli_err("usage: canonical-mbt-b64 <utf8_base64_mbt>")
      } else {
        match decode_mbt_b64(parts[1]) {
          Err(error) => cli_err(error)
          Ok(text) =>
            match @decl.load_mbt_project(text) {
              Err(error) => cli_err(error)
              Ok(model) => {
                let canonical_b64 = encode_mbt_b64(model.to_mbt())
                "{\"ok\":true,\"mbt_b64\":\"\{canonical_b64}\"}"
              }
            }
        }
      }
    "load-mbt-b64" =>
      if parts.length() < 2 {
        cli_err("usage: load-mbt-b64 <utf8_base64_mbt>")
      } else {
        match decode_mbt_b64(parts[1]) {
          Err(error) => cli_err(error)
          Ok(text) =>
            match @decl.load_mbt_project(text) {
              Err(error) => cli_err(error)
              Ok(model) => {
                let entry = @core.json_escape(model.entry)
                p.replace_with(model.project)
                "{\"ok\":true,\"entry\":\"\{entry}\",\"revision\":\{p.revision}}"
              }
            }
        }
      }
    "export-mbt-human" =>
      match @decl.project_to_mbt(p) {
        Err(error) => cli_err(error)
        Ok(model) =>
          match model.commit_and_render(@core.HumanGate) {
            Err(error) => cli_err(error)
            Ok(rendered) => rendered
          }
      }
    "export-mbt-agent" =>
      match @decl.project_to_mbt(p) {
        Err(error) => cli_err(error)
        Ok(model) =>
          match model.commit_and_render(@core.AgentGate) {
            Err(error) => cli_err(error)
            Ok(rendered) => rendered
          }
      }
    "apply-agent-mbt-b64" =>
      if parts.length() < 2 {
        cli_err("usage: apply-agent-mbt-b64 <utf8_base64_mbt>")
      } else {
        match decode_mbt_b64(parts[1]) {
          Err(error) => cli_err(error)
          Ok(text) =>
            match @decl.load_mbt_project(text) {
              Err(error) => cli_err(error)
              Ok(model) =>
                match model.commit_and_render(@core.AgentGate) {
                  Err(error) => cli_err(error)
                  Ok(rendered) => rendered
                }
            }
        }
      }
    "apply-human-mbt-op-b64" | "apply-agent-mbt-op-b64" =>
      if parts.length() < 3 {
        cli_err(
          "usage: apply-<human|agent>-mbt-op-b64 <utf8_base64_mbt> <utf8_base64_operation>",
        )
      } else {
        let gate = if parts[0] == "apply-human-mbt-op-b64" {
          @core.HumanGate
        } else {
          @core.AgentGate
        }
        match (decode_mbt_b64(parts[1]), decode_mbt_b64(parts[2])) {
          (Ok(text), Ok(operation)) =>
            match @decl.load_mbt_project(text) {
              Err(error) => cli_err(error)
              Ok(model) => {
                // fix 是引擎的还债操作：AgentGate 阻断时，若总违规数相对
                // 操作前严格下降，允许以 HumanGate 提交（剩余记为视觉债），
                // 否则自动修复对带债项目永远不可用。
                let is_fix = mbt_op_is_fix(operation)
                let before = if is_fix {
                  project_total_violations(model.project)
                } else {
                  0
                }
                // 用户组件注册表是会话级状态（component-compile/library-restore
                // 写入 CLI 全局 p）；apply-op 从 MBT 重建的 project 需要注入，
                // 否则该路径 place 用户组件恒 unknown_component。
                for uid in p.user_components.keys() {
                  match p.user_components.get(uid) {
                    Some(udef) => model.project.user_components.set(uid, udef)
                    None => ()
                  }
                }
                match apply_mbt_operation(model.project, operation) {
                  Err(error) => cli_err(error)
                  Ok(_) =>
                    match model.commit_and_render(gate) {
                      Err(error) => {
                        let repaid = is_fix &&
                          project_total_violations(model.project) < before
                        if repaid {
                          match model.commit_and_render(@core.HumanGate) {
                            Err(_) => cli_err(error)
                            Ok(rendered) => rendered
                          }
                        } else {
                          cli_err(error)
                        }
                      }
                      Ok(rendered) => rendered
                    }
                }
              }
            }
          (Err(error), _) => cli_err(error)
          (_, Err(error)) => cli_err(error)
        }
      }
    "create" =>
      if parts.length() < 2 {
        cli_err("usage: create <name> [width] [height]")
      } else {
        let w = if parts.length() >= 3 { parse_d(parts[2]) } else { 390.0 }
        let h = if parts.length() >= 4 { parse_d(parts[3]) } else { 844.0 }
        let name = parts[1]
        let id = p.create_artboard(name~, width=w, height=h)
        "{\"ok\":true,\"artboard\":\"\{id}\",\"w\":\{w},\"h\":\{h}}"
      }
    "template" =>
      if parts.length() < 3 {
        cli_err("usage: template <template_id> <name> [width] [height]")
      } else {
        let w = if parts.length() >= 4 { parse_d(parts[3]) } else { 0.0 }
        let h = if parts.length() >= 5 { parse_d(parts[4]) } else { 0.0 }
        match
          p.apply_template(
            template_id=parts[1],
            name=parts[2],
            width=w,
            height=h,
          ) {
          Ok(id) => "{\"ok\":true,\"artboard\":\"\{id}\"}"
          Err(e) => cli_err(e)
        }
      }
    "place" =>
      if parts.length() < 4 {
        cli_err("usage: place <artboard> <component> <id> [variant] [x] [y]")
      } else {
        let ab = parts[1]
        let comp = parts[2]
        let nid = parts[3]
        // "-" 占位 = 使用组件默认 variant
        let variant = if parts.length() >= 5 && parts[4] != "-" {
          parts[4]
        } else {
          ""
        }
        let x = if parts.length() >= 6 { parse_d(parts[5]) } else { 0.0 }
        let y = if parts.length() >= 7 { parse_d(parts[6]) } else { 0.0 }
        // 尾部 k=v 对：用户组件参数槽传参（内置组件忽略）
        let kv : Map[String, String] = Map::new()
        let mut kv_error = ""
        for i = 7; i < parts.length(); i = i + 1 {
          match parts[i].find("=") {
            None =>
              if kv_error == "" {
                kv_error = "place_invalid_arg:" + parts[i]
              }
            Some(pos) => {
              let k = parts[i].substring(start=0, end=pos)
              // k=v 值反转义（与 update 路径一致，兑现 split_cmd 注释协议）
              let v = @decl.unescape_value(parts[i].substring(start=pos + 1))
              if k != "" {
                kv.set(k, v)
              }
            }
          }
        }
        if kv_error != "" {
          cli_err(kv_error)
        } else {
          match
            p.place_component(
              artboard=ab,
              component_id=comp,
              instance_id=nid,
              variant~,
              x~,
              y~,
              args=kv,
            ) {
            Ok(msg) => msg
            Err(e) => cli_err(e)
          }
        }
      }
    "query" =>
      if parts.length() < 2 {
        cli_err("usage: query <artboard> [kind] [component]")
      } else {
        match p.query_nodes(artboard=parts[1]) {
          Ok(json) => json
          Err(e) => cli_err(e)
        }
      }
    "lint" =>
      if parts.length() < 2 {
        cli_err("usage: lint <artboard>")
      } else {
        match p.lint(artboard=parts[1]) {
          Ok(json) => json
          Err(e) => cli_err(e)
        }
      }
    "critique" =>
      if parts.length() < 2 {
        cli_err("usage: critique <artboard>")
      } else {
        match p.critique(artboard=parts[1]) {
          Ok(json) => json
          Err(e) => cli_err(e)
        }
      }
    "benchmark" => {
      let b = p.benchmark()
      b.to_json()
    }
    "fix" =>
      if parts.length() < 2 {
        cli_err("usage: fix <artboard>")
      } else {
        match p.auto_fix(artboard=parts[1]) {
          Ok(json) => json
          Err(e) => cli_err(e)
        }
      }
    "theme" =>
      if parts.length() < 2 {
        cli_err("usage: theme <name>")
      } else {
        match p.apply_theme(parts[1]) {
          Ok(json) => json
          Err(e) => cli_err(e)
        }
      }
    "infer" =>
      if parts.length() < 2 {
        cli_err("usage: infer <artboard>")
      } else {
        match p.infer_page_type(artboard=parts[1]) {
          Ok(json) => json
          Err(e) => cli_err(e)
        }
      }
    "missing" =>
      if parts.length() < 2 {
        cli_err("usage: missing <artboard>")
      } else {
        match p.infer_missing(artboard=parts[1]) {
          Ok(json) => json
          Err(e) => cli_err(e)
        }
      }
    "export-svg" =>
      if parts.length() < 2 {
        cli_err("usage: export-svg <artboard>")
      } else {
        match p.export_svg(artboard=parts[1]) {
          Ok(svg) =>
            "{\"ok\":true,\"svg_length\":\{svg.length()},\"svg\":\"\{cli_json_escape(svg)}\"}"
          Err(e) => cli_err(e)
        }
      }
    "move" =>
      if parts.length() < 5 {
        cli_err("usage: move <artboard> <node_id> <x> <y>")
      } else {
        match
          p.move_node(
            artboard=parts[1],
            node_id=parts[2],
            x=parse_d(parts[3]),
            y=parse_d(parts[4]),
          ) {
          Ok(json) => json
          Err(e) => cli_err(e)
        }
      }
    "update" =>
      if parts.length() < 4 {
        cli_err("usage: update <artboard> <node_id> k=v [k=v ...]")
      } else {
        let kvs : Array[(String, String)] = []
        let mut i = 3
        while i < parts.length() {
          let kv = parts[i]
          let eq = index_of_str(kv, "=")
          if eq > 0 {
            let k = kv.substring(start=0, end=eq)
            let v = @decl.unescape_value(
              kv.substring(start=eq + 1, end=kv.length()),
            )
            kvs.push((k, v))
          }
          i = i + 1
        }
        if kvs.length() == 0 {
          cli_err("no k=v pairs given")
        } else {
          match p.edit_node(artboard=parts[1], node_id=parts[2], kvs~) {
            Ok(json) => json
            Err(e) => cli_err(e)
          }
        }
      }
    "delete" =>
      if parts.length() < 3 {
        cli_err("usage: delete <artboard> <node_id>")
      } else {
        match p.delete_node(artboard=parts[1], node_id=parts[2]) {
          Ok(json) => json
          Err(e) => cli_err(e)
        }
      }
    "responsive" =>
      if parts.length() < 2 {
        cli_err(
          "usage: responsive <artboard> （生成 _tablet/_desktop 变体）",
        )
      } else {
        match p.generate_responsive(artboard=parts[1]) {
          Ok(json) => json
          Err(e) => cli_err(e)
        }
      }
    "save" => p.to_project_json()
    "load" => {
      // 从原始行截取载荷：split_cmd 的引号支持会剥掉 JSON 的双引号，
      // 必须在分词前截取 "load " 之后的原文
      let raw = line.substring(start=4, end=line.length()).trim().to_string()
      if raw.length() == 0 {
        cli_err("usage: load <project_json> （JSON 需单行）")
      } else {
        match p.from_project_json(raw) {
          Ok(_) => "{\"ok\":true,\"artboards\":\{p.artboards.size()}}"
          Err(e) => cli_err(e)
        }
      }
    }
    "export-decl" =>
      if parts.length() < 2 {
        cli_err("usage: export-decl <artboard> （.mbt.md 声明文本）")
      } else {
        match p.artboards.get(parts[1]) {
          None => cli_err("unknown_artboard: \{parts[1]}")
          Some(ab) => {
            let proto = @decl.from_document(ab.doc)
            let t = proto.to_decl_text()
            "{\"ok\":true,\"decl\":\"\{cli_json_escape(t)}\"}"
          }
        }
      }
    "doc-json" =>
      if parts.length() < 2 {
        cli_err("usage: doc-json <artboard>")
      } else {
        match p.artboards.get(parts[1]) {
          None => cli_err("unknown_artboard: \{parts[1]}")
          Some(ab) =>
            "{\"ok\":true,\"json\":\"\{cli_json_escape(ab.doc.to_json())}\"}"
        }
      }
    "duplicate" =>
      if parts.length() < 3 {
        cli_err("usage: duplicate <src> <new_name>")
      } else {
        match p.duplicate_artboard(src=parts[1], new_name=parts[2]) {
          Ok(json) => json
          Err(e) => cli_err(e)
        }
      }
    "delete-artboard" =>
      if parts.length() < 2 {
        cli_err("usage: delete-artboard <artboard>")
      } else {
        match p.delete_artboard(id=parts[1]) {
          Ok(json) => json
          Err(e) => cli_err(e)
        }
      }
    "flow" =>
      // 建立导航流：flow <from_ab> <to_ab> <node_id>  （tap node → 导航）
      if parts.length() < 4 {
        cli_err("usage: flow <from_artboard> <to_artboard> <node_id>")
      } else {
        let trigger = "tap:\{parts[3]}"
        p.add_flow(from=parts[1], to=parts[2], trigger~)
        "{\"ok\":true,\"flow\":\"\{parts[1]} --tap:\{parts[3]}--> \{parts[2]}\"}"
      }
    "flows" => p.flow_json()
    "group" =>
      if parts.length() < 5 {
        cli_err("usage: group <artboard> <group_id> <n1> <n2> [n3 ...]")
      } else {
        let ids : Array[String] = []
        let mut i = 3
        while i < parts.length() {
          ids.push(parts[i])
          i = i + 1
        }
        match
          p.group_nodes(artboard=parts[1], node_ids=ids, group_id=parts[2]) {
          Ok(json) => json
          Err(e) => cli_err(e)
        }
      }
    "ungroup" =>
      if parts.length() < 3 {
        cli_err("usage: ungroup <artboard> <group_id>")
      } else {
        match p.ungroup_node(artboard=parts[1], group_id=parts[2]) {
          Ok(json) => json
          Err(e) => cli_err(e)
        }
      }
    "align" =>
      if parts.length() < 5 {
        cli_err("usage: align <artboard> <mode> <n1> <n2> [n3 ...]")
      } else {
        let ids : Array[String] = []
        let mut i = 3
        while i < parts.length() {
          ids.push(parts[i])
          i = i + 1
        }
        match p.align_nodes(artboard=parts[1], mode=parts[2], node_ids=ids) {
          Ok(json) => json
          Err(e) => cli_err(e)
        }
      }
    "flip" =>
      if parts.length() < 4 {
        cli_err("usage: flip <artboard> <node> h|v|both|none")
      } else {
        match p.flip_node(artboard=parts[1], node_id=parts[2], axis=parts[3]) {
          Ok(json) => json
          Err(e) => cli_err(e)
        }
      }
    "copy" =>
      if parts.length() < 4 {
        cli_err("usage: copy <artboard> <src> <new_id> [dx] [dy]")
      } else {
        let dx = if parts.length() >= 5 { parse_d(parts[4]) } else { 24.0 }
        let dy = if parts.length() >= 6 { parse_d(parts[5]) } else { 24.0 }
        match
          p.copy_node(
            artboard=parts[1],
            node_id=parts[2],
            new_id=parts[3],
            dx~,
            dy~,
          ) {
          Ok(json) => json
          Err(e) => cli_err(e)
        }
      }
    "resize-canvas" =>
      // Figma Constraints：画板尺寸变更 + 按约束智能重排
      if parts.length() < 4 {
        cli_err("usage: resize-canvas <artboard> <width> <height>")
      } else {
        match
          p.resize_canvas(
            artboard=parts[1],
            width=parse_d(parts[2]),
            height=parse_d(parts[3]),
          ) {
          Ok(json) => json
          Err(e) => cli_err(e)
        }
      }
    "reorder" =>
      // Z 序：reorder <ab> <node> front|back|up|down
      if parts.length() < 4 {
        cli_err("usage: reorder <artboard> <node_id> front|back|up|down")
      } else {
        match
          p.reorder_node(artboard=parts[1], node_id=parts[2], order=parts[3]) {
          Ok(json) => json
          Err(e) => cli_err(e)
        }
      }
    "restyle" =>
      // 主组件传播：restyle <ab> <component_id> k=v ...
      if parts.length() < 4 {
        cli_err("usage: restyle <artboard> <component_id> k=v [k=v ...]")
      } else {
        let kvs : Array[(String, String)] = []
        let mut i = 3
        while i < parts.length() {
          let kv = parts[i]
          let eq = index_of_str(kv, "=")
          if eq > 0 {
            kvs.push(
              (
                kv.substring(start=0, end=eq),
                kv.substring(start=eq + 1, end=kv.length()),
              ),
            )
          }
          i = i + 1
        }
        if kvs.length() == 0 {
          cli_err("no k=v pairs")
        } else {
          match
            p.restyle_component(artboard=parts[1], component_id=parts[2], kvs~) {
            Ok(json) => json
            Err(e) => cli_err(e)
          }
        }
      }
    "tap" =>
      // 播放模式命中：tap <ab> <x> <y> → 状态变更 JSON
      if parts.length() < 4 {
        cli_err("usage: tap <artboard> <x> <y>")
      } else {
        match @core.MoonVizRT::create(p, initial_artboard=parts[1]) {
          Err(e) => cli_err(e)
          Ok(rt) => {
            let changes = rt.handle_event(
              @core.TapEvent(parse_d(parts[2]), parse_d(parts[3])),
            )
            let items : Array[String] = []
            for c in changes.iter() {
              let d = c.describe()
              let (typ, val) = split_change(d)
              items.push("{\"type\":\"\{typ}\",\"value\":\"\{val}\"}")
            }
            "{\"ok\":true,\"artboard\":\"\{parts[1]}\",\"changes\":[\{join_arr(items)}]}"
          }
        }
      }
    "export-artifact" => p.export_artifact(agent_id="cli")
    "spec" =>
      if parts.length() < 2 {
        cli_err("usage: spec <artboard>")
      } else {
        match p.generate_spec(artboard=parts[1]) {
          Ok(spec) => "{\"ok\":true,\"spec_length\":\{spec.length()}}"
          Err(e) => cli_err(e)
        }
      }
    "list" => p.list_artboards_json()
    "exit" | "quit" => ":exit"
    other => cli_err("unknown_command: " + other)
  }
}

///|
fn cli_help() -> String {
  "Commands:\n" +
  "  list-templates       List all page templates\n" +
  "  component-compile-b64 <b64>  Compile & register a user component\n" +
  "  component-describe <id>       Describe a user component (params/usage)\n" +
  "  component-delete <id>         Remove a user component\n" +
  "  component-export <id>         Export as MCF (proprietary format)\n" +
  "  component-import <b64>        Import MCF (full re-validation)\n" +
  "  library-snapshot              Dump user library (host persists)\n" +
  "  library-restore-b64 <b64>...  Restore user library at session start\n" +
  "  list-components      List all UI components (builtin + user)\n" +
  "  list-tools           List all agent tools\n" +
  "  list-tokens          List design tokens\n" +
  "  list-themes          List available themes\n" +
  "  render-mbt-b64 <b64> Render one complete .mbt.md source\n" +
  "  validate-mbt-b64 <b64> Validate one complete .mbt.md source\n" +
  "  canonical-mbt-b64 <b64> Normalize one complete .mbt.md source\n" +
  "  load-mbt-b64 <b64> Load a complete .mbt.md into the temporary engine cache\n" +
  "  export-mbt-human      Canonical MBT after HumanGate validation\n" +
  "  export-mbt-agent      Canonical MBT after AgentGate validation\n" +
  "  apply-agent-mbt-b64 <b64> Validate and commit Agent MBT source\n" +
  "  apply-human-mbt-op-b64 <mbt> <op> Commit a human MBT operation\n" +
  "  apply-agent-mbt-op-b64 <mbt> <op> Commit an Agent MBT operation\n" +
  "  list                 List all artboards\n" +
  "  create <name>        Create empty artboard\n" +
  "  template <id> <name> Apply page template\n" +
  "  place <ab> <comp> <id> [variant] [x] [y]  Place component\n" +
  "  query <ab>           Query nodes in artboard\n" +
  "  lint <ab>            Run design lint\n" +
  "  critique <ab>        Run 8-principle critique\n" +
  "  benchmark            Run performance benchmark\n" +
  "  fix <ab>             Auto-fix violations\n" +
  "  theme <name>         Switch theme\n" +
  "  export-svg <ab>      Export artboard as SVG\n" +
  "  export-artifact      Export .moonviz artifact\n" +
  "  spec <ab>            Generate design spec\n" +
  "  exit                 Exit CLI"
}

///|
fn cli_err(msg : String) -> String {
  "{\"error\":\"\{msg}\"}"
}

///|
fn split_cmd(line : String) -> Array[String] {
  // 支持双引号包裹带空格的参数：update ab n text="Hello World"
  let out : Array[String] = []
  let buf = StringBuilder::new()
  let mut in_q = false
  let mut esc = false
  for c in line.iter() {
    if esc {
      // 保留转义序列原文（含 \" \, 等），由 k=v 解析端统一还原。
      buf.write_char('\\')
      buf.write_char(c)
      esc = false
      continue
    }
    if c == '\\' && in_q {
      esc = true
    } else if c == '"' {
      in_q = !in_q
    } else if (c == ' ' || c == '\t' || c == '\r') && !in_q {
      if buf.to_string().length() > 0 {
        out.push(buf.to_string())
        buf.reset()
      }
    } else {
      buf.write_char(c)
    }
  }
  if buf.to_string().length() > 0 {
    out.push(buf.to_string())
  }
  out
}

///|
/// 把 StateChange.describe 输出（"type:value"）拆成两段
fn split_change(d : String) -> (String, String) {
  let mut i = 0
  let n = d.length()
  while i < n {
    if char_at_str(d, i) == ":" {
      return (d.substring(start=0, end=i), d.substring(start=i + 1, end=n))
    }
    i = i + 1
  }
  (d, "")
}

///|
fn char_at_str(s : String, i : Int) -> String {
  s.substring(start=i, end=i + 1)
}


///|
/// 查找子串首次出现位置；未找到返回 -1
fn index_of_str(s : String, sub : String) -> Int {
  let sl = s.length()
  let subl = sub.length()
  if subl == 0 || subl > sl {
    return -1
  }
  let mut i = 0
  while i + subl <= sl {
    if s.substring(start=i, end=i + subl) == sub {
      return i
    }
    i = i + 1
  }
  -1
}

///|
fn parse_d(s : String) -> Double {
  let mut result = 0.0
  let mut frac = 0.0
  let mut div = 10.0
  let mut seen_dot = false
  let mut neg = false
  for c in s.iter() {
    let code = c.to_int()
    if code == 45 {
      neg = true
    } else if code >= 48 && code <= 57 {
      if seen_dot {
        frac = frac + (code - 48).to_double() / div
        div = div * 10.0
      } else {
        result = result * 10.0 + (code - 48).to_double()
      }
    } else if code == 46 {
      seen_dot = true
    }
  }
  if neg {
    -(result + frac)
  } else {
    result + frac
  }
}

///|
/// JSON 字符串转义（export-svg 内嵌完整 SVG 用）
fn cli_json_escape(s : String) -> String {
  let sb = StringBuilder::new()
  for c in s.iter() {
    match c {
      '"' => sb.write_string("\\\"")
      '\\' => sb.write_string("\\\\")
      '\n' => sb.write_string("\\n")
      '\r' => sb.write_string("\\r")
      '\t' => sb.write_string("\\t")
      _ => {
        let code = c.to_int()
        if code < 32 {
          let hex = "0123456789abcdef"
          let h1 = char_at(hex, code / 16)
          let h2 = char_at(hex, code % 16)
          sb.write_string("\\u00\{h1}\{h2}")
        } else {
          sb.write_char(c)
        }
      }
    }
  }
  sb.to_string()
}

///|
fn char_at(s : String, i : Int) -> String {
  let buf : Array[String] = []
  let mut idx = 0
  for c in s.iter() {
    if idx == i {
      buf.push(c.to_string())
    }
    idx = idx + 1
  }
  if buf.length() > 0 {
    buf[0]
  } else {
    "0"
  }
}

///|
fn join_arr(parts : Array[String]) -> String {
  let sb = StringBuilder::new()
  for i in 0..<parts.length() {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string(parts[i])
  }
  sb.to_string()
}
