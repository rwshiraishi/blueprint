# app-blueprint

**A portable agent skill that turns "I want to build X" into a build-ready documentation package
an autonomous coding agent can execute start-to-finish.**

Point an agent at a product idea — or a legacy codebase you want to replace — and this skill walks
a preparation pipeline that ends with a repo you can hand to a coding agent with one word: *begin*.

You do **not** need an existing PRD, repo, design system, or brand. The common case is a person
with one sentence, and the pipeline starts by getting you from there to pinned scope and a stated
design direction.

---

## Why this exists

Builds don't usually fail in the implementation. They fail in the preparation: requirements that
can't be tested, designs nobody audited, security bolted on at the end, costs quoted from memory,
and a plan the coding agent has to improvise around.

The core bet: **time spent making requirements adversarially-audited, tests-first, and
machine-checkable pays back multiples.** The output isn't documentation — it's the acceptance
oracle, the dependency graph, and the operating contract for the build itself.

The skill is deliberately opinionated about one thing above all: **every rule names the machine
that enforces it.** A rule with no CI grep, lint rule, test suite, or database privilege behind it
is not a rule, it is a wish — and it will not survive contact with the build.

## What makes it different from "write me a PRD"

Most planning output is prose that reads well and cannot say *no* to anything. This skill produces
**acceptance contracts**: exhaustive required-content schemas with worked examples, so a
deliverable either satisfies them or visibly does not.

Three examples of what that means in practice:

- A requirement like *"the system should be fast"* is diagnosed as vacuous by construction — no
  actor, no operation, no number, therefore no input can make it fail — and rewritten into a
  numeric NFR plus a behavioral FR, with the degrade path specified.
- A button is not "styled." It is specified across every variant × size × state, with a named
  token in every cell, including the disabled state staying focusable so a tooltip can explain why.
- A security control is graded on *how* it is enforced, on a seven-tier scale where making the
  unsafe thing inexpressible ranks first and "code review" is explicitly **not** enforcement.

## What it produces

A document package, scaled to product size — a weekend tool gets a page per phase, a multi-tenant
SaaS gets the full treatment:

```
repo/
├── CLAUDE.md / AGENTS.md      ← entry point: the build's operating contract
└── docs/
    ├── PRD.md                 ← testable requirements, open decisions with recommendations
    ├── DESIGN_SPEC.md         ← normative architecture, schema DDL, verified-price cost model
    ├── DESIGN_SYSTEM.md       ← design semantics: one-message-per-screen, locked tokens
    ├── DESIGN_TOKENS.md       ← every visual value, drop-in, dark mode as token swap
    ├── SCREENS.md             ← per-screen layout, components, exact copy
    ├── MOTION.md              ← calm-default motion contract
    ├── STATE_AND_DATA.md      ← UI state model + data shapes
    ├── WIREFRAMES.md/.html    ← structural record with requirement traceability
    ├── PROTOTYPE.html         ← runnable reference + screenshots/
    ├── SECURITY.md            ← threat model; every rule names its machine enforcement
    ├── EXTENSIBILITY.md       ← fixed kernel + extension surfaces; what is NOT extensible
    ├── TESTS_TDD.md           ← the acceptance oracle: tests-first, real-infrastructure
    ├── LOOP_GOALS.md          ← build goals with literal exit commands + dependency graph
    └── AUDIT_LOG.md           ← every audit's findings, fixes, and verification verdicts
```

A declared **precedence chain** (PRD intent > spec mechanism > design semantics > visual values >
wireframes) keeps the documents from contradicting each other across edit passes.

## Platforms covered

Design and architecture deliverables are specified per platform, because a CSS custom-property
file handed to an iOS build is inert and a breakpoint scale means nothing on native:

| | Responsive web | Native iOS | Native Android | Cross-platform | Desktop | SaaS shell |
|---|---|---|---|---|---|---|
| **Token format** | CSS custom properties | Swift constants / asset catalog | Kotlin + `res/values/` or Compose theme | JSON source + generated adapters | CSS + OS accent hooks | CSS + tenant-overridable subset |
| **Adaptive axis** | Breakpoints + container queries | Size classes + Dynamic Type | Window size classes + density | Both, resolved by adapters | Window size, multi-window | Breakpoints + density mode |
| **Min target** | 24×24 px (WCAG 2.2) | 44×44 pt (HIG) | 48×48 dp (Material) | larger of the two | 24×24 px | 24×24, 32 for primary |

