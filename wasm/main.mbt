///|
/// MoonViz WASM 边界：把引擎渲染/校验管线暴露给浏览器与 Node 宿主。
///
/// 所有入口均为 String → String 的 JSON 约定：
///   render_mbt(mbt)        → 引擎 RenderResult JSON（画板 SVG + 交互流）
///   validate_mbt(mbt)      → 校验（不渲染）
///   apply_agent_op(mbt,op) → 应用一条 Agent 操作语法并提交（AgentGate），
///   apply_human_op(mbt,op) → 同一语法经 HumanGate（视觉债放行）——画布
///                            拖拽/属性编辑等人类行为走这里
///                            返回 canonical MBT + 渲染结果——与 CLI/Studio
///                            同一操作语法，playground 由此获得实时编辑能力
///   list_templates()       → 模板清单
///   version_info()         → 引擎版本 JSON

///|
pub fn render_mbt(mbt : String) -> String {
  match @decl.load_mbt_project(mbt) {
    Err(error) => "{\"ok\":false,\"error\":\"\{@core.json_escape(error)}\"}"
    Ok(model) => model.render_json()
  }
}

///|
pub fn validate_mbt(mbt : String) -> String {
  match @decl.load_mbt_project(mbt) {
    Err(error) => "{\"ok\":false,\"error\":\"\{@core.json_escape(error)}\"}"
    Ok(model) => {
      let entry = @core.json_escape(model.entry)
      let block_kinds = model.document.block_kind_counts()
      "{\"ok\":true,\"entry\":\"\{entry}\",\"revision\":\{model.project.revision},\"blockKinds\":\{block_kinds}}"
    }
  }
}

///|
pub fn version_info() -> String {
  "{\"ok\":true,\"engine\":\"moonviz\",\"version\":\"\{@core.ENGINE_VERSION}\"}"
}

///|
/// 应用一条 Agent 操作语法（与 CLI 的 apply-agent-mbt-op-b64 同一分发器），
/// 经 AgentGate 提交后返回 canonical MBT + 全量渲染结果。
pub fn apply_agent_op(mbt : String, op : String) -> String {
  match @decl.load_mbt_project(mbt) {
    Err(error) => "{\"ok\":false,\"error\":\"\{@core.json_escape(error)}\"}"
    Ok(model) =>
      match @core.apply_operation(model.project, op) {
        Err(error) => "{\"ok\":false,\"error\":\"\{@core.json_escape(error)}\"}"
        Ok(_) =>
          match model.commit_and_render(@core.AgentGate) {
            Err(error) => "{\"ok\":false,\"error\":\"\{@core.json_escape(error)}\"}"
            Ok(rendered) => rendered
          }
      }
  }
}

///|
/// 导出可交互 HTML 原型（单文件自包含）：节点级 flow/⚡ 词汇表绑定、
/// 组件状态 CSS 变体、导航栈与 toast，全部由 .mbt.md 数据驱动。
pub fn export_html(mbt : String) -> String {
  match @decl.load_mbt_project(mbt) {
    Err(error) => "{\"ok\":false,\"error\":\"\{@core.json_escape(error)}\"}"
    Ok(model) => {
      let html = model.project.export_html()
      "{\"ok\":true,\"html\":\"\{@core.json_escape(html)}\"}"
    }
  }
}

///|
/// 预设组件库清单（playground 组件面板）：52 组件 × 93 变体。
pub fn list_components() -> String {
  @core.list_components_json(@core.builtin_components())
}

///|
/// 预设主题清单：name/display_name/is_dark（前端主题切换器）。
pub fn list_themes() -> String {
  let parts : Array[String] = []
  for t in @core.builtin_themes().iter() {
    let dark = if t.is_dark { "true" } else { "false" }
    parts.push(
      "{\"name\":\"\{t.name}\",\"display_name\":\"\{t.display_name}\",\"is_dark\":\{dark}}",
    )
  }
  let joined = parts.join(",")
  "[\{joined}]"
}

///|
/// 默认设计令牌清单（颜色/间距/圆角/字号）。
pub fn list_tokens() -> String {
  @core.DesignTokens::default().to_json()
}

///|
/// 机器可读 op 面字典：25 条 mutating op（usage/category/gates），
/// 与 CLI list-ops / MCP list_ops 同源（core/agent_api.mbt）。
pub fn list_ops() -> String {
  @core.list_ops_json()
}

