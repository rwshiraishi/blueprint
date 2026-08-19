# Design deliverables — the acceptance contract

Phase 3 of `app-blueprint` produces the visual half of the build contract. This file says what
"done" means for each design deliverable, exhaustively enough that a build agent working alone at
3am cannot satisfy the letter of the spec while producing something thin.

The failure this file exists to prevent: SKILL.md says "tokens file (every value, drop-in CSS)"
and "per-screen spec with exact copy". Those are statements of *intent*. An agent reading them
invents a plausible `DESIGN_TOKENS.md` with twelve colors and three spacing values, ships it, and
the build then invents the other four hundred decisions inline — inconsistently, in forty files,
with no authority to appeal to. Intent does not constrain. A field list does.

So: every section below is an acceptance checklist. If a required item is absent, the deliverable
is not done, and Phase 8's pre-flight audit should catch it. Treat missing items as build
blockers, not as todos.

## §0 — How this file relates to the other design skills

This file does not teach design. It specifies output. The craft lives in dedicated skills, and
duplicating them here would guarantee two drifting copies of the same algorithm.

| Need | Skill that owns it | What this file adds |
|---|---|---|
| Color ramp generation, type scale math, WCAG contrast computation, export formats | `design-system` (`references/token-generation.md`) | The *required token inventory* the ramp must fill, and the contrast pairs that must be verified |
| Component file structure, atomic hierarchy, naming, variant patterns | `design-system` (`references/component-architecture.md`) | The *required matrix* (variant × size × state) and the required component inventory |
| Every string in the UI — labels, errors, empty states, buttons | `writing-for-interfaces` | The rule that copy in `SCREENS.md` is final, never placeholder |
| Preset palette + font pairings for one-off artifacts | `theme-factory` | Nothing; if the product needs a durable token system, `theme-factory` is the wrong tool |
| iOS conventions, navigation patterns, platform idioms | `apple-hig-expert` | Which HIG decisions must be *recorded as tokens* rather than left implicit |
| iOS 26+ material system | `liquid-glass-design` | The requirement to declare a fallback path for pre-26 |
| Brand voice, logo usage, brand color meaning | `brand-guidelines` / `brand-voice` | The boundary between brand assets and product tokens |
| The audit pass over finished screens | `design-review` | The definition-of-done the audit is run against |
| Whole-frontend visual direction, "not generic AI UI" | `frontend-design` | Nothing; that skill is the sibling entry point, this is the acceptance contract |

**Dispatch, don't reimplement.** When Phase 3 needs a ramp, say "generate the ramp with the
`design-system` skill" and then check the output against §2 here. When it needs button copy, say
"draft with `writing-for-interfaces`" and check against §6. If you find yourself writing an
algorithm in a `docs/` file, you have crossed into another skill's territory — link instead.

## §1 — Platform matrix (decide this before writing a single token)

Platform is the first design decision and it is never an assumption. A CSS custom-property file
handed to an iOS build is inert. A breakpoint scale handed to a native app is meaningless, but a
size-class scale is not. Getting this wrong is not a formatting problem; it is a whole deliverable
that has to be rewritten.

State the platform explicitly in `DESIGN_SYSTEM.md` §0, in the same breath as the precedence
chain. If the product ships on two platforms, say which is primary and which adapts — "both are
equal" is how you get two half-designed products.

### The matrix

| | **Responsive web** | **Native iOS** | **Native Android** | **Cross-platform (RN / Flutter)** | **Desktop (Electron / Tauri / native)** | **SaaS app shell** |
|---|---|---|---|---|---|---|
| **Token output format** | CSS custom properties on `:root`, plus a `@media (prefers-color-scheme: dark)` block or `[data-theme]` swap | Swift constants or an asset catalog: `Color` set with Any/Dark appearances, `UIFont.TextStyle` mappings | Kotlin `object` constants + `res/values/` XML, or a Compose `MaterialTheme` extension | One JSON source of truth + generated per-platform adapters (see §4.4) | CSS custom properties, plus OS-level accent/vibrancy hooks | CSS custom properties **plus** a documented tenant-overridable subset (§4.6) |
| **Adaptive axis** | Breakpoints in `px`/`rem` (`sm`…`2xl`) + container queries | Size classes (compact/regular × horizontal/vertical) + `.dynamicTypeSize` | Window size classes (compact/medium/expanded) + density buckets | Both; the shared token file carries neither — adapters do | Window size + multi-window; no assumption of full-screen | Breakpoints **and** a density mode toggle (comfortable/compact) |
| **Type scale** | Fluid `clamp()` ramp, `rem`-based | Dynamic Type ramp mapped to text styles; **never** fixed `pt` for body copy | `sp` units with `fontScale` respected; **never** `dp` for text | Shared semantic names, per-platform resolution | `rem` ramp; respect OS text-size setting where the shell exposes it | Two ramps: default and compact-density |
| **Dark mode** | Token swap under `prefers-color-scheme` / explicit `[data-theme]` | Semantic colors with Any/Dark appearance in the asset catalog; free at runtime | `values-night/` or M3 dark color scheme | Token swap in shared layer, resolved per platform | Token swap + respect OS setting including "auto at sunset" | Token swap **and** tenant-brand interaction rules (§4.6) |
| **Elevation** | `box-shadow` scale, 5–6 levels | Layering + material blur; iOS uses shadow sparingly and prefers grouping | M3 **tonal** elevation (surface tint by level) + optional shadow | Both; shadow values do not port | Shadow scale; heavier than mobile is idiomatic | Shadow scale, restrained; data density punishes heavy shadow |
| **Touch/pointer** | Both: `@media (hover: hover)` gates hover states | Touch only (plus pointer on iPadOS with a pointer connected) | Touch only (plus desktop mode / ChromeOS) | Both; hover must degrade | Pointer primary; keyboard is a first-class input | Pointer primary, keyboard heavy, touch on tablet |
| **Min target** | 24×24 CSS px (WCAG 2.2 AA `2.5.8`); 44×44 recommended | 44×44 pt (HIG) | 48×48 dp (Material) | Take the **larger** of the two per platform | 24×24 px, but pointer precision allows tighter | 24×24 px minimum; 32×32 for primary actions |
| **Deliverables that change shape** | `PROTOTYPE.html` is real and runnable | No HTML prototype; deliver a SwiftUI preview file or annotated screenshots instead | Compose preview file or annotated screenshots | Prototype in whichever runtime ships first | HTML prototype if web-tech shell; otherwise screenshots | Prototype includes the shell chrome, not just one screen |
| **Deliverables that get added** | — | `HIG_CONFORMANCE.md` (§4.2) | `MATERIAL_CONFORMANCE.md` (§4.3) | `PLATFORM_ADAPTERS.md` (§4.4) | Window-state spec (§4.5) | `APP_SHELL.md` (§4.6), keyboard map, tenant theming boundary |
| **Deliverables that drop** | — | `MOTION.md` keeps timing but drops CSS easing syntax for `Animation` curves | Same, with M3 motion tokens | — | — | — |

### The rule this matrix enforces

**A token file must be consumable by the target runtime without translation.** If the build agent
has to convert `--color-surface-raised: #F8FAFC` into a `Color` asset by hand, you have shipped a
web token file and called it cross-platform. Ship the format the runtime eats — or ship the JSON
source *plus* the generated adapters, never the JSON alone.

Record the platform decision as `D-UI-1` in `DESIGN_SYSTEM.md` with the alternatives you rejected.
"Web first, native later" and "native first, web later" produce materially different token files,
and the second one is much harder to retrofit.

## §2 — `DESIGN_TOKENS.md` required contents

This is the visual truth file. Per the precedence chain in `document-set.md`, it beats every other
visual document, so it must be complete: an incomplete token file does not fail loudly, it fails by
delegating four hundred decisions to whoever writes the next component.

**The blocking rule.** A token referenced anywhere in `SCREENS.md`, `MOTION.md`, or a component
spec but absent from `DESIGN_TOKENS.md` is a build blocker, not a warning. Phase 8 should grep for
`var(--` and `token.` references across `docs/` and diff the set against the token file's
definitions; any name in the first set and not the second exits nonzero. This is the same
mechanical-sweep discipline as `scripts/id-sweep.sh` for FR IDs, applied to visual names.

**The second blocking rule.** Every color token has both a light value and a dark value, on the
same line, in the same table. Dark mode is a *token swap*, never a second palette. Two independent
palettes drift within one sprint: someone adds `--color-warning-subtle` to light and forgets dark,
and the dark build renders transparent or inherits something arbitrary. One table with two value
columns makes the omission visible at authoring time.

### 2.1 Color — semantic roles

Generate the underlying ramps with the `design-system` skill (it owns the HSV/OKLCH stepping and
the contrast math). This section specifies what the ramps must be *wired into*. Raw ramp steps
(`--slate-500`) are the private layer; components consume only semantic names.

Every role below must exist with a concrete value. "We'll use the 500 step" is not a value.

**Surface / background layers.** Products need more than one background or every card looks like
the page. Four layers is the working minimum; a data-dense SaaS usually wants five.

| Token | Role | Light (illustrative) | Dark (illustrative) |
|---|---|---|---|
| `--color-surface-base` | App canvas, furthest back | `#FFFFFF` | `#0B0F14` |
| `--color-surface-sunken` | Wells, inset areas, code blocks | `#F1F5F9` | `#070A0E` |
| `--color-surface-raised` | Cards, panels, list rows | `#F8FAFC` | `#141A21` |
| `--color-surface-overlay` | Modals, popovers, menus | `#FFFFFF` | `#1B222B` |
| `--color-surface-inverse` | Tooltips, high-contrast callouts | `#0B0F14` | `#F8FAFC` |

Note the dark column inverts the *ordering* logic, not just the values: in light mode raised
surfaces get lighter, in dark mode they get lighter too. Raised is never darker than base in either
theme, because elevation reads as "closer to the light" in both. Getting this backwards in dark
mode is the single most common dark-theme bug.

**Text hierarchy.** Three levels minimum, plus the inverse and the link.

| Token | Role | Light | Dark | Must contrast against |
|---|---|---|---|---|
| `--color-text-primary` | Headlines, body copy | `#0F172A` | `#F1F5F9` | every surface layer |
| `--color-text-secondary` | Supporting copy, labels | `#475569` | `#A9B4C2` | base, raised, overlay |
| `--color-text-tertiary` | Metadata, timestamps, hints | `#64748B` | `#8593A3` | base, raised |
| `--color-text-disabled` | Disabled control labels | `#94A3B8` | `#5B6673` | base, raised (3:1, see note) |
| `--color-text-inverse` | On inverse surfaces and filled buttons | `#FFFFFF` | `#0B0F14` | inverse surface, brand-solid |
| `--color-text-link` | Inline links | `#1D4ED8` | `#7EA6FF` | base, raised |
| `--color-text-link-visited` | Visited links (content sites) | `#6D28D9` | `#B79CFF` | base, raised |

Disabled text is exempt from the 4.5:1 requirement under WCAG 1.4.3 (disabled controls are not
"text" for contrast purposes), but shipping it below 3:1 makes disabled states unreadable for
low-vision users who still need to know what the control *says*. Hold 3:1 and record the choice.

**Border and divider.** Separate tokens, because a divider between list rows and the border of a
focused input are not the same weight of statement.

| Token | Role | Light | Dark |
|---|---|---|---|
| `--color-border-subtle` | Dividers, table row rules | `#E2E8F0` | `#222A34` |
| `--color-border-default` | Input borders, card outlines | `#CBD5E1` | `#2E3844` |
| `--color-border-strong` | Emphasis outlines, active table headers | `#94A3B8` | `#48566A` |
| `--color-border-inverse` | Borders on inverse surfaces | `#334155` | `#CBD5E1` |

