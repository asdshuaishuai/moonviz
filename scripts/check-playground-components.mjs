#!/usr/bin/env node
// playground 组件表 ↔ 引擎组件目录 一致性门（AGENTS.md 检查单第 2 条的固化）。
//
// 校验三方键集相等：
//   1. site/playground.html 的 COMP_ZH（中文名表）
//   2. site/playground.html 的 COMP_ICON（卡片图标表）
//   3. 引擎组件目录（core/component.mbt + core/components_ext.mbt 的 m.set("id"））
//
// 漂移即非零退出——不再依赖人工纪律。site/assets/ 下的 wasm 与 tools json
// 仍由 CI 重建，本脚本只做源码级断言，无需构建产物。
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const htmlPath = path.join(root, 'site', 'playground.html');
const catalogFiles = [
  path.join(root, 'core', 'component.mbt'),
  path.join(root, 'core', 'components_ext.mbt'),
];

// 从 html 中抽出 `const NAME={...}` 的对象字面量源码（括号配平 + 字符串状态
// 跟踪，容忍 COMP_ICON 的多行/单引号/未加引号键），交给 JS 求值后取键集。
function extractTableKeys(html, name) {
  const declStart = html.indexOf(`const ${name}=`);
  if (declStart < 0) {
    throw new Error(`playground.html 中找不到 const ${name}`);
  }
  const objStart = html.indexOf('{', declStart);
  let depth = 0;
  let inStr = null;
  let esc = false;
  let i = objStart;
  for (; i < html.length; i++) {
    const c = html[i];
    if (inStr) {
      if (esc) esc = false;
      else if (c === '\\') esc = true;
      else if (c === inStr) inStr = null;
      continue;
    }
    if (c === '"' || c === "'" || c === '`') {
      inStr = c;
      continue;
    }
    if (c === '{') depth++;
    if (c === '}') {
      depth--;
      if (depth === 0) {
        i++;
        break;
      }
    }
  }
  if (depth !== 0) {
    throw new Error(`const ${name} 括号不配平（抽取失败）`);
  }
  const src = html.slice(objStart, i);
  const obj = new Function(`"use strict"; return (${src});`)();
  return Object.keys(obj).sort();
}

// 引擎目录：两个注册文件的 `m.set("<id>"` 即组件注册（目录单一事实源的
// 静态投影；组件目录扩充时 agent_test 的 catalog 断言是权威锚）。
function catalogIds() {
  const ids = new Set();
  for (const f of catalogFiles) {
    const text = fs.readFileSync(f, 'utf8');
    for (const m of text.matchAll(/\bm\.set\(\s*"([a-z0-9_]+)"/g)) {
      ids.add(m[1]);
    }
  }
  return [...ids].sort();
}

function diffKeys(a, b) {
  const sa = new Set(a);
  const sb = new Set(b);
  const onlyA = a.filter((k) => !sb.has(k));
  const onlyB = b.filter((k) => !sa.has(k));
  return { onlyA, onlyB };
}

const html = fs.readFileSync(htmlPath, 'utf8');
const zh = extractTableKeys(html, 'COMP_ZH');
const icon = extractTableKeys(html, 'COMP_ICON');
const catalog = catalogIds();

console.log(
  `COMP_ZH=${zh.length}  COMP_ICON=${icon.length}  catalog=${catalog.length}`,
);

let failed = false;
for (const [label, keys] of [
  ['COMP_ZH ↔ catalog', diffKeys(zh, catalog)],
  ['COMP_ICON ↔ catalog', diffKeys(icon, catalog)],
]) {
  if (keys.onlyA.length || keys.onlyB.length) {
    failed = true;
    if (keys.onlyA.length) console.error(`${label} 多出: ${keys.onlyA.join(', ')}`);
    if (keys.onlyB.length) console.error(`${label} 缺少: ${keys.onlyB.join(', ')}`);
  }
}
if (zh.length !== icon.length || icon.length !== catalog.length) {
  failed = true;
}
if (failed) {
  console.error('playground 组件表与引擎目录不一致（检查单第 2 条）');
  process.exit(1);
}
console.log('playground 组件表与引擎目录一致 ✓');