## Resumable by design

Long builds outlive a context window. The plan is written so a session can end mid-goal — on a
budget cap, a blocker, or a deliberate context clear — and a fresh agent can pick it up cold.

`LOOP_GOALS.md` opens with a progress ledger the build ticks in place, and every goal carries a
nine-step checklist so "half done" is a readable state rather than a guess:

```
- [x] G-1.2  Database schema and migration runner
- [~] G-4.2  Live provider send path            (3/4 EC green · blocked on B-3 for EC-3)
- [!] G-7.1  App Store Connect upload pipeline   (B-5: ASC API key)
- [ ] G-4.3  Bounce and complaint webhook intake

G-4.3  Steps
  [x] 2. Write the failing tests   [x] 3. Confirm each fails on its intended assertion
  [x] 4. Commit the failing tests  [~] 5. Implement until green
  [ ] 6. Invariant gate            [ ] 7. Exit criteria, green twice
```

Status markers are the **only** thing the build may edit in that file — a build that can edit its
own acceptance criteria has no acceptance criteria. The cold-resume sequence is written into the
entry-point file verbatim, because an agent that has just lost its context cannot infer a recovery
procedure from principles. It reads five things in order, then **re-runs the criteria already
marked green before trusting them**: a marker records what the last session believed, and the
command reports what is true.

## The pipeline

| # | Phase | The point |
|---|---|---|
| — | **Intake** | Establish what you actually have. Batched concrete option questions, never turn-by-turn interrogation. Pins scope and pulls a **design direction out of nothing** via references, anti-references, and forced-choice registers. |
| 0 | **Source audit** | Read the legacy code, not its README. Line-verified defects become named requirements and regression tests. With no predecessor, this retargets to competitors or your current manual process — a greenfield product still enters Phase 1 on evidence. |
| 1 | **PRD** | Testable FRs, numeric NFRs, and an open-decisions table — decisions surfaced, never silently assumed. |
| 2 | **Design spec + adversarial audits** | Write the spec, then *attack it* with fresh-context audit passes before anyone builds. Verify the fixes separately — patches breed their own bugs. |
| 3 | **Design language** | Semantics → wireframes (traceability) → hi-fi (tokens, screens, motion), with precedence declared and deltas recorded. |
| 4 | **Security** | Threat model by actor × surface; rules that name a CI grep, lint rule, or test — never policy prose. |
| 5 | **Extensibility + scale** | Fixed kernel, enumerated extension surfaces; scaling designed for *both* axes — data volume and users. |
| 6 | **TDD spec** | Failing-tests-first; real database with real security policies (mocked authz tests are worthless); regression tests named for Phase-0 defects. |
| 7 | **Goals + playbook** | Machine-checkable exit criteria, dependency graph, invariant gate, grep-enforced anti-goals, and the never-stop protocol that routes blockers instead of halting. |
| 8 | **Pre-flight audit** | A mechanical ID sweep plus a readiness audit against your own package: broken refs, first-hour traps, world-class blind spots (i18n, billing, email deliverability, error tracking, SLAs). Fix to GO. |
| 9 | **Repo layout** | Entry point at root, everything in flat `docs/` — a repo that bootstraps itself. |

### Sizing gate

The full treatment is a real cost. The skill picks a tier out loud before starting and will not
drift upward silently:

| Tier | Trigger | Output |
|---|---|---|
| **Sketch** | One user, no auth, no money | One `BUILD.md`. Phases 1, 6, 7 only. |
| **Standard** | Real users, auth, a database | Six documents, all phases, one audit pass each. |
| **Full** | Multi-tenant, money, compliance, or a rewrite | The full set, every audit, both verification passes. |

## Operating principles baked in

- **Verify, never assume** — every external claim (API, price, platform capability) checked against
  a primary source with URL and fetch date recorded. Unfetchable is recorded as "could not verify,"
  never estimated silently. A remembered price is a guess wearing a citation.