///|
/// 模板清单（playground 模板选择器）。
pub fn list_templates() -> String {
  @core.list_templates_json()
}

///|
/// 人类路线：同一操作语法，经 HumanGate 提交（结构违规拒绝、视觉债放行）。
/// 画布直接操作（拖拽移动、属性面板编辑）属于人类行为，应与 Agent 硬门槛
/// 区分——轻微重叠/越界记为视觉债而非拒绝，对齐 Studio 画布的语义。
pub fn apply_human_op(mbt : String, op : String) -> String {
  match @decl.load_mbt_project(mbt) {
    Err(error) => "{\"ok\":false,\"error\":\"\{@core.json_escape(error)}\"}"
    Ok(model) =>
      match @core.apply_operation(model.project, op) {
        Err(error) => "{\"ok\":false,\"error\":\"\{@core.json_escape(error)}\"}"
        Ok(_) =>
          match model.commit_and_render(@core.HumanGate) {
            Err(error) => "{\"ok\":false,\"error\":\"\{@core.json_escape(error)}\"}"
            Ok(rendered) => rendered
          }
      }
  }
}

// ---------------------------------------------------------------------------
// 会话 API：有状态句柄，覆盖 CLI/MCP 的会话型能力（lint/critique/导出 SVG/
// 用户组件/交互运行时等）。句柄为 i32 索引（classic wasm 无法导出 GC ref，
// 索引方案双目标通用）；生产宿主应配对调用 session_close 回收。
// ---------------------------------------------------------------------------

struct WasmSession {
  project : @core.Project
  /// 存活标记：close 置 false（tombstone，槽位不复用以保句柄稳定）。
  /// session_get 对已关槽位返回 None——宿主得到 invalid_session_handle
  /// 而不是在空项目上误操作（issue #4A）。
  alive : Bool
}

let sessions : @ref.Ref[Array[@ref.Ref[WasmSession]]] = Ref::new([])

fn session_store() -> Array[@ref.Ref[WasmSession]] {
  sessions.val
}

///|
/// 打开会话：从 canonical MBT 构建有状态 Project。返回句柄（<0 表示错误）。
pub fn session_open(mbt : String) -> Int {
  match @decl.load_mbt_project(mbt) {
    Err(_) => -1
    Ok(model) => {
      let s : Array[@ref.Ref[WasmSession]] = session_store()
      s.push(Ref::new({ project: model.project, alive: true }))
      s.length() - 1
    }
  }
}

///|
/// 关闭会话：清空内容并置 tombstone（槽位下标不复用，句柄稳定）。
/// 重复 close 同一句柄返回 false。
pub fn session_close(handle : Int) -> Bool {
  let s = session_store()
  if handle >= 0 && handle < s.length() && s[handle].val.alive {
    s[handle] = Ref::new({ project: @core.Project::new(), alive: false })
    true
  } else {
    false
  }
}

///|
/// 当前活跃（已打开且未关闭）会话数：下游测试锁定 session 泄漏用
/// （issue #1）。
pub fn session_count() -> Int {
  session_store().iter().filter(fn(s) { s.val.alive }).count()
}

///|
/// 从 project JSON 快照（session_save 输出）打开会话——save/open 回灌
/// 闭环，跨进程持久化会话不再退化回无状态用法（issue #4B）。
pub fn session_open_project_json(project_json : String) -> Int {
  let p = @core.Project::new()
  match p.from_project_json(project_json) {
    Err(_) => -1
    Ok(_) => {
      let s : Array[@ref.Ref[WasmSession]] = session_store()
      s.push(Ref::new({ project: p, alive: true }))
      s.length() - 1
    }
  }
}

///|
fn session_get(handle : Int) -> @core.Project? {
  let s = session_store()
  if handle >= 0 && handle < s.length() && s[handle].val.alive {
    Some(s[handle].val.project)
  } else {
    None
  }
}

///|
/// 统一信封：只读导出返回 {ok:true, data:<原生 JSON>}，与其它导出的
/// {ok,...} 形态一致——宿主解析不再逐个特判（issue #4C）。
fn sess_json(handle : Int, f : (@core.Project) -> Result[String, String]) -> String {
  match session_get(handle) {
    None => "{\"ok\":false,\"error\":\"invalid_session_handle\"}"
    Some(p) =>
      match f(p) {
        Ok(json) => "{\"ok\":true,\"data\":\{json}}"
        Err(e) => "{\"ok\":false,\"error\":\"\{@core.json_escape(e)}\"}"
      }
  }
}

