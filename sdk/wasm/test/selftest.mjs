// WASM SDK 自检：加载包内 wasm，覆盖 version / validate / render 全链路。
// 运行：node sdk/wasm/test/selftest.mjs（需 Node ≥ 22 的 wasm-gc 支持）
import { createEngine } from '../index.mjs';
import assert from 'node:assert/strict';

const engine = await createEngine();

// 1. 版本
const ver = engine.version();
assert.equal(ver.ok, true, 'version 应返回 ok');
assert.equal(ver.engine, 'moonviz', 'engine 名称应为 moonviz');

// 2. 最小合法文档渲染
const mbt = `---
moonbit:
  backend: native
  import:
    - path: moonviz/decl
      alias: decl
moonviz:
  format: visual-document
  revision: 1
  title: WASM Selftest
  entry: a
  artboards:
    - a
  flows: []
---

# WASM Selftest

## a

<!-- moonviz:artboard a -->
\`\`\`mbt
///| @moonviz:visual a
fn visual_a() -> @decl.Prototype {
  let page = @decl.prototype(name="a", width=390, height=844)
  page.add(@decl.generic_node(id="title",component="heading",kind="text",width=@decl.fixed(200),height=@decl.fixed(36),x=95,y=120,text="Hello WASM",fill="none",stroke="none",stroke_width=0,radius=0,opacity=1,font_size=24,text_color="#1A1C1E",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page
}
\`\`\`
`;

const v = engine.validate(mbt);
assert.equal(v.ok, true, 'validate 应通过: ' + JSON.stringify(v));

const r = engine.render(mbt);
assert.equal(r.ok, true, 'render 应成功: ' + JSON.stringify(r));
assert.equal(r.entry, 'a', '入口应为 a');
assert.equal(r.artboards.length, 1, '应有一个画板');
assert.ok(r.artboards[0].svg.includes('<svg'), '画板应含 SVG');
assert.ok(r.artboards[0].svg.includes('Hello WASM'), 'SVG 应包含节点文本');

// 3. 非法文档：render/validate 都应失败但不抛异常
const bad = engine.render('not a document');
assert.equal(bad.ok, false, '非法输入应返回 ok:false');

console.log('WASM SDK selftest passed: version/validate/render all OK');