`--color-border-default` must reach **3:1** against the surface it sits on (WCAG 1.4.11, non-text
contrast), because an input whose boundary is invisible is an input a user cannot find.

**Interactive states.** Every interactive color role needs the full set. Specify them as tokens,
not as "darken by 10%" — runtime color math is a source of inconsistency and of accidental contrast
failures, and it cannot be verified statically.

| Token family | Members | Notes |
|---|---|---|
| `--color-action-primary-{default,hover,active,disabled}` | 4 | Filled primary button background |
| `--color-action-primary-fg-{default,disabled}` | 2 | Text on the above |
| `--color-action-secondary-{default,hover,active,disabled}` | 4 | Tonal/secondary fill |
| `--color-action-secondary-fg-{default,disabled}` | 2 | |
| `--color-action-ghost-{hover,active}` | 2 | Ghost/text buttons have no default fill |
| `--color-action-destructive-{default,hover,active,disabled}` | 4 | See LOCKED below |
| `--color-action-destructive-fg` | 1 | |
| `--color-selected-bg` / `--color-selected-fg` / `--color-selected-border` | 3 | Selected rows, chips, nav items |

Worked (illustrative) values for the primary family, light mode: `#2563EB` default, `#1D4ED8`
hover, `#1E40AF` active, `#93C5FD` disabled, foreground `#FFFFFF`. In dark mode the *ordering
inverts for hover*: hover goes lighter (`#3B82F6`), not darker, because "darker" on a dark surface
reads as recessed rather than engaged.

**Status / feedback.** Five roles, each with three tints: a solid (for badges and icons), a subtle
background (for banners), and a border.

| Role | Solid | Subtle bg | Border | Foreground on subtle |
|---|---|---|---|---|
| `success` | `--color-status-success` | `--color-status-success-bg` | `--color-status-success-border` | `--color-status-success-fg` |
| `warning` | same pattern | | | |
| `danger` | same pattern | | | |
| `info` | same pattern | | | |
| `neutral` | same pattern | | | |

Illustrative light values for `danger`: solid `#DC2626`, bg `#FEF2F2`, border `#FECACA`, fg
`#991B1B`. Dark: solid `#F87171`, bg `#2A1416`, border `#5B2225`, fg `#FCA5A5`.

**Focus ring.** Its own token family, never reusing the brand color by accident — the focus ring
must be visible against *every* surface and against every interactive fill, including the primary
button it may land on.

| Token | Role | Requirement |
|---|---|---|
| `--color-focus-ring` | Ring color | ≥3:1 against every adjacent surface AND against the focused element's own fill |
| `--color-focus-ring-offset` | Halo between element and ring | Usually the surface color, so the ring reads on filled buttons |
| `--focus-ring-width` | Thickness | ≥2px; 3px if the ring color is low-chroma |
| `--focus-ring-offset-width` | Gap | 2px typical |

A single focus ring color rarely clears 3:1 against both a white card and a saturated primary
button. The standard fix is the offset ring (ring + contrasting halo). Specify both tokens or the
build will ship a ring that vanishes on primary buttons.

**Overlay / scrim.**

| Token | Role | Light | Dark |
|---|---|---|---|
| `--color-scrim` | Behind modals and drawers | `rgba(15,23,42,0.45)` | `rgba(0,0,0,0.65)` |
| `--color-scrim-light` | Loading veils over content | `rgba(255,255,255,0.72)` | `rgba(11,15,20,0.72)` |
| `--color-backdrop-blur` | Blur radius if used | `12px` | `12px` |

The dark scrim is *stronger*, not weaker. A 0.45 scrim over a dark UI barely separates the modal
from the page.

**Data-visualization palette.** If the product charts anything, the categorical sequence, the
sequential ramp, and the diverging ramp are tokens too, and they are the tokens most often
forgotten until the first chart is built inline with arbitrary hexes. Name them
`--color-chart-1` … `--color-chart-n` (categorical), `--color-chart-seq-{1..9}`,
`--color-chart-div-{neg-4..pos-4}`. Categorical series must be distinguishable at 3:1 from each
other *and* survive the common color-vision deficiencies — dispatch the palette construction to
the `dataviz` skill and record its output here.

### 2.2 LOCKED tokens — the semantics tenants must not theme

Some colors carry meaning, not style. If a tenant can re-map "danger" to their brand green, the
product now ships a destructive-confirm dialog that reads as safe. That is a safety defect wearing
a theming feature's clothes.

Mark these **LOCKED** in the token file, in a dedicated column, and enforce it in the theming API
(the override map rejects locked keys — a test asserts the rejection).

| Locked family | Why |
|---|---|
| `--color-status-danger-*`, `--color-action-destructive-*` | Destructive intent must be recognizable across every tenant |
| `--color-status-warning-*` | Same |
| `--color-status-success-*` | Confirmation must not be confusable with failure |
| `--color-focus-ring` (hue may vary, contrast floor may not) | Accessibility requirement, not a style choice |
| Confidence / quality encodings (e.g. `--color-confidence-{low,med,high}`) | The encoding *is* the information |
| `--color-text-*` contrast floors | A tenant may set the hue; the computed ratio is validated and rejected below threshold |

The rule to write down: **a tenant may change hue and chroma within a validated contrast envelope;
a tenant may never change which semantic role a color is bound to.** State the validation function
and where it runs (server-side at theme save, plus a test).

### 2.3 The contrast pairs that must be verified

Do not write "meets WCAG AA." Write the pairs and the ratio each must hit, and produce the
computed table as an artifact. `design-system` owns the computation; this is the required coverage.

| Pair | Minimum | Standard |
|---|---|---|
| `text-primary` on each of the 5 surface layers | 4.5:1 | 1.4.3 |
| `text-secondary` on base, raised, overlay | 4.5:1 | 1.4.3 |
| `text-tertiary` on base, raised | 4.5:1 | 1.4.3 |
| `text-inverse` on `surface-inverse`, on `action-primary-default`, on `action-destructive-default` | 4.5:1 | 1.4.3 |
| Large display type (≥24px, or ≥18.66px bold) on its surface | 3:1 | 1.4.3 |
| `border-default` on base and raised | 3:1 | 1.4.11 |
| `focus-ring` on every surface + every action fill | 3:1 | 1.4.11 |
| Each status solid on its own subtle bg | 4.5:1 (if it carries text) / 3:1 (icon only) | 1.4.3 / 1.4.11 |
| Icon-only affordances against their surface | 3:1 | 1.4.11 |
| Adjacent categorical chart colors | 3:1 | 1.4.11 |
| Every pair above, **in both themes** | as listed | — |

Ship the computed table into `DESIGN_TOKENS.md` with actual ratios (`text-secondary` on
`surface-raised`: **7.21:1** ✓). A ratio column full of ✓ with no numbers means nobody computed it.

### 2.4 Typography

**Family stacks**, with real fallbacks, one line each:

```
--font-sans: "Inter var", Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
             "Helvetica Neue", Arial, sans-serif;
--font-serif: "Source Serif 4", Georgia, "Times New Roman", serif;
--font-mono:  "JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
```

(Illustrative. Substitute the product's actual choices; if the brand has a licensed face, confirm
the license covers web embedding and app embedding separately — they are different grants.)

**The scale as a table.** Every row: token, rem, px at 16px root, line-height (unitless), weight,
letter-spacing, intended use. Unitless line-height, because a fixed `px` line-height breaks the
moment the user scales text.

| Token | rem | px | Line-height | Weight | Tracking | Use |
|---|---|---|---|---|---|---|
| `--text-display` | 3.000 | 48 | 1.05 | 700 | -0.02em | Marketing hero only |
| `--text-h1` | 2.250 | 36 | 1.15 | 700 | -0.02em | Screen headline band (P0) |
| `--text-h2` | 1.750 | 28 | 1.20 | 650 | -0.015em | Section heading |
| `--text-h3` | 1.375 | 22 | 1.30 | 600 | -0.01em | Subsection, card title |
| `--text-h4` | 1.125 | 18 | 1.40 | 600 | 0 | Group label, dense heading |
| `--text-body-lg` | 1.125 | 18 | 1.60 | 400 | 0 | Lede paragraph |
| `--text-body` | 1.000 | 16 | 1.55 | 400 | 0 | Default body |
| `--text-body-sm` | 0.875 | 14 | 1.50 | 400 | 0 | Dense body, table cells |
| `--text-label` | 0.875 | 14 | 1.30 | 550 | 0.01em | Form labels, buttons |
| `--text-caption` | 0.8125 | 13 | 1.40 | 400 | 0.01em | Metadata, helper text |
| `--text-overline` | 0.6875 | 11 | 1.30 | 650 | 0.08em | Eyebrow labels, all-caps |
| `--text-code` | 0.875 | 14 | 1.55 | 400 | 0 | Inline and block code |

Generate the ratio with `design-system`; record which ratio you used and why (a 1.25 major third
is calm and works in dense UI; a 1.333 perfect fourth is more dramatic and starts colliding in
tables). Never ship a scale with two steps under 2px apart — the distinction is invisible and
someone will use them interchangeably.

**Fluid behavior.** Say explicitly whether the ramp is fluid, and where it clamps. A fluid ramp
that never stops growing produces a 96px headline on an ultrawide monitor.

```
--text-h1: clamp(1.75rem, 1.25rem + 2.5vw, 2.25rem);
```

On native, "fluid" is the wrong model: iOS uses Dynamic Type (§4.2), Android uses `sp` with
`fontScale` (§4.3). Say which model applies and delete the other.

**Font loading and the FOUT/FOIT decision.** This is a design decision with a measurable
performance cost, so it belongs in the token file, not in someone's webpack config.

Record: (1) `font-display` value and why; (2) preload list — which weights/subsets get
`<link rel=preload>`; (3) whether a variable font replaces multiple static weights; (4) the
fallback metric override (`size-adjust`, `ascent-override`) that keeps the layout from shifting
when the real face arrives; (5) the self-host vs. CDN decision, with the privacy implication
noted if the product has EU users.

Default recommendation, stated with its reason: `font-display: swap` plus a metric-matched
fallback. FOIT (`block`) hides content for up to 3s and reads as a broken page; unmatched swap
causes a visible reflow that costs CLS. Metric-matched swap gets text on screen immediately with
near-zero layout shift. If the brand cannot tolerate a flash of the fallback face, say so and
accept the CLS cost explicitly — do not leave it to the build to discover.

**Tabular numerals — the rule.** Any place numbers are compared vertically or update in place
(tables, dashboards, timers, currency columns, price lists, metric tiles) must set
`font-variant-numeric: tabular-nums`. Proportional digits make a column of numbers ragged and make
a live-updating counter jitter. Ship it as a token (`--font-numeric-tabular`) and name the
components that must apply it in §3, rather than hoping.

Also specify: `font-variant-numeric: slashed-zero` where zero/O confusion matters (IDs, codes,
keys), and whether the face has real small caps or needs synthesis (synthesized small caps look
bad; if the face lacks them, do not use them).

### 2.5 Spacing

One scale, geometric enough to be memorable, dense enough to be usable. 4px base.

| Token | px | rem | Typical use |
|---|---|---|---|
| `--space-0` | 0 | 0 | Reset |
| `--space-px` | 1 | 0.0625 | Hairlines |
| `--space-1` | 4 | 0.25 | Icon-to-label gap |
| `--space-2` | 8 | 0.5 | Dense stack, chip padding |
| `--space-3` | 12 | 0.75 | Control inner padding |
| `--space-4` | 16 | 1 | Default gap, card padding (compact) |
| `--space-5` | 20 | 1.25 | |
| `--space-6` | 24 | 1.5 | Card padding (comfortable), section gap |
| `--space-8` | 32 | 2 | Between related groups |
| `--space-10` | 40 | 2.5 | |
| `--space-12` | 48 | 3 | Between sections |
| `--space-16` | 64 | 4 | Page block rhythm |
| `--space-20` | 80 | 5 | |
| `--space-24` | 96 | 6 | Marketing section rhythm |

