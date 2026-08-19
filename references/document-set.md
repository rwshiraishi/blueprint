# The document set

Fourteen deliverables. Scale to the product — small tools merge documents; the roles and the
precedence chain stay. Every document is prose-first with reasons attached; bullets only where a
list is genuinely a list.

Each row's "must contain" cell is a summary. The **acceptance contract** — the exhaustive required
contents, with field schemas and worked examples — lives in the deliverable-spec files. Load the
matching one before producing the document; a summary produces a plausible, thin document, which is
the failure this whole reference layer exists to prevent.

| Document | Acceptance contract |
|---|---|
| PRD | `deliverables-requirements.md` |
| DESIGN_SPEC, EXTENSIBILITY | `deliverables-architecture.md` |
| DESIGN_SYSTEM, DESIGN_TOKENS, SCREENS, MOTION, WIREFRAMES, PROTOTYPE | `deliverables-design.md` |
| SECURITY | `deliverables-security.md` |
| TESTS_TDD | `deliverables-testing.md` |
| LOOP_GOALS, STATE_AND_DATA | `deliverables-build-goals.md` |
| CLAUDE.md | `claude-md-template.md` |

Before any of it: `elicitation.md` establishes what the user actually has and pins the scope and
design direction. Most users arrive with a sentence and no artifacts; that is the normal case.

| Document | Role | Must contain |
|---|---|---|
| `CLAUDE.md` (repo root) | Entry point + operating contract for the build | Document map, precedence chain, never-stop protocol, prerequisites, phase table, merged non-negotiables, definition of done, maintained build-state section |
| `docs/PRD.md` | What and why | FR groups (testable, prioritized), NFRs with numbers, personas, launch metrics, risks, open decisions D1…Dn with recommendations, Phase-0 failure-mode rationale |
| `docs/DESIGN_SPEC.md` | How — normative; wins on mechanism | AD table, schema DDL, service/pipeline design, API, integrations, observability/SLOs, cost model (dated verified prices), capacity + user-scaling, build plan, verification backlog (⚠ items with fallbacks) |
| `docs/DESIGN_SYSTEM.md` | Design semantics — wins on meaning | Principles (P0 one-message-per-screen first), locked semantic tokens, typography, a11y, content rules, recorded design decisions |
| `docs/DESIGN_TOKENS.md` | Visual truth — values | Every color/type/spacing/radius token as drop-in CSS + theme extension; dark mode as token swap |
| `docs/SCREENS.md` | Visual truth — screens | Per screen: headline message, layout, components with values, exact copy |
| `docs/MOTION.md` | Motion contract | Calm default / expressive opt-in inventory with timings; reduced-motion disables all |
| `docs/STATE_AND_DATA.md` | UI state + data shapes | State model, URL-addressable view state, handlers, per-screen data interfaces matching the schema |
| `docs/WIREFRAMES.md/.html` | Structural + traceability record | Gray-box screens, numbered FR annotations, state policy; marked superseded-visually with deltas listed |
| `docs/PROTOTYPE.html` + `docs/screenshots/` | Measurable reference | Self-contained runnable prototype; captures of every screen |
| `docs/SECURITY.md` | Threat model + enforced rules | Actor×surface threats, rules each naming machine enforcement, isolation defense-in-depth, security test suites mapped to CI jobs |
| `docs/EXTENSIBILITY.md` | Modularity contract | Fixed kernel, enumerated extension surfaces, tenant config governance, worked module examples, what is NOT extensible + escalation path |
| `docs/TESTS_TDD.md` | Acceptance oracle | Test-first protocol, real-infra substrate, per-subsystem suites with skeletons, regression tests named for Phase-0 defects, eval gates, FR↔test traceability |
| `docs/LOOP_GOALS.md` | Build backbone | Toolchain pins + data sources, invariant gate definition, goals with Depends + literal exit commands, inheritance rule for plan items without full entries, TDD reading map, anti-goals with greps, budget notes |

## Precedence chain

On any conflict: **PRD intent > DESIGN_SPEC mechanism > DESIGN_SYSTEM semantics > visual files
(TOKENS/SCREENS/MOTION) > wireframes.** Within UI: safety semantics override visual files; the
tokens file overrides everything else visual; wireframes lose on visuals but are the only FR
traceability layer. Write this chain into CLAUDE.md and DESIGN_SYSTEM §0 verbatim — fourteen
documents without a declared winner rot into contradictions within three edit passes.

## Numbering conventions

- Requirements: `FR-<GROUP>-<n>` / `NFR-<AXIS>-<n>` — stable IDs, never renumber.
- Decisions: `D<n>` in the PRD; design decisions recorded where made (e.g., D-UI-n).
- Architecture decisions: `AD-<n>` table in DESIGN_SPEC.
- Goals: `G-<phase>.<n>`, matching the build plan's deliverable numbering.
- Test suites: `TS-<GROUP>-<n>` — the group matches the FR group it proves wherever one exists.
- Phase-0 defects: `DR-<n>` (defect register), cited by the regression test named for it.

Every ID family in this list is recognised by `scripts/id-sweep.sh`. Adding a family here without
adding it to that script's grammar makes the new IDs invisible to the pre-flight gate — which is
exactly how a cross-reference check passes while references dangle.
- Every threshold/constant in the spec is tenant/user configuration with a recorded default —
  hardcoded values are a named anti-pattern.
