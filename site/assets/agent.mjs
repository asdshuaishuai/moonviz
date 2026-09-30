/**
 * MoonViz Playground — 在线 AI Agent 运行时（BYOK）
 * =================================================
 * deepOrca 模式的浏览器版：
 *   - models.dev 目录做「数据骨干」——厂商清单 / API base URL / 模型能力，
 *     运行时拉取，不在本文件里硬编码任何厂商；
 *   - Vercel AI SDK（ai@5 + @ai-sdk/openai-compatible@1，esm.sh CDN ?bundle）
 *     做调用实现——用户自选厂商 + 自带 API Key（BYOK，仅存浏览器本地）；
 *   - 工具环：Agent 通过 apply_ops / query_nodes / lint / list_artboards /
 *     get_source 五个工具驱动 wasm 引擎（与 CLI / MCP 同一 op 语法、同一
 *     AgentGate 硬门槛）。引擎 facade 由宿主注入，本模块不直接持有 wasm。
 *
 * 边界：本模块只做编排；所有文档变更必须经引擎（双门纪律不变）。
 */

// —— CDN 常量：版本对齐已验证（ai@5 期望 specificationVersion:"v2"，
//    openai-compatible@1.0.57 产出 v2 模型；?bundle 双份拷贝走结构兼容，
//    AI SDK 对 provider 只做属性检查，无 instanceof）——
let AI_SDK_URL = 'https://esm.sh/ai@5.0.270?bundle';
let OPENAI_COMPAT_URL = 'https://esm.sh/@ai-sdk/openai-compatible@1.0.57?bundle';
let MODELS_DEV_URL = 'https://models.dev/api.json';

// —— 目录偏好：置顶常用厂商（其余按名称排序追加，全部来自 models.dev）——
const PINNED_PROVIDERS = [
  'deepseek', 'moonshotai', 'alibaba-cn', 'zhipu', 'minimax', 'siliconflow',
  'openrouter', 'together', 'groq', 'xai', 'ollama', 'lmstudio',
];

/** esm.sh 模块懒加载缓存（首次 Agent 使用才拉取——画布本体不依赖 CDN）。 */
let aiMods = null;

// —— 测试缝：Node 端到端测试把 importer 换成本地文件加载（网络 import 在
//    Node 需实验旗标）；生产路径永远是原生动态 import —— 
let importModule = u => import(u);

/**
 * 测试/宿主覆盖缝（下划线前缀 = 非公开 API）：
 * 换 CDN 源、换目录地址、换模块加载器（Node 测试用本地 bundle）。
 */
export function _configureSdk({ aiUrl, ocUrl, modelsDevUrl, importer } = {}) {
  if (aiUrl) AI_SDK_URL = aiUrl;
  if (ocUrl) OPENAI_COMPAT_URL = ocUrl;
  if (modelsDevUrl) MODELS_DEV_URL = modelsDevUrl;
  if (importer) importModule = importer;
  aiMods = null;
}

export async function loadAiSdk() {
  if (aiMods) return aiMods;
  const [ai, oc] = await Promise.all([
    importModule(AI_SDK_URL),
    importModule(OPENAI_COMPAT_URL),
  ]);
  aiMods = { ai, oc };
  return aiMods;
}

// ---------------------------------------------------------------------------
// models.dev 目录
// ---------------------------------------------------------------------------

let catalog = null;          // 原始 {providerId: {...}}
export function catalogProviders() { return catalog; }

/**
 * 拉取 models.dev 目录。失败抛错（UI 显示重试；「自定义厂商」路径不依赖目录）。
 */
export async function fetchCatalog() {
  const res = await fetch(MODELS_DEV_URL, { cache: 'no-cache' });
  if (!res.ok) throw new Error('models.dev 目录加载失败（HTTP ' + res.status + '）');
  catalog = await res.json();
  return catalog;
}

/**
 * 目录 → 选择器条目：只留声明了 api base URL 的厂商（openai-compatible 可直连）。
 * 返回 [{id,name,api,models}]，置顶偏好在前，其余按名称排序。
 */
