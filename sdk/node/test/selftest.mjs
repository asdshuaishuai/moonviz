// SDK 自检（无外部依赖）：覆盖 模板 → 操作 → 交互流 → 导出 → 渲染 全链路。
// 运行：cd moonviz && node sdk/node/test/selftest.mjs
import { MoonViz, Project, DDP } from '../src/index.js';
import assert from 'node:assert/strict';

const engine = new MoonViz({ moonvizDir: new URL('../../../', import.meta.url).pathname });

// 1. 会话执行
const rs = await engine.run(['list-templates']);
assert.ok(Array.isArray(rs) && rs.length > 0, 'list-templates 应返回数组');

// 2. 项目构建
const project = new Project(engine);
project.template('login', 't_login', 390, 844);
project.template('dashboard', 't_home', 390, 844);
project.update('t_login', 'welcome_title', { text: '欢迎回来' });
project.flow('t_login', 't_home', 'login_btn');
const mbt = await project.exportHuman();
assert.ok(mbt.includes('moonviz:artboard t_login'), '导出应包含 t_login 画板标记');
assert.ok(mbt.includes('flows:') && mbt.includes('tap:login_btn'), '导出应包含交互流');

// 3. 引擎重渲染（AgentGate）
const render = await engine.render(mbt);
assert.equal(render.ok, true, '渲染应成功');
assert.equal(render.artboards.length, 2, '应有两个画板');
assert.equal(render.flows.length, 1, '应有一条交互流');

// 4. DDP 免密切换（DDP2）
const noPass = await DDP.encrypt(mbt, '');
assert.equal(noPass.mode, 'DDP2', '空密码应产出 DDP2 免密容器');
const back = await DDP.decrypt(noPass.bytes);
assert.equal(back.mbt, mbt, 'DDP2 往返应字节一致');

// 5. DDP 加密（DDP1）
const locked = await DDP.encrypt(mbt, 'test-password');
assert.equal(locked.mode, 'DDP1', '带密码应产出 DDP1 加密容器');
const open = await DDP.decrypt(locked.bytes, 'test-password');
assert.equal(open.mbt, mbt, 'DDP1 往返应字节一致');
await assert.rejects(() => DDP.decrypt(locked.bytes, 'wrong'), /认证|auth/i, '错密码应认证失败');

// 6) 能力对齐面：字典 / 清单 / 导出
const tools = await engine.tools();
assert.ok(Array.isArray(tools) && tools.length >= 47, 'tools() 应返回 47+ 工具');
assert.ok(tools.some(t => t.name === 'list_ops' && t.inputSchema), 'tools() 应含 list_ops 且带 schema');
const ops = await engine.ops();
assert.ok(Array.isArray(ops) && ops.length === 25, 'ops() 应返回 25 条 op');
const themes = await engine.listThemes();
assert.ok(Array.isArray(themes) && themes.length === 6, 'listThemes() 应返回 6 主题');
const tokens = await engine.listTokens();
assert.ok(tokens && Array.isArray(tokens.colors) && tokens.colors.some(c => c.k === 'primary'), 'listTokens() 应含颜色令牌');
const html = await engine.exportHtml(mbt);
assert.ok(html.includes('<!DOCTYPE html>') && html.includes('MV_ACT'), 'exportHtml() 应产出可交互原型');

console.log('SDK selftest passed: template/update/flow/export/render/DDP1/DDP2/tools/ops/themes/tokens/exportHtml all OK');
