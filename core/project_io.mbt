/// 项目持久化：MoonViz Studio 文档格式（.mvz.json）。
///
/// 格式 = 多画板文档集合，每画板内嵌 Document::to_json 树。
/// 与 .mbt.md（声明文本）互为投影：save 存结构真相，export-decl 存声明视图。

///|
/// 整个项目序列化为 JSON（save 用）
pub fn Project::to_project_json(self : Project) -> String {
  let sb = StringBuilder::new()
  sb.write_string("{\"moonviz\":\"studio\",\"version\":2,\"artboards\":[")
  let mut first = true
  for id in self.artboards.keys() {
    match self.artboards.get(id) {
      Some(ab) => {
        if !first {
          sb.write_string(",")
        }
        first = false
        sb.write_string(
          "{\"id\":\"\{json_escape(ab.id)}\",\"name\":\"\{json_escape(ab.name)}\",\"width\":\{ab.width},\"height\":\{ab.height},\"doc\":\{ab.doc.to_json()}}",
        )
      }
      None => ()
    }
  }
  sb.write_string("]}")
  sb.to_string()
}

///|
/// 从项目 JSON 重建 Project（替换当前内容；load 用）
pub fn Project::from_project_json(
  self : Project,
  text : String,
) -> Result[Unit, String] {
  // 逐画板定位 "doc":{...} 子对象并解析
  let art_marker = "\"artboards\":["
  let arr_start = match text.find(art_marker) {
    Some(i) => i + art_marker.length()
    None => return Err("missing_artboards")
  }
  // 清空现有画板
  let ids : Array[String] = []
  for k in self.artboards.keys() {
    ids.push(k)
  }
  for k in ids.iter() {
    self.artboards.remove(k)
  }
  // 逐个解析画板对象
  let body = text.substring(start=arr_start)
  let mut pos = 0
  let n = body.length()
  let mut count = 0
  while pos < n {
    let obj_start = find_obj_start(body, pos)
    match obj_start {
      -1 => break
      os => {
        let end = skip_object2(body, os)
        if end <= os {
          break
        }
        let obj = body.substring(start=os, end~)
        match load_one_artboard(obj) {
          LoadOk(id, meta) => {
            self.artboards.set(id, meta)
            count = count + 1
          }
          LoadErr(_e) => ()
        }
        pos = end
      }
    }
  }
  if count == 0 {
    Err("no_artboards_loaded")
  } else {
    self.revision = self.revision + 1
    Ok(())
  }
}

///|
enum LoadOutcome {
  LoadOk(String, ArtboardMeta)
  LoadErr(String)
}

///|
fn load_one_artboard(obj : String) -> LoadOutcome {
  let id = jstr_field(obj, "id")
  let name = jstr_field(obj, "name")
  let w = jnum_field(obj, "width")
  let h = jnum_field(obj, "height")
  if id == "" {
    return LoadErr("missing_id")
  }
  // 提取 "doc":{...}
  let dm = "\"doc\":"
  let dpos = match obj.find(dm) {
    Some(i) => i + dm.length()
    None => return LoadErr("missing_doc")
  }
  let dstart = match find_obj_from(obj, dpos) {
    Some(i) => i
    None => return LoadErr("missing_doc_obj")
  }
  let dend = skip_object2(obj, dstart)
  let doc_json = obj.substring(start=dstart, end=dend)
  match Document::from_json(doc_json) {
    Ok(doc) => LoadOk(id, { id, name, width: w, height: h, doc })
    Err(e) => LoadErr(e)
  }
}

///|
/// 提取 "key":"value" 的 value（已反转义）
fn jstr_field(obj : String, key : String) -> String {
  let pattern = "\"" + key + "\":\""
  match obj.find(pattern) {
    Some(i) => {
      let rest = obj.substring(start=i + pattern.length())
      match rest.find("\"") {
        Some(e) => unescape_json(rest.substring(start=0, end=e))
        None => ""
      }
    }
    None => ""
  }
}

///|
/// 提取 "key":N 数值
fn jnum_field(obj : String, key : String) -> Double {
  let pattern = "\"" + key + "\":"
  match obj.find(pattern) {
    Some(i) => {
      let rest = obj.substring(start=i + pattern.length())
      let mut num = 0.0
      let mut frac = 0.1
      let mut dot = false
      for c in rest.iter() {
        let code = c.to_int()
        if code >= 48 && code <= 57 {
          let d = (code - 48).to_double()
          if dot {
            num = num + d * frac
            frac = frac * 0.1
          } else {
            num = num * 10.0 + d
          }
        } else if code == 46 && !dot {
          dot = true
        } else {
          break
        }
      }
      num
    }
    None => 0.0
  }
}

///|
/// 从 from 起（含）找第一个 '{'
fn find_obj_from(s : String, from : Int) -> Int? {
  let n = s.length()
  let mut i = from
  while i < n {
    if char_at2(s, i) == "{" {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
fn find_obj_start(s : String, from : Int) -> Int {
  match find_obj_from(s, from) {
    Some(i) => i
    None => -1
  }
}

///|
/// 跳过完整对象文本（含字符串内转义），返回结束下标（不含）
fn skip_object2(s : String, start : Int) -> Int {
  let mut depth = 0
  let mut pos = start
  let mut in_str = false
  let n = s.length()
  while pos < n {
    let c = char_at2(s, pos)
    if in_str {
      if c == "\\" {
        pos = pos + 2
        continue
      }
      if c == "\"" {
        in_str = false
      }
    } else if c == "\"" {
      in_str = true
    } else if c == "{" {
      depth = depth + 1
    } else if c == "}" {
      depth = depth - 1
      if depth == 0 {
        return pos + 1
      }
    }
    pos = pos + 1
  }
  n
}

///|
/// 画板复制（Studio 的 ⌘D）：深拷贝文档并重命名
pub fn Project::duplicate_artboard(
  self : Project,
  src~ : String,
  new_name~ : String,
) -> Result[String, String] {
  match self.artboards.get(src) {
    None => Err("unknown_artboard: \{src}")
    Some(ab) => {
      if self.artboards.contains(new_name) {
        return Err("artboard_exists: \{new_name}")
      }
      let copied = ab.doc.clone()
      let copy : ArtboardMeta = {
        id: new_name,
        name: new_name,
        width: ab.width,
        height: ab.height,
        doc: copied,
      }
      self.artboards.set(new_name, copy)
      self.revision = self.revision + 1
      Ok("{\"ok\":true,\"artboard\":\"\{new_name}\",\"from\":\"\{src}\"}")
    }
  }
}
