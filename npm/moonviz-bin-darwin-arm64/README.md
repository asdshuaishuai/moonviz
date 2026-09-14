# moonviz-bin-darwin-arm64

Prebuilt, self-contained MoonViz engine binaries for **macOS Apple Silicon (darwin-arm64)**:

- `bin/moonviz-mcp` — MCP server (stdio JSON-RPC), launched by [`moonviz-mcp`](https://www.npmjs.com/package/moonviz-mcp)
- `bin/moonviz-cli` — stateful CLI (newline-framed JSON over stdio), usable by [`moonviz-engine-sdk`](https://www.npmjs.com/package/moonviz-engine-sdk) via `MOONVIZ_CLI_BIN` to eliminate the MoonBit toolchain dependency

Both binaries are produced by `moon build --release --target native` from the [moonviz repository](https://github.com/asdshuaishuai/moonviz) and link only the system C library (verified with `otool -L` / `ldd`) — no MoonBit toolchain, no engine sources, no runtime dependencies.

This package is an implementation detail installed automatically via `optionalDependencies`; npm resolves only the package matching your platform. Do not depend on it directly.

## License

MIT © MoonViz contributors