///|
/// 应用一条 mutating op（AgentGate）。返回 { ok, mbt } —— canonical 文本随
/// 变更回写，宿主需保存供下次 session_open 使用。
pub fn session_apply_agent(handle : Int, op : String) -> String {
  match session_get(handle) {
    None => "{\"ok\":false,\"error\":\"invalid_session_handle\"}"
    Some(p) => {
      // AgentGate 与无状态 apply_agent_op 同一门：克隆会话 Project →
      // 克隆上应用 op → project_gate_check 直接在 Project 上做门检查
      // （不序列化、不重解析、不渲染，issue #6 的三重往返优化）。
      // 通过才把克隆替换回会话槽位（apply 失败不污染会话状态）；
      // 响应的 canonical 文本复用克隆（省第二次序列化）。绕过门检查
      // 会让 Agent 硬门槛在会话面被架空（issue #2）。
      let snapshot = p.clone()
      let flow_check = @decl.mbt_validate_flows(snapshot)
      match flow_check {
        Err(e) => "{\"ok\":false,\"error\":\"\{@core.json_escape(e)}\"}"
        Ok(_) =>
          match @core.apply_operation(snapshot, op) {
            Err(e) => "{\"ok\":false,\"error\":\"\{@core.json_escape(e)}\"}"
            Ok(_) =>
              match @decl.project_gate_check(snapshot, @core.AgentGate) {
                Err(e) => "{\"ok\":false,\"error\":\"\{@core.json_escape(e)}\"}"
                Ok(_) => {
                  p.replace_with(snapshot)
                  match @decl.project_to_mbt(p) {
                    Err(e) =>
                      "{\"ok\":false,\"error\":\"\{@core.json_escape(e)}\"}"
                    Ok(final_model) =>
                      "{\"ok\":true,\"mbt\":\"\{@core.json_escape(final_model.to_mbt())}\"}"
                  }
                }
              }
          }
      }
    }
  }
}



///|
/// 应用一条 mutating op（HumanGate，视觉债放行）。
pub fn session_apply_human(handle : Int, op : String) -> String {
  match session_get(handle) {
    None => "{\"ok\":false,\"error\":\"invalid_session_handle\"}"
    Some(p) => {
      // HumanGate：结构违规拒绝、视觉债放行并计入 debt 字段——
      // 与无状态 apply_human_op 同门（此前实现无门检查，注释失实）
      let snapshot = p.clone()
      match @core.apply_operation(snapshot, op) {
        Err(e) => "{\"ok\":false,\"error\":\"\{@core.json_escape(e)}\"}"
        Ok(_) => {
          match @decl.project_gate_check(snapshot, @core.HumanGate) {
            Err(e) => "{\"ok\":false,\"error\":\"\{@core.json_escape(e)}\"}"
            Ok(debt) => {
              p.replace_with(snapshot)
              match @decl.project_to_mbt(p) {
                Err(e) => "{\"ok\":false,\"error\":\"\{@core.json_escape(e)}\"}"
                Ok(final_model) =>
                  "{\"ok\":true,\"debt\":\{debt},\"mbt\":\"\{@core.json_escape(final_model.to_mbt())}\"}"
              }
            }
          }
        }
      }
    }
  }
}

///|
/// 画板级 SVG 导出（含主题 surface/outline）。
pub fn session_export_svg(handle : Int, artboard : String) -> String {
  sess_json(handle, fn(p) {
    match p.export_svg(artboard~) {
      Ok(svg) =>
        Ok("{\"ok\":true,\"svg\":\"\{@core.json_escape(svg)}\"}")
      Err(e) => Err(e)
    }
  })
}

///|
/// 设计 Lint（对比度/触控/间距/一致性）。
pub fn session_lint(handle : Int, artboard : String) -> String {
  sess_json(handle, fn(p) { p.lint(artboard~) })
}

///|
/// AI 设计批评。
pub fn session_critique(handle : Int, artboard : String) -> String {
  sess_json(handle, fn(p) { p.critique(artboard~) })
}

///|
/// 自动修复（违规严格下降才提交）。
pub fn session_auto_fix(handle : Int, artboard : String) -> String {
  sess_json(handle, fn(p) { p.auto_fix(artboard~) })
}

