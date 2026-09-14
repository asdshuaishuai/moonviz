# 09 · MoonBit 绘制引擎生态调研（2026-09 实测检索）

回应一个关键问题：**绘制引擎并不只能基于终端 canvas / 浏览器 canvas**。
MoonBit 社区已经长出一整套纯 MoonBit（Wasm/JS/Native 同源）的图形栈，
MoonViz 的渲染层可以按需逐级接入。

## 生态图谱（按抽象层从低到高）

| 层 | 项目 | 是什么 | 对 MoonViz 的意义 |
| :--- | :--- | :--- | :--- |
| GPU 驱动契约 | **mizchi/gfx** | 后端无关的 GPU 命令缓冲契约（从 mizchi/kagura 抽出）：`GraphicsDriver` trait（initialize/begin/end/draw_triangles/read_pixels…）+ CommandQueue（可合并相邻 draw）+ ShaderFrontend（WGSL）。后端枚举：wgpu-native / WebGPU / WebGL2 / Null | 现成"驱动契约"：MoonViz 未来若要 GPU 主机，实现一个把 Scene Graph 化为 DrawTrianglesCommand 的 renderer 即可；自带的 Null 驱动 + framebuffer 快照对比正好做视觉回归测试 |
| CPU 光栅化 | **mizchi/canvas** | 纯 MoonBit headless 2D 栅格化器：镜像 CanvasRenderingContext2D 的子集（rect/path/贝塞尔/变换/文本/PNG），4x 超采样抗锯齿，js/native/wasm-gc 三目标可测 | **近期首选**：给 MoonViz 接"离屏位图画布"，从终端输出升级为 PNG 截图（不依赖浏览器/Node）；也是 `moon prove` 之外的图形回归金样来源 |
| 平台与窗口 | **mizchi/kagura** | Ebiten 风格 2D 游戏引擎：窗口/输入/音频/文字排版/sprite/tilemap；WebGPU(wasm) + wgpu-native(桌面 macOS/Linux) | 未来"人类视觉画布"的可宿主运行时（窗口 + 指针事件 + 帧循环） |
| GUI 框架 | **MoUI (wzzc-dev)** | 渲染器门面 + 5 后端：Skia 光栅/GPU(native)、WebGPU/Canvas2D(wasm)，窗口/IME/桌面打包；示例含 Markdown 编辑器、Excel/PDF 工作台 | 若要完整编辑器 UI（面板/表格/富文本/IME），这是 MoonBit 世界的现成底座 |
| 矢量编辑内核 | **wccerty/moonbit-artboard** | 2D 矢量画板内核：场景图、仿射运算、形状感知命中、视口裁剪/剔除、吸附、选择手柄、框选、pan/zoom、undo/redo、RenderPlan→Canvas2D/SVG/PDF 导出、网格空间索引 | 与 MoonViz 领域完全重合——既是"此路可行"的最强实证，也是场景图/命中的对拍参照物 |
| 动画/格式 | **moon-lottie (cg-zhou)** | 原生 MoonBit Lottie 引擎：Json 解析→矢量渲染→Wasm/JS 浏览器渲染 + CLI（终端播放 / SVG 帧导出） | 证明"纯 MoonBit 矢量渲染引擎+多宿主输出"完整可行；导出格式路线参照 |
| SVG 生成 | CAB EOX/svg (eDSL)、mizchi/svg、gmlewis/moonbit-fonts(draw.Graphic→SVG/Canvas) | 多个 SVG 生成/渲染路径 | 与 core/svg 通属"场景图→宿主把戏"，可作为导出侧的可替换件 |
| UI 架构 | **Rabbit-TEA** | Elm 架构 UI 框架（mooncakes.io 官网即用它构建，含 VirtualDom，33KB 计数器） | 若未来用 Wasm 做人类画布 Web 宿主，TEA 循环与 MoonViz 的"模型→视图"层天然对齐 |
| 工具链 | **官方** | `@async.stdin` 已入 beta 标准库（cat 示例）：stdin 异步读取；多目标 wasm/js/native 全栈工作流（前后端共享模型） | 交互回路可用标准库替换 C FFI；也验证了"引擎+多宿主"是官方拥戴的工程形态 |

官方博客/展示（moonbitlang.cn 与 m10665.moonbitlang.cn/blog/）确认：多目标全栈
（native 后端 + JS 前端共享类型）、TEA 架构与生态仓库都是官方推广的方向；
moon-lottie / Enimate / MoUI / artboard 均为纯 MoonBit 跨端图形项目。

## 结论与路线影响

1. **指点引擎的边界不变，后端是多变的**。MoonViz 已把"布局求解→不崩谓词→
   渲染计划"做纯库化，barrier 同 kwiver / artboard / MoUI 的分层一致。
   现有渲染面=SVG 字符串 + 终端栅格；生态给出两个明确的下一站：
   - `mizchi/canvas`：离屏位图渲染（PNG 快照、胖输出、无浏览器依赖）；
   - `mizchi/gfx`：GPU 驱动契约（交互式画布的未来后端）。
2. **人类视觉画布的宿主选择面扩大**：不必自己写窗子系统——kagura 平台层
   或 MoUI 的 HostEvent/窗口/IME 都可做宿主层，MoonViz 只需实现其
   SurfaceProvider/事件转换（引擎侧零改动，符合"宿主可替换"红线）。
3. **moonbit-artboard 是最接近的对拍基线**：其场景图/命中测试/RenderPlan/
   吸附/undo 的 API 设计是 MoonViz 自研模型的收敛参考；不直接依赖也可
   拿来当结构性评审对象与基准测试对照。
4. **交互输入**：`@async.stdin`（beta 标准库）可在未来替换当前的
   `extern "c" getchar`（native 能力不变、代码更可移植）。

## 结果：纯 MoonBit 自实现像素画布（零外部依赖）

网络受限（`moon add mizchi/canvas` 因 `mizchi/image` 版本冲突而失败——
`pixelmatch@0.6.1` 钳住旧版 `image@0.1.2`，与 `canvas@0.9.1` 要的 `image@0.4.3` 冲突）。
因此 MoonViz 以纯 MoonBit 手写了完整 PNG 编码管线（playground/png.mbt）：

| 层 | 实现 | 验证 |
| :--- | :--- | :--- |
| RGBA 帧缓冲 | `RgbaBuf`（FixedArray[Int] ARGB，fill/stroke_rect，clamp 裁剪） | `moon test` 断言像素 |
| CRC32-IEEE | Int64 承载 32 位位模式（poly 0xEDB88320 = 3988292384L） | `"123456789" → 0xCBF43926` 规范值 |
| Adler32 | s1/s1 累积 mod 65521，Int 域 | `"abc def" → 163906166` |
| zlib | store 块 deflate（无压缩但合法），≤65535B 分块 | Python `zlib.decompress` 可解压 |
| PNG | IHDR + IDAT + IEND 三块全编码，chunk CRC 附带 | Python 解析：magic ✓ CRC ✓ 尺寸 ✓ |

**端到端**：`moon run --target native playground` → 输入 `png` → base64 →
`base64 -d > moonviz.png` → 用图像预览工具打开，可清晰看到嵌套容器布局、
多色填充与边框。这才是"用 MoonBit 自己实现一套画布"的像素级证明。