Do not ship both `--space-5` and a habit of writing `18px` inline. State the rule: **any spacing
value not in this scale is a review failure**, enforced by a stylelint rule or a grep in CI.

### 2.6 Sizing

Control heights are their own scale, because they must align across button/input/select in a row.

| Token | px | Use |
|---|---|---|
| `--size-control-xs` | 24 | Inline table actions, dense chips |
| `--size-control-sm` | 32 | Toolbar controls, compact density |
| `--size-control-md` | 40 | Default control height |
| `--size-control-lg` | 48 | Primary CTA, touch-first surfaces |
| `--size-icon-{xs,sm,md,lg,xl}` | 12/16/20/24/32 | |
| `--size-avatar-{xs,sm,md,lg,xl}` | 20/24/32/40/64 | |
| `--size-touch-min` | 44 | Minimum hit area, may exceed visual size |

Note the last one: a 24px icon button may have a 44px hit area via padding or a pseudo-element.
Visual size and target size are different tokens and conflating them is how you ship a compliant-
looking design that fails 2.5.8.

### 2.7 Radius

| Token | px | Use |
|---|---|---|
| `--radius-none` | 0 | Tables, full-bleed |
| `--radius-sm` | 4 | Chips, tags, inline code |
| `--radius-md` | 8 | Buttons, inputs, small cards |
| `--radius-lg` | 12 | Cards, panels |
| `--radius-xl` | 16 | Modals, sheets |
| `--radius-2xl` | 24 | Marketing surfaces |
| `--radius-full` | 9999 | Pills, avatars, switches |

State the nesting rule: an inner radius should be `outer − padding` to stay concentric. A 12px card
with 8px padding wants an 4px inner radius, not another 12px. Without this rule you get the
"squircle inside a squircle" tell that reads as unconsidered.

### 2.8 Border width

`--border-width-{0,hairline,default,thick}` = `0 / 1px / 1px / 2px`. Hairline and default are
separate names even at the same value, because hairline means "should be a device pixel on retina"
and a native build resolves it differently (`1/UIScreen.main.scale`).

### 2.9 Elevation / shadow

Exact values per level, both themes. In dark mode shadows barely read, so dark elevation is
carried by *surface lightness plus a subtle border* — state that, or dark mode will look flat.

| Token | Light value | Dark value | Use |
|---|---|---|---|
| `--shadow-none` | `none` | `none` | Flush elements |
| `--shadow-xs` | `0 1px 2px rgba(15,23,42,0.06)` | `0 1px 2px rgba(0,0,0,0.5)` + `--color-border-subtle` | Resting cards |
| `--shadow-sm` | `0 1px 3px rgba(15,23,42,0.10), 0 1px 2px rgba(15,23,42,0.06)` | `0 1px 3px rgba(0,0,0,0.6)` + border | Raised cards |
| `--shadow-md` | `0 4px 8px rgba(15,23,42,0.10), 0 2px 4px rgba(15,23,42,0.06)` | `0 4px 8px rgba(0,0,0,0.65)` + border | Dropdowns, popovers |
| `--shadow-lg` | `0 12px 20px rgba(15,23,42,0.12), 0 4px 8px rgba(15,23,42,0.08)` | `0 12px 20px rgba(0,0,0,0.7)` + border | Modals |
| `--shadow-xl` | `0 24px 40px rgba(15,23,42,0.16)` | `0 24px 40px rgba(0,0,0,0.75)` + border | Full-screen sheets |
| `--shadow-focus` | see `--focus-ring-*` | same | Never a shadow level; separate concern |

Two-layer shadows (a tight contact shadow + a soft ambient one) look materially better than one
blurred blob. If you ship single-layer shadows, say it was deliberate.

### 2.10 Z-index scale with named layers

Unnamed z-index is where every UI eventually breaks: a tooltip inside a modal renders behind the
scrim and nobody can explain why. Name every layer, leave gaps, and forbid literals.

| Token | Value | Layer |
|---|---|---|
| `--z-base` | 0 | Document flow |
| `--z-raised` | 10 | Sticky table headers, raised cards |
| `--z-sticky` | 100 | Sticky page headers, sub-navs |
| `--z-nav` | 200 | App shell nav, sidebar |
| `--z-dropdown` | 300 | Menus, comboboxes, date pickers |
| `--z-scrim` | 400 | Modal/drawer backdrop |
| `--z-modal` | 500 | Dialogs, drawers, sheets |
| `--z-popover` | 600 | Popovers anchored above modals |
| `--z-tooltip` | 700 | Tooltips (always on top of popovers) |
| `--z-toast` | 800 | Transient notifications |
| `--z-devtool` | 9000 | Debug overlays, never in prod builds |

Rule: **no raw z-index literals in component code**, grep-enforced. And record the stacking-context
hazard: a parent with `transform`, `filter`, `opacity < 1`, `will-change`, or `contain` creates a
new stacking context and the child's z-index becomes local. Layer tokens do not save you from that;
portals do. Say which overlay components must portal to `body`.

### 2.11 Breakpoints, containers, grid

Web only (see §4.1 and §4.2/§4.3 for the native equivalents).

| Token | Min-width | Target |
|---|---|---|
| `--bp-sm` | 640px | Large phone landscape |
| `--bp-md` | 768px | Tablet portrait |
| `--bp-lg` | 1024px | Tablet landscape / small laptop |
| `--bp-xl` | 1280px | Desktop |
| `--bp-2xl` | 1536px | Large desktop |

Containers: `--container-sm/md/lg/xl/2xl` = `640/768/1024/1152/1280px`, plus
`--container-prose: 68ch` (measure, not pixels — line length is a typographic constraint, and 45–75
characters is the readable band) and `--container-full: 100%`.

Grid: columns per breakpoint (4 / 8 / 12 is standard), `--grid-gutter` per breakpoint, and
`--grid-margin` (page edge inset) per breakpoint. State whether the product uses a strict column
grid at all — many app UIs use flex + container queries and a column grid is decoration. Saying
"12-column grid" and then never using it is worse than saying "no formal grid; layout is
flex/auto-grid with `--space-*` gaps."

**Container queries.** If components must adapt to their container rather than the viewport (a card
that is wide in the main column and narrow in the sidebar), say so and name the container types.
Viewport breakpoints cannot express that, and pretending they can produces the classic
sidebar-card-that-thinks-it-is-full-width bug.

### 2.12 Motion tokens

Values live here; the *inventory* of transitions lives in `MOTION.md` (§5).

| Token | Value | Use |
|---|---|---|
| `--duration-instant` | 0ms | Reduced-motion target |
| `--duration-fast` | 120ms | Hover, focus, small color changes |
| `--duration-normal` | 200ms | Dropdowns, tooltips, tab switches |
| `--duration-slow` | 320ms | Modals, drawers, page transitions |
| `--duration-deliberate` | 480ms | Onboarding reveals, celebration |
| `--ease-standard` | `cubic-bezier(0.2, 0, 0, 1)` | Default; most transitions |
| `--ease-decelerate` | `cubic-bezier(0, 0, 0, 1)` | Entering elements |
| `--ease-accelerate` | `cubic-bezier(0.3, 0, 1, 1)` | Exiting elements |
| `--ease-emphasized` | `cubic-bezier(0.2, 0, 0, 1)` w/ longer duration | Hero moments only |
| `--ease-spring` | spring(stiffness, damping) per runtime | Drag/dismiss physics |

Entering uses decelerate (fast in, gentle stop) and exiting uses accelerate (gentle start, quick
out). Using the same symmetric ease for both is the tell of motion nobody thought about.

### 2.13 Output formats

Ship all formats the platform actually consumes. The token file contains the *canonical* table plus
the drop-in blocks.

| Platform | Required output |
|---|---|
| Web | CSS custom properties on `:root`, plus the dark block; a copy-pasteable `<style>` an agent can drop in and get the full system |
| Web + Tailwind | Additionally a `tailwind.config` theme extension mapping token names to the CSS vars (never duplicating values) |
| Any | A `tokens.json` (W3C Design Tokens format if the toolchain reads it) as the machine source |
| iOS | Swift `enum` constants + an asset-catalog manifest for colors with Any/Dark appearances |
| Android | `Color.kt` / `Type.kt` / `Dimens.kt` or `res/values` XML + `values-night` |
| RN / Flutter | The JSON, plus the generated per-platform adapter files (§4.4) |

**Generated, not hand-maintained.** If more than one format ships, say which is the source and how
the others are produced (a script in `scripts/`, run in CI, with the check that regenerating
produces no diff). Hand-maintained parallel token files diverge; a CI diff check makes divergence a
red build instead of a mystery.

## §3 — Component specification

The rule, stated once and enforced everywhere: **a component is specified as variant × size ×
state, exhaustively, with every cell naming its tokens — or it is not specified.**

Why this shape and not prose. A prose description ("the button darkens on hover") produces a
different result in every component an agent writes, and produces *nothing at all* for the states
nobody mentioned. The overwhelming majority of visual bugs in agent-built UIs are missing states:
the disabled button that still shows a hover cursor, the input that has no error styling so errors
render as unstyled red text, the loading button that changes width and makes the toolbar jump. A
matrix has an empty cell where prose has a silence, and empty cells get filled.

`design-system`'s `references/component-architecture.md` owns the file structure, the atomic
hierarchy, and the naming conventions. Follow it for *how the component is organized*. This section
governs *what must be decided before it is written*.

### 3.1 The required state list

Every interactive component specifies all nine, or explicitly marks a state N/A with a reason.

| State | Trigger | Never omit because |
|---|---|---|
| `default` | Resting | — |
| `hover` | Pointer over, gated by `@media (hover: hover)` | On touch, a sticky hover leaves the control looking pressed after the finger lifts |
| `focus-visible` | Keyboard focus (not click focus) | This is the only state a keyboard user can see; `:focus` alone puts rings on mouse clicks and gets removed by someone annoyed, taking keyboard access with it |
| `active` / `pressed` | Pointer or key held | Without it the control feels dead on slow networks |
| `disabled` | Not actionable | Needs its own color, cursor, and the decision: `disabled` attribute (removed from tab order, no tooltip possible) vs. `aria-disabled` (focusable, can explain why) |
| `loading` | Async in flight | Must reserve width/height or the layout jumps; must block re-submission; must announce to AT |
| `error` / `invalid` | Validation failed | Color alone is insufficient (1.4.1); needs icon or text too |
| `selected` / `checked` | Part of a chosen set | Distinct from `active`, which is momentary |
| `read-only` | Value shown, not editable | Distinct from `disabled`: read-only is focusable and copyable, and looks different |

Compound states must be resolved, not left to CSS specificity: `hover + disabled` = disabled wins;
`focus-visible + error` = both render (ring plus error border, ring on top); `loading + hover` =
hover suppressed; `selected + disabled` = selected styling at disabled contrast.

### 3.2 Worked example — Button, complete

This is the shape every other component must match. Values illustrative; tokens from §2.

**Variants:** `primary`, `secondary`, `ghost`, `destructive`, `link`.
**Sizes:** `sm`, `md`, `lg`.
**Plus:** `icon-only` modifier (square, requires `aria-label`), `full-width` modifier.

**Size dimensions (variant-independent):**

