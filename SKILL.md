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

Prebuilt CLI/MCP binaries (no toolchain needed) are published per platform by
`.github/workflows/binaries.yml` as `moonviz-bin-<platform>` (`bin/moonviz-cli`,
`bin/moonviz-mcp`).

### Operation grammar (mutating ops — Agent and Human share them)

Machine-readable source of truth: `list-ops` (CLI) / `list_ops` (MCP) emit the
complete op surface as JSON (op / usage / category / gates / description) —
`moonviz-ops.json` on Pages is generated from it. Keep this block in lockstep.

Session-level tools (stateful, mirror the CLI session commands):
`history` (init/commit/log/undo/redo/checkout/diff — design version control) ·
`collab_merge` (multi-agent three-way merge with OT conflict detection) ·
`animation_presets` / `animation_css` (6 presets → CSS @keyframes) ·
`protest` (assertion-based prototype test scripts).

Structural:
`create <name> [w] [h]` · `template <id> <name> [w] [h]` ·
`place <ab> <component> <id> [variant|-] [x] [y] [k=v ...]` ·
`duplicate <ab> <new_name>` · `delete-artboard <ab>` ·
`move <ab> <node> <x> <y>` · `copy <ab> <node> <new_id> [dx] [dy]` ·
`delete <ab> <node>` · `reorder <ab> <node> front|back|up|down` ·
`flip <ab> <node> h|v|both|none` ·
`group <ab> <group_id> <n1> <n2> ...` · `ungroup <ab> <group_id>` ·
`align <ab> <mode> <n1> <n2> ...` · `resize-canvas <ab> <w> <h>` ·
`responsive <ab>` · `restyle <ab> <component_id> k=v ...`

Images: `place <ab> image <id>` then `update <ab> <id> text=<https://...|data:image/...> radius=<n>` —
a non-empty URL renders a real `<image>` (rounded clip, cover-fit); empty text falls back to the
placeholder glyph. The URL lives in the node's `text` field and round-trips through canonical MBT.

Multi-agent / versioning / animation / testing:
`collab-merge <base_rev> <agent>=<op>[+op...]`（OT 三方合并；op: insert/delete/
move/fill/radius/font/text/pos/size/gap）· `history init|commit|log|undo|redo|
checkout|diff`（设计版本控制）· `anim-css <node> <preset>` / `anim-list`
（press/fade_in/slide_in_right/modal_present/shake/pop）· `protest <ab> <script>`
（tap:x:y>board; back>board; swipe:left>board; set:node:val; noviol; render）

Navigation / theme / tokens / debt:
`flow <from_ab> <to_ab> <node>` (tap navigation edge) ·
`unflow <from_ab> <to_ab> <node>` (remove one navigation edge) ·
`theme <name>` (`light dark high_contrast sepia nord sunset`) ·
`token <name> <value>` (COLOR tokens ONLY — `primary`, `on_primary`,
`secondary`, `surface`, `background`, `error`, `text_primary`, ...; full set
via `list-tokens`. Spacing/radii/typography names return `unknown_token`.
An override recolors immediately, persists in the document's frontmatter
`tokens:` section, and setting the default value back removes it) ·
`fix <ab>` (commits only when violations strictly decrease)

Node properties (`update <ab> <node> k=v ...`):
`w h text fill text_color stroke stroke_width radius opacity font_size weight
shadow rotate blur blend line tracking constraint align italic dash visible
layout gap justify padding width_mode height_mode x_mode y_mode name`

- `align` `left|center|right`; `italic true|false`; `dash solid|dashed|dotted`
- `visible false` hides the subtree without deleting it — it also stops
  rendering *and* hit-testing, so hidden nodes cannot be tapped
- `layout vertical|horizontal|none` enables/clears a container stack layout;
  `gap`, `justify start|center|end`, `padding` shape it
- `width_mode`/`height_mode` `hug|fill`; `w`/`h` also accept `fill`/`hug`
- `x_mode`/`y_mode` `center|start`; `x=@decl.center`, `x=@decl.end(24)`
- `name` renames a node (its carrier for interaction markers)

Interaction and state (mutating):
`interact <ab> <node> <trigger> <action_spec>` ·
`uninteract <ab> <node>` ·
`state <ab> <node> <state_name> k=v ...` ·
`set-state <node> <state_name> [toggle]` — define the state via `state`
BEFORE `set-state` can target it (otherwise `no_states`)

- triggers: `tap long_press swipe_left swipe_right swipe_up swipe_down
  scroll_end key_enter focus blur`
- actions: `back` · `haptic` · `navigate_to:<board>` · `show_toast:<msg>` ·
  `set_text:<node>:<text>` · `set_state:<node>:<state>` ·
  `toggle_state:<node>` · `play_sound:<name>`
- interactions persist as name markers and are executed by the runtime:
  tap resolution is flow → marker → `NodeUpdated`
- component states persist as `[state:name:k=v,...]` markers and apply as a
  render-time transform when activated

### Read-only ops (inspection — NOT accepted by the apply-op gates)

Both `apply-human-mbt-op-b64` and `apply-agent-mbt-op-b64` reject every op
below with `mbt_operation_unsupported`. Run them after `load-mbt-b64`:

`list` · `flows` · `list-templates` · `list-components` · `list-tools` ·
`list-tokens` · `list-themes` · `benchmark` ·
`lint <ab>` · `critique <ab>` · `query <ab>` · `infer <ab>` · `spec <ab>` ·
`missing <ab>` · `doc-json <ab>` · `states <ab>` · `interactions <ab>` ·
`export-svg <ab>` · `export-html <ab>` (self-contained interactive HTML
prototype: node-level tap bindings + component states as CSS variants) ·
`tap <ab> <x> <y>` (simulate a tap, returns state changes)

