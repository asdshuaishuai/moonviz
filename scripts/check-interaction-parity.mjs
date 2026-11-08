#!/usr/bin/env node
// 交互词表一致性断言（P3）：manifest 是单一事实源，三处消费面必须逐项对齐。
//
// 四层守卫：
//   1. manifest 形态：core.interaction_manifest_json() 的 version/triggers/actions；
//   2. core 解析面：trigger_from_spec / action_from_spec 覆盖 manifest 全词表；
//   3. 导出面：export_html 的绑定 switch 与 JS 处理器覆盖 supported 动作
//      （NavigateTo 的绑定 kind 是 "navigate"，与 manifest 的 navigate_to 不同名）；
//   4. playground 选择器：site/playground.html 的触发/动作下拉与 manifest 一致。
//
// 用法：node scripts/check-interaction-parity.mjs [manifest.json]
//   默认读仓库根 moonviz-interactions.json（CI 由
//   `printf 'interaction-manifest\nexit\n' | cli | sed -n 2p` 产出）。
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const manifestPath = process.argv[2] || join(root, 'moonviz-interactions.json');

function die(msg) {
  console.error(`交互词表断言失败：${msg}`);
  process.exit(1);
}

async function readText(path) {
  try {
    return await readFile(path, 'utf8');
  } catch (e) {
    die(`读不到 ${path}：${e.message}`);
  }
}

// ── manifest ──
const manifestRaw = await readText(manifestPath);
let manifest;
try {
  manifest = JSON.parse(manifestRaw);
} catch (e) {
  die(`manifest 不是合法 JSON（${manifestPath}）：${e.message}`);
}
if (manifest.ok !== true) {
  die(`manifest 必须是成功信封（ok:true）：${manifestRaw.slice(0, 120)}`);
}
if (manifest.version !== 2) {
  die(`manifest version 应为 2，实际 ${manifest.version}`);
}
const triggers = manifest.triggers;
const actions = manifest.actions;
if (!Array.isArray(triggers) || triggers.length === 0) {
  die('manifest.triggers 必须是非空数组');
}
if (!Array.isArray(actions) || actions.length === 0) {
  die('manifest.actions 必须是非空数组');
}
const kinds = actions.map((a) => a.kind);
if (kinds.some((k) => typeof k !== 'string' || k === '')) {
  die('manifest.actions[].kind 必须是非空字符串');
}
const dupKinds = kinds.filter((k, i) => kinds.indexOf(k) !== i);
const dupTriggers = triggers.filter((t, i) => triggers.indexOf(t) !== i);
if (dupKinds.length) die(`manifest.actions 有重复 kind：${[...new Set(dupKinds)].join(', ')}`);
if (dupTriggers.length) die(`manifest.triggers 有重复项：${[...new Set(dupTriggers)].join(', ')}`);
console.log(`OK manifest：${triggers.length} triggers / ${kinds.length} actions（version 2）`);

// ── core 解析面 ──
const interactionSrc = await readText(join(root, 'core/interaction.mbt'));
function fnBody(src, name) {
  const start = src.indexOf(`pub fn ${name}`);
  if (start < 0) return '';
  const rest = src.slice(start);
  const next = rest.slice(1).search(/\npub fn |\nfn /);
  return next < 0 ? rest : rest.slice(0, next + 1);
}
const triggerBody = fnBody(interactionSrc, 'trigger_from_spec');
const actionBody = fnBody(interactionSrc, 'action_from_spec');
if (!triggerBody) die('core/interaction.mbt 找不到 pub fn trigger_from_spec');
if (!actionBody) die('core/interaction.mbt 找不到 pub fn action_from_spec');
for (const t of triggers) {
  if (!triggerBody.includes(`"${t}"`)) {
    die(`trigger_from_spec 缺 manifest 触发词：「${t}」`);
  }
}
for (const k of kinds) {
  if (!actionBody.includes(`"${k}"`)) {
    die(`action_from_spec 缺 manifest 动作分支：「${k}」`);
  }
}
console.log('OK core：trigger_from_spec / action_from_spec 覆盖 manifest 全词表');