| | `sm` | `md` | `lg` |
|---|---|---|---|
| Height | `--size-control-sm` (32) | `--size-control-md` (40) | `--size-control-lg` (48) |
| Padding X | `--space-3` (12) | `--space-4` (16) | `--space-6` (24) |
| Gap (icon↔label) | `--space-1` (4) | `--space-2` (8) | `--space-2` (8) |
| Type | `--text-caption` 13/1.30/550 | `--text-label` 14/1.30/550 | `--text-body` 16/1.30/550 |
| Icon | `--size-icon-sm` (16) | `--size-icon-md` (20) | `--size-icon-md` (20) |
| Radius | `--radius-md` (8) | `--radius-md` (8) | `--radius-md` (8) |
| Icon-only width | 32 | 40 | 48 |
| Hit area | 44×44 via inset pseudo-element | 44×44 | native |

**`primary` × all states (light theme):**

| State | Background | Foreground | Border | Shadow | Cursor | Other |
|---|---|---|---|---|---|---|
| default | `--color-action-primary-default` | `--color-action-primary-fg-default` | none | `--shadow-xs` | `pointer` | — |
| hover | `--color-action-primary-hover` | same | none | `--shadow-sm` | `pointer` | `--duration-fast` `--ease-standard` |
| focus-visible | `--color-action-primary-default` | same | none | `--shadow-xs` | `pointer` | ring: `--focus-ring-width` `--color-focus-ring`, offset `--focus-ring-offset-width` in `--color-focus-ring-offset` |
| active | `--color-action-primary-active` | same | none | `--shadow-none` | `pointer` | `transform: translateY(1px)` — suppressed under reduced-motion |
| disabled | `--color-action-primary-disabled` | `--color-action-primary-fg-disabled` | none | none | `not-allowed` | `aria-disabled="true"`, still focusable so a tooltip can explain why |
| loading | `--color-action-primary-default` | `--color-action-primary-fg-default` | none | `--shadow-xs` | `progress` | spinner replaces leading icon; **label stays, width frozen**; `aria-busy="true"`; pointer events off |
| error | N/A | | | | | Buttons do not hold validation state; the form does |
| selected | `--color-action-primary-active` | same | none | inset `--shadow-xs` | `pointer` | Only in a segmented/toggle context; `aria-pressed="true"` |
| read-only | N/A | | | | | |

**`secondary` × all states:** identical geometry; `--color-action-secondary-*` family; adds
`--border-width-default` in `--color-border-default`, which becomes `--color-border-strong` on
hover.

**`ghost` × all states:** transparent default background; `--color-action-ghost-hover` /
`-active`; foreground `--color-text-primary`; no border; no shadow at any state. Disabled is
`--color-text-disabled` on transparent.

**`destructive` × all states:** `--color-action-destructive-*` (LOCKED, §2.2), foreground
`--color-action-destructive-fg`. Additional rule: a destructive button in a confirm dialog is never
the auto-focused element — focus goes to cancel, so an accidental Enter does not delete anything.

**`link` × all states:** no background, no padding-x, no fixed height (it flows inline);
`--color-text-link`; underline `--border-width-default` at `text-underline-offset: 0.15em`; hover
thickens the underline rather than changing color, because a color-only change fails 1.4.1 for
users who cannot distinguish the pair.

**Cross-cutting rules for this component:**
- Label copy comes from `writing-for-interfaces`; never "Submit" when "Create project" is available.
- `icon-only` requires `aria-label` and a tooltip; ship both, not one.
- Text never wraps inside a button; if it would, the label is too long — fix the copy.
- `type="button"` unless it genuinely submits; a bare `<button>` in a form submits it.
- Motion values from §2.12; motion is decorative here and fully removable under reduced-motion.

That is one component. Every component below gets the same treatment. If that feels like a lot of
specification, compare it to the cost of an agent making these forty decisions inconsistently
across sixty files.

### 3.3 Required component inventory

The baseline for a typical product. Anything appearing in `SCREENS.md` must appear here — that is
mechanically checkable and Phase 8 should check it.

| Group | Components | Specification notes beyond the standard matrix |
|---|---|---|
| **Actions** | Button, IconButton, ButtonGroup, SplitButton, ToggleButton, Link | Loading width freeze; destructive focus rule |
| **Text input** | TextField, TextArea, PasswordField, SearchField, NumberField | Label position, required marker, helper text, char counter, error message slot (reserved height so validation does not shift layout), autofill styling, `inputmode` per type |
| **Choice** | Select (native), Combobox (filterable), MultiSelect, Autocomplete | Popup max-height, virtualization threshold, no-results state, loading-options state, keyboard: ↑↓ move, Enter select, Esc close, Home/End, type-ahead |
| **Boolean** | Checkbox, Radio, Switch, CheckboxGroup, RadioGroup | Indeterminate checkbox state; switch must have an on/off label or icon, not color alone; the group owns the error, not each item |
| **Complex input** | DatePicker, DateRangePicker, TimePicker, FileUpload, Slider, RichTextEditor, ColorPicker, TagInput | Locale formatting (§8); FileUpload needs drag-over, uploading with %, success, rejected-type, too-large, and the virus-scan-pending state if applicable |
| **Form structure** | Form, FormField, Fieldset, FormActions, InlineValidation, FormError summary | Where errors appear (inline + summary at top, summary linked to fields); when validation fires (on blur, then on change once errored — not on every keystroke from empty) |
| **Overlay** | Modal, Drawer/Sheet, Popover, Tooltip, ContextMenu, Menu, CommandPalette | Focus trap, initial focus target, return focus on close, Esc behavior, scroll lock, scrim token, portal target, stacking (§2.10), mobile adaptation (modal→sheet) |
| **Feedback** | Toast, Alert/Banner, InlineMessage, ProgressBar, Spinner, Skeleton, EmptyState, ErrorState | Toast: position, max stack, duration per severity, whether errors auto-dismiss (they should not), pause on hover, `role="status"` vs `role="alert"` |
| **Data display** | Table, DataGrid, List, DescriptionList, Card, Stat/MetricTile, Badge, Tag/Chip, Avatar, AvatarGroup, Timeline, Tree | Table gets its own full spec (§4.6); Stat tiles need the tabular-numeral rule (§2.4) |
| **Navigation** | Tabs, Breadcrumb, Pagination, Sidebar/NavRail, TopBar, Stepper, BackLink | Tabs: manual vs. automatic activation (manual is correct when panels are expensive); Pagination: page-size control, total count, jump-to-page, and the truncation pattern (1 … 4 5 6 … 20) |
| **Layout** | Container, Stack, Grid, Divider, Splitter/ResizablePanel, ScrollArea, Section | Whether panel sizes persist per user |
| **Utility** | VisuallyHidden, SkipLink, FocusTrap, Portal, KeyboardShortcut hint, CopyButton | SkipLink is required for any page with repeated nav (2.4.1) |

Note what this list does *not* include: anything product-specific. Those are additional and get the
same matrix. The point of the baseline is that these exist in nearly every product and get invented
badly when unspecified.

### 3.4 Per-component required fields

Beyond the matrix, each component entry carries:

1. **Anatomy** — a labeled parts list (container, leading icon, label, trailing icon, badge) so
   parts can be referenced unambiguously in states and in `SCREENS.md`.
2. **Props/API** — name, type, default, required. Defaults matter: `<Button>` with no `variant`
   must resolve to something stated, not to whatever the implementer chose.
3. **Composition rules** — what may nest inside, what may not. "A Tooltip may not contain
   interactive content" prevents a whole class of keyboard traps.
4. **Semantics** — the element or role, required ARIA attributes and when they change, the
   accessible-name source, and what is announced on state change.
5. **Keyboard** — every key the component handles, and what it does. If the component handles no
   keys, say "none beyond native" explicitly, so the reader knows it was considered.
6. **Responsive/adaptive behavior** — what changes at each size class (§7).
7. **Content rules** — max label length, truncation vs. wrap, what happens with an empty value,
   and the pluralization rule if it counts things.
8. **Do / Don't** — two of each, concrete. "Don't use a destructive button for 'Archive'; archive
   is reversible" teaches the boundary better than a paragraph.

## §4 — Per-platform additions

Each subsection is required only for the platforms selected in §1. Each is specified to the same
depth as the web sections; a native platform treated as "web but smaller" is the second most
common way this phase produces something thin.

### 4.1 Web

**Breakpoint behavior table.** Not just the values (§2.11) but what happens at each one, per major
layout region. See §7 for the full contract; the token file carries values, §7 carries behavior.

**Hover / pointer capability.** Every hover state is wrapped:

```css
@media (hover: hover) and (pointer: fine) { .btn:hover { ... } }
```

Without the guard, iOS Safari applies `:hover` on tap and leaves it applied until the user taps
elsewhere. Also specify: `@media (pointer: coarse)` raises target sizes to 44px, and hover-only
affordances (a row's action icons that appear on hover) need a persistent alternative on touch —
name the alternative, do not leave the feature unreachable.

**Print.** One paragraph minimum, because "we don't support print" is itself a decision. If the
product has invoices, reports, or anything a user will Ctrl+P: specify the print stylesheet's
scope (which regions hide), page margins, whether backgrounds print, link-URL expansion, and page
breaks (`break-inside: avoid` on cards and table rows).

**SSR / hydration and theming.** The dark-mode flash is a design defect with an implementation
cause, so the design spec must state the strategy:
- Theme resolution order: URL/query override → user preference in DB → `localStorage` →
  `prefers-color-scheme` → default.
- The blocking inline script in `<head>` that sets `data-theme` before first paint. This is the
  one legitimate render-blocking script; say so, so a performance pass does not "optimize" it away
  and reintroduce the flash.
- `color-scheme: light dark` on `:root` so native form controls and scrollbars match.
- What the server renders when it does not know the user's theme (usually: the stored preference
  if authed, otherwise a neutral shell the script corrects before paint).
- The `<meta name="theme-color">` value per theme.

**Other web-only required decisions:** scroll restoration on back-navigation;
`scroll-behavior: smooth` gated on reduced-motion; sticky-header offset for anchor links
(`scroll-margin-top`);
`::selection` colors; custom scrollbar styling or none; `:target` styling; viewport meta (never
`user-scalable=no` — it fails 1.4.4); safe-area insets on notched phones in browser
(`env(safe-area-inset-*)`).

### 4.2 Native iOS

Dispatch conventions and navigation patterns to `apple-hig-expert`. This section specifies what
must be *recorded as design output*.

**Dynamic Type ramp — required mapping table.** iOS body copy that ignores Dynamic Type is an
accessibility failure and an App Review risk. Map every semantic type token to a system text style
rather than a point size:

| Design token | iOS text style | Default size (Large) | Weight | Notes |
|---|---|---|---|---|
| `text-display` | `.largeTitle` | 34pt | `.bold` | Navigation large-title only |
| `text-h1` | `.title` | 28pt | `.bold` | Screen headline band (P0) |
| `text-h2` | `.title2` | 22pt | `.semibold` | |
| `text-h3` | `.title3` | 20pt | `.semibold` | |
| `text-h4` | `.headline` | 17pt | `.semibold` | |
| `text-body` | `.body` | 17pt | `.regular` | |
| `text-body-sm` | `.callout` | 16pt | `.regular` | |
| `text-label` | `.subheadline` | 15pt | `.medium` | |
| `text-caption` | `.footnote` | 13pt | `.regular` | |
| `text-overline` | `.caption1` | 12pt | `.regular` | |
| — | `.caption2` | 11pt | `.regular` | Legal/fine print only |