- **Never fabricate** — no invented company names, emails, URLs, or legal entities. Those become
  explicit placeholders or open questions.
- **No placeholder data** — a fabricated value that renders identically to a real one is forbidden.
  Missing data surfaces as an explicit empty state and returns null upstream.
- **Fresh eyes for audits** — audit agents get no authorship context; authorship bias is real.
- **Every audit leaves an artifact** — `AUDIT_LOG.md`, even when nothing is found. An audit with no
  record is indistinguishable from an audit that never ran.
- **Negative-test every gate** — a check that has never gone red is passing vacuously, and a vacuous
  gate is worse than no gate: it converts an unexamined package into a confident GO.
- **Decisions belong to the user** — anything genuinely their call goes in the decisions table with
  a recommendation attached.

## Does it work?

Benchmarked against a no-skill baseline on two realistic prompts (a small landlord-maintenance
SaaS; a nonprofit legacy-system rewrite), graded on 16 objective assertions:

| | Assertion pass rate |
|---|---|
| **With skill** | **94%** |
| Baseline (no skill) | 13% |

The baselines produced competent engineering documents — and missed every workflow element: no
build playbook, silent assumptions instead of decision tables, security as prose, no audit of their
own output. One baseline *fabricated* details of a legacy system it never saw; the skill run
flagged the same unknown as a verification item.

*Measured against the pipeline as it stood before the Intake phase, sizing gate, and the
`references/deliverables-*` acceptance contracts were added. Those changes are not covered by this
benchmark and it has not been re-run.*

---

# Installation

The skill is a folder containing `SKILL.md`, `references/`, and `scripts/`. Most agent tools load
that same shape; only the directory differs.

## Claude Code

```bash
git clone https://github.com/rwshiraishi/blueprint.git
mkdir -p ~/.claude/skills/app-blueprint
cp -R blueprint/SKILL.md blueprint/references blueprint/scripts ~/.claude/skills/app-blueprint/
chmod +x ~/.claude/skills/app-blueprint/scripts/id-sweep.sh
```

Project-scoped instead of global: use `.claude/skills/app-blueprint/` inside the repo.

Verify it loaded by starting Claude Code and asking it to list available skills, or just describe a
product — the skill triggers on preparation-shaped requests.

## Claude apps (claude.ai, desktop, Cowork)

Download `app-blueprint.skill` from this repo, then either:

- attach it in a conversation and choose **Save skill**, or
- add it under **Settings → Capabilities → Skills**.

The `.skill` file is a zip of the same folder, rebuilt from source on every release.

## OpenAI Codex

Codex loads `SKILL.md` skills from a skills directory, activated on relevance rather than always-on:

```bash
git clone https://github.com/rwshiraishi/blueprint.git
mkdir -p ~/.codex/skills/app-blueprint
cp -R blueprint/SKILL.md blueprint/references blueprint/scripts ~/.codex/skills/app-blueprint/
chmod +x ~/.codex/skills/app-blueprint/scripts/id-sweep.sh
```

Use `.codex/skills/app-blueprint/` inside a repo for project scope.

If you would rather have it always in context, append `SKILL.md` to your `AGENTS.md` instead —
but note Codex's default `project_doc_max_bytes` is 32 KiB, so append the pipeline and load the
`references/` files on demand rather than pasting everything.

## Any agent that reads AGENTS.md

`AGENTS.md` is a cross-tool standard stewarded by the Agentic AI Foundation, and is read by Claude
Code, Codex, and a growing set of other tools. For anything that supports it but has no skills
directory:

```bash
cat blueprint/SKILL.md >> AGENTS.md
```

Then tell the agent to read the matching file in `references/` when it enters a phase. The phase →
reference map is in `SKILL.md`; that indirection is what keeps the always-on context small.

## Cursor, Windsurf, and other IDE agents

Copy `SKILL.md` into the tool's rules file (`.cursor/rules/`, `.windsurfrules`, or equivalent) and
keep `references/` in the repo. The skill is plain markdown with no runtime dependency beyond one
optional shell script, so it ports without modification.