// ── 导出面 ──
const exportSrc = await readText(join(root, 'core/export.mbt'));
// manifest kind → export switch 的构造器分支
const switchPattern = {
  navigate_to: 'Some(NavigateTo(',
  back: 'Some(Back)',
  toggle_state: 'Some(ToggleState(',
  set_state: 'Some(SetState(',
  set_text: 'Some(SetText(',
  submit_form: 'Some(SubmitForm(',
  show_toast: 'Some(ShowToast(',
  haptic: 'Some(HapticFeedback)',
  play_sound: 'Some(PlaySound(',
};
// manifest kind → 导出 JS 的绑定 kind（NavigateTo 的绑定名是 navigate）
const handlerPattern = {
  navigate_to: "k==='navigate'",
  back: "k==='back'",
  toggle_state: "k==='toggle_state'",
  set_state: "k==='set_state'",
  set_text: "k==='set_text'",
  submit_form: "k==='submit_form'",
  show_toast: "k==='toast'",
  haptic: "k==='haptic'",
  play_sound: "k==='play_sound'",
};
for (const a of actions) {
  const k = a.kind;
  if (typeof a.supported_in_export !== 'boolean') {
    die(`manifest action「${k}」缺 supported_in_export 布尔字段`);
  }
  if (!a.supported_in_export) continue;
  const sp = switchPattern[k];
  if (!sp) die(`一致性脚本未登记动作「${k}」的导出 switch 模式（manifest 新增动作需同步脚本）`);
  if (!exportSrc.includes(sp)) {
    die(`export_html 绑定 switch 缺「${k}」分支（期望 ${sp}）`);
  }
  const hp = handlerPattern[k];
  if (!hp || !exportSrc.includes(hp)) {
    die(`export_html JS 处理器缺「${k}」分支（期望 ${hp}）`);
  }
}
console.log('OK export：supported 动作在绑定 switch 与 JS 处理器均有分支');

// ── playground 选择器 ──
const playground = await readText(join(root, 'site/playground.html'));
const trigStart = playground.indexOf('id="ix-trig"');
if (trigStart < 0) die('site/playground.html 找不到 id="ix-trig" 触发下拉');
const trigArrStart = playground.indexOf('[', trigStart);
const trigArrEnd = playground.indexOf(']', trigArrStart);
if (trigArrStart < 0 || trigArrEnd < 0) die('playground 触发下拉数组无法解析');
const trigSection = playground.slice(trigArrStart, trigArrEnd + 1);
const pgTriggers = [...trigSection.matchAll(/'([a-z_]+)'/g)].map((m) => m[1]);

const kindStart = playground.indexOf('id="ix-kind"');
if (kindStart < 0) die('site/playground.html 找不到 id="ix-kind" 动作下拉');
const kindEnd = playground.indexOf('</select>', kindStart);
if (kindEnd < 0) die('playground 动作下拉未闭合');
const kindSection = playground.slice(kindStart, kindEnd);
const pgKinds = [...kindSection.matchAll(/value="([a-z_]+)"/g)].map((m) => m[1]);

function compareSets(label, actual, expected) {
  const a = [...new Set(actual)].sort();
  const e = [...new Set(expected)].sort();
  const missing = e.filter((x) => !a.includes(x));
  const extra = a.filter((x) => !e.includes(x));
  if (missing.length || extra.length) {
    die(
      `${label} 与 manifest 不一致` +
        (missing.length ? `；缺：${missing.join(', ')}` : '') +
        (extra.length ? `；多：${extra.join(', ')}` : ''),
    );
  }
  if (actual.length !== a.length) {
    die(`${label} 有重复项：${actual.join(', ')}`);
  }
}
compareSets('playground 触发下拉', pgTriggers, triggers);
compareSets('playground 动作下拉', pgKinds, kinds);
console.log(
  `OK playground：触发下拉 ${pgTriggers.length} 项 / 动作下拉 ${pgKinds.length} 项与 manifest 一致`,
);

console.log('交互词表一致性通过：manifest ⇄ core ⇄ export ⇄ playground');
