#!/usr/bin/env node
// classic wasm ABI 布局断言（issue #8）：导出清单 / 0 imports /
// 字符串对象判别式实测。用法：node scripts/check-wasm-abi.mjs <wasm路径>
import { readFile } from 'node:fs/promises';

const path = process.argv[2] ?? '_build/wasm/release/build/wasm/wasm.wasm';
const bytes = await readFile(path);
const mod = new WebAssembly.Module(new Uint8Array(bytes));
const inst = new WebAssembly.Instance(mod, {});
const X = inst.exports;

const names = WebAssembly.Module.exports(mod).map(e => e.name);
// 全量导出清单（除 memory 外全部必须存在）——契约文档 docs/wasm-abi.md
const required = [
  'version_info', 'render_mbt', 'validate_mbt',
  'apply_agent_op', 'apply_human_op', 'export_html', 'list_ops',
  'list_templates', 'list_components', 'list_themes', 'list_tokens',
  'session_open', 'session_close', 'session_count',
  'session_open_project_json', 'session_save',
  'session_apply_agent_in', 'session_apply_human_in',
  'session_query_nodes_in', 'session_lint_in', 'session_critique_in',
  'session_auto_fix_in', 'session_export_svg_in', 'session_interactions_in',
  'session_states_in', 'session_spec_in', 'session_flows',
  'session_constrain_in', 'session_infer_page_type_in',
  'session_infer_missing_in', 'session_extract_design_system_in',
  'session_generate_responsive_in', 'session_component_compile_b64_in',
  'session_tap_in', 'session_benchmark',
  'in_reset', 'in_push', 'in_len', 'arg_reset', 'arg_push', 'arg_len',
  'arg2_reset', 'arg2_push', 'render_mbt_in', 'validate_mbt_in',
  'export_html_in', 'session_open_project_json_in',
];
const missing = required.filter(n => !names.includes(n));
if (missing.length) {
  console.error(`ABI 断言失败：缺导出 ${missing.join(', ')}`);
  process.exit(1);
}
if (WebAssembly.Module.imports(mod).length !== 0) {
  console.error('ABI 断言失败：classic 产物不应有 imports');
  process.exit(1);
}

// 判别式实测：version_info 返回的字符串对象应满足双布局判别之一，
// 且解码出 {"ok":true,"version":...}
const dv = new DataView(X.memory.buffer);
const ptr = X.version_info();
const w0 = dv.getUint32(ptr, true);
const w1 = dv.getUint32(ptr + 4, true);
let len, dataAt;
if ((w1 >>> 28) === 0x5) { len = w1 & 0x0FFFFFFF; dataAt = ptr + 8; }
else {
  // 静态字面量布局：len@ptr-4，数据@ptr（判别：ptr-4 处 u32 合理且 < 1M）
  len = dv.getUint32(ptr - 4, true); dataAt = ptr;
  if (len === 0 || len > 1_000_000) {
    console.error(`ABI 断言失败：无法识别的字符串对象布局 w0=${w0.toString(16)} w1=${w1.toString(16)} len@-4=${len}`);
    process.exit(1);
  }
}
const units = [];
for (let i = 0; i < len; i++) units.push(dv.getUint16(dataAt + i * 2, true));
const s = String.fromCharCode(...units);
if (!s.includes('"version"')) {
  console.error(`ABI 断言失败：解码结果异常 ${s.slice(0, 60)}`);
  process.exit(1);
}
console.log(`ABI 断言通过：${names.length} 导出 / 0 imports / 字符串判别式 OK / ${len} 码元`);
