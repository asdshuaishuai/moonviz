/**
 * agent.mjs 的 Node 端到端测试（无浏览器依赖）：
 *
 * 前置：一次性准备 esm.sh ?bundle 产物到 /tmp/mv_agent_test/（与生产同一
 * 下载链路），zod/node 垫片按脚本内注释替换绝对路径：
 *   curl -sL 'https://esm.sh/ai@5.0.270/es2022/ai.bundle.mjs' -o ai.bundle.mjs
 *   curl -sL 'https://esm.sh/@ai-sdk/openai-compatible@1.0.57/es2022/openai-compatible.bundle.mjs' -o oc.bundle.mjs
 *   npm pack zod@3.25.76 && tar xzf zod-3.25.76.tgz   # oc/ai bundle 的 /zod 导入改指 package/v3|v4/index.js
 *   buffer.mjs: export {Buffer} from "node:buffer";  process.mjs: export default undefined;
 *   （/node/*.mjs 导入同样改指本地垫片）
 * 运行：node scripts/e2e-agent-node.mjs
 *
 * 流程：本地 bundle 加载 ai@5 + @ai-sdk/openai-compatible（与 esm.sh ?bundle
 * 产物同源），mock 一个 OpenAI wire /chat/completions SSE 服务器，
 * 假引擎 facade 验证工具环 → apply_ops → 假引擎 的真实调用链。
 */
import http from 'node:http';
import { pathToFileURL } from 'node:url';
import assert from 'node:assert/strict';

import { fileURLToPath } from 'node:url';
const AGENT_MJS = fileURLToPath(new URL('../site/assets/agent.mjs', import.meta.url));
const agent = await import(pathToFileURL(AGENT_MJS).href);

// 本地 bundle 映射（模拟 esm.sh ?bundle 产物——同一下载链路拿到的文件）
const HERE = pathToFileURL('/tmp/mv_agent_test/').href;
agent._configureSdk({
  aiUrl: HERE + 'ai.bundle.mjs',
  ocUrl: HERE + 'oc.bundle.mjs',
  importer: u => import(u),
});

// —— mock OpenAI wire 服务器：第 1 轮回 tool_calls(apply_ops)，第 2 轮回文本 ——
let callCount = 0;
const receivedBodies = [];
const server = http.createServer((req, res) => {
  let body = '';
  req.on('data', c => { body += c; });
  req.on('end', () => {
    receivedBodies.push({ auth: req.headers.authorization, body: JSON.parse(body || '{}') });
    callCount++;
    res.writeHead(200, {
      'content-type': 'text/event-stream',
      'cache-control': 'no-cache',
      connection: 'keep-alive',
    });
    const send = obj => res.write(`data: ${JSON.stringify(obj)}\n\n`);
    if (callCount === 1) {
      // tool_call 流：名字 + 参数分片下发（贴近真实 SSE 分片）
      const args = JSON.stringify({ ops: ['place demo button b1 - 20 20 120 44', 'update demo b1 text=确定'] });
      send({ id: 'c1', object: 'chat.completion.chunk', created: 1, model: 'mock', choices: [{ index: 0, delta: { role: 'assistant', tool_calls: [{ index: 0, id: 'call_1', type: 'function', function: { name: 'apply_ops', arguments: '' } }] } }] });
      send({ id: 'c1', object: 'chat.completion.chunk', created: 1, model: 'mock', choices: [{ index: 0, delta: { tool_calls: [{ index: 0, function: { arguments: args } }] } }] });
      send({ id: 'c1', object: 'chat.completion.chunk', created: 1, model: 'mock', choices: [{ index: 0, delta: {}, finish_reason: 'tool_calls' }] });
    } else {
      send({ id: 'c2', object: 'chat.completion.chunk', created: 2, model: 'mock', choices: [{ index: 0, delta: { role: 'assistant', content: '已在画板 demo 放置按钮并写上「确定」。' } }] });
      send({ id: 'c2', object: 'chat.completion.chunk', created: 2, model: 'mock', choices: [{ index: 0, delta: {}, finish_reason: 'stop' }] });
    }
    send({ id: 'x', object: 'chat.completion.chunk', created: 9, model: 'mock', choices: [{ index: 0, delta: {} }], usage: { prompt_tokens: 100, completion_tokens: 20, total_tokens: 120 } });
    res.write('data: [DONE]\n\n');
    res.end();
  });
});
await new Promise(r => server.listen(0, '127.0.0.1', r));
const base = `http://127.0.0.1:${server.address().port}/v1`;

