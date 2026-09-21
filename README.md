# MoonViz — The Agent-Driven Prototype Design Engine for the AI Era

> 🇨🇳 简体中文: [README.zh-CN.md](./README.zh-CN.md)

**`.mbt.md` is the single source of truth, MoonBit is the unified compute kernel. Agents discover components, place elements, check quality, and fix violations through a tool API — all over a structured text protocol. This repository is 100% MoonBit with zero hand-written JS/Node.**

```
┌─────────────────────────────────────────────────────────────┐
│  Agent (any LLM)                                             │
│  discover components → create artboard → place → lint →      │
│  fix → export                                                │
└──────────────┬────────▲─────────────────────────────────────┘
               │ Agent Tools API (52 tools, JSON in/out)
┌──────────────▼────────┴─────────────────────────────────────┐
│  Engine core/ + decl/ (pure MoonBit libraries)               │
│  ┌────────────┐ ┌────────────┐ ┌───────────┐ ┌───────────┐ │
│  │ DesignTokens│ │ Components │ │ Project   │ │ Agent API │ │
│  │ 16 colors/  │ │ 8 comps ×  │ │ multi-    │ │ lint/diff │ │
│  │ 7 spacing/  │ │ 22 variants│ │ boards/   │ │ /suggest  │ │
│  │ 6 radii/    │ │            │ │ flows/    │ │           │ │
│  │ 8 font sizes│ │            │ │ tokens    │ │           │ │
│  └────────────┘ └────────────┘ └───────────┘ └───────────┘ │
│  ┌────────────┐ ┌────────────┐ ┌───────────┐ ┌───────────┐ │
│  │ Scene Graph │ │ Layout     │ │ Non-crash │ │ Decl      │ │
│  │ node tree   │ │ solver     │ │ preds     │ │ round-trip│ │
│  │             │ │ Fixed/Fill │ │ P0–P4     │ │ .mbt.md   │ │
│  └────────────┘ └────────────┘ └───────────┘ └───────────┘ │
│  ┌────────────┐ ┌────────────┐ ┌───────────┐               │
│  │ SVG output  │ │ PNG pixels │ │ Terminal  │               │
│  │             │ │ DEFLATE+AA │ │ canvas    │               │
│  └────────────┘ └────────────┘ └───────────┘               │
└──────────────┬────────▲─────────────────────────────────────┘
               │ .mbt.md fact source
┌──────────────▼────────┴─────────────────────────────────────┐
│  decl/login.mbt.md etc. (compiled & executed by moon check/test) │
└─────────────────────────────────────────────────────────────┘
```

## Agent Tool List (52 tools)

| Tool | Semantics |
| :--- | :--- |
| `list_components` | List all available UI components (with variants/descriptions/categories) |
| `list_tokens` | List design tokens (colors/spacings/radii/font sizes) |
| `create_artboard` | Create a new artboard (name, width, height) |
| `list_artboards` | List all artboards in the project with metadata |
| `place_component` | Place a component instance on an artboard |
| `query_nodes` | Query nodes by kind/component/text content |
| `lint_design` | Design quality checks (contrast/touch/spacing/consistency) |
| `get_violations` | Get the non-crash predicate violation list |
| `suggest_fix` | Actionable fix patches for violations |
| `export_svg` | Export an artboard as engine-derived SVG |
| `collab_merge` | Multi-agent three-way merge: submit N agents' op sequences, get conflicts + auto-resolution |
| `history` | Design version control: init/commit/log/undo/redo/checkout/diff (time travel + semantic diff) |
| `animation_presets` / `animation_css` | List the 6 animation presets / generate CSS @keyframes for a node |
| `protest` | Run a prototype test script (assertion-based navigation/inputs/render/violations) |
| `read_mbt` | Read and validate a complete `.mbt.md` source |
| `render_mbt` | Re-parse and render from `.mbt.md` |
| `ddp_view` | Read-only DDP view and render contract |
| `export_react` | React TSX component stubs (code generation only, not a fact source) |
| `apply_template` | Generate a complete artboard from a template (one sentence → full page) |
| `fork_variants` | Fork design variants (parallel A/B exploration) |
| `score_variants` | Score all variants (violations/lint/alignment/richness) |
| `merge_variant` | Merge the best variant back into the main branch |
| `auto_arrange` | Vertical equal-spacing auto-arrange |
| `snap_to_grid` | Snap to an N px grid |
| `center_in_parent` | Center within parent |
| `suggest_alignment` | Detect near-alignments and suggest snapping |

