// WASM SDK 自检：加载包内 wasm，覆盖 version / validate / render 全链路。
// 运行：node sdk/wasm/test/selftest.mjs（需 Node ≥ 22 的 wasm-gc 支持）
import { createEngine } from '../index.mjs';
import assert from 'node:assert/strict';

const engine = await createEngine();

// 1. 版本
const ver = engine.version();
assert.equal(ver.ok, true, 'version 应返回 ok');
assert.equal(ver.engine, 'moonviz', 'engine 名称应为 moonviz');

// 基线同步硬断言（AGENTS.md 元规则）：包内 dist wasm 的引擎自报版本必须
// 等于本包版本——dist 忘了随 release 更新时这里直接 fail，而不是静默发旧引擎。
const pkgVersion = JSON.parse(await import('node:fs/promises').then(fs => fs.readFile(new URL('../package.json', import.meta.url), 'utf8'))).version;
assert.equal(ver.version, pkgVersion, `dist wasm 引擎版本(${ver.version})必须等于包版本(${pkgVersion})——dist 未随基线同步`);

// 2. 组件目录基线（0.1.4 = 65 组件 × 115 变体）；list_components 返回裸数组
const comps = engine.listComponents();
const catalog = Array.isArray(comps) ? comps : comps.components;
assert.ok(Array.isArray(catalog) && catalog.length >= 65, `组件目录应 ≥65（当前 ${catalog?.length}）——dist wasm 疑似旧构建`);
const allIds = new Set(catalog.map(c => c.id));
for (const need of ['multi_select', 'command_palette', 'bento_grid', 'resize_handle']) {
  assert.ok(allIds.has(need), `新组件 ${need} 不在目录中——dist wasm 疑似 0.1.3 前旧构建`);
}

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
