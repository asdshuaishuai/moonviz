# moonviz-bin-darwin-arm64

**macOS Apple Silicon（darwin-arm64）** 平台的 MoonViz 引擎预编译自包含二进制：

- `bin/moonviz-mcp` — MCP 服务器（stdio JSON-RPC），由 [`moonviz-mcp`](https://www.npmjs.com/package/moonviz-mcp) 拉起
- `bin/moonviz-cli` — 有状态 CLI（stdio 上的换行分帧 JSON），[`moonviz-engine-sdk`](https://www.npmjs.com/package/moonviz-engine-sdk) 可经 `MOONVIZ_CLI_BIN` 使用它来消除 MoonBit 工具链依赖

> 🇬🇧 English: [README.md](./README.md)

两个二进制均由 [moonviz 仓库](https://github.com/asdshuaishuai/moonviz) 的 `moon build --release --target native` 产出，仅链接系统 C 库（经 `otool -L` / `ldd` 验证）——无需 MoonBit 工具链、无引擎源码、无运行时依赖。

本包是实现细节，经 `optionalDependencies` 自动安装；npm 只解析匹配你平台的包。请勿直接依赖。

## 许可

MIT © MoonViz contributors