## Built-in Page Templates (14 complete pages)

| Template | Contents |
|:---|:---|
| `login` | Logo + title + email + password + sign-in button + sign-up link |
| `signup` | Title + name + email + password × 2 + sign-up button |
| `dashboard` | App bar + stat cards 2×2 + chart + activity list |
| `profile` | Avatar + name + bio + stats + actions + content list |
| `settings` | 4 groups (notifications/privacy/appearance/about) + sign-out button |
| `list_detail` | List page + detail page |
| `onboarding` | Three-page onboarding |
| `empty_state` | Illustration + copy + CTA button |
| `web_landing` | Web landing page: hero + feature cards + CTA |
| `web_login` | Web login: split layout with branding panel |
| `web_dashboard` | Web dashboard: sidebar + topbar + stat cards + table |
| `pc_app` | Desktop app frame: sidebar navigation + content |
| `adaptive_landing` | Adaptive landing page for web widths |
| `login_v2` | Login page, second style variant |

## Built-in Component Library (52 components × 93 variants)

| Component | Category | Variants |
| :--- | :--- | :--- |
| `button` | actions | primary / secondary / danger |
| `text_input` | inputs | default / filled |
| `card` | layout | elevated |
| `app_bar` | layout | surface / primary |
| `divider` | layout | default |
| `heading` | display | h1 / h2 / h3 / h4 |
| `body_text` | display | body / caption |
| `badge` | display | primary / success |

## Design Lint

| Rule | Severity | Checks |
| :--- | :--- | :--- |
| `contrast` | error | Text contrast ≥ WCAG AA 4.5:1 |
| `touch_target` | warning | Interactive elements ≥ 44×44 |
| `spacing` | info | Padding inside containers ≥ 8 |
| `empty_container` | warning | Frame with no children |

## Quick Start

### Environment Setup

```bash
# 1. Install the MoonBit toolchain (moon ≥ latest stable)
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
moon version    # Verify: ~/.moon/bin/moon is on PATH

# 2. Clone the engine repository
git clone https://github.com/asdshuaishuai/moonviz && cd moonviz

# 3. (Optional, for DDP encrypted distribution) Build the Rust codec
cd ddp && cargo build --release && cd ..
#    Produces ddp/target/release/ddp_codec (stdin JSON → stdout JSON)
#    Override the path with MOONVIZ_DDP_HELPER; the SDK searches ddp/target/{debug,release} automatically

# 4. Full test suite (174 tests)
moon test
```

### First Run

```bash
# A. Stateful CLI session: one command per stdin line → one JSON per stdout line
moon run --target native cli
template login t_login 390 844     # Create an artboard from a template
update t_login welcome_title text="Welcome back"
flow t_login t_home login_btn      # Sign-in button → navigate to home
export-mbt-human                    # HumanGate validation + returns canonical .mbt.md
exit

# B. Stateless one-shot: render / validate (base64 carries multi-line MBT source)
moon run --target native cli <<< "render-mbt-b64 $(base64 <<< "$MBT")"

# C. MCP Server (stdio JSON-RPC, plugs into any MCP client)
moon run --target native mcp

# D. Prebuilt binaries (no toolchain, millisecond startup)
moon build --release --target native mcp
_build/native/release/build/mcp/mcp.exe   # Self-contained executable (links libc only)

# E. Interactive canvas / scripted demo
moon run --target native playground       # Interactive (`png` command emits a PNG)
moon run playground                       # Scripted demo
```

## Repository Tour

