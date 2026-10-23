#!/usr/bin/env node
// 双产物 ABI 布局断言（issue #8 + 双清单锁步回归锚）：导出清单以 wasm/moon.pkg
// 的 classic exports 段为准（单一事实源，AGENTS.md 规则 3），防手工清单漂移。
// 三层守卫：
//   1. required 烘焙同步：required 数组必须与 moon.pkg classic 段逐字一致
//      （忘烘焙即红，issue #8 一类的手改漂移）。
//   2. 双清单锁步：moon.pkg 的 wasm 与 wasm-gc exports 段必须逐字相等
//      （ea27dbf 后 gc 段曾漏 session_generate_in：classic 73 / gc 72）。
//   3. 产物实测：classic 全量断言（0 imports + 字符串判别式）；wasm-gc 按
//      js-string builtins 实例化后做 required 子集断言 + version 冒烟。
// 用法：node scripts/check-wasm-abi.mjs [路径...]
//   无参数 = 默认双路径（classic + wasm-gc 各自全检）；
//   传路径 = 只检指定产物（CI 现行用法），按 imports 自动判别产物形态。
import { readFile } from 'node:fs/promises';

const required = ["render_mbt", "validate_mbt", "apply_agent_op", "apply_human_op", "list_templates", "list_components", "list_themes", "list_tokens", "list_ops", "export_html", "version_info", "in_reset", "in_push", "in_len", "arg_reset", "arg_push", "arg_len", "render_mbt_in", "validate_mbt_in", "export_html_in", "apply_agent_op_in", "apply_human_op_in", "session_open_in", "session_apply_agent_in", "session_apply_human_in", "session_export_svg_in", "session_lint_in", "session_query_nodes_in", "session_interactions_in", "session_states_in", "session_spec_in", "session_infer_page_type_in", "session_infer_missing_in", "session_extract_design_system_in", "session_generate_responsive_in", "session_generate_in", "session_component_compile_b64_in", "session_constrain_in", "session_tap_in", "session_critique_in", "session_auto_fix_in", "session_open_project_json_in", "arg2_reset", "arg2_push", "session_apply_agent", "session_apply_human", "session_auto_fix", "session_benchmark", "session_close", "session_count", "session_open_project_json", "session_component_compile_b64", "session_constrain", "session_critique", "session_export_svg", "session_extract_design_system", "session_flows", "session_history", "session_history_in", "session_generate_responsive", "session_generate", "session_infer_missing", "session_infer_page_type", "session_interactions", "session_library_snapshot", "session_lint", "session_list_artboards", "session_open", "session_query_nodes", "session_save", "session_spec", "session_states", "session_tap"];

function die(msg) {
  console.error(`ABI 断言失败：${msg}`);
  process.exit(1);
}

// ── 守卫 1+2：moon_pkg 源级断言（不依赖产物是否已构建）──
const pkgSrc = await readFile(new URL('../wasm/moon.pkg', import.meta.url), 'utf8');
// 锚定 link 键（"wasm"/"wasm-gc"）归属清单，而非按段出现顺序取——键重排
// 时守卫 1 的「classic 独有」标签才不会张冠李戴；[^{}] 限定段体不出所在
// 对象，防止跨段误配。
const sections = [...pkgSrc.matchAll(/"(wasm|wasm-gc)"\s*:\s*\{[^{}]*?"exports"\s*:\s*\[([^\]]*)\]/g)]
  .map(m => {
    const key = m[1];
    // raw-token 总数 vs 解析条目数一致性断言：导出名若含字符类之外的字
    // 符，窄正则会静默丢弃——锁步两边同过滤仍相等、required 烘焙比对看
    // 不到、守卫 3 只查子集，三层守卫全部失明，故必须就地失衡即红。
    const raw = [...m[2].matchAll(/"([^"]+)"/g)].map(x => x[1]);
    const bad = raw.filter(n => !/^[A-Za-z0-9_]+$/.test(n));
    if (bad.length) {
      die(`moon.pkg ${key} 段 raw token ${raw.length} 个 / 解析仅得 ${raw.length - bad.length} 个：` +
        `导出名含 [A-Za-z0-9_] 之外字符会被静默丢弃：${bad.join(', ')}`);
    }
    return [key, raw];
  });
const byKey = Object.fromEntries(sections);
if (sections.length !== 2 || !byKey.wasm || !byKey['wasm-gc']) {
  die(`moon.pkg 解析到 ${sections.length} 个 exports 段（键：${sections.map(([k]) => k).join(', ') || '无'}；应恰为 wasm / wasm-gc 各 1）`);
}
const classicList = byKey.wasm;
const gcList = byKey['wasm-gc'];
const bakeMiss = classicList.filter(n => !required.includes(n));
const bakeExtra = required.filter(n => !classicList.includes(n));
if (bakeMiss.length || bakeExtra.length) {
  die(
    'required 烘焙与 moon.pkg classic 段漂移（单一事实源被手改？从 moon.pkg 重新烘焙 required）' +
    (bakeMiss.length ? `；classic 独有：${bakeMiss.join(', ')}` : '') +
    (bakeExtra.length ? `；required 独有：${bakeExtra.join(', ')}` : ''),
  );
}
if (classicList.length !== gcList.length || classicList.some((n, i) => n !== gcList[i])) {
  const diff = [...new Set([...classicList, ...gcList])].filter(n => !classicList.includes(n) || !gcList.includes(n));
  die(`moon.pkg 双清单失锁步：classic ${classicList.length} / wasm-gc ${gcList.length}（差异：${diff.join(', ')}）——两段必须逐字相等`);
}
console.log(`清单锁步通过：moon.pkg classic/gc 各 ${classicList.length} 导出逐字相等，required 烘焙同步`);

