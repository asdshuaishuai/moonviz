# MoonViz: AI-Native Prototype Design Engine

## What This Is

MoonViz is a prototype design engine built entirely in MoonBit. It treats one MoonBit literate source file (`.mbt.md`) as the only project fact source. Human canvas edits and Agent edits both commit back to that same source; every visual preview is rebuilt from it.

`.mbt.md` follows MoonBit's official literate-source rules: `mbt` compiles, `mbt check` runs document tests, while `mbt nocheck` and `moonbit` are display-only. MoonViz adds explicit `moonviz:artboard` visual blocks and parses only supported public `@decl` declarations.

## Quick Start

```bash
# Inspect and render one complete MBT source through the engine
moon run --target native cli
render-mbt-b64 <base64-utf8-mbt>
validate-mbt-b64 <base64-utf8-mbt>

# Human and Agent operations both return canonical MBT plus engine-rendered SVG
apply-human-mbt-op-b64 <mbt-base64> <operation-base64>
apply-agent-mbt-op-b64 <mbt-base64> <operation-base64>
```

## MCP Server

Add to your MCP config:

```json
{
  "mcpServers": {
    "moonviz": {
      "command": "moon",
      "args": ["run", "--target", "native", "mcp"],
      "cwd": "/path/to/moonviz"
    }
  }
}
```

Source-facing MCP tools include `read_mbt` and `render_mbt`. `ddp_view` is read-only metadata for integrations; it exposes no mutation path.

## Components

The component catalog is owned by `core/`, not by the Studio shell. `builtin_components()` currently provides **52 unique engine presets** across actions, inputs, selection, display, layout, navigation, feedback, and overlay categories, with variants and default geometry. The shell discovers this catalog through the engine and only renders previews/materializes operations.

## Rendering

The render path is:

```text
.ddp authenticated bytes
  → DDP codec
  → one complete `.mbt.md` source
  → official fence scanner
  → explicit MoonViz visual blocks
  → `@decl` parser
  → Prototype / Document / Scene Graph
  → layout solve + predicates
  → SVG / RenderPlan
  → Studio or read-only ddpView
```

Markdown is available as a source-reading view. It is never converted to HTML as the visual source of truth. SVG and RenderPlan are derived display outputs only.

## DDP

A `.ddp` file is the authenticated encrypted representation of one complete `.mbt.md` source. It is not a ZIP, archive, manifest, or collection of files. It contains no `pm-design.md`, OpenUI, HTML, or `.mvz.json` source.

The Tauri shell and browser server transport opaque DDP bytes through the authenticated codec. The engine then decrypts, validates, and renders the MBT source. Import is atomic: a bad password, damaged bytes, invalid MBT, unknown visual entry, invalid flow, or predicate failure leaves the current project unchanged.

## Read-only ddpView

`moonviz-demo-tauri/ddpView.html` is a read-only viewer. It can select a `.ddp`, decrypt it through the server's DDP codec, send the resulting MBT to MoonViz for validation/rendering, and display the derived SVG/source diagnostics. It has no edit, operation, save, or export controls; it cannot write the source or alter a DDP.

## Architecture

- **Engine (`core/`, `decl/`)**: MBT scanning, visual declaration parsing, 52 component presets, project reconstruction, layout, predicates, Human/Agent gates, canonical MBT serialization, SVG and RenderPlan.
- **CLI/MCP**: Source-based engine protocols over stdin/stdout.
- **Tauri/browser shell**: file dialogs, opaque DDP transport, and visual presentation only.
- **DDP**: one encrypted `.mbt.md` source.