///|
/// 节点查询。
pub fn session_query_nodes(handle : Int, artboard : String) -> String {
  sess_json(handle, fn(p) { p.query_nodes(artboard~) })
}

///|
/// 画板清单。
pub fn session_list_artboards(handle : Int) -> String {
  sess_json(handle, fn(p) { Ok(p.list_artboards_json()) })
}

///|
/// 导航流清单。
pub fn session_flows(handle : Int) -> String {
  sess_json(handle, fn(p) { Ok(p.flow_json()) })
}

///|
/// 交互清单（⚡ 标记解析）。
pub fn session_interactions(handle : Int, artboard : String) -> String {
  sess_json(handle, fn(p) { p.interactions_json(artboard~) })
}

///|
/// 组件状态清单。
pub fn session_states(handle : Int, artboard : String) -> String {
  sess_json(handle, fn(p) { p.node_states_json(artboard~) })
}

///|
/// 设计标注（开发者交接 Spec）。
pub fn session_spec(handle : Int, artboard : String) -> String {
  sess_json(handle, fn(p) {
    match p.generate_spec(artboard~) {
      Ok(spec) =>
        Ok("{\"ok\":true,\"spec\":\"\{@core.json_escape(spec)}\"}")
      Err(e) => Err(e)
    }
  })
}

///|
/// 自然语言布局意图（居中对齐/垂直排列/等宽/间距 N…）。
pub fn session_constrain(handle : Int, artboard : String, intent : String) -> String {
  sess_json(handle, fn(p) { p.apply_constraint(intent, artboard~) })
}

///|
/// 页面类型推断。
pub fn session_infer_page_type(handle : Int, artboard : String) -> String {
  sess_json(handle, fn(p) { p.infer_page_type(artboard~) })
}

///|
/// 缺失元素推断。
pub fn session_infer_missing(handle : Int, artboard : String) -> String {
  sess_json(handle, fn(p) { p.infer_missing(artboard~) })
}

///|
/// 设计系统反向提取。
pub fn session_extract_design_system(handle : Int, artboard : String) -> String {
  sess_json(handle, fn(p) {
    match p.extract_design_system(artboard~) {
      Ok(ds) => Ok(ds.to_json())
      Err(e) => Err(e)
    }
  })
}

///|
/// 响应式断点变体生成。
pub fn session_generate_responsive(handle : Int, artboard : String) -> String {
  sess_json(handle, fn(p) { p.generate_responsive(artboard~) })
}

///|
/// 性能基准。
pub fn session_benchmark(handle : Int) -> String {
  sess_json(handle, fn(p) { Ok(p.benchmark().to_json()) })
}

///|
/// 项目 JSON 快照（save 语义；session_open 反向恢复需 from_project_json
/// 路线，见 roadmap）。
pub fn session_save(handle : Int) -> String {
  // 统一信封 {ok:true,data:"<project_json 字符串>"}；session_open_project_json
  // 接收 data 里的 project_json 文本
  sess_json(handle, fn(p) { Ok("\"\{@core.json_escape(p.to_project_json())}\"") })
}

///|
/// 用户组件：编译注册（声明为 base64 utf8 文本）。
pub fn session_component_compile_b64(handle : Int, decl_b64 : String) -> String {
  match session_get(handle) {
    None => "{\"ok\":false,\"error\":\"invalid_session_handle\"}"
    Some(p) => {
      let decoded = try? @base64.decode(decl_b64)
      match decoded {
        Err(_) => "{\"ok\":false,\"error\":\"invalid_base64\"}"
        Ok(bytes) => {
          let text = try? @utf8.decode(bytes)
          match text {
            Err(_) => "{\"ok\":false,\"error\":\"invalid_utf8\"}"
            Ok(txt) =>
              match @decl.parse_user_component(txt) {
                Err(e) => "{\"ok\":false,\"error\":\"\{@core.json_escape(e)}\"}"
                Ok(def) => {
                  p.user_components.set(def.id, def)
                  "{\"ok\":true,\"component\":\"\{@core.json_escape(def.id)}\",\"params_count\":\{def.params.length()}}"
                }
              }
          }
        }
      }
    }
  }
}