```
moonviz/
├── core/
│   ├── node.mbt       Node tree (scene graph)
│   ├── layout.mbt     Layout solver
│   ├── predicates.mbt Non-crash predicates P0–P4
│   ├── policy.mbt     Dual-route policy (human soft / agent hard)
│   ├── patch.mbt      Transactional patches
│   ├── tokens.mbt     Design tokens (Material 3 style)
│   ├── component.mbt  Component system (52 components × 93 variants)
│   ├── project.mbt    Multi-artboard project + navigation flows + lint + fix suggestions
│   ├── agent_api.mbt  Agent tool API (47 tools + list-ops op dictionary)
│   ├── autofix.mbt    Auto-fix engine (overflow shrink/overlap shift)
│   ├── templates.mbt  Page template library (login/dashboard/settings/profile/empty state…)
│   ├── align.mbt      Smart alignment (grid snap/centering/equal spacing/near-detection)
│   ├── variants.mbt   Variant exploration (fork/score/merge)
│   ├── interaction.mbt Interactive prototypes (Trigger/Action/Transition/nav stack)
│   ├── artifact.mbt   Agent intermediate artifacts (.moonviz cross-agent handoff)
│   ├── runtime.mbt    Embedded runtime SDK (events/render plan/hot reload/input)
│   ├── intelligence.mbt Design intelligence (page-type inference/missing detection/suggestions/scoring)
│   ├── lineage.mbt    Lineage tracking (token/component usage + change impact + design-system audit)
│   ├── prototest.mbt  Prototype testing (assertion-based verification of navigation/input/render/violations)
│   ├── reasoning.mbt  Layout reasoning (natural-language constraints → StackLayout/alignment/scaling)
│   ├── responsive.mbt Responsive breakpoints (phone/tablet/desktop auto-adaptation)
│   ├── collab.mbt     Multi-agent collaboration (operational transform/conflict detection/three-way merge)
│   ├── history.mbt    Design version control (time travel/branching/change replay/undo-redo)
│   ├── critique.mbt   AI design critique (automatic review against 8 design principles)
│   ├── annotate.mbt   Design annotation (auto-generated spec docs/CSS variables/spacing-color-type annotations)
│   ├── animation.mbt  Property animation (keyframes/easing/timeline choreography/CSS export)
│   ├── extract.mbt    Design-system reverse extraction (infer tokens + component patterns from existing designs)
│   ├── theme.mbt      Theme system (6 predefined themes/auto dark/token-level switching/registry)
│   ├── slots.mbt      Component slot system (6 composable components/nested content distribution/recursive composition)
│   ├── benchmark.mbt  Performance benchmark engine (node stats/complexity analysis/anti-pattern detection/optimization advice)
│   ├── diff.mbt       Semantic diff (added/moved/resized/restyled)
│   ├── export.mbt     HTML prototype + React TSX export
│   ├── svg.mbt        SVG rendering
│   └── agent_test.mbt Agent workflow end-to-end tests
├── decl/              Declaration DSL + .mbt.md round-trip
├── cli/               Agent CLI (newline-framed JSON-lines protocol; one process = one stateful session)
├── mcp/               MCP Server (stdio JSON-RPC; 52 tools mirroring the CLI)
├── wasm/              WASM boundary — dual builds: wasm-gc (JS hosts, JS String Builtins) + classic standard MVP; 11 stateless APIs + 24 session_* APIs (i32 handles)
├── ddp/               Rust ddp_codec: DDP1 encryption (Argon2id+XChaCha20-Poly1305) / DDP2 keyless (zstd+CRC32)
├── sdk/node/          Node SDK "moonviz-engine-sdk": sessions/Project builder/DDP bridge (pure transport)
├── sdk/wasm/          WASM SDK "moonviz-engine-wasm": in-process render/validate, zero toolchain (Node ≥22 / modern browsers)
├── npm/               npm distribution: moonviz-mcp (launcher) + moonviz-bin-<platform> (prebuilt platform packages)
├── playground/        Terminal canvas + PNG rendering + REPL
├── site/              Website (GitHub Pages: asdshuaishuai.github.io/moonviz/)
├── scripts/           publish-npm.sh and other release scripts
└── docs/              Design documents 01–10
```

## Interactive Prototype System

Prototypes are not static pictures — MoonViz has a complete interaction runtime:

| Concept | Description |
|:---|:---|
| **Trigger** | tap / long_press / swipe / keyboard / focus / blur |
| **Action** | navigate_to / back / toggle_state / set_text / submit_form / show_toast |
| **Transition** | push / pop / modal / sheet / fade |
| **ComponentState** | Component polymorphism (default / pressed / disabled / loading) |
| **NavigationState** | Navigation stack (push / pop / back) |

## Agent Intermediate Artifacts (.moonviz)

Agent A finishes a design → exports a `.moonviz` JSON file → Agent B reads it and continues.