Required alongside: which screens must remain usable at **AX5** (the largest accessibility size),
and what they do there — this is where fixed-height rows and side-by-side layouts break, and the
answer is usually "stack vertically above `.accessibility1`". Specify the threshold, e.g.
`@Environment(\.dynamicTypeSize) ... if size >= .accessibility1 { VStack } else { HStack }`.
Specify also which elements may cap their scaling (`.dynamicTypeSize(...DynamicTypeSize.xxxLarge)`)
— tab bar labels and fixed chrome legitimately cap; body content never does.

**Semantic colors and dark mode.** iOS dark mode is free *if* colors come from the asset catalog
with Any/Dark appearances or from system semantic colors. Required output: a color-asset manifest
listing each token, its Any Appearance value, its Dark Appearance value, and whether it also
defines a High Contrast variant (iOS ships `Increase Contrast`; system semantic colors adapt
automatically, custom ones do not unless you supply the variant). Prefer system semantics where
they fit — `.label`, `.secondaryLabel`, `.tertiaryLabel`, `.separator`,
`.systemBackground`, `.secondarySystemBackground`, `.systemGroupedBackground` — and say which
tokens map to system semantics versus which are custom brand colors. Mapping to system semantics
buys High Contrast, Increase Legibility, and future OS changes for free.

**SF Symbols.** Required: the symbol name for every icon in the product, its rendering mode
(monochrome / hierarchical / palette / multicolor), its weight and scale, the minimum iOS version
each symbol requires (symbols are versioned; a symbol introduced in SF Symbols 6 crashes nothing
but renders blank on older OS), and the fallback for any custom icon that has no SF Symbol.
Variable-color symbols need their value binding specified.

**Safe areas and layout margins.** Specify: which surfaces extend under the safe area (background
fills, scroll content, images) and which never do (interactive controls, text); the keyboard
avoidance behavior per screen; the home-indicator inset on bottom bars; the Dynamic Island /
status-bar overlap on scroll-to-top surfaces; landscape and iPad handling including Slide Over and
Split View if the app supports multitasking.

**HIG conformance record.** A short `HIG_CONFORMANCE.md` listing, per screen: the navigation
pattern used (stack / tab / modal sheet / full-screen cover), why, the swipe-back behavior, the
sheet detents if used (`.medium`, `.large`, custom), and any deliberate deviation from HIG with its
justification. Deliberate deviations are fine; undocumented ones get flagged in review by a human
who assumes you did not know.

**Liquid Glass (iOS 26+).** If targeting iOS 26 or later, dispatch material choices to
`liquid-glass-design`. Required output regardless: which surfaces adopt the glass material, the
legibility guarantee behind it (glass over arbitrary content can drop text contrast below 4.5:1 —
state the scrim or vibrancy fallback that holds the floor), the `Reduce Transparency` behavior
(system setting; the design must specify the opaque fallback, not let the OS pick), and the
pre-26 fallback path if the deployment target is lower. "Looks great on 26" plus "unspecified on
18" is half a design.

**Also required:** haptics map (which actions fire which `UIFeedbackGenerator` type — overusing
haptics is worse than none); the app icon at every required size plus the tinted/dark variants;
launch screen; Control Center / widget / Live Activity surfaces if any; and the `Reduce Motion`
contract (§5), which on iOS also disables the default view transitions unless you opt back in.

### 4.3 Native Android

**Material 3 token mapping.** M3 has its own token vocabulary and fighting it costs more than
adopting it. Required output: a mapping table from the product's semantic tokens to the M3 color
roles — `primary`, `onPrimary`, `primaryContainer`, `onPrimaryContainer`, `secondary`/`tertiary`
(same four each), `surface`, `onSurface`, `surfaceVariant`, `onSurfaceVariant`,
`surfaceContainerLowest/Low/Default/High/Highest`, `outline`, `outlineVariant`, `error`, `onError`,
`errorContainer`, `onErrorContainer`, `inverseSurface`, `inverseOnSurface`, `inversePrimary`,
`scrim`. Every one gets a light and dark value. Generate the tonal palettes (tones 0–100) with the
`design-system` skill from the brand seed.

**Dynamic color.** Android 12+ can derive the palette from the user's wallpaper. This is a product
decision with real consequences, so record it: does the app opt in? If yes, which roles come from
dynamic color and which stay branded — and note that the LOCKED semantic tokens (§2.2) never come
from wallpaper, because a wallpaper-derived "error" color is not reliably alarming. If no, state
why (brand fidelity, multi-tenant theming) so nobody "fixes" it later.

**Density buckets.** Everything in `dp` and `sp`, never `px`. Required: the asset delivery plan
(vector drawables preferred; raster only where unavoidable, then at mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi),
and confirmation that text uses `sp` so `fontScale` applies. A layout that breaks at `fontScale`
1.3 is the Android equivalent of the Dynamic Type failure — specify which screens must survive
`fontScale` 2.0 and how.

**Elevation semantics.** M3 replaced shadow-driven elevation with **tonal** elevation: higher
surfaces get more primary-color tint, not more shadow. Required: the level table (0/1/2/3/4/5 →
0/1/3/6/8/12 dp) mapped to component roles, and whether shadow is also drawn (M3 draws both for
some components). Porting the web `--shadow-*` scale directly to Android is wrong and looks it.

**Gesture insets and system bars.** Required: edge-to-edge behavior (Android 15+ enforces it),
`WindowInsets` handling per screen (system bars, display cutout, IME, gesture navigation), which
elements must inset and which draw behind, and the gesture-conflict resolution for any horizontal
swipe near the screen edge (a swipeable carousel at the edge fights back-gesture navigation —
specify the exclusion rect or move the affordance).

**Also required:** predictive-back support and what the preview shows; adaptive icon (foreground /
background / monochrome layers); notification channels and their importance levels; and the
`Remove animations` developer/accessibility setting behavior (§5).

### 4.4 Cross-platform (React Native / Flutter)

The pattern: **one shared semantic token source, per-platform adapters, and an explicit
do-not-share list.** Anything else produces a UI that is subtly wrong on both platforms.

**Shared layer** (`tokens.json`, the source of truth):
- Semantic color roles and their light/dark values.
- The type *scale relationships* (ratio, weights, tracking) and semantic names.
- Spacing, radius, border width, z-layer ordering.
- Motion durations and the semantic easing names.
- Component variant/size/state matrices — the decisions, not the rendering.

**Must NOT be shared** (per-platform adapters own these):

| Concern | Why sharing it breaks |
|---|---|
| Absolute font sizes | iOS Dynamic Type and Android `fontScale` resolve differently; a shared 17px is neither |
| Elevation/shadow values | iOS uses shadow, M3 uses tonal tint; the same value is wrong on one of them |
| Navigation patterns and transitions | Back-swipe vs. back-gesture vs. back-button are different interaction models |
| Default control heights | 44pt vs 48dp; taking one loses compliance on the other |
| Haptic mappings | Different APIs, different cultural expectations of intensity |
| System font stacks | SF vs. Roboto have different metrics; the same line-height reads differently |
| Date/time/number formatting | Platform locale APIs differ; do not hand-roll a shared formatter |
| Scroll physics, overscroll, pull-to-refresh | Platform muscle memory; a shared bounce is uncanny on Android |
| Modal presentation | iOS sheet detents vs. Android bottom sheet behavior |

**Required deliverable: `PLATFORM_ADAPTERS.md`** listing every adapter, the shared token it
consumes, the per-platform value it produces, and the rule that produced it. Plus the generation
story: is the adapter generated from the JSON in CI (with a no-diff check), or hand-written and
tested? Either is acceptable; unstated is not.

**The escape-hatch rule.** Name the sanctioned mechanism for platform divergence
(`Platform.select` / `Platform.isIOS`) and the rule that every use of it points at a line in
`PLATFORM_ADAPTERS.md`. Unexplained platform branches accumulate into two codebases wearing one
repo.

### 4.5 Desktop (Electron / Tauri / native shell)

Frequently forgotten, so specified here: **window state**. Minimum, maximum, and default window
size; what the layout does below minimum (it must still work — users resize to absurd widths);
multi-window behavior and whether windows share state; full-screen behavior; the title-bar
decision (native chrome vs. custom/frameless, and if custom, the drag region and the traffic-light
inset on macOS); menu-bar structure per OS, since macOS and Windows menu conventions differ;
platform keyboard conventions (⌘ vs. Ctrl, and the fact that ⌘W closing a window is expected on
macOS and surprising on Windows); OS accent color and vibrancy/mica if adopted; system tray
presence; and the offline/no-network design, since desktop apps are launched on planes.

### 4.6 SaaS app shell

The shell is the product's actual interface — the thing every screen lives inside — and it is
routinely under-specified relative to individual screens.

**Navigation architecture.** Required: the primary pattern (persistent sidebar / top nav / rail /
hybrid) with its reason; the information architecture as a tree, showing every destination and its
depth (three levels is the practical ceiling before users get lost); the collapsed/expanded sidebar
behavior and whether the state persists per user; the active-item indicator; how the current
location is communicated in more than one way (highlighted nav item **and** breadcrumb **and**
page title — one is not enough); the workspace/tenant switcher including how it behaves with one
workspace versus many; the account menu contents; and mobile adaptation (sidebar → drawer or
bottom tabs, and which destinations survive the cut, because a bottom bar holds five).

**Density modes.** Data-heavy products need both. Specify comfortable *and* compact as a token
overlay, not as ad-hoc CSS: which tokens change (control heights, table row height, spacing scale
offsets, `text-body` → `text-body-sm`), which never change (type *ratios*, all color tokens,
target minimums — compact density must not push targets below 24px), where the control lives, and
whether the preference is per-user, per-workspace, or per-view. Per SKILL.md's P0, **comfortable is
the default and density is opt-in**; a product that ships compact-by-default has decided its power
users matter more than its new ones, which is a decision that should be made deliberately if at all.

**Data table specification.** The single most complex component in most SaaS products, and the one
most often specified as "a table." Required:

| Aspect | Must specify |
|---|---|
| Column model | Default visible set, hideable columns, reorder, resize, min/max widths, pinned/frozen columns, and whether the config persists per user per view |
| Row model | Height per density, zebra or not, hover, selected, focused, expanded/detail-row, grouped headers |
| Sorting | Which columns, single vs. multi, default sort, the indicator, and the announcement to AT on change |
| Filtering | Where filters live (toolbar / column headers / a panel), filter chips showing active filters, clear-all, and whether filters are URL-addressable (they must be — a filtered view is a thing people share) |
| Selection | Checkbox column, select-all semantics (**this page** vs. **all matching**, which are different and must both be offered when they differ), the selection-count bar, and bulk actions |
| Pagination | Page size options, total count (and what shows when the count is expensive/unknown), cursor vs. offset, jump-to-page, or infinite scroll with its own end-of-list and scroll-restoration story |
| Cell rendering | Per data type: text, number (tabular numerals, alignment right, unit placement), currency, date (locale, relative vs. absolute, tooltip with the absolute), status badge, avatar, link, action menu, boolean, null/empty |
| Truncation | Which columns truncate vs. wrap; the tooltip or expansion for truncated content; never truncate an ID mid-string without a copy affordance |
| Empty / loading / error | No data at all, no data matching filters (different message, different action: "clear filters"), initial load skeleton (matching the real row height so nothing jumps), loading more, partial failure, total failure with retry |
| Scale | The row count at which virtualization turns on, and the horizontal-scroll behavior with pinned columns |
| Keyboard + AT | Arrow navigation within the grid, Enter to open, Space to select, the `role="grid"` vs. `role="table"` decision (grid only if cells are focusable), sort announcements, and the caption/summary |
| Export | Whether rows export, respecting current filters and column config |