// ── 守卫 3：产物实测 ──
const paths = process.argv.slice(2);
if (paths.length === 0) {
  paths.push('_build/wasm/release/build/wasm/wasm.wasm', '_build/wasm-gc/release/build/wasm/wasm.wasm');
}

const GC_OPTS = { builtins: ['js-string'], importedStringConstants: '_' };

for (const path of paths) {
  let bytes;
  try {
    bytes = await readFile(path);
  } catch (e) {
    die(`读不到产物 ${path}（先 moon build --release --target <wasm|wasm-gc> wasm）：${e.message}`);
  }
  // classic 产物无特殊导入可直接编译；wasm-gc（js-string builtins）必须带
  // builtins 编译选项——编译失败即按 gc 形态重试，imports 数判别产物形态。
  let mod, withBuiltins = false;
  try {
    mod = new WebAssembly.Module(new Uint8Array(bytes));
  } catch {
    try {
      mod = new WebAssembly.Module(new Uint8Array(bytes), GC_OPTS);
      withBuiltins = true;
    } catch (e) {
      die(`产物编译失败（gc 侧需 wasm-gc + js-string builtins 运行时，Node ≥ 24 / Chrome 119+）：${e.message}`);
    }
  }
  let imports = WebAssembly.Module.imports(mod);
  if (imports.length !== 0 && !withBuiltins) {
    try {
      mod = new WebAssembly.Module(new Uint8Array(bytes), GC_OPTS);
      withBuiltins = true;
      imports = WebAssembly.Module.imports(mod);
    } catch (e) {
      die(`产物带 imports 且 builtins 形态编译失败：${e.message}`);
    }
  }
  const names = WebAssembly.Module.exports(mod).map(e => e.name);
  const missing = required.filter(n => !names.includes(n));
  if (missing.length) {
    die(`${path}：缺导出 ${missing.join(', ')}`);
  }
  // 形态判别用 memory 导出而非 imports 数：js-string builtins 形态下
  // 特殊导入会被引擎特化，Module.imports 可能恒为 0（Node 24 实测）；
  // classic 配置 export-memory-name 恒有 memory，wasm-gc 恒无。
  if (!withBuiltins && imports.length === 0) {
    if (!names.includes('memory')) {
      die(`${path}：0 imports 但无 memory 导出，产物形态异常`);
    }
    // classic 全量断言（issue #8 原逻辑）
    const inst = new WebAssembly.Instance(mod, {});
    const X = inst.exports;
    // 判别式实测：version_info 返回的字符串对象应满足双布局判别之一，
    // 且解码出 {"ok":true,"version":...}
    const dv = new DataView(X.memory.buffer);
    const ptr = X.version_info();
    const w0 = dv.getUint32(ptr, true);
    const w1 = dv.getUint32(ptr + 4, true);
    let len, dataAt;
    if ((w1 >>> 28) === 0x5) { len = w1 & 0x0FFFFFFF; dataAt = ptr + 8; }
    else {
      // 静态字面量布局：len@ptr-4，数据@ptr
      len = dv.getUint32(ptr - 4, true); dataAt = ptr;
      if (len === 0 || len > 1000000) {
        die(`${path}：无法识别的字符串对象布局 w0=${w0.toString(16)} w1=${w1.toString(16)} len@-4=${len}`);
      }
    }
    const units = [];
    for (let i = 0; i < len; i++) units.push(dv.getUint16(dataAt + i * 2, true));
    const s = String.fromCharCode(...units);
    if (!s.includes('"version"')) {
      die(`${path}：解码结果异常 ${s.slice(0, 60)}`);
    }
    console.log(`ABI 断言通过（classic）：${path} ${names.length} 导出 / 0 imports / 字符串判别式 OK / ${len} 码元`);
  } else {
    // wasm-gc：required 子集断言 + version 冒烟。无 opts 编译成功但带普通
    // imports 的先按 gc 形态重编译，否则实例化会因 imports 未解析而失败。
    if (!withBuiltins) {
      mod = new WebAssembly.Module(new Uint8Array(bytes), GC_OPTS);
    }
    // 实例化兜底：Module.imports 仍如实上报 builtins imports 的引擎（未
    // 特化 js-string）会在此抛未捕获异常，与编译失败同款给可读诊断。
    let inst;
    try {
      inst = new WebAssembly.Instance(mod, {});
    } catch (e) {
      die(`${path}：wasm-gc 实例化失败（gc 侧需 wasm-gc + js-string builtins 运行时，Node ≥ 24 / Chrome 119+）：${e.message}`);
    }
    const s = inst.exports.version_info();
    if (typeof s !== 'string' || !s.includes('"version"')) {
      die(`${path}：version_info 未返回含 "version" 的字符串（js-string 判别失败：${typeof s}）`);
    }
    console.log(`ABI 断言通过（wasm-gc）：${path} required ${required.length} 项全导出（实导 ${names.length}）/ version 判别式 OK`);
  }
}
