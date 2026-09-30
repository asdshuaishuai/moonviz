/**
 * Playground AI Agent 浏览器端到端测试（Playwright + Chromium）：
 *
 * 前置：npm i playwright && npx playwright install chromium；先构建并部署
 * 最新 wasm（moon build --target wasm-gc --release 后复制到 site/assets/moonviz.wasm，
 * 脚本内 SITE 路径按本机调整）。models.dev 与 LLM 端点均被拦截 mock，可离线跑。
 * 运行：node scripts/e2e-agent-playground.mjs
 *
 * 流程：
 *   1. 静态服务 site/，加载 playground.html（真 wasm-gc 引擎 + 真 esm.sh ai-sdk CDN）
 *   2. 拦截 models.dev（离线稳定）与 LLM /chat/completions（mock SSE 双轮）
 *   3. 断言：抽屉打开 → 目录装载 → mock Agent 工具环 → 画布出现新节点 →
 *      助手文本回流 → 会话失同步修复（后续 Human 操作不丢 Agent 的修改）
 */
import { chromium } from 'playwright';
import http from 'node:http';
import { readFileSync, existsSync } from 'node:fs';
import { join, extname } from 'node:path';
import assert from 'node:assert/strict';

import { fileURLToPath } from 'node:url';
const SITE = fileURLToPath(new URL('../site', import.meta.url));
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm', '.svg': 'image/svg+xml', '.css': 'text/css' };

// —— 静态服务（同源加载 wasm / agent.mjs）——
const staticSrv = http.createServer((req, res) => {
  let p = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  if (p === '/') p = '/playground.html';
  const f = join(SITE, p);
  if (!existsSync(f)) { res.writeHead(404); res.end('nf'); return; }
  res.writeHead(200, { 'content-type': MIME[extname(f)] || 'application/octet-stream' });
  res.end(readFileSync(f));
});
await new Promise(r => staticSrv.listen(0, '127.0.0.1', r));
const BASE = `http://127.0.0.1:${staticSrv.address().port}`;

// —— mock models.dev（最小 deepseek 条目）——
const MODELS_DEV = {
  deepseek: {
    id: 'deepseek', name: 'DeepSeek', npm: '@ai-sdk/openai-compatible',
    api: 'https://api.deepseek.com',
    models: {
      'deepseek-chat': { id: 'deepseek-chat', name: 'DeepSeek Chat', tool_call: true, reasoning: false, limit: { context: 128000 }, cost: { input: 0.27, output: 1.1 } },
      'deepseek-reasoner': { id: 'deepseek-reasoner', name: 'DeepSeek Reasoner', tool_call: true, reasoning: true, limit: { context: 128000 } },
    },
  },
  moonshotai: {
    id: 'moonshotai', name: 'Moonshot AI', api: 'https://api.moonshot.ai/v1',
    models: { 'kimi-k3': { id: 'kimi-k3', name: 'Kimi K3', tool_call: true } },
  },
};

// —— mock LLM：第 1 轮 tool_calls(apply_ops)，第 2 轮文本 ——
let llmCalls = 0;
const sse = (res, chunks) => {
  res.writeHead(200, { 'content-type': 'text/event-stream', 'access-control-allow-origin': '*' });
  for (const c of chunks) res.write(`data: ${JSON.stringify(c)}\n\n`);
  res.write('data: [DONE]\n\n');
  res.end();
};
const chunk = (id, delta, finish) => ({ id, object: 'chat.completion.chunk', created: 1, model: 'mock', choices: [{ index: 0, delta, finish_reason: finish ?? null }] });

const browser = await chromium.launch();
const page = await browser.newPage();
const errors = [];
page.on('pageerror', e => errors.push(String(e)));
page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });

// playwright route + SSE 需要手写 response body —— 上面的占位换成完整实现：
await page.unroute('**/mock-llm/v1/chat/completions');
await page.route('**/mock-llm/v1/chat/completions', async r => {
  llmCalls++;
  if (llmCalls === 1) {
    const args = JSON.stringify({ ops: ['place demo button ai_btn - 40 740 140 44', 'update demo ai_btn text=来自AI'] });
    const body = [
      chunk('c1', { role: 'assistant', tool_calls: [{ index: 0, id: 'call_1', type: 'function', function: { name: 'apply_ops', arguments: '' } }] }),
      chunk('c1', { tool_calls: [{ index: 0, function: { arguments: args } }] }),
      chunk('c1', {}, 'tool_calls'),
      { id: 'c1', object: 'chat.completion.chunk', created: 1, model: 'mock', choices: [{ index: 0, delta: {} }], usage: { prompt_tokens: 120, completion_tokens: 30, total_tokens: 150 } },
    ].map(c => `data: ${JSON.stringify(c)}`).join('\n\n') + '\n\ndata: [DONE]\n\n';
    await r.fulfill({ status: 200, contentType: 'text/event-stream', body });
  } else {
    const body = [
      chunk('c2', { role: 'assistant', content: '已在 demo 画板放置按钮「来自AI」。' }),
      chunk('c2', {}, 'stop'),
    ].map(c => `data: ${JSON.stringify(c)}`).join('\n\n') + '\n\ndata: [DONE]\n\n';
    await r.fulfill({ status: 200, contentType: 'text/event-stream', body });
  }
});