**Keyboard shortcut map.** Required as a table: key, scope (global / view / component), action,
and whether it appears in the in-app shortcut sheet. Plus the rules: never override browser-native
shortcuts the user relies on; single-letter shortcuts must not fire while a text input has focus;
`?` opens the shortcut sheet; a command palette (⌘K) is the discoverable superset and should exist
before an extensive shortcut set does. Include Escape's behavior at every nesting depth — the most
common keyboard bug is Escape closing the wrong layer.

**Multi-tenant theming boundary.** Restates §2.2 as an API contract:

| Tier | Tokens | Enforcement |
|---|---|---|
| **Overridable** | Brand primary hue, logo, accent, favicon, marketing surfaces, optional custom font | Validated at save: derived ramp is regenerated, all contrast pairs (§2.3) recomputed, save rejected with the failing pair named |
| **Constrained** | Text and surface colors — hue adjustable, computed contrast must clear the floor | Same validator; the tenant sees which pair failed and by how much |
| **LOCKED** | Status/danger/warning/success, focus ring contrast floor, confidence encodings, target sizes, type scale ratios, spacing scale | Override map rejects the key; a test asserts rejection; a CI grep asserts no code path bypasses the map |

Also required: what an unthemed tenant gets (the product default, fully specified — never an
unstyled fallback); how theme values reach the client without a flash (§4.1 SSR); and the preview
mechanism so an admin sees the theme before committing it.

**First-run and empty states.** The first hour decides retention and is the part of the design most
often skipped, because designing screens with data is more satisfying. Required, each as a full
screen spec (§6): the post-signup empty workspace for every major object type, each with an
explicit primary action; whether demo/sample data is offered — and if it is, the rule from the
house principles applies: **sample data must be visibly labeled as sample and must not render
identically to real data**, with a one-click way to remove it; the onboarding checklist if any,
including its dismissal and whether it can return; progressive disclosure of advanced features;
and the invite-teammates moment if the product is collaborative.

## §5 — `MOTION.md`

Values come from §2.12. This document is the **inventory**: every animation in the product, named,
with its trigger and its parameters. An inventory exists so that motion is a system rather than
sixty independent decisions, and so that the reduced-motion contract can be verified rather than
assumed.

### 5.1 The named transition inventory

Every entry: name, trigger, animated properties, duration token, easing token, delay, and the
reduced-motion behavior. Illustrative rows:

| Name | Trigger | Properties | Duration | Easing | Delay | Reduced-motion |
|---|---|---|---|---|---|---|
| `button-hover` | Pointer enter (hover-capable only) | `background-color`, `box-shadow` | `--duration-fast` | `--ease-standard` | 0 | Keep (color only, no transform) |
| `button-press` | Pointer/key down | `transform: translateY(1px)` | `--duration-fast` | `--ease-standard` | 0 | **Remove** |
| `focus-ring-in` | `:focus-visible` | `outline-color`, `outline-offset` | `--duration-fast` | `--ease-decelerate` | 0 | Keep, or snap to instant |
| `dropdown-open` | Menu/combobox open | `opacity` 0→1, `transform: scale(.98)→1` | `--duration-normal` | `--ease-decelerate` | 0 | Opacity only |
| `dropdown-close` | Close | `opacity` 1→0 | `--duration-fast` | `--ease-accelerate` | 0 | Instant |
| `modal-enter` | Dialog open | scrim `opacity`; panel `opacity` + `translateY(8px)→0` | `--duration-slow` | `--ease-decelerate` | 0 | Opacity only |
| `drawer-enter` | Drawer open | `translateX(100%)→0` | `--duration-slow` | `--ease-decelerate` | 0 | Opacity only |
| `toast-enter` | Toast queued | `translateY(16px)→0` + `opacity` | `--duration-normal` | `--ease-decelerate` | 0 | Opacity only |
| `toast-exit` | Dismiss or timeout | `opacity` + `translateX` | `--duration-normal` | `--ease-accelerate` | 0 | Instant |
| `tab-indicator` | Tab change | `transform: translateX`, `width` | `--duration-normal` | `--ease-standard` | 0 | Instant reposition |
| `accordion-expand` | Disclosure open | `height` (or `grid-template-rows`) | `--duration-normal` | `--ease-standard` | 0 | Instant |
| `skeleton-shimmer` | Loading | `background-position` loop | 1200ms loop | `linear` | 0 | **Replace with static tint** |
| `spinner` | Async in flight | `rotate` loop | 800ms loop | `linear` | 0 | **Keep** — it is a status indicator, see 5.3 |
| `progress-determinate` | Progress value change | `width`/`transform: scaleX` | `--duration-normal` | `--ease-standard` | 0 | Keep (or instant jump) |
| `list-stagger` | List first render | `opacity` + `translateY(4px)` per item | `--duration-fast` | `--ease-decelerate` | 20ms × index, cap 6 items | **Remove entirely** |
| `page-transition` | Route change | `opacity` crossfade | `--duration-normal` | `--ease-standard` | 0 | Instant |
| `value-flash` | Live number updated | `background-color` pulse | `--duration-normal` | `--ease-standard` | 0 | Keep as a static highlight that fades on next interaction |

Rows with no entry are transitions that do not exist. That is the point: if a build agent wants to
animate something not on this list, it is adding to the system and the addition should be a
deliberate edit here, not an inline `transition: all 0.3s` (which is itself an anti-pattern worth
grep-banning — `transition: all` animates properties you did not intend, including ones that cost
layout).

### 5.2 Calm default, expressive opt-in

The product's baseline motion is **calm**: short durations, opacity and small transforms, no
bounce, no stagger beyond a handful of items, nothing that delays a user's next action. Calm motion
is what makes an interface feel responsive rather than animated.

**Expressive** motion — springs, longer durations, staggered reveals, celebratory effects — is
opt-in per surface and each instance is listed here with a justification. Legitimate uses:
onboarding first-run, a genuine milestone (first project published, plan upgraded), an empty-state
illustration. Illegitimate uses: anything a user encounters more than a few times. A delightful
480ms reveal is delightful once and an obstruction on the fortieth visit.

State the ceiling explicitly: **no transition on a path a user repeats may exceed
`--duration-normal`**, and no transition may block input. A user who clicks during an animation
gets the result immediately; the animation is decoration over an already-committed state change,
never a gate in front of one.

### 5.3 The `prefers-reduced-motion` contract

Required as an explicit two-column contract, because "we respect reduced motion" implemented as a
blanket `animation: none !important` breaks loading spinners and progress bars, which is a
different accessibility failure.

**What reduced motion disables:**
- Any transform-based movement: slide, scale, rotate, parallax, translate.
- Staggered sequences (collapse to simultaneous, or to instant).
- Looping decorative animation: shimmer, pulse, floating illustration, animated gradient.
- Auto-playing video, GIFs, and carousels that advance on their own.
- Scroll-linked effects and smooth scrolling.
- Springs and physics-driven motion.

**What reduced motion must preserve:**
- **Opacity crossfades**, which are the sanctioned replacement for movement — they convey the
  change without vestibular risk.
- **Loading and progress indicators.** A spinner is not decoration; it is the only signal that the
  system is working. Reduce it (a slower, non-pulsing indicator) rather than removing it, or
  replace it with a static "Loading…" that updates.
- **Focus ring appearance.** It may become instant; it may never become invisible.
- **State changes themselves.** The modal still opens; it appears instead of sliding.
- **Any animation carrying information** (see 5.4).

Implementation note to record: the correct default is motion-off with an opt-in, i.e. write the
static rule and add motion inside `@media (prefers-reduced-motion: no-preference)`, rather than
writing motion and subtracting it in a reduce block. Subtraction misses whatever was added last.
On iOS this is `UIAccessibility.isReduceMotionEnabled` / `@Environment(\.accessibilityReduceMotion)`;
on Android, `Settings.Global.ANIMATOR_DURATION_SCALE == 0` plus the M3 reduced-motion guidance.

Also record whether the product exposes its *own* motion toggle in settings. It should, if any
motion survives the reduced-motion pass, because OS-level settings are coarse and some users want
the app calm without changing their whole system.

### 5.4 Motion never gates information

The load-bearing rule. Stated three ways because it is violated three ways:

1. **No information may exist only in motion.** If a row flashes to indicate "updated", the updated
   state must also be readable when the flash is over — a badge, a timestamp, a persistent tint.
   Under reduced motion the flash does not happen at all, so a design that relies on it silently
   loses data for those users.
2. **No animation may delay access.** Content behind a 400ms reveal is content unavailable for
   400ms. If the reveal is skippable by clicking, say so; if it is not, shorten it.
3. **No scroll-triggered reveal may hide content from a user who does not scroll the way you
   expected** — or from a crawler, or from Ctrl+F. Scroll-reveal that starts at `opacity: 0` and
   never fires (because the element was already in view, or because IntersectionObserver did not
   run) is a blank page. Specify the fail-open default: content is visible, animation *adds* to it.

Each rule gets a check in Phase 8: run the product with reduced motion forced and confirm every
screen still conveys everything; disable JavaScript animation and confirm nothing is stuck at
`opacity: 0`.

## §6 — `SCREENS.md`

One entry per screen. A screen entry that omits any required field is incomplete, and the omission
is exactly where the build agent will improvise.

### 6.1 Required fields per screen

**1. Screen ID and route.** Stable ID (`SCR-DASH-1`), the URL pattern with its parameters, and
whether the state is URL-addressable — filters, tabs, sort, pagination, and open panels should be
in the URL, because a view a user cannot link to is a view they cannot share or return to.

**2. The one headline message.** Per SKILL.md's P0, every screen leads with one message and that
message wins. Write the actual sentence. The headline band renders it in the largest type on the
screen; everything else is progressive disclosure. If you cannot write the sentence, the screen
does not have a purpose yet and should not be designed.

**3. Layout per breakpoint or size class.** Not "responsive" — the actual arrangement at each stop.
A three-line table per screen (see §7 for the contract this fills in). Include what is above the
fold at the smallest supported size, since that is what most users see first.

**4. Component list with exact props and tokens.** Every component instance: which component from
§3, which variant, which size, which props, and any token overrides (there should be almost none —
a screen that needs token overrides is telling you the component matrix is incomplete). Reference
components by name; do not describe them again.

**5. Exact final copy.** Every string, verbatim, ready to ship: headline, body, labels, button
text, helper text, placeholder text, error messages, empty-state copy, tooltip text, confirmation
dialogs, success toasts, and the page `<title>` / meta description if it is a public page.

**This is the hard rule and it has teeth.** Never lorem ipsum. Never "Some description here."
Never a plausible-sounding invented company name, statistic, testimonial, price, or user name
presented as though it were the product's real content. Placeholder copy that reads as finished
copy is the exact failure mode the house rules forbid: **a fabricated value must not render
identically to a real one.**

When the real copy is not knowable — it depends on a business fact the user has not supplied —
write it as an explicit typed placeholder (`{{COMPANY_LEGAL_NAME}}`, `{{SUPPORT_EMAIL}}`,
`{{PRICE_PRO_MONTHLY}}`) and add it to the open decisions table so it is surfaced, not buried. A
`{{TOKEN}}` is honest; "Acme Inc." is a fabrication that will ship. Draft the copy that *is*
knowable with `writing-for-interfaces` rather than improvising voice per screen.

**6. Every state the screen can be in.** Not the happy path plus a shrug. Each state gets its own
layout note and its own copy:

