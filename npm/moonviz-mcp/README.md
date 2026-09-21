# moonviz-mcp

MCP (Model Context Protocol) server launcher for the [MoonViz](https://github.com/asdshuaishuai/moonviz) engine.

> 🇨🇳 简体中文: [README.zh-CN.md](./README.zh-CN.md)

MoonViz is a prototype design engine written entirely in MoonBit: one `.mbt.md` file as the single source of truth, human/Agent dual-route editing, and every preview rebuilt from source. This package ships the engine's MCP server as a **prebuilt platform binary** — `npx` to start, zero compile, zero toolchain.

## Usage

Point any MCP client (Claude Desktop / ZCode / Cursor / 5ire …) at it:

```json
{
  "mcpServers": {
    "moonviz": {
      "command": "npx",
      "args": ["-y", "moonviz-mcp"]
    }
  }
}
```

Tools that need the engine directory (`read_mbt` / `render_mbt` / `apply_*` …) resolve the repo via `MOONVIZ_DIR`:

```json
{
  "mcpServers": {
    "moonviz": {
      "command": "npx",
      "args": ["-y", "moonviz-mcp"],
      "env": { "MOONVIZ_DIR": "/path/to/moonviz" }
    }
  }
}
```

## How it works

1. Resolves the optional platform package by `os-arch` (`moonviz-bin-darwin-arm64` / `-linux-x64` / `-linux-arm64` / `-win32-x64`; npm installs only the one matching your platform) and runs the embedded binary over stdio — millisecond startup.
2. Falls back to `moon run --target native mcp` when no prebuilt binary matches your platform (requires the [MoonBit toolchain](https://docs.moonbitlang.com/) + `MOONVIZ_DIR` pointing at the engine repo).

## Tools (excerpt)

| Tool | Description |
|---|---|
| `read_mbt` / `render_mbt` | Source-side read/write: read canonical source / render all artboards from source |
| `list_templates` / `list_components` / `list_themes` / `list_tokens` / `list_artboards` | Enumerate templates (8 pages) / components (8×22 variants) / themes / tokens / artboards |
| `apply_template` / `apply_theme` / `set_token` | Instantiate a template / switch theme / override a design token |
| `place_component` / `update_node` / `move_node` / `group_nodes` / `align_nodes` | Structural editing |
| `interact` / `define_state` / `set_state` | Interactions (⚡trigger→action) and component state variants |
| `lint_design` / `auto_fix` | Design lint and auto-fix |
| `critique` / `infer_page_type` / `infer_missing` | Design critique and inference |
| `extract_design_system` / `generate_spec` / `generate_responsive` | Design-system extraction / handoff spec / responsive variants |
| `export_svg` / `export_html` / `export_artifact` / `benchmark` | Exports and performance benchmark |
| `ddp_view` | Read-only DDP container metadata |

52 tools total, each with a full JSON-Schema input description — see `tools/list` or the [tools dictionary](https://asdshuaishuai.github.io/moonviz/assets/moonviz-tools.json).

## Building the binaries from source

```bash
git clone https://github.com/asdshuaishuai/moonviz && cd moonviz
moon build --release --target native mcp
# → _build/native/release/build/mcp/mcp.exe (self-contained, libc only)
```

Platform packages are built by the repo's `.github/workflows/binaries.yml` CI matrix.

## License

MIT © MoonViz contributors
