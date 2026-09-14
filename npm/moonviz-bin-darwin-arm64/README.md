# moonviz-bin-darwin-arm64

Prebuilt MoonViz MCP server binary for **macOS Apple Silicon (darwin-arm64)**.

This package is an implementation detail of [`moonviz-mcp`](https://www.npmjs.com/package/moonviz-mcp) and is installed automatically via `optionalDependencies` — npm resolves only the package matching your platform. Do not depend on it directly.

Artifact: `bin/moonviz-mcp` — a self-contained Mach-O executable (links only libSystem), produced by `moon build --release --target native mcp` from the [moonviz repository](https://github.com/asdshuaishuai/moonviz).

## License

MIT © MoonViz contributors