// —— 假引擎 facade（与 wasm 包裹面同形）——
const appliedOps = [];
let sessH = 7;
const engine = {
  get sessH() { return sessH; },
  session_apply_agent: (h, op) => {
    assert.equal(h, 7);
    appliedOps.push(op);
    return { ok: true, revision: appliedOps.length, mbt: 'DOC<' + appliedOps.length + '>' };
  },
  session_query_nodes: (h, a) => ({ artboard: a, nodes: [{ id: 'b1' }] }),
  session_lint: (h, a) => ({ artboard: a, rows: [] }),
  session_list_artboards: h => ({ artboards: [{ id: 'demo', width: 390, height: 844 }] }),
  list_ops: () => [{ op: 'place', usage: 'place <ab> <comp> <id>', description: '放置组件' }],
  list_components: () => [{ id: 'button', default_size: [120, 44], variants: ['default'] }],
};

const opsSeen = [];
const deltas = [];
const result = await agent.runAgentTurn({
  engine,
  providerCfg: { apiKey: 'sk-test', baseURL: base, model: 'mock-model' },
  messages: [{ role: 'user', content: '在画板上放一个写着确定的按钮' }],
  hooks: {
    onOps: results => opsSeen.push(results),
    onDelta: d => deltas.push(d),
    getMbt: () => 'DOC<0>',
    context: () => ({ mbt: 'DOC<0>', artboards: [{ id: 'demo', width: 390, height: 844, nodes: [] }] }),
  },
  signal: new AbortController().signal,
});

// —— 断言：工具环真实走通 ——
assert.deepEqual(appliedOps, ['place demo button b1 - 20 20 120 44', 'update demo b1 text=确定'],
  'apply_ops 应通过 session_apply_agent 落到引擎');
assert.equal(opsSeen.length, 1, 'onOps 回调应触发一次');
assert.equal(result.text.includes('确定'), true, '第二轮文本应回流: ' + result.text);
assert.ok(deltas.length > 0, '流式 delta 应有产出');
assert.ok(receivedBodies.length >= 2, '应有两轮请求');
// 第一轮请求应带 tools 声明 + system
const first = receivedBodies[0].body;
assert.equal(first.tools?.length >= 5, true, '应声明 5 个工具: ' + first.tools?.length);
assert.ok(first.messages.some(m => m.role === 'system' && m.content.includes('place <ab>')), 'system 应含引擎 op 语法');
assert.equal(first.messages[0].role === 'system', true, 'system 在首位');
assert.equal(receivedBodies[0].auth, 'Bearer sk-test', 'BYOK key 应进 Authorization');
assert.ok(first.messages.some(m => m.role === 'user'), '用户消息应存在');
// 第二轮请求应含 tool 结果回灌
const second = receivedBodies[1].body;
const toolMsg = second.messages.find(m => m.role === 'tool');
assert.ok(toolMsg, '工具结果应回灌为 tool 消息');
assert.ok(JSON.stringify(toolMsg.content).includes('applied'), '工具结果应含 applied 清单');
// usage 汇总
assert.ok(result.usage, 'usage 应可得: ' + JSON.stringify(result.usage));

console.log('E2E PASS — 工具环/双轮对话/BYOK 头/system 注入/usage 全部验证');

// —— 目录解析走真实 models.dev（Node fetch 无 CORS 限制）——
try {
  const cat = await agent.fetchCatalog();
  const provs = agent.providerOptions();
  assert.ok(provs.length > 100, '应解析出 100+ 可直连厂商: ' + provs.length);
  const ds = agent.findProvider('deepseek');
  assert.ok(ds && ds.api === 'https://api.deepseek.com', 'deepseek 条目应正确');
  const mm = agent.modelOptions(ds);
  assert.ok(mm.length >= 1 && mm[0].toolCall !== undefined, 'deepseek 模型条目应带能力位');
  console.log('CATALOG PASS — models.dev 真实目录解析', provs.length, '个可直连厂商');
} catch (e) {
  console.log('CATALOG SKIP — 网络不可达:', e.message);
}

server.close();
