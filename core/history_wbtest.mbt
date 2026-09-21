///|
/// history 边界：set_artboard_doc + 时间旅行落回。
test "history：commit/checkout 落回画板文档" {
  let p = Project::new()
  let ab = p.create_artboard(name="a", width=390.0, height=844.0)
  let _ = p.place_component(artboard="a", component_id="button", instance_id="b", x=20.0, y=20.0)
  let doc0 = match p.artboards.get(ab) {
    Some(x) => x.doc.clone()
    None => {
      println("no artboard")
      return
    }
  }
  let h = DesignHistory::new(doc0)
  let _ = p.edit_node(artboard="a", node_id="b", kvs=[("text", "第一版")])
  match p.artboards.get(ab) {
    Some(x) => {
      let _ = h.commit("t", "v1", [], x.doc.clone())
    }
    None => ()
  }
  let _ = doc0
  let _ = p.edit_node(artboard="a", node_id="b", kvs=[("text", "第二版")])
  // 首次 commit 生成 rev1（rev0 为初始快照）
  assert_eq(h.rev(), 1)
  // 时间旅行回 rev1 并落回画板
  match h.checkout(1) {
    Err(e) => fail(e)
    Ok(doc) => {
      match p.set_artboard_doc(artboard=ab, doc) {
        Err(e) => fail(e)
        Ok(_) => {
          let q = match p.query_nodes(artboard=ab) {
            Ok(j) => j
            Err(e) => fail(e)
          }
          assert_true(q.contains("第一版"))
          assert_false(q.contains("第二版"))
        }
      }
    }
  }
}