| State | Must specify |
|---|---|
| **Empty — never had data** | The reason it is empty, the primary action, and an illustration or not. Different from the next row and must not share copy. |
| **Empty — filtered to nothing** | "No results for X", the clear-filters action, and preserving the filter controls so the user can adjust them |
| **Loading — initial** | Skeleton matching the real layout's dimensions (so nothing shifts on arrival) or a spinner, and which; plus the announcement to AT |
| **Loading — refreshing existing data** | Whether stale data stays visible (it should) and how "updating" is indicated without hiding content |
| **Partial** | Some sections loaded, some pending or failed. Very common and almost never specified. Per-section states, and whether a failed section blocks the screen (it should not) |
| **Error — recoverable** | What failed, in user language, plus a retry that actually retries; never a raw status code as the whole message |
| **Error — unrecoverable** | The dead end, the way out (back / home / contact), and whether an error ID is shown for support |
| **Permission denied** | Distinguish "you are not signed in" (→ sign in, return here after) from "your role cannot see this" (→ who to ask) from "this does not exist" (→ do not leak existence of another tenant's object) |
| **Offline / connection lost** | What still works from cache, what queues, what is blocked, and how recovery is signaled |
| **Stale / conflict** | If concurrent edits are possible: how a conflict surfaces and which version wins |
| **Over quota / plan limit** | The limit, current usage, and the upgrade or cleanup path |
| **Read-only** | If the object can be locked, archived, or viewed by a role without write access — what visibly changes |

A screen that genuinely cannot enter a state marks it N/A with a one-line reason. N/A is a decision;
absence is an oversight, and the reader cannot tell them apart unless you write it down.

**7. The keyboard path.** Tab order through the screen in sequence, the initial focus target on
load and after each navigation, focus behavior when a dialog opens and closes (trap in, restore
out), every screen-level shortcut, and what Escape does at each nesting depth. Also: where the skip
link goes and what the landmark structure is (`header` / `nav` / `main` / `aside` / `footer`),
since that is the screen-reader user's equivalent of a layout.

**8. The FR IDs this screen implements.** `FR-DASH-3`, `FR-DASH-7`, `NFR-PERF-2`. This is the
traceability link that lets Phase 8 prove every requirement has a surface and every surface has a
requirement. `WIREFRAMES.md` carries the numbered annotations; `SCREENS.md` carries the roll-up.
A screen implementing no FR is either missing its requirement or is scope that nobody asked for —
both are worth catching before it is built.

**9. Data dependencies.** Which API calls or queries populate it, which are blocking versus
deferred, and the interface shape — cross-referenced to `STATE_AND_DATA.md` rather than duplicated.

**10. Analytics and instrumentation.** The events this screen emits and their properties, if the
product measures anything. Retrofitting analytics costs more than specifying it, and a screen spec
is where the question "what would we want to know about this screen?" is cheapest to answer.

### 6.2 Screen inventory completeness

The set of screens is itself a deliverable and it is routinely short. Beyond the feature screens,
the inventory must account for: sign-up, sign-in, password reset (request + confirm), email
verification, invitation acceptance, SSO callback and failure, account settings, billing and plan
management, workspace/tenant settings, member management, notification preferences, the 404, the
500, the maintenance page, the offline page, the legal pages (terms, privacy), and the
account-deletion flow. Most of these are legally or operationally required, none are interesting,
and all of them get invented at 2am by someone with no spec if they are not here.

## §7 — Adaptive and responsive behavior

A first-class section, not a footnote on each screen, because responsive behavior is a *system*
decision. Deciding per screen produces a product where the sidebar collapses at 1024 on one page
and 900 on another, and nobody can say which is right.

### 7.1 The layout contract

One table for the product, filled in per major layout region. Screens then say "standard" or
declare their deviation, which keeps §6 short and keeps the deviations visible.

| Region | Compact (<640 / compact size class) | Medium (640–1023 / compact-regular) | Expanded (≥1024 / regular) |
|---|---|---|---|
| Primary nav | Bottom tab bar (max 5) or hamburger drawer | Collapsed icon rail, expands on hover/tap | Persistent expanded sidebar, collapsible, state persisted |
| Page header | Title only; actions in an overflow menu | Title + primary action; rest in overflow | Title + subtitle + full action group |
| Content columns | 1 | 1 or 2 | 2 or 3 |
| Secondary panel / inspector | Full-screen sheet on demand | Overlay drawer | Docked side panel, resizable |
| Data table | Card list per row, or horizontal scroll with the identifying column pinned | Horizontal scroll, pinned first column | Full table, all default columns |
| Filters | Bottom sheet | Popover from a Filters button | Inline toolbar |
| Modal | Full-screen sheet | Centered dialog, `--container-sm` | Centered dialog, sized to content |
| Page margin | `--space-4` | `--space-6` | `--space-8` |
| Density control | Hidden (comfortable forced) | Available | Available |

### 7.2 Reflows versus hides — the rule

Every element at every breakpoint is one of three things, and which one must be recorded:

- **Reflows** — same content, different arrangement. Always preferred.
- **Collapses** — same content, behind an affordance (overflow menu, accordion, sheet). Acceptable
  when the affordance is discoverable and labeled.
- **Hides** — content genuinely removed at that size.

**Hiding requires a justification per element**, because hiding is how mobile users lose features
permanently. The only defensible reasons: the content is decorative (a hero illustration), or an
equivalent path exists and is named. "There wasn't room" is not a reason; it is a layout problem
wearing a responsive-design costume. Record hidden elements in a short list so a reviewer can scan
what the small-screen user does not get. And never hide via `display: none` something that is still
in the tab order, or keyboard users tab to invisible controls.

The inverse rule matters too: **nothing may appear only on large screens that the product's success
metrics depend on.** If the primary conversion action is desktop-only, that is a product decision,
and it should be in the PRD, not discovered in the CSS.

### 7.3 Touch targets

| Platform | Minimum | Source | Spacing between adjacent targets |
|---|---|---|---|
| Web (AA) | 24×24 CSS px | WCAG 2.2 `2.5.8` | If under 24px, targets need 24px of clear space (the exception clause) |
| Web (recommended) | 44×44 CSS px | WCAG `2.5.5` AAA | 8px |
| iOS | 44×44 pt | Apple HIG | 8pt |
| Android | 48×48 dp | Material | 8dp |
| Desktop pointer | 24×24 px | — | 4px |

The recurring bug: visual size satisfies the design, target size does not. A 16px close icon looks
right and is a 16px target. Fix with padding or an inset pseudo-element that extends the hit area
without changing the visual — and specify which, because `::after` inset targets must not overlap
adjacent targets. Where the design genuinely requires small visual affordances (a dense table's row
actions), state the compensating behavior: larger targets on coarse pointers via
`@media (pointer: coarse)`, or a row-level action menu instead of per-cell icons.

### 7.4 Orientation

Never lock orientation without a stated reason (WCAG `1.3.4` requires content to work in both
unless a specific orientation is essential — a piano app is essential, a settings screen is not).
Required: landscape layout for phone-sized viewports, which is where fixed-height headers and
vertically-centered content break; the keyboard-open case, since an open keyboard on a landscape
phone leaves roughly 200px of usable height and any centered modal becomes unreachable; and
tablet-specific layouts if the product ships to tablets, including iPad multitasking widths, which
are *not* the same as phone widths despite being narrow.

## §8 — Internationalization impact on design

i18n is on SKILL.md's Phase 8 blind-spot list because it is discovered late and costs a redesign
when it is. These are the design-time decisions; the engineering pipeline belongs to the
`i18n-workflow` skill.

Even a product shipping English-only should record these decisions, because the cheap version
("leave room, do not bake text into images, do not concatenate strings") costs nothing now and
saves a rebuild later. If the product will never localize, say so explicitly as a decision with a
date, so the next person knows it was considered rather than forgotten.

### 8.1 Text expansion allowance

Translated UI text is longer than English. German and Finnish run long; the short-string case is the
worst, because a 10-character English button can grow past 200%.

| English source length | Plan for | Notes |
|---|---|---|
| ≤10 chars | +200–300% | Buttons, labels, tabs, badges |
| 11–20 chars | +180% | Menu items, form labels |
| 21–30 chars | +160% | Short helper text |
| 31–50 chars | +140% | Sentences |
| 51+ chars | +130% | Paragraphs |

Design consequences to specify: no fixed-width buttons or tabs; no single-line assumption for
labels; navigation must survive its longest translated label without wrapping into two lines and
breaking the rail height; truncation with a tooltip where wrapping is genuinely impossible; and
tables need a column-width strategy that is not "whatever fits English." Also: never build a
sentence by concatenating fragments around a variable — word order differs across languages and the
concatenation cannot be translated correctly. Use full templated strings with named placeholders,
and specify the pluralization mechanism (ICU MessageFormat plural categories, which include `zero`,
`one`, `two`, `few`, `many`, `other` — English uses two of the six).

### 8.2 RTL mirroring

If Arabic, Hebrew, Persian, or Urdu are in scope — and the decision should be explicit either way.

**Mirrors:** overall layout direction; text alignment; the reading order of rows and lists;
navigation position (sidebar moves to the right); progress and slider fill direction; breadcrumb
direction; back/forward and next/previous arrows; the leading/trailing side of icons in buttons;
drawer entry side; and the physical meaning of padding/margin — which is why every spacing property
should be **logical** (`margin-inline-start`, `padding-inline-end`, `inset-inline`,
`border-start-start-radius`) rather than physical (`margin-left`). Specifying logical properties
in the token and component layer is the single highest-leverage RTL decision; retrofitting it
later means touching every component.

**Never mirrors:** clock faces and time direction; media playback controls (play always points in
the direction of time, which is not the direction of text); musical notation; the direction of
physical-world imagery and photographs; numbers themselves (digit sequences stay LTR even in RTL
text); code, file paths, and URLs; chart axes where the axis represents time (verify against
locale convention rather than assuming); and most brand logos.

**Ambiguous, so decide and record:** checkmarks and X marks; volume and signal-strength ramps;
charts generally. Write the decision down rather than leaving it to the implementer.

### 8.3 Locale typography and numerals

Required decisions: whether the font stack covers the target scripts (Latin-only faces render CJK,
Arabic, Devanagari, and Thai as fallback, which looks broken and often breaks the line-height);
per-script line-height overrides, since CJK and Devanagari need more leading than Latin at the same
size and Thai needs more still for its ascenders and tone marks; whether the product supports
non-Western digit systems (Arabic-Indic ٠١٢٣, Devanagari ०१२३) and whether numerals in UI chrome
follow the locale or stay Latin; and word-breaking, since CJK breaks anywhere while Thai has no
spaces at all and needs a proper line-breaking implementation rather than `word-break: break-all`.

### 8.4 Formatting inside components

Every component that renders a date, time, number, currency, name, or address must specify that it
formats via the platform's locale API (`Intl.*` on web, `Foundation` formatters on iOS,
`android.icu` on Android) rather than a hand-rolled format string. Then specify the design-visible
consequences:

- **Dates** vary in *length* wildly across locales, so a column sized for `08/19/2026` breaks on
  `19. August 2026`. Specify which format style each surface uses (`short` / `medium` / `long`) and
  size the container for the long case.
- **Relative time** ("3 days ago") needs a threshold at which it switches to absolute, and an
  absolute value in the tooltip regardless.
- **Currency** varies in symbol position, decimal separator, grouping separator, and grouping *size*
  (Indian lakh/crore grouping is 2,2,3, not 3,3,3). Never right-pad a currency column assuming
  three-digit groups.
- **Time zone** display: state whether times render in the user's zone, the workspace zone, or UTC,
  and show the zone abbreviation wherever ambiguity would cost the user something (a meeting, a
  deadline, an audit log).
- **Names and addresses** have no universal structure. Prefer a single full-name field and a
  free-form address block over first/last and street/city/state, unless a business rule genuinely
  requires the parts.
- **Sorting** is locale-dependent (`Intl.Collator`); a list sorted by ASCII is wrong in most
  European locales and very wrong in CJK.