///|
/// 用户组件库快照（source_b64 列表，持久化用）。
pub fn session_library_snapshot(handle : Int) -> String {
  match session_get(handle) {
    None => "{\"ok\":false,\"error\":\"invalid_session_handle\"}"
    Some(p) => {
      let items : Array[String] = []
      for id in p.user_components.keys() {
        match p.user_components.get(id) {
          Some(def) =>
            items.push(
              "{\"id\":\"\{@core.json_escape(id)}\",\"source_b64\":\"\{encode_mbt_b64(def.source)}\"}",
            )
          None => ()
        }
      }
      let joined = items.join(",")
      "{\"ok\":true,\"op\":\"library-snapshot\",\"count\":\{items.length()},\"components\":[\{joined}]}"
    }
  }
}

///|
/// 交互运行时命中：tap <x> <y> → 状态变更/导航（原型播放语义）。
pub fn session_tap(handle : Int, artboard : String, x : Double, y : Double) -> String {
  match session_get(handle) {
    None => "{\"ok\":false,\"error\":\"invalid_session_handle\"}"
    Some(p) =>
      match @core.MoonVizRT::create(p, initial_artboard=artboard) {
        Err(e) => "{\"ok\":false,\"error\":\"\{@core.json_escape(e)}\"}"
        Ok(rt) => {
          let changes = rt.handle_event(@core.TapEvent(x, y))
          let items : Array[String] = []
          for c in changes.iter() {
            items.push("\"\{@core.json_escape(c.describe())}\"")
          }
          let joined = items.join(",")
          "{\"ok\":true,\"changes\":[\{joined}],\"current\":\"\{@core.json_escape(rt.nav.current)}\"}"
        }
      }
  }
}

///|
fn encode_mbt_b64(text : String) -> String {
  @base64.encode(@utf8.encode(text))
}

// ---------------------------------------------------------------------------
// 写路径：分块字符串槽（classic wasm 双向调用）
//
// classic wasm 无法导出 GC 内部的字符串分配原语（unsafe_make_string_raw
// 不可达），宿主也没有 FFI 写引擎堆的通道。本协议用全公开 API 打通：
//   1. in_reset() / arg_reset()           清空输入槽
//   2. in_push(chunk, n) / arg_push(...)  小端 4 字节小块压入（n=有效字节 1-4）
//   3. render_mbt_in() 等 *_in 变体       用槽内字符串调用既有入口
// UTF-8 解码失败时槽内字符串为空（宿主应保证 in_len 与预期一致）。
// ---------------------------------------------------------------------------

let g_in_bytes : Ref[Array[Byte]] = Ref::new([])
let g_arg_bytes : Ref[Array[Byte]] = Ref::new([])

fn slot_push(slot : Ref[Array[Byte]], chunk : Int, n : Int) -> Unit {
  let count = if n < 1 {
    1
  } else if n > 4 {
    4
  } else {
    n
  }
  let mut i = 0
  while i < count {
    let b = ((chunk >> (i * 8)) & 0xFF).to_byte()
    slot.val.push(b)
    i = i + 1
  }
}

fn slot_string(slot : Ref[Array[Byte]]) -> String {
  @utf8.decode(Bytes::from_iter(slot.val.iter())) catch {
    _ => ""
  }
}

///|
/// 主输入槽：重置（render/validate/apply/session_open 的 MBT 文本）。
pub fn in_reset() -> Unit {
  g_in_bytes.val = []
}

///|
/// 主输入槽：压入一小块（chunk 小端 4 字节，n 为有效字节数 1-4）。
pub fn in_push(chunk : Int, n : Int) -> Unit {
  slot_push(g_in_bytes, chunk, n)
}

///|
/// 主输入槽当前字节数。
pub fn in_len() -> Int {
  g_in_bytes.val.length()
}

///|
/// 辅输入槽：重置（apply_*_op 的 op 文本 / session_* 的 artboard 文本）。
pub fn arg_reset() -> Unit {
  g_arg_bytes.val = []
}

///|
/// 辅输入槽：压入一小块（chunk 小端 4 字节，n 为有效字节数 1-4）。
pub fn arg_push(chunk : Int, n : Int) -> Unit {
  slot_push(g_arg_bytes, chunk, n)
}

///|
/// 辅输入槽当前字节数。
pub fn arg_len() -> Int {
  g_arg_bytes.val.length()
}

///|
/// 用主输入槽渲染（等价 render_mbt）。
pub fn render_mbt_in() -> String {
  render_mbt(slot_string(g_in_bytes))
}

