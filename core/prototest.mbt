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
  let sb = StringBuilder::new()
  sb.write_string("[")
  for i in 0..<parts.length() {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string("\"\{parts[i]}\"")
  }
  sb.write_string("]")
  sb.to_string()
}