```json
{
  "meta": { "version": "0.1.0", "created_by": "agent-abc", "context": "Food delivery app" },
  "artboards": { "login": { "name": "Login", "size": [390,844], "decl": "..." } },
  "flows": [{ "from": "login", "to": "home", "trigger": "tap:submit" }],
  "todo": ["Add form validation", "Create error state"],
  "notes": [{ "artboard": "login", "note": "Email needs regex", "priority": "high" }]
}
```

## Embedded Runtime SDK

How other projects embed MoonViz:

```moonbit
let rt = MoonVizRT::create(project, initial_artboard="login")?
rt.set_input("email", "user@test.com")
let changes = rt.handle_event(TapEvent(160.0, 422.0))  // → navigate to home
let plan = rt.render_plan()                               // → RenderPlan (backend-agnostic display list)
rt.hot_reload(new_decl)                                   // → hot reload (keeps nav stack and input values)
```

The RenderPlan is a **backend-agnostic display list** (CmdRect / CmdText / CmdLine / CmdClip) that any rendering backend (Canvas / Skia / SVG / terminal / OpenGL) can consume.

## Design Intelligence

The engine does not just execute designs — it **understands** them:

| Capability | Description |
|:---|:---|
| `infer_page_type` | Infer page type from node structure (auth/dashboard/list/profile/settings…) |
| `infer_missing` | Infer missing elements from page type ("login page is missing a forgot-password link") |
| `suggest_improvements` | Suggest improvements based on design principles (hierarchy/spacing/consistency/density) |
| `design_quality_score` | Composite grade A–D (hierarchy/consistency/stability/richness) |

## Lineage Tracking

You changed one token — which nodes are affected?

| Capability | Description |
|:---|:---|
| `token_lineage("primary")` | Every node using the primary color (with artboard + field) |
| `component_lineage("button")` | Location and size of every button instance |
| `impact_analysis(patch)` | Preview a patch's impact (color contrast/size overflow/position) |
| `audit_design_system` | Audit hardcoded colors → suggest nearest-token replacements |

## Prototype Testing

A prototype is not just "looks right" — it is **testable**:

```moonbit
let pt = ProtoTest::create(project, initial="login")?
pt.tap_and_expect_navigate(160, 422, "home")  // tap sign-in → home
pt.back_and_expect("login")                    // back → login
pt.set_input_and_expect("email", "a@b.com")    // input value stored correctly
pt.expect_no_violations()                      // no layout violations
pt.expect_renderable()                         // render plan non-empty
pt.result() // → {"status":"PASS","passed":5,"failed":0}
```

## Layout Reasoning Engine

The agent says "center the buttons", the engine infers parameters and executes — no StackLayout API knowledge required:

```moonbit
p.apply_constraint("center align", artboard="login")   // → center_in_parent
p.apply_constraint("vertical stack", artboard="login") // → StackLayout(Vertical)
p.apply_constraint("equal widths", artboard="login")   // → all width = Fill
p.apply_constraint("spacing 16", artboard="login")     // → gap = 16
p.apply_constraint("scale 1.5x", artboard="login")     // → all sizes × 1.5
p.apply_constraint("grid 8", artboard="login")         // → snap_to_grid(8)
```

12 layout intents in Chinese and English; numbers auto-extracted ("间距 16px" → gap=16.0).

## Responsive Breakpoints

One design adapts automatically to phone/tablet/desktop:

```moonbit
p.generate_responsive(artboard="login")
// → creates login_tablet (768×1024) + login_desktop (1200×800)
//   layout auto-adapts: phone vertical → tablet widened → desktop horizontal multi-column

p.preview_breakpoint(artboard="login", breakpoint="tablet")
// → preview the tablet variant

p.list_breakpoint_variants(artboard="login")
// → [{"breakpoint":"mobile","width":390}, {"breakpoint":"tablet","width":768}, ...]
```

| Breakpoint | Size | Adaptation strategy |
|:---|:---|:---|
| mobile | 390×844 | Vertical single column, compact spacing |
| tablet | 768×1024 | Vertical kept, cards widened ×1.2, spacing 16 |
| desktop | 1200×800 | Horizontal multi-column, spacing 24, margins 48 |

## Multi-Agent Collaboration

The core scenario of the AI era: **multiple agents working on one prototype at the same time**.