export function providerOptions() {
  if (!catalog) return [];
  const out = [];
  for (const [id, p] of Object.entries(catalog)) {
    if (!p || typeof p !== 'object') continue;
    if (!p.api || typeof p.api !== 'string') continue;
    const models = p.models && typeof p.models === 'object' ? p.models : {};
    if (!Object.keys(models).length) continue;
    out.push({ id, name: p.name || id, api: p.api, models });
  }
  out.sort((a, b) => {
    const ia = PINNED_PROVIDERS.indexOf(a.id), ib = PINNED_PROVIDERS.indexOf(b.id);
    if (ia >= 0 || ib >= 0) {
      if (ia < 0) return 1;
      if (ib < 0) return -1;
      if (ia !== ib) return ia - ib;
    }
    return a.name.localeCompare(b.name);
  });
  return out;
}

/**
 * 厂商模型 → 选择器条目：tool_call 在前，其余按名称排序。
 * 返回 [{id,name,toolCall,reasoning,context,costIn,costOut}]。
 */
export function modelOptions(provider) {
  if (!provider || !provider.models) return [];
  const out = [];
  for (const [id, m] of Object.entries(provider.models)) {
    if (!m || typeof m !== 'object') continue;
    const cost = m.cost || {};
    out.push({
      id,
      name: m.name || id,
      toolCall: m.tool_call === true,
      reasoning: m.reasoning === true,
      context: m.limit && m.limit.context,
      costIn: cost.input,
      costOut: cost.output,
    });
  }
  out.sort((a, b) => (b.toolCall - a.toolCall) || a.id.localeCompare(b.id));
  return out;
}

export function findProvider(pid) {
  return providerOptions().find(p => p.id === pid) || null;
}

// ---------------------------------------------------------------------------
// BYOK 持久化（localStorage；仅浏览器本地，无服务端）
// ---------------------------------------------------------------------------

const LS = {
  key: pid => 'mv_ai_key_' + pid,
  base: pid => 'mv_ai_base_' + pid,
  model: pid => 'mv_ai_model_' + pid,
};

export function loadCfg(providerId) {
  if (!providerId) return null;
  return {
    apiKey: localStorage.getItem(LS.key(providerId)) || '',
    baseURL: localStorage.getItem(LS.base(providerId)) || '',
    model: localStorage.getItem(LS.model(providerId)) || '',
  };
}

export function saveCfg(providerId, { apiKey, baseURL, model }) {
  try {
    if (apiKey) localStorage.setItem(LS.key(providerId), apiKey); else localStorage.removeItem(LS.key(providerId));
    if (baseURL) localStorage.setItem(LS.base(providerId), baseURL); else localStorage.removeItem(LS.base(providerId));
    if (model) localStorage.setItem(LS.model(providerId), model); else localStorage.removeItem(LS.model(providerId));
  } catch (e) { /* 隐私模式等 localStorage 不可用：仅本次会话生效 */ }
}

// ---------------------------------------------------------------------------
// Provider 工厂（openai-compatible；Anthropic 浏览器直连需要豁免头）
// ---------------------------------------------------------------------------

function browserHeaders(baseURL) {
  const h = {};
  try {
    if (/anthropic\.com/i.test(new URL(baseURL).host)) {
      h['anthropic-dangerous-direct-browser-access'] = 'true';
    }
  } catch (e) { /* baseURL 非法时由 provider 报错 */ }
  return h;
}

