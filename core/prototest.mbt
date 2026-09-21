///|
/// 原型测试：断言式验证交互流程。
///
/// Agent（或 CI 管道）可以写"原型测试用例"：
/// ```moonbit nocheck
/// test_rt.tap(160, 422).expect_navigate("home")
/// test_rt.back().expect_artboard("login")
/// test_rt.set_input("email", "test@x.com").expect_value("email", "test@x.com")
/// ```
/// 这让原型变成**可测试的**，而不仅仅是"看起来对的"。
pub(all) struct ProtoTest {
  rt : MoonVizRT
  mut passed : Int
  mut failed : Int
  mut failures : Array[String]
}

///|
/// 创建原型测试运行器
pub fn ProtoTest::create(
  project : Project,
  initial? : String = "",
) -> Result[ProtoTest, String] {
  match MoonVizRT::create(project, initial_artboard=initial) {
    Ok(rt) => Ok({ rt, passed: 0, failed: 0, failures: [] })
    Err(e) => Err(e)
  }
}

// ---------------------------------------------------------------------------
// 断言方法（链式调用风格）
// ---------------------------------------------------------------------------

///|
/// 模拟点击 → 期望导航到指定画板
pub fn ProtoTest::tap_and_expect_navigate(
  self : ProtoTest,
  x : Double,
  y : Double,
  expected : String,
) -> Bool {
  let _ = self.rt.handle_event(TapEvent(x, y))
  let actual = self.rt.current_artboard()
  if actual == expected {
    self.passed = self.passed + 1
    true
  } else {
    self.failed = self.failed + 1
    self.failures.push(
      "tap(\{x.to_int()},\{y.to_int()}) expected \{expected} but got \{actual}",
    )
    false
  }
}

///|
/// 模拟返回 → 期望回到指定画板
pub fn ProtoTest::back_and_expect(self : ProtoTest, expected : String) -> Bool {
  let _ = self.rt.handle_event(KeyEvent("back"))
  let actual = self.rt.current_artboard()
  if actual == expected {
    self.passed = self.passed + 1
    true
  } else {
    self.failed = self.failed + 1
    self.failures.push("back expected \{expected} but got \{actual}")
    false
  }
}

///|
/// 设置输入 → 期望值正确存储
pub fn ProtoTest::set_input_and_expect(
  self : ProtoTest,
  node_id : String,
  value : String,
) -> Bool {
  self.rt.set_input(node_id, value)
  let actual = self.rt.get_input(node_id)
  if actual == value {
    self.passed = self.passed + 1
    true
  } else {
    self.failed = self.failed + 1
    self.failures.push("input \{node_id} expected \{value} but got \{actual}")
    false
  }
}

///|
/// 期望当前画板无违规
pub fn ProtoTest::expect_no_violations(self : ProtoTest) -> Bool {
  let current = self.rt.current_artboard()
  match self.rt.project.artboards.get(current) {
    Some(ab) => {
      let vs = validate(ab.doc)
      if vs.length() == 0 {
        self.passed = self.passed + 1
        true
      } else {
        self.failed = self.failed + 1
        self.failures.push("\{current} has \{vs.length()} violations")
        false
      }
    }
    None => {
      self.failed = self.failed + 1
      false
    }
  }
}

///|
/// 期望渲染计划非空
pub fn ProtoTest::expect_renderable(self : ProtoTest) -> Bool {
  match self.rt.render_plan() {
    Ok(plan) =>
      if plan.commands.length() > 0 {
        self.passed = self.passed + 1
        true
      } else {
        self.failed = self.failed + 1
        self.failures.push("render plan is empty")
        false
      }
    Err(e) => {
      self.failed = self.failed + 1
      self.failures.push("render failed: \{e}")
      false
    }
  }
}

///|
/// 模拟滑动导航
pub fn ProtoTest::swipe_and_expect(
  self : ProtoTest,
  direction : String,
  expected : String,
) -> Bool {
  let _ = self.rt.handle_event(SwipeEvent(direction))
  let actual = self.rt.current_artboard()
  if actual == expected {
    self.passed = self.passed + 1
    true
  } else {
    self.failed = self.failed + 1
    self.failures.push(
      "swipe_\{direction} expected \{expected} but got \{actual}",
    )
    false
  }
}

// ---------------------------------------------------------------------------
// 测试结果
// ---------------------------------------------------------------------------