```moonbit
let cm = CollabManager::new(base_revision=1)
let agent_a = cm.join("designer_bot")     // Agent A: design the login page
let agent_b = cm.join("ux_optimizer")     // Agent B: optimize layout

agent_a.add_op(OpSetFill("login_btn", "#4B6BFB", "#FF0000"))
agent_b.add_op(OpSetPosition("login_btn", 24.0, 100.0, 400.0, 450.0))

let conflicts = cm.total_conflicts()  // → 0 (different fields, parallel is safe)

// If there is a conflict:
agent_b.add_op(OpSetFill("login_btn", "#4B6BFB", "#00FF00"))  // same field, different value
cm.total_conflicts()  // → 1 (needs resolution)
cm.status()           // → "Conflicts: 1 ⚠"
```

**Conflict rules**:

| Case | Result |
|:---|:---|
| Different nodes | ✅ No conflict |
| Same node, different fields | ✅ No conflict (parallel is safe) |
| Same node, same field, same value | ✅ Idempotent, auto-resolved |
| Same node, same field, different values | ⚠️ Conflict, manual choice required |
| One deletes + the other edits | ⚠️ Conflict, keeping the edit suggested |
| Both delete | ✅ Idempotent |

**Operational transform (OT)**: simultaneous inserts at the same position are ordered by timestamp.

## Design Version Control

Every change produces a commit; agents can time-travel, branch, and replay changes:

```moonbit
let h = DesignHistory::new(doc)
h.commit("agent_a", "change button color", ops, doc)   // rev 1
h.commit("agent_b", "increase spacing", ops2, doc)     // rev 2

h.log()          // → "→ rev2 [agent_b] increase spacing
  rev1 [agent_a] change button color
..."
h.checkout(1)    // → time-travel to rev1's document snapshot
h.undo()         // → back to rev1
h.redo()         // → forward to rev2
h.replay(0, 2)   // → replay all operations
h.branch(1, "experiment") // → branch from rev1
h.diff(0, 2)     // → semantic diff between two revisions
```

## AI Design Critique Engine