await page.goto(BASE + '/playground.html');
// 引擎启动（wasm-gc + js-string）
await page.waitForSelector('#bootlayer.off', { timeout: 30000 });
await page.waitForFunction(() => document.querySelector('#ver')?.textContent.includes('engine'), { timeout: 10000 });
console.log('BOOT OK —', await page.textContent('#ver'));

// 打开 AI 抽屉 → 目录装载
await page.click('#ai-btn');
await page.waitForFunction(() => document.querySelector('#ai-dot')?.classList.contains('ok'), { timeout: 15000 });
console.log('CATALOG OK —', await page.textContent('#ai-hdinfo'));
const provCount = await page.locator('#ai-prov option').count();
assert.ok(provCount >= 3, '厂商选项应含 deepseek/moonshotai/自定义: ' + provCount);

// 配置（deepseek → mock endpoint）
await page.selectOption('#ai-prov', 'deepseek');
await page.fill('#ai-model', 'deepseek-chat');
const baseVal = await page.inputValue('#ai-base');
assert.equal(baseVal, 'https://api.deepseek.com', 'baseURL 应从目录自动填充: ' + baseVal);
await page.fill('#ai-base', BASE + '/mock-llm/v1');
await page.fill('#ai-key', 'sk-browser-test');
// 持久化断言
const saved = await page.evaluate(() => localStorage.getItem('mv_ai_key_deepseek'));
assert.equal(saved, 'sk-browser-test', 'Key 应落 localStorage');

// 发送 → 工具环 → 画布更新
await page.fill('#ai-input', '在画板上放一个写着「来自AI」的按钮');
await page.click('#ai-send');
try {
  await page.waitForFunction(() => {
    const rows = [...document.querySelectorAll('#ai-log .ai-ops .ok')];
    return rows.length >= 2;
  }, { timeout: 60000 });
} catch (e) {
  console.log('--- DEBUG ai-log ---');
  console.log(await page.evaluate(() => document.getElementById('ai-log').innerText.slice(0, 1500)));
  console.log('--- DEBUG page errors ---');
  console.log(errors.join('\n---\n').slice(0, 2000));
  throw e;
}
console.log('TOOLRING OK —', await page.locator('#ai-log .ai-ops .ok').count(), 'ops applied');
// 助手文本
await page.waitForFunction(() => document.querySelector('#ai-log .ai-a:not(.thinking)')?.textContent.includes('来自AI'), { timeout: 30000 });
console.log('ASSISTANT OK');
// 画布真实出现 Agent 放的节点（wasm 渲染联动）
await page.waitForFunction(() => document.querySelector('#canvas svg #n_ai_btn') !== null, { timeout: 15000 });
console.log('CANVAS OK — n_ai_btn 已渲染');
// 规范面板同步（setSrc 生效）
const srcHas = await page.evaluate(() => document.getElementById('src').value.includes('ai_btn'));
assert.ok(srcHas, '源码面板应含 ai_btn（canonical 同步）');

// 会话失同步回归：无状态 op 控制台改动 → 会话路径 Human 操作，两者必须共存
// （若无 resyncSession 修复，humanOp 的 sr.mbt 来自陈旧会话，会静默回滚控制台改动）
await page.click('#tab-ops');
await page.fill('#ops', 'update demo ai_btn text=AI改名');
await page.press('#ops', 'Enter');
await page.waitForFunction(() => document.getElementById('src').value.includes('AI改名'), { timeout: 15000 });
await page.click('#canvas svg #n_ai_btn rect');            // 选中 Agent 放的节点
await page.evaluate(() => window.hideNode());               // HumanGate 会话路径隐藏
await page.waitForFunction(() => document.getElementById('src').value.includes('visible=false'), { timeout: 15000 });
const both = await page.evaluate(() => {
  const s = document.getElementById('src').value;
  return s.includes('AI改名') && /ai_btn[\s\S]{0,400}visible=false/.test(s);
});
assert.ok(both, '控制台改动与会话路径改动应共存（失同步修复）');
console.log('DESYNC-FIX OK — 无状态 op 与会话 Human 操作共存');

// Key 被拒（401 路径）：换坏 key 断言错误提示
const errBody = JSON.stringify({ error: { message: 'Incorrect API key provided', type: 'invalid_request_error' } });
await page.unroute('**/mock-llm/v1/chat/completions');
await page.route('**/mock-llm/v1/chat/completions', r => r.fulfill({ status: 401, contentType: 'application/json', body: errBody }));
await page.fill('#ai-input', '再来一个');
await page.click('#ai-send');
try {
  await page.waitForFunction(() => document.querySelector('#ai-log .ai-err')?.textContent.includes('Key 无效'), { timeout: 30000 });
} catch (e) {
  console.log('--- DEBUG err-log ---');
  console.log(await page.evaluate(() => document.getElementById('ai-log').innerText.slice(-600)));
  console.log('--- page console/errors ---');
  console.log(errors.join('\n').slice(0, 2500));
  throw e;
}
console.log('ERROR-PATH OK — 401 → 友好提示');

// 页面无未捕获错误（过滤 CDN 与 mock 相关噪声）
const real = errors.filter(e => !/net::|Failed to fetch|models\.dev|esm\.sh|status of 401|AI_APICallError/.test(e));
assert.equal(real.length, 0, '页面不应有未捕获错误: ' + real.join(' | '));

console.log('BROWSER E2E PASS — 全链路（抽屉/目录/BYOK/工具环/画布联动/错误路径）验证通过');
await browser.close();
staticSrv.close();
process.exit(0);