///|
/// 记录一条语法/解析失败（不计 passed）。
pub fn ProtoTest::reject_invalid(self : ProtoTest, detail : String) -> Bool {
  self.failed = self.failed + 1
  self.failures.push(detail)
  false
}

///|
pub fn ProtoTest::result(self : ProtoTest) -> String {
  let status = if self.failed == 0 { "PASS" } else { "FAIL" }
  let fj = jstr16(self.failures)
  "{\"status\":\"\{status}\",\"passed\":\{self.passed},\"failed\":\{self.failed},\"failures\":\{self.failures.length()},\"detail\":\{fj}}"
}

///|
pub fn ProtoTest::is_pass(self : ProtoTest) -> Bool {
  self.failed == 0 && self.passed > 0
}

///|
fn jstr16(parts : Array[String]) -> String {
  let escaped : Array[String] = []
  for p in parts.iter() {
    escaped.push(json_escape(p))
  }
  let sb = StringBuilder::new()
  sb.write_string("[")
  for i in 0..<escaped.length() {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string("\"\{parts[i]}\"")
  }
  sb.write_string("]")
  sb.to_string()
}

// ---------------------------------------------------------------------------
// 边界入口：测试脚本 DSL（CLI `protest` / MCP `protest` 共用）
// ---------------------------------------------------------------------------

///|
/// 原型测试脚本（分号分隔，可带空行）：
///   `tap:<x>:<y>><expect_board>`    点击 → 期望导航
///   `back><expect_board>`           返回 → 期望画板
///   `swipe:<dir>><expect_board>`    滑动 → 期望画板（dir: left/right/up/down）
///   `set:<node>:<value>`            输入 → 期望回读一致
///   `noviol`                        期望零违规
///   `render`                        期望可渲染
/// 例：`tap:160:422>home; back>login; noviol; render`
pub fn run_protest_script(
  project : Project,
  initial : String,
  script : String,
) -> String {
  match ProtoTest::create(project, initial~) {
    Err(e) => "{\"ok\":false,\"error\":\"\{json_escape(e)}\"}"
    Ok(pt) => {
      let lines : Array[String] = []
      for l in script.split(";").iter() {
        let t = l.trim().to_string()
        if t != "" {
          lines.push(t)
        }
      }
      // 语法错误计入 failed 并写进 failures detail——断言 DSL 的价值在
      // CI 可信，静默跳过会把拼写错误变成"少执行一条"的假 PASS
      for cmd in lines {
        let arrow = match cmd.find(">") {
          Some(i) => i
          None => -1
        }
        if cmd.starts_with("tap:") && arrow > 0 {
          let coords = cmd.substring(start=4, end=arrow).to_string()
          let expect = cmd.substring(start=arrow + 1).to_string()
          let nums : Array[String] = []
          for n in coords.split(":").iter() {
            nums.push(n.to_string())
          }
          if nums.length() >= 2 {
            let _ = pt.tap_and_expect_navigate(
              parse_double(nums[0]), parse_double(nums[1]), expect,
            )
          } else {
            let _ = pt.reject_invalid("tap 断言缺少 >期望画板：\{cmd}")
          }
        } else if cmd.starts_with("back>") {
          let expect = cmd.substring(start=5).to_string()
          let _ = pt.back_and_expect(expect)
        } else if cmd.starts_with("swipe:") && arrow > 0 {
          let dir = cmd.substring(start=6, end=arrow).to_string()
          let expect = cmd.substring(start=arrow + 1).to_string()
          let _ = pt.swipe_and_expect(dir, expect)
        } else if cmd.starts_with("set:") {
          let body = cmd.substring(start=4).to_string()
          let colon = match body.find(":") {
            Some(i) => i
            None => -1
          }
          if colon > 0 {
            let node = body.substring(start=0, end=colon).to_string()
            let value = body.substring(start=colon + 1).to_string()
            let _ = pt.set_input_and_expect(node, value)
          } else {
            let _ = pt.reject_invalid("set 断言缺少 :值：\{cmd}")
          }
        } else if cmd == "noviol" {
          let _ = pt.expect_no_violations()
        } else if cmd == "render" {
          let _ = pt.expect_renderable()
        } else {
          let _ = pt.reject_invalid("未知断言：\{cmd}")
        }
      }
      "{\"ok\":true,\"script_lines\":\{lines.length()},\"result\":\{pt.result()}}"
    }
  }
}