The engine reviews prototypes like a **senior designer** — not rule checking (that's lint), but a holistic evaluation against 8 design principles:

| Principle | What is checked |
|:---|:---|
| Visual hierarchy | ≥ 3 font sizes (clear size contrast) |
| Proximity | Spacing between related elements ≥ 8px (Gestalt) |
| Alignment | Nodes snap to the grid |
| Consistency | Colors come from design tokens |
| Whitespace | Reasonable density (not cramped, not sparse) |
| Balance | Left/right visual weight is balanced |
| Focus | A clear primary CTA exists (primary button) |
| Rhythm | Spacing values unify to standard tokens |

```moonbit
p.critique(artboard="login")
// → {"principles":8,"results":[
//     {"principle":"visual_hierarchy","score":9,"verdict":"good",...},
//     {"principle":"balance","score":6,"verdict":"fair",...},...]}

p.critique_summary(artboard="login")
// → "Design Critique: B (7/10)"
```

## Design Annotation (Developer Handoff)

Auto-generate a developer handoff spec from the prototype — the equivalent of Figma Dev Mode:

```moonbit
p.generate_spec(artboard="login")
// → Markdown document containing:
//   ## Components (component list + variants + sizes)
//   ## Colors (colors + semantic token mapping)
//   ## Typography (font sizes + tokens)
//   ## Spacing (exact coordinates)
//   ## Layout (flex-direction/gap/padding)
//   ## CSS Custom Properties (--color-* / --spacing-*)
```

## Property Animation System

Prototypes need motion — property interpolation / easing functions / timeline choreography:

```moonbit
let tl = Timeline::new()
tl.add(fade_in_animation("title"))         // fade in
tl.add(slide_in_right("card"))             // slide in from right
tl.add(press_animation("submit_btn"))      // press bounce
tl.add_sequence([modal_present("modal"), shake_animation("error")]) // sequential

tl.to_css() // → generates complete CSS @keyframes + animation
```

**6 easing functions**: Linear / EaseIn / EaseOut / EaseInOut / Spring / Bounce
**6 animation presets**: press / fade_in / slide_in_right / modal_present / shake / pop
**Choreography**: parallel (`add`) / sequential (`add_sequence`) / delayed

## Design-System Reverse Extraction

Hand the engine an existing prototype and it **infers** the design system:

```moonbit
let ds = p.extract_design_system(artboard="dashboard")
ds.summary()
// → Extracted Design System:
//     Colors: 6 tokens
//       primary = #4B6BFB (used 5x, confidence 0.9)
//       surface = #FFFFFF (used 12x, confidence 0.9)
//       error = #BA1A1A (used 1x, confidence 0.5)
//     Spacing: 3 values
//       md = 8px, xl = 16px, xxl = 24px
//     Typography: 4 sizes
//       h2 = 24px, h3 = 20px, body = 14px, caption = 12px
//     Components: 3 patterns
//       card (4 instances), button (2 instances), heading (3 instances)
```

**Inference logic**:
- Colors: sorted by usage frequency → brightness/saturation analysis → semantic name inferred (primary/surface/error)
- Spacing: gap/padding identified → matched to standard token names (xs/sm/md/lg/xl)
- Font sizes: matched to the standard scale (display/h1-h4/body/caption/overline)
- Components: ≥2 nodes with identical (kind, fill, radius) → inferred as one component pattern

**Extract → reuse loop**: Agent extracts a design system from design A → creates design B with those tokens and components → visual consistency is automatic.

## Theme System

One-click dark/light/custom theme switching — **every node referencing tokens updates automatically**:

```moonbit
p.apply_theme("dark")         // → surface becomes #1A1C1E, text #E0E0E0
p.apply_theme("nord")         // → Nordic palette
p.apply_theme("high_contrast") // → WCAG AAA high contrast

p.set_token("primary", "#FF5722")  // single-token change, global effect
p.preview_themes("btn")            // preview the button under each theme

p.enable_auto_dark()          // derive a dark variant from the current theme
```

**6 predefined themes**:

| Theme | Style | primary | surface |
|:---|:---|:---|:---|
| light | Light (default) | #4B6BFB | #FFFFFF |
| dark | Dark | #A5B4FC | #1A1C1E |
| high_contrast | High contrast | #0000EE | #FFFFFF |
| sepia | Sepia | #8D6E63 | #FAF6F0 |
| nord | Nordic | #88C0D0 | #3B4252 |
| sunset | Warm sunset | #FF7043 | #FFF8E1 |

**Auto dark**: `Theme::auto_dark(light)` → invert luminance, keep hue → a dark variant is generated automatically.

## Component Slot System

Like React/Vue children/slots — the agent places content into designated component slots:

```moonbit
p.place_slotted(artboard="page", component_id="modal", instance_id="dialog")
p.fill_slot(artboard="page", instance_id="dialog", slot_name="title", content="Confirm")
p.fill_slot(artboard="page", instance_id="dialog", slot_name="content", content="Are you sure?")
p.fill_slot_with_component(artboard="page", instance_id="dialog",
  slot_name="actions", child_component="button", child_id="ok_btn")  // recursive composition
```

**6 composable components**:

| Component | Slots | Layout |
|:---|:---|:---|
| `card` | header / content / footer | vertical, gap=8, padding=16 |
| `list` | header / item_1..3 | vertical, gap=4 |
| `form_field` | label / input / error | vertical, gap=4 |
| `modal` | title / content / actions | vertical, gap=16, padding=24 |
| `app_bar` | leading / title / trailing | horizontal, gap=12 |
| `tab_bar` | tab_1..4 | horizontal, gap=0 |

**Key capabilities**:
- **Default content**: empty slots auto-fill defaults (Card header → "Title")
- **Recursive composition**: `fill_slot_with_component` puts a Button into the Modal's actions slot
- **Slot inspection**: `list_slots` returns every slot and its current content

## Performance Benchmark Engine

After the agent produces a design, the engine answers "will this design run well":

```moonbit
let bench = p.benchmark_artboard(artboard="dashboard")
// → { nodes: 15, depth: 3, fill: 8, hug: 2, score: 85 }

let proj = p.benchmark()
proj.report()
// → Performance Benchmark Report
//   Overall: B (72/100)
//   Total nodes: 45
//   [dashboard] 15 nodes, depth 3, 8 Fill, 2 Hug, score 85/100
//   [login] 10 nodes, depth 2, 3 Fill, 1 Hug, score 90/100

p.suggest_optimizations(artboard="dashboard")
// → {"optimizations":1,"detail":[{"type":"reduce_fill","description":"8 Fills; fixed sizes would reduce solve work"}]}
```

**Benchmark metrics**:

| Metric | Meaning | Anti-pattern threshold |
|:---|:---|:---|
| node_count | Total nodes | > 100 |
| max_depth | Max tree depth | > 8 |
| fill_node_count | Fill nodes (layout solve cost) | > 30 |
| hug_node_count | Hug nodes (highest cost) | > 20 |
| avg_children | Average children per node | > 15 |
| layout_complexity | Layout solve operation count | - |
| svg_bytes | SVG render output bytes | - |
| memory_estimate | Memory estimate (nodes×200 + text×2) | - |

**Scoring** (0–100): node count(30) + depth(25) + Fill(25) + Hug(20) → A/B/C/D

## Dual Gates and Visual Debt

The two editing routes apply different merge thresholds to the same set of non-crash predicates (P0–P4) (`core/policy.mbt`):

| | HumanGate (`export-mbt-human` / `apply-human-mbt-op-b64`) | AgentGate (`export-mbt-agent` / `apply-agent-mbt-op-b64` / `render-mbt-b64`) |
|---|---|---|
| Structural predicates (lost nodes/empty artboard/broken flows) | **Hard block** — the patch is rejected as a whole | **Hard block** |
| Visual predicates (overflow/overlap/contrast) | Soft warning — merge allowed, violations recorded as **visual debt** | **Hard block** — any violation rejects the whole patch |
| Typical shape | Mid-drag canvas states can be saved with debt | Programmatic edits must be right in one shot |

- **Debt is not an error**: the human route's export carries the current visual debt list in the `debt` field; Studio surfaces it as a badge, and later edits or `auto_fix` can repay it.
- **The agent's responsibility boundary**: zero tolerance on the agent route — the engine returns a Reject with the blocking violation list (artboard + predicate name + details), and the agent fixes and replays the patch; this guarantees agent writes never degrade document quality.
- **Render is acceptance**: `render-mbt-b64` fully rebuilds from source at AgentGate level — products of both routes pass the same render acceptance.

## Integration Overview

Six integration routes, the same `.mbt.md` fact source, the same dual gates:

| Route | Shape | Fits |
|---|---|---|
| **CLI line protocol** | `moon run --target native cli` (newline-framed JSON; one process = one stateful Project session) | Scripts, CI, manual driving |
| **MCP** | `npx -y moonviz-mcp` (prebuilt platform binary, stdio JSON-RPC) or `moon run --target native mcp` | Claude Desktop / ZCode / Cursor and other MCP clients |
| **Node SDK** | npm `moonviz-engine-sdk` (spawns the CLI: sessions/Project builder/dual-gate ops/DDP bridge) | Node-hosted backends/toolchains |
| **WASM SDK** | npm `moonviz-engine-wasm` (wasm-gc in-process render/validate, JS String passthrough) | Browsers, Edge Functions, dependency-free rendering on Node ≥22 |
| **SKILL** | Repo-root `SKILL.md` (agent operation spec: fact-source discipline/dual-gate semantics/red lines) | Any coding agent's skill mount |
| **DDP container** | Rust `ddp_codec` (DDP1 encrypted / DDP2 keyless) | Encrypted design distribution, read-only viewers |
| **WASM (classic)** | `moon build --target wasm` — pure WASM MVP (0 imports, linear memory), consumed by wasmtime/wasmi and any spec-compliant runtime | Rust hosts, server-side embedding |

Every `engine-v*` tag publishes the **full artifact set** to GitHub Releases: 4 platform binary tarballs + both wasm builds (versioned, e.g. `moonviz-wasm-gc-0.1.1.wasm` / `moonviz-wasm-classic-0.1.1.wasm`) + the current npm package tarballs. Distribution does not depend on npm alone.

MCP client configuration (npx prebuilt route):

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

Environment variable cheat sheet: `MOONVIZ_DIR` (engine root, must contain `cli/moon.pkg`) · `MOONVIZ_MOON`/`MOON` (moon executable directory) · `MOONVIZ_DDP_HELPER` (full path to ddp_codec) · `MOONVIZ_CLI_BIN` (prebuilt CLI binary, takes precedence over `moon run`).

## Tech Stack and Binary Distribution

### The rendering pipeline in one sentence

One `.mbt.md` → declaration parsing (literate block scanning) → scene graph (node tree + Fixed/Fill/Hug size specs) → **two-pass layout solve** (sizes first, positions second; failure ≠ crash) → P0–P4 non-crash predicates + dual-gate acceptance → three pure-MoonBit render backends: **SVG** (the vector main path: system font stack + elevation shadow tokens + gradient paints), **PNG** (a homegrown software rasterizer: 2x supersampled AA + rounded-corner scanning + a 5×7 bitmap font + pure-MoonBit DEFLATE, 5–20× smaller output), and a **terminal ANSI true-color canvas** (camera pan/zoom + pick & drag). Any host backend (Canvas/Skia/OpenGL) integrates through the backend-agnostic **RenderPlan display list**. The full pipeline is documented in [docs/10-render-pipeline.md](docs/10-render-pipeline.md).

### Stack composition

| Layer | Technology | External dependencies |
|---|---|---|
| Engine kernel + three render backends + CLI/MCP | **100% MoonBit** | `moonbitlang/core` standard library only |
| WASM boundary | MoonBit → wasm-gc | none (JS String Builtins) |
| DDP codec | Rust (standalone ddp_codec process) | argon2 / chacha20poly1305 / zstd |
| npm launcher / Node SDK | very thin JS | zero dependencies |

### Binary distribution: moon exists only at compile time

`moon build --release --target native` produces **self-contained binaries** (CLI 1.26MB / MCP 1.10MB; `otool -L` verifies they link only the system libc). Copy them to a machine without moon or sources and they just work. Distribution matrix:

| Consumer | Needs moon? | Needs engine sources? |
|---|---|---|
| `npx moonviz-mcp` (MCP clients) | ✗ | ✗ (source-side tools set MOONVIZ_DIR) |
| Node SDK + `moonviz-bin-<platform>` | ✗ (auto-discovers the prebuilt CLI) | ✗ |
| Browsers / Edge (moonviz-engine-wasm) | ✗ | ✗ |
| Engine developers | ✓ | ✓ |

Binary archives are also published on GitHub Releases (`engine-v*` tags), so distribution does not depend on npm alone.

### MoonBit toolchain risk management

MoonBit evolves fast; minor versions carry real behavioral risk. Four layers of mitigation:

1. **Artifact freezing** (the fundamental measure): prebuilt binaries and WASM are snapshotted once released — later breaking toolchain changes cannot affect any distributed artifact; language uncertainty is isolated at build time.
2. **Build toolchain**: CI (`binaries.yml`) installs the **latest** moon (pinned versions have been pulled from the download CDN); toolchain upgrades are exercised by the full test suite + CLI/MCP smoke gates on every build.
3. **Protocol stability**: external protocols such as `SolvedLayout` / `GateDecision` / `RenderPlan` are deliberately stable (the solver reserves a Cassowary swap interface) and do not drift with language versions.
4. **Component isolation as backstop**: DDP already demonstrates the standalone-process route for non-MoonBit components; in the extreme, any component can be replaced that way without touching the `.mbt.md` fact-source format.

## Architecture Red Lines

- **The engine depends on no client**: core/decl are pure libraries
- **Agents have zero dependency on the engine internals**: interaction happens over the JSON text protocol
- **100% MoonBit**: zero hand-written JS/Node/frontend code

## Documentation Index

- Website and full usage docs: https://asdshuaishuai.github.io/moonviz/ (usage / CLI / Node SDK / WASM / MCP / SKILL / DDP)

1. [01-architecture.md](docs/01-architecture.md) — Layered architecture
2. [02-mbtmd-format.md](docs/02-mbtmd-format.md) — The `.mbt.md` spec and the declaration DSL
3. [03-scene-graph.md](docs/03-scene-graph.md) — The visual document model
4. [04-layout-and-predicates.md](docs/04-layout-and-predicates.md) — Layout engine and non-crash predicates
5. [05-sync-pipeline.md](docs/05-sync-pipeline.md) — Bidirectional incremental sync pipeline
6. [06-render.md](docs/06-render.md) — Render backends
7. [07-agent-loop.md](docs/07-agent-loop.md) — Agent workflow and error-fix loop
8. [08-roadmap-risks.md](docs/08-roadmap-risks.md) — Implementation path and risks
9. [09-rendering-ecosystem.md](docs/09-rendering-ecosystem.md) — MoonBit rendering ecosystem survey
10. [10-render-pipeline.md](docs/10-render-pipeline.md) — **Complete technical notes on the rendering scheme and pipeline** (declaration parsing → layout → predicates → SVG/PNG/terminal backends + tech stack + binary distribution and toolchain risk)