///|
/// 用主输入槽校验（等价 validate_mbt）。
pub fn validate_mbt_in() -> String {
  validate_mbt(slot_string(g_in_bytes))
}

///|
/// 用主输入槽导出交互 HTML（等价 export_html）。
pub fn export_html_in() -> String {
  export_html(slot_string(g_in_bytes))
}

///|
/// Agent 路线操作：主槽 = MBT，辅槽 = op（等价 apply_agent_op）。
pub fn apply_agent_op_in() -> String {
  apply_agent_op(slot_string(g_in_bytes), slot_string(g_arg_bytes))
}

///|
/// Human 路线操作：主槽 = MBT，辅槽 = op（等价 apply_human_op）。
pub fn apply_human_op_in() -> String {
  apply_human_op(slot_string(g_in_bytes), slot_string(g_arg_bytes))
}

///|
/// 用主输入槽打开会话（等价 session_open）。
pub fn session_open_in() -> Int {
  session_open(slot_string(g_in_bytes))
}

///|
/// 会话 Agent 操作：辅槽 = op（等价 session_apply_agent）。
pub fn session_apply_agent_in(handle : Int) -> String {
  session_apply_agent(handle, slot_string(g_arg_bytes))
}

///|
/// 会话 Human 操作：辅槽 = op（等价 session_apply_human）。
pub fn session_apply_human_in(handle : Int) -> String {
  session_apply_human(handle, slot_string(g_arg_bytes))
}

///|
/// 会话只读变体（artboard 经辅槽）：与 session_query_nodes 等一一对应，
/// 供 classic wasm 宿主（无 String 传参能力）调用。
pub fn session_export_svg_in(handle : Int) -> String {
  session_export_svg(handle, slot_string(g_arg_bytes))
}

///|
pub fn session_lint_in(handle : Int) -> String {
  session_lint(handle, slot_string(g_arg_bytes))
}

///|
pub fn session_query_nodes_in(handle : Int) -> String {
  session_query_nodes(handle, slot_string(g_arg_bytes))
}

///|
pub fn session_interactions_in(handle : Int) -> String {
  session_interactions(handle, slot_string(g_arg_bytes))
}

///|
pub fn session_states_in(handle : Int) -> String {
  session_states(handle, slot_string(g_arg_bytes))
}

///|
pub fn session_spec_in(handle : Int) -> String {
  session_spec(handle, slot_string(g_arg_bytes))
}

///|
pub fn session_infer_page_type_in(handle : Int) -> String {
  session_infer_page_type(handle, slot_string(g_arg_bytes))
}

///|
pub fn session_infer_missing_in(handle : Int) -> String {
  session_infer_missing(handle, slot_string(g_arg_bytes))
}

///|
pub fn session_extract_design_system_in(handle : Int) -> String {
  session_extract_design_system(handle, slot_string(g_arg_bytes))
}

///|
pub fn session_generate_responsive_in(handle : Int) -> String {
  session_generate_responsive(handle, slot_string(g_arg_bytes))
}

///|
pub fn session_component_compile_b64_in(handle : Int) -> String {
  session_component_compile_b64(handle, slot_string(g_arg_bytes))
}

///|
/// 第三槽（intent/value 等自由文本）。
let g_arg2_bytes : Ref[Array[Byte]] = Ref::new([])

///|
pub fn arg2_reset() -> Unit {
  g_arg2_bytes.val = []
}

///|
pub fn arg2_push(chunk : Int, n : Int) -> Unit {
  slot_push(g_arg2_bytes, chunk, n)
}

///|
pub fn session_constrain_in(handle : Int) -> String {
  session_constrain(handle, slot_string(g_arg_bytes), slot_string(g_arg2_bytes))
}

///|
pub fn session_tap_in(handle : Int, x : Double, y : Double) -> String {
  session_tap(handle, slot_string(g_arg_bytes), x, y)
}

///|
pub fn session_critique_in(handle : Int) -> String {
  session_critique(handle, slot_string(g_arg_bytes))
}

///|
pub fn session_auto_fix_in(handle : Int) -> String {
  session_auto_fix(handle, slot_string(g_arg_bytes))
}

///|
/// save→open 回灌的 classic 入口：主槽压 project_json 字符串后调用。
pub fn session_open_project_json_in() -> Int {
  session_open_project_json(slot_string(g_in_bytes))
}