/** 创建 openai-compatible provider。baseURL 缺 scheme 时自动补 https://。 */
export async function makeProvider({ apiKey, baseURL }) {
  const { oc } = await loadAiSdk();
  let url = (baseURL || '').trim();
  if (url && !/^https?:\/\//i.test(url)) url = 'https://' + url;
  url = url.replace(/\/+$/, '');
  if (!url) throw new Error('baseURL 未配置');
  if (!apiKey) throw new Error('API Key 未配置');
  return oc.createOpenAICompatible({
    name: 'moonviz',
    apiKey,
    baseURL: url,
    includeUsage: true,
    headers: browserHeaders(url),
  });
}

// ---------------------------------------------------------------------------
// 系统提示词：与引擎运行时同源生成（op 语法 / 组件目录 / 画板状态）
// ---------------------------------------------------------------------------

export function buildSystemPrompt(engine, { mbt, artboards }) {
  const parts = [];
  parts.push(
    '你是 MoonViz 原型设计引擎的 AI Agent。用户用中文/英文描述需求，你通过工具调用修改 .mbt.md 视觉文档。\n' +
    '核心纪律：\n' +
    '- 一切变更必须通过 apply_ops 工具提交 op 数组；每条 op 走 AgentGate 硬门槛，被拒（"error" 带 mbt_gate_block 等前缀）时读错误信息修正后重试，不要重复同一 op。\n' +
    '- 完成或被连续拒绝 3 次后，用一句中文总结结果（改了什么 / 剩余问题）。\n' +
    '- 设计原则：画板内布局、兄弟不重叠（装饰层除外，可声明 overlay=true）、间距均匀、字号成阶（24/16/14/12）、主色克制。\n' +
    '- 文本组件（body_text/heading）不带 w 放置时宽度自适应画板；按钮等组件 fit=auto 可让文字自适应不溢出。\n'
  );
  try {
    const ops = engine.list_ops();
    if (Array.isArray(ops) && ops.length) {
      parts.push('## op 语法（与引擎版本同步，勿自创）\n' +
        ops.map(o => `- ${o.usage} — ${o.description}`).join('\n'));
    }
  } catch (e) { /* 无 op 表：只靠 usage 提示 */ }
  try {
    const comps = engine.list_components();
    if (Array.isArray(comps) && comps.length) {
      parts.push('## 组件目录（component · 默认尺寸 · variants）\n' +
        comps.map(c => `- ${c.id} ${c.default_size ? c.default_size[0] + 'x' + c.default_size[1] : ''} [${(c.variants || []).join(',')}]`).join('\n'));
    }
  } catch (e) { /* 目录缺失不阻塞 */ }
  if (Array.isArray(artboards) && artboards.length) {
    parts.push('## 画板状态（当前文档）\n' +
      artboards.map(a =>
        `- 画板 ${a.id} ${a.width}x${a.height}：` +
        (a.nodes || []).map(n => {
          const r = n.rect || {};
          return `${n.id}(${n.component || n.kind} ${Math.round(r.x ?? 0)},${Math.round(r.y ?? 0)} ${Math.round(r.w ?? 0)}x${Math.round(r.h ?? 0)}${n.text ? ' "' + String(n.text).slice(0, 16) + '"' : ''})`;
        }).join(' ')
      ).join('\n'));
  }
  if (mbt) {
    parts.push('## 当前 .mbt.md（get_source 可再取最新）\n```\n' + mbt.slice(0, 6000) + (mbt.length > 6000 ? '\n…(截断)' : '') + '\n```');
  }
  return parts.join('\n\n');
}

// ---------------------------------------------------------------------------
// 工具环
// ---------------------------------------------------------------------------

function engineResult(engine, mbt, op) {
  // 设计模式且有活动会话：走 session_apply_agent（有状态，省整文档重建）；
  // 响应含 canonical mbt，宿主用它刷新源码面板与画布。
  if (typeof engine.session_apply_agent === 'function' && engine.sessH >= 0) {
    return { r: engine.session_apply_agent(engine.sessH, op), session: true };
  }
  return { r: engine.apply_agent_op(mbt, op), session: false };
}

export function makeTools(engine, hooks) {
  const { ai } = aiMods;
  const { jsonSchema, tool } = ai;
  const onOps = hooks && hooks.onOps;
  const getMbt = hooks.getMbt;

  const applyOps = async ({ ops }) => {
    if (!Array.isArray(ops) || !ops.length) return { error: 'ops 为空' };
    const results = [];
    let latest = getMbt();
    for (const op of ops) {
      if (typeof op !== 'string' || !op.trim()) continue;
      const { r, session } = engineResult(engine, latest, op.trim());
      results.push({ op, ok: r.ok === true, error: r.error, revision: r.revision });
      if (r.ok === true && r.mbt) latest = r.mbt;
    }
    if (onOps) onOps(results, latest);
    const failed = results.filter(x => !x.ok);
    return {
      applied: results.filter(x => x.ok).map(x => x.op),
      rejected: failed,
      hint: failed.length ? '读 rejected[].error 修正参数后重试；unknown_id 类错误可先用 query_nodes 查真实 id' : '全部通过',
    };
  };

  return {
    apply_ops: tool({
      description: '提交一批 MoonViz op（与 CLI 语法一致）修改文档。一次一批效率更高；顺序执行，前者失败不影响后续。',
      inputSchema: jsonSchema({
        type: 'object',
        properties: { ops: { type: 'array', items: { type: 'string' }, description: 'op 字符串数组，如 ["place demo button btn1 - 20 20 120 44", "update demo btn1 text=确定"]' } },
        required: ['ops'],
      }),
      execute: applyOps,
    }),
    query_nodes: tool({
      description: '查询某画板的全部节点（id/组件/几何/样式）。',
      inputSchema: jsonSchema({
        type: 'object',
        properties: { artboard: { type: 'string', description: '画板 id' } },
        required: ['artboard'],
      }),
      execute: async ({ artboard }) => {
        if (typeof engine.session_query_nodes === 'function' && engine.sessH >= 0) {
          return engine.session_query_nodes(engine.sessH, artboard);
        }
        return { error: '会话不可用' };
      },
    }),
    lint: tool({
      description: '对画板跑设计 lint（违规清单），用于自查。',
      inputSchema: jsonSchema({
        type: 'object',
        properties: { artboard: { type: 'string' } },
        required: ['artboard'],
      }),
      execute: async ({ artboard }) => {
        if (typeof engine.session_lint === 'function' && engine.sessH >= 0) {
          return engine.session_lint(engine.sessH, artboard);
        }
        return { error: '会话不可用' };
      },
    }),
    list_artboards: tool({
      description: '列出全部画板（id/尺寸）。',
      inputSchema: jsonSchema({ type: 'object', properties: {} }),
      execute: async () => {
        if (typeof engine.session_list_artboards === 'function' && engine.sessH >= 0) {
          return engine.session_list_artboards(engine.sessH);
        }
        return { error: '会话不可用' };
      },
    }),
    get_source: tool({
      description: '读取当前 .mbt.md 源码（canonical 事实源）。',
      inputSchema: jsonSchema({ type: 'object', properties: {} }),
      execute: async () => ({ mbt: getMbt() }),
    }),
  };
}

// ---------------------------------------------------------------------------
// Agent 主循环
// ---------------------------------------------------------------------------

/**
 * @param {object} opts
 * @param {object} opts.engine      宿主注入的 wasm facade（本模块只调上面
 *                                  用到的方法；sessH 由宿主保持最新）
 * @param {object} opts.providerCfg {apiKey, baseURL, model}
 * @param {Array}  opts.messages    [{role:'user'|'assistant', content}] 历史
 * @param {object} opts.hooks       {onOps(results,mbt), onDelta(text), getMbt()}
 * @param {AbortSignal} opts.signal
 * @returns {Promise<{text, steps, usage}>}
 */
export async function runAgentTurn({ engine, providerCfg, messages, hooks, signal }) {
  const { ai } = await loadAiSdk();
  const provider = await makeProvider(providerCfg);
  const model = provider(providerCfg.model);
  const tools = makeTools(engine, hooks);
  const system = buildSystemPrompt(engine, hooks.context ? hooks.context() : {});

  // fullStream + onError：textStream 会静默吞掉 provider 错误（401/CORS 只表现
  // 为空文本）；error part 不一定出现在 fullStream（create 阶段的 4xx 走
  // onError 回调），两条路都接住，宿主才能给出可行动的提示。
  let streamError = null;
  const result = ai.streamText({
    model,
    system,
    messages,
    tools,
    stopWhen: ai.stepCountIs(16),
    abortSignal: signal,
    onError: ({ error }) => { streamError = error; },
  });
  for await (const part of result.fullStream) {
    if (part.type === 'text-delta') {
      if (hooks && hooks.onDelta) hooks.onDelta(part.text);
    } else if (part.type === 'error') {
      throw part.error;
    }
  }
  let text;
  try {
    text = await result.text;
  } catch (e) {
    throw streamError || e;
  }
  if (streamError) throw streamError;
  let usage = null;
  try { usage = await result.totalUsage; } catch (e) { /* 部分网关不回 usage */ }
  return { text, usage };
}