### CLI-pipeline-only (NOT reachable through either apply gate)

`constrain <ab> <intent_text>` — LAYOUT INTENT ONLY (居中 | 垂直居中 |
垂直排列 | 水平排列 | 等宽 | 等高 | 等间距 | 网格 N | 顶部 | 底部 |
放大 N | 缩小 N | 边距 N | 间距 N) — it does NOT do layering/z-order.
Both apply gates return `mbt_operation_unsupported`; it only runs on the
load/session pipeline. Layering: a fully-contained sibling (fullscreen
background + content) passes both gates since 0.1.5-fix (containment
exemption); z-order via `reorder <ab> <node> front|back|up|down`.
To rename a node through the gates, use `update <ab> <node> name=<id>`
(there is no standalone `name` op on the gated surface).

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

The tool registry lives in `core/agent_api.mbt` (single source of truth)
and is emitted by the CLI's `list-tools` as valid JSON in MCP `tools/list`
form: `name` / `description` / `inputSchema{properties,required}`. Both the
MCP server and the CLI consume it directly. Enumerate the surface from
`list-tools` (the docs site CI also deploys it as `moonviz-tools.json`);
do not cite a hardcoded tool count:

- **Project/template**: `list_templates`, `list_components`, `list_tokens`,
  `list_themes`, `list_artboards`, `apply_template`, `place_component`
- **Node editing**: `update_node` (full property key set above), `move_node`
- **Structure**: `group_nodes`, `ungroup_node`, `align_nodes`,
  `resize_canvas`, `restyle_component`, `generate_responsive`
- **Interaction**: `interact`, `uninteract`, `interactions`
- **Component states**: `define_state`, `set_state`, `list_states`
- **Inspection**: `query_nodes`, `lint_design`, `critique`, `auto_fix`,
  `read_mbt`, `render_mbt`, `export_svg`, `generate_spec`,
  `infer_page_type`, `infer_missing`, `suggest_alignment`,
  `extract_design_system`, `benchmark`, `export_artifact`
- **Theme/tokens/export**: `apply_theme`, `set_token`, `export_html`
- **User components**: `component_compile`, `component_describe`,
  `component_export`, `component_import`, `component_delete`,
  `library_snapshot`, `library_restore`

`ddp_view` is read-only metadata for integrations; it exposes no mutation path.

`list-tools` is the machine-readable tool registry (resolved: it
previously dumped a subset with unescaped nested JSON — fixed in the
`core/agent_api.mbt` registry rebuild).

Argument passing mirrors the CLI: list-ish arguments are comma-separated
(`nodes="a,b"`), property arguments are space-separated `k=v`
(`args="fill=#fff radius=8"`). Parsing tolerates both `"key":"v"` and
`"key": "v"` JSON spacing.

## Components

The component catalog is owned by `core/`, not by the Studio shell. `builtin_components()` currently provides **65 unique engine presets** across actions, inputs, selection, display, layout, navigation, feedback, and overlay categories, with variants and default geometry. The shell discovers this catalog through the engine and only renders previews/materializes operations.

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

## Read-only ddpView (removed)

`ddpView.html` was a read-only browser viewer (select a `.ddp`, decrypt via
the server's DDP codec, render via MoonViz, show diagnostics; no edit/save
controls). It lived in the demo repo, since renamed `deepdesign-studio`, and
was removed there along with the browser-mode server during a dead-code
purge. The design intent is preserved here for reference in case a viewer
returns.

## Architecture

- **Engine (`core/`, `decl/`)**: MBT scanning, visual declaration parsing, 65 component presets, project reconstruction, layout, predicates, Human/Agent gates, canonical MBT serialization, SVG and RenderPlan.
- **CLI/MCP**: Source-based engine protocols over stdin/stdout.
- **Tauri/browser shell**: file dialogs, opaque DDP transport, and visual presentation only.
- **DDP**: one encrypted `.mbt.md` source.
- **Release baseline (agent 元规则)**: whenever build artifacts are synced, docs, website, all
  artifacts, and the playground move to the same baseline together. Two authoritative values must
  agree (CI smoke asserts it, mismatch fails the job): `core/version.mbt` `ENGINE_VERSION` and
  `binaries.yml` `MOONVIZ_VERSION` in the engine repo. Full procedure:
  root [`AGENTS.md`](AGENTS.md) — checklist, sync targets, red lines.


## User Components (custom component registry)

The engine treats custom components exactly like builtins — the registry is
source-agnostic. Whether the declaration comes from an Agent (natural-language
translation) or a human (Studio canvas), the artifact is the same: a
single-artboard `.mbt.md` declaration with a `component:` front-matter section.

Workflow:

```
# 1. Agent drafts the declaration (params as ${name} slots in node attrs)
# 2. Compile & register (full pipeline: syntax → single-artboard → param
#    closure → instantiation probe → registry)
component-compile-b64 <b64>

# 3. Discover & use exactly like builtins
list-components        # merged view, source: user
component-describe <id>  # params/variants/usage template
place <artboard> <id> <inst> [variant] [x] [y] key=value...

# 4. Share — the ONLY outbound form is the proprietary MCF container
component-export <id>   # → mcf_b64 (byte source never leaves the engine)
component-import <b64>  # strict validation (magic/version/CRC×2/fingerprint)
                        # then FULL re-compilation before registration

# 5. Host-side persistence (engine is IO-free by design)
library-snapshot        # dump for the host to persist
library-restore-b64 ... # rehydrate at session start
```

Rules: `.mbt.md` component source exists only inside the engine/local library;
outbound distribution is always MCF. MCF is a pure data container — imports are
re-validated through the same compile pipeline, no code execution surface.