## Requirements

Nothing, to author documents. The one script (`scripts/id-sweep.sh`) needs `bash` and a `grep`
supporting `\b` word boundaries — GNU grep or macOS/BSD grep both work, and the script checks for
this at startup and fails loudly rather than silently mismatching. Busybox grep is not sufficient.

---

# Usage

Describe the product. The skill triggers on preparation-shaped requests:

> "I want to build a SaaS for small landlords to manage maintenance requests — prepare everything a
> coding agent needs to build it."

> "We have a 10-year-old PHP tool that's a mess. Plan a modern rewrite we can hand to an AI coding
> agent, with security done right this time."

> "Spec out an iOS app for tracking climbing sessions. I have no designs and no brand yet."

The agent will state its sizing tier, interview you at phase boundaries with concrete options
rather than open-ended questions, run the audits, and deliver the package. When it's done, point
your coding agent at the repo — it reads the entry-point file and begins.

## The ID sweep

Phase 8 requires a mechanical cross-reference check rather than eyeballing, because eyeballing has
never once caught a dangling requirement reference in a fourteen-document set:

```bash
./scripts/id-sweep.sh docs
```

It greps every `FR-`, `NFR-`, `TS-`, `AD-`, `DR-`, `D`, and `G-` identifier across your package and
exits nonzero when one is referenced but never defined. Definitions are graded **STRONG** (heading,
list item, bold lead-in, or `ID: text` idiom), **WEAK** (alone in a table cell — a definition table
and a traceability table are structurally identical, so these are reported for eyeballing rather
than guessed at), and **NONE** (mentioned only in prose, treated as undefined). Append its output
to `AUDIT_LOG.md`.

---

# Repository contents

| Path | What |
|---|---|
| `SKILL.md` | The skill: trigger description, sizing gate, pipeline, phase → reference map |
| `references/elicitation.md` | Intake: triage, interview protocol, question bank, and eliciting a design direction from nothing |
| `references/deliverables-requirements.md` | Acceptance contract for the PRD and the Phase-0 audit |
| `references/deliverables-architecture.md` | Acceptance contract for the design spec and extensibility |
| `references/deliverables-design.md` | Acceptance contract for tokens, components, screens, motion, per platform |
| `references/deliverables-security.md` | Acceptance contract for the threat model and enforced rules |
| `references/deliverables-testing.md` | Acceptance contract for the TDD specification |
| `references/deliverables-build-goals.md` | Acceptance contract for build goals and state/data |
| `references/document-set.md` | The deliverables, their roles, the precedence chain, numbering conventions |
| `references/audits.md` | The adversarial audit playbook and the pre-flight readiness gate |
| `references/claude-md-template.md` | Skeleton for the autonomous-build playbook |
| `references/lessons.md` | Living ledger — the skill records how it performed and promotes rules on evidence |
| `scripts/id-sweep.sh` | The mechanical cross-reference gate |
| `app-blueprint.skill` | Packaged skill for the Claude apps |

## Self-improvement

`references/lessons.md` is a living ledger with an explicit promotion protocol: CANDIDATE on one
observation, PROMOTED into the skill on two confirmations or one airtight causal chain (date
stamped, with the edit recorded), DEMOTED by reverting the edit when counter-evidence appears,
never by silent deletion.

The signal it records is **which phase caught a defect and which earlier phase should have** — a
defect caught at pre-flight that Phase 0 should have caught names a hole in an earlier gate. Four
mechanisms are guarded and may never be weakened by a lesson: the line-verified source audit, the
pre-flight gate, the fresh-agent rule for audits, and the requirement that every audit leave an
artifact.

## Contributing

Issues and pull requests welcome. If you change a phase, update the matching acceptance contract in
`references/` in the same change — a phase whose contract still describes the old behavior is the
exact drift this skill exists to prevent.

If you add an identifier family, update three places together: the numbering conventions in
`document-set.md`, the grammar in `scripts/id-sweep.sh`, and the traceability tables that use it.
Adding it in only one place makes the new identifiers invisible to the pre-flight gate.

## License

MIT — use it, fork it, adapt the methodology to your stack.