## §9 — Accessibility acceptance criteria

Each line below is a checkable criterion. "Accessible" is not a criterion; "every interactive
element has a visible focus indicator meeting 3:1 against adjacent colors" is. If a line cannot be
checked by running something or by inspecting a specific attribute, rewrite it until it can.

State the **target level** explicitly, with its reason. WCAG 2.2 Level AA is the working default
because it is what most procurement, most public-sector requirements, and the European Accessibility
Act align to. AAA is not a realistic whole-product target; adopt individual AAA criteria (7:1
contrast, 44px targets) where the audience warrants it and say which.

### 9.1 Web — WCAG 2.2 AA

| Criterion | Check |
|---|---|
| `1.1.1` Non-text content | Every `<img>` has `alt`; decorative images have `alt=""`; icon-only buttons have an accessible name. Automated axe scan finds zero violations. |
| `1.3.1` Info and relationships | Headings are a correct hierarchy with no skipped levels; form controls have programmatic labels; tables have headers with correct scope. |
| `1.3.4` Orientation | No orientation lock, or a documented essential-use exception. |
| `1.3.5` Identify input purpose | `autocomplete` set on every field with a standard purpose (name, email, address, payment). |
| `1.4.3` Contrast (minimum) | The §2.3 table computed, all pairs passing, in both themes. |
| `1.4.4` Resize text | Usable at 200% browser zoom with no loss of content or function; no `user-scalable=no`. |
| `1.4.10` Reflow | No horizontal scroll at 320 CSS px width (i.e. 400% zoom on a 1280 viewport), except for data tables and code, which are exempt. |
| `1.4.11` Non-text contrast | UI component boundaries, focus rings, icons, and chart series all clear 3:1 (§2.3). |
| `1.4.12` Text spacing | No content lost with line-height 1.5×, paragraph spacing 2×, letter-spacing 0.12em, word-spacing 0.16em applied. |
| `1.4.13` Content on hover/focus | Tooltips and popovers are dismissible (Esc), hoverable (pointer can enter them), and persistent until dismissed. |
| `2.1.1` Keyboard | Every function reachable and operable by keyboard, verified by a full keyboard-only pass per screen. |
| `2.1.2` No keyboard trap | Focus can always leave; verified on every modal, drawer, embedded editor, and iframe. |
| `2.4.1` Bypass blocks | Skip link present and functional on every page with repeated nav. |
| `2.4.3` Focus order | Tab order matches visual order; no positive `tabindex`. |
| `2.4.7` Focus visible | Every focusable element has a visible indicator; `outline: none` without a replacement is a CI grep failure. |
| `2.4.11` Focus not obscured | The focused element is never fully hidden behind a sticky header or footer — verified by tabbing a long page with sticky chrome. |
| `2.5.7` Dragging movements | Every drag interaction has a non-drag alternative (a menu, buttons, a keyboard path). |
| `2.5.8` Target size | 24×24 minimum with the spacing exception applied correctly (§7.3). |
| `3.2.2` On input | No context change on input without warning; a `<select>` never auto-navigates. |
| `3.3.1` / `3.3.3` Errors | Errors identified in text (not color alone), with a suggested correction; the error summary is linked to the fields. |
| `3.3.7` Redundant entry | Previously entered information is auto-populated or selectable, not re-typed. |
| `3.3.8` Accessible authentication | No cognitive-function test without an alternative; password managers work (no paste blocking, correct `autocomplete`). |
| `4.1.2` Name/role/value | Every custom control exposes the right role, name, and state; verified in the accessibility tree, not just by attribute presence. |
| `4.1.3` Status messages | Toasts, validation results, and async completions announce via `role="status"` or `role="alert"` without stealing focus. |

Plus, beyond the checklist: an actual screen-reader pass (NVDA on Windows / VoiceOver on macOS) of
every critical flow, and a `prefers-reduced-motion` pass per §5.3. Automated tooling catches roughly
a third of real issues; the criteria above that say "verified by" mean a human or a scripted browser
run, not axe alone.

### 9.2 iOS

| Criterion | Check |
|---|---|
| VoiceOver labels | Every control has a label; images that convey information have labels; decorative ones are hidden with `.accessibilityHidden(true)`. |
| VoiceOver traits | Buttons have `.isButton`, headers `.isHeader`, selected states `.isSelected`; custom controls expose value and adjustable actions. |
| VoiceOver flow | Every critical flow completable with VoiceOver on and the screen curtain enabled — the test that catches "tappable but unlabeled". |
| Reading order | Grouped and ordered logically via `.accessibilityElement(children:)` and `.accessibilitySortPriority`. |
| Dynamic Type | Every screen usable at AX5 with no clipping or overlap (§4.2); layout switches at the stated threshold. |
| Contrast | §2.3 pairs verified in both appearances, plus the Increase Contrast variants where custom colors are used. |
| Target size | 44×44 pt minimum, verified with the Accessibility Inspector audit. |
| Reduce Motion | Honored per §5.3, including `.accessibilityReduceMotion` on custom transitions. |
| Reduce Transparency | Any blur or glass material has a specified opaque fallback (§4.2). |
| Differentiate Without Color | Status conveyed by shape or text as well as hue; verified with the setting on. |
| Bold Text / Button Shapes | Layout survives both system settings. |
| Voice Control | Every control has a name that can be spoken; `.accessibilityInputLabels` set where the visible label is an icon. |
| Accessibility Inspector audit | Zero issues on every screen. |

### 9.3 Android

| Criterion | Check |
|---|---|
| TalkBack labels | `contentDescription` on every non-text control; `null` explicitly on decorative images; Compose `semantics { }` for custom composables. |
| TalkBack flow | Every critical flow completable with TalkBack; verified with the Accessibility Scanner reporting zero issues. |
| Touch targets | 48×48 dp minimum, verified by Accessibility Scanner. |
| Font scale | Usable at `fontScale` 2.0; text in `sp`, not `dp`. |
| Display size | Usable at the largest system display-size setting. |
| Contrast | §2.3 pairs verified against both M3 schemes, and against dynamic-color output if adopted (§4.3). |
| Focus order | Logical traversal order; focus visible for keyboard and D-pad input. |
| Live regions | Async results announced via `LiveRegionMode` / `announceForAccessibility` without stealing focus. |
| Reduced motion | `ANIMATOR_DURATION_SCALE == 0` honored per §5.3. |
| Switch Access | Every flow completable with Switch Access, which is the check that finds unreachable custom gestures. |

### 9.4 Cross-cutting, all platforms

- **Never color alone** (`1.4.1`): every status, every chart series, every diff, every required-field
  marker carries a second channel — icon, shape, text, or pattern.
- **Focus visibility is non-negotiable** and its contrast is a LOCKED token (§2.2).
- **Every animation has a reduced-motion behavior** and none of them gates information (§5.4).
- **Every error tells the user what to do**, not only what went wrong.
- **Semantics before ARIA**: a native `<button>` beats `role="button"`; the best ARIA is the ARIA
  you did not need. Record any custom control's full ARIA pattern by name (the APG pattern it
  implements) so the build has something to conform to rather than improvise.

## §10 — Phase 3 definition of done

Every line mechanically checkable. Run these before declaring Phase 3 complete; Phase 8's pre-flight
audit re-runs them against the finished package and appends the result to `docs/AUDIT_LOG.md`. Per
SKILL.md's rule on vacuous gates, show each check **failing** on a deliberately broken input before
trusting a pass.

**Platform**
1. `DESIGN_SYSTEM.md` §0 names the target platform(s) and the primary one, recorded as `D-UI-1`
   with rejected alternatives.
2. Every §4 subsection required by that platform exists; every one not required is explicitly
   marked N/A.

**Tokens**
3. Every semantic role in §2.1 has a named token with a concrete value.
4. Every color token has both a light and a dark value in the same table. Grep: no color token row
   with an empty value cell.
5. The LOCKED column exists and every token in the §2.2 list is marked LOCKED.
6. The §2.3 contrast table is present with **computed numeric ratios**, both themes, all passing.
   Grep: no ✓ without an adjacent number.
7. The type scale table has all seven columns for every row; no two steps within 2px.
8. Font loading strategy states `font-display`, preloads, and the fallback metric override.
9. Spacing, sizing, radius, border-width, elevation, z-index, breakpoint, container, and motion
   scales all exist with values; z-index layers are all named.
10. Token-reference sweep: every `var(--*)` / `token.*` name used anywhere in `docs/` is defined in
    `DESIGN_TOKENS.md`. Exit nonzero on any orphan.
11. Every output format the platform requires is present, with the source-of-truth format named and
    the regeneration command stated.

**Components**
12. Every component in the §3.3 inventory relevant to the product has an entry.
13. Every component entry has a variant × size × state matrix covering all nine states in §3.1, or
    an explicit N/A with a reason per omitted state. Grep: no empty matrix cells.
14. Every matrix cell names tokens, not literal values. Grep: no hex codes or raw px in component
    tables.
15. Every component entry has all eight fields from §3.4.
16. Component-reference sweep: every component named in `SCREENS.md` exists in the component spec.

**Motion**
17. `MOTION.md` inventory lists every animation with trigger, properties, duration token, easing
    token, delay, and reduced-motion behavior. No row is missing the reduced-motion column.
18. Expressive-motion instances are listed with justifications; no transition on a repeated path
    exceeds `--duration-normal`.
19. The reduced-motion contract names both what is disabled and what is preserved, and preserved
    includes loading indicators and focus visibility.
20. No information exists only in motion — checked per §5.4 against every animation in the
    inventory.

**Screens**
21. Every screen has all ten fields from §6.1.
22. Every screen has one written headline sentence.
23. Every screen enumerates all states from the §6.1 table, N/A with reason where inapplicable.
24. Copy is final everywhere. Grep for `lorem`, `Lorem`, `TODO`, `TBD`, `placeholder`, `Acme`,
    `John Doe`, `example.com`, `xxx`, `Coming soon`. Any hit that is not an explicit `{{TOKEN}}`
    fails. Every `{{TOKEN}}` appears in the open decisions table.
25. Every screen lists its FR IDs; the union across screens covers every UI-bearing FR in the PRD;
    every listed FR ID exists (`scripts/id-sweep.sh docs` exits zero).
26. The §6.2 inventory is complete: auth, settings, billing, errors, legal, and deletion screens all
    accounted for.

**Adaptive and i18n**
27. The §7.1 layout contract table is filled in for every region.
28. Every hidden-at-small-size element is listed with its justification or its equivalent path.
29. Touch-target minimums are stated per platform and every component's target size meets them.
30. Expansion allowance, RTL decision (including logical-property adoption), locale typography, and
    the locale-formatting rule are all recorded — including an explicit "English only, decided
    YYYY-MM-DD" if that is the answer.

**Accessibility**
31. The target WCAG level is stated with its reason.
32. Every §9 criterion for the target platform has a named check, and each check has been run at
    least once with a recorded result — not merely listed.
33. Automated scan (axe / Accessibility Inspector / Accessibility Scanner) reports zero violations
    on the prototype or reference build.
34. A keyboard-only pass and a screen-reader pass have been completed on every critical flow, with
    findings logged.

**Package integrity**
35. `design-review` has been run as a fresh-agent audit pass over the finished design deliverables,
    with findings, fixes, and the verification verdict written to `docs/AUDIT_LOG.md`.
36. The precedence chain (semantics > tokens > screens/motion > wireframes) is written verbatim in
    both `CLAUDE.md` and `DESIGN_SYSTEM.md` §0.
37. Wireframe-to-hi-fi deltas are recorded wherever the visual design deliberately diverges.
38. Every check above has been demonstrated failing on a known-bad input before being trusted.
