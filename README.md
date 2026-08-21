# app-blueprint

**A portable agent skill that turns "I want to build X" into a build-ready documentation package
an autonomous coding agent can execute start-to-finish.**

Point an agent at a product idea, or at a legacy codebase you want to replace, and this skill walks
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
machine-checkable pays back multiples.** The output isn't documentation. It's the acceptance
oracle, the dependency graph, and the operating contract for the build itself.

The skill is deliberately opinionated about one thing above all: **every rule names the machine
that enforces it.** A rule with no CI grep, lint rule, test suite, or database privilege behind it
is not a rule, it is a wish, and it will not survive contact with the build.

That standard is applied to the skill itself. Its own gates ship as scripts, each one demonstrated
failing on a known-bad input before being trusted, because a check that has never gone red is
passing vacuously.

## What makes it different from "write me a PRD"

Most planning output is prose that reads well and cannot say *no* to anything. This skill produces
**acceptance contracts**: exhaustive required-content schemas with worked examples, so a
deliverable either satisfies them or visibly does not.

Four examples of what that means in practice:

- A requirement like *"the system should be fast"* is diagnosed as vacuous by construction (no
  actor, no operation, no number, therefore no input can make it fail) and rewritten into a
  numeric NFR plus a behavioral FR, with the degrade path specified.
- A button is not "styled." It is specified across every variant, size, and state, with a named
  token in every cell, including the disabled state staying focusable so a tooltip can explain why.
- A security control is graded on *how* it is enforced, on a seven-tier scale where making the
  unsafe thing inexpressible ranks first and "code review" is explicitly **not** enforcement.
- A visual direction is elicited before any token is written, with references, anti-references, and
  a derivation table tying each choice back to a sentence of that direction. A palette that comes
  out as default-framework greys with a default-framework accent is treated as a symptom: it is
  what a model reaches for when nobody gave it a point of view.

## What it produces

A document package, scaled to product size. A weekend tool gets a page per phase; a multi-tenant
SaaS gets the full treatment:

```
repo/
├── CLAUDE.md / AGENTS.md      ← entry point: the build's operating contract
├── foreman-notes.md           ← build commands, shared-tree hazards, parallel-safe goals
└── docs/
    ├── PRD.md                 ← testable requirements, open decisions with recommendations
    ├── DESIGN_SPEC.md         ← normative architecture, schema DDL, verified-price cost model,
    │                            integrations, verification backlog, the numbered build plan
    ├── DESIGN_SYSTEM.md       ← design semantics: direction, one-message-per-screen, locked tokens
    ├── DESIGN_TOKENS.md       ← every visual value, drop-in, dark mode as token swap
    ├── SCREENS.md             ← per-screen layout, components, exact copy
    ├── MOTION.md              ← calm-default motion contract
    ├── STATE_AND_DATA.md      ← UI state model and data shapes
    ├── WIREFRAMES.md/.html    ← structural record with requirement traceability
    ├── PROTOTYPE.html         ← runnable reference plus screenshots/
    ├── SECURITY.md            ← threat model; every rule names its machine enforcement
    ├── EXTENSIBILITY.md       ← fixed kernel and extension surfaces; what is NOT extensible
    ├── TESTS_TDD.md           ← the acceptance oracle: tests-first, real-infrastructure
    ├── LOOP_GOALS.md          ← build goals with literal exit commands and a dependency graph
    └── AUDIT_LOG.md           ← every audit's findings, fixes, and verification verdicts
```

A declared **precedence chain** (PRD intent, then spec mechanism, then design semantics, then
visual values, then wireframes) keeps the documents from contradicting each other across edit
passes.

## Platforms covered

Design and architecture deliverables are specified per platform, because a CSS custom-property
file handed to an iOS build is inert and a breakpoint scale means nothing on native:

| | Responsive web | Native iOS | Native Android | Cross-platform | Desktop | SaaS shell |
|---|---|---|---|---|---|---|
| **Token format** | CSS custom properties | Swift constants / asset catalog | Kotlin plus `res/values/` or Compose theme | JSON source plus generated adapters | CSS plus OS accent hooks | CSS plus tenant-overridable subset |
| **Adaptive axis** | Breakpoints plus container queries | Size classes plus Dynamic Type | Window size classes plus density | Both, resolved by adapters | Window size, multi-window | Breakpoints plus density mode |
| **Min target** | 24×24 px (WCAG 2.2) | 44×44 pt (HIG) | 48×48 dp (Material) | larger of the two | 24×24 px | 24×24, 32 for primary |

## Resumable by design

Long builds outlive a context window. The plan is written so a session can end mid-goal, on a
budget cap, a blocker, or a deliberate context clear, and a fresh agent can pick it up cold.

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

Status markers are the **only** thing the build may edit in that file. A build that can edit its
own acceptance criteria has no acceptance criteria. The cold-resume sequence is written into the
entry-point file verbatim, because an agent that has just lost its context cannot infer a recovery
procedure from principles. It reads five things in order, then **re-runs the criteria already
marked green before trusting them**: a marker records what the last session believed, and the
command reports what is true.

## The pipeline

| # | Phase | The point |
|---|---|---|
| : | **Intake** | Establish what you actually have. Batched concrete option questions, never turn-by-turn interrogation. Pins scope and pulls a **design direction out of nothing** via references, anti-references, and forced-choice registers. |
| 0 | **Source audit** | Read the legacy code, not its README. Line-verified defects become named requirements and regression tests. With no predecessor, this retargets to competitors or your current manual process, so a greenfield product still enters Phase 1 on evidence. |
| 1 | **PRD** | Testable FRs, numeric NFRs, and an open-decisions table. Decisions are surfaced, never silently assumed. |
| 2 | **Design spec plus adversarial audits** | Write the spec, then *attack it* with fresh-context audit passes before anyone builds. Verify the fixes separately, because patches breed their own bugs. |
| 3 | **Design language** | Direction, then semantics, then wireframes (traceability), then hi-fi (tokens, screens, motion), with precedence declared and deltas recorded. |
| 4 | **Security** | Threat model by actor × surface across fourteen domains. Rules name a CI grep, lint rule, test, or database privilege, never policy prose. |
| 5 | **Extensibility plus scale** | Fixed kernel, enumerated extension surfaces, and scaling designed for *both* axes: data volume and users. |
| 6 | **TDD spec** | Failing-tests-first, real database with real security policies (mocked authz tests are worthless), regression tests named for Phase-0 defects. |
| 7 | **Goals plus playbook** | Machine-checkable exit criteria, dependency graph, invariant gate, grep-enforced anti-goals, and the never-stop protocol that routes blockers instead of halting. |
| 8 | **Pre-flight audit** | Two mechanical sweeps plus a readiness audit against your own package: broken refs, first-hour traps, world-class blind spots (i18n, billing, email deliverability, error tracking, SLAs). Fix to GO. |
| 9 | **Repo layout and handoff** | Entry point at root, everything in flat `docs/`. A repo that bootstraps itself. |

### Sizing gate

The full treatment is a real cost. The skill picks a tier out loud before starting and will not
drift upward silently:

| Tier | Trigger | Output |
|---|---|---|
| **Sketch** | One user, no auth, no money | One `BUILD.md`. Phases 1, 6, 7 only. |
| **Standard** | Real users, auth, a database | Six documents, all phases, one audit pass each. |
| **Full** | Multi-tenant, money, compliance, or a rewrite | The full set, every audit, both verification passes. |

Every acceptance contract carries its own tier paragraph naming what drops and, more importantly,
what never drops at any tier.

## The three gates

Phase 8 requires mechanical sweeps rather than eyeballing, because eyeballing has never once caught
a dangling requirement reference in a fourteen-document set. All three ship with the skill, need
nothing but `bash` and `awk`, and have been negative-tested one fixture per branch.

```bash
./scripts/id-sweep.sh docs                      # cross-references resolve
./scripts/goal-graph.sh docs/LOOP_GOALS.md      # build order is sound
./scripts/lessons-check.sh references/lessons.md  # the skill is still measuring itself
```

**`id-sweep.sh`** greps every identifier family listed in `references/document-set.md` (currently
`FR- NFR- TS- EVAL- SCR- UNTESTABLE- ADR- AD- AG- DR- PI- EC- D- D<n> G-<n>.<n>[a-z]`) and exits
nonzero when one is referenced but never defined. Definitions are graded **STRONG** (heading, list
item, bold lead-in, or the `ID: text` idiom), **WEAK** (alone in a table cell, reported for
eyeballing because a definition table and a traceability table are structurally identical), and
**NONE** (mentioned only in prose, treated as undefined). Append the output to `AUDIT_LOG.md`.

**`goal-graph.sh`** reads the `Depends on:` fields and exits nonzero on a cycle, a dependency on an
undefined goal, a self-dependency, or a graph with no root. A cycle makes the never-stop protocol's
unblocked set permanently empty, which presents as a build that stops for no visible reason.

**`lessons-check.sh`** validates the self-improvement ledger. See below.

## Self-improvement, with a gate on it

`references/lessons.md` is a living ledger with an explicit promotion protocol: CANDIDATE on one
observation; PROMOTED into the skill on two confirmations or one airtight causal chain, date
stamped with the edit recorded; DEMOTED by reverting the edit when counter-evidence appears, never
by silent deletion. A lesson promoted on a *sibling* skill's evidence keeps a `(transfer)`
qualifier until a real run confirms it, because borrowed evidence that never gets tested hardens
into fact.

The signal it records is **which phase caught a defect and which earlier phase should have.** A
defect caught at pre-flight that Phase 0 should have caught names a hole in an earlier gate, and
that is the only kind of entry that improves the method rather than describing it.

That was a request with no machine behind it, which by the skill's own standard makes it a wish.
So `scripts/lessons-check.sh` now enforces it. It fails on:

- a lesson at PROMOTED with no `Landed-in`, meaning the ledger claims an edit the skill may not have
- a lesson missing its Rule or its Evidence
- a run record missing any required field, since those fields are precisely the numbers that answer
  the ledger's open questions
- an undated run record
- a ledger with **no UNANSWERED section**, which is a ledger claiming the method is fully understood

It warns when transfers remain unconfirmed after three real runs. Run it as the last step of
Phase 9, before the handoff message.

Four mechanisms are guarded and may never be weakened by a lesson: the line-verified source audit,
the pre-flight gate, the fresh-agent rule for audits, and the requirement that every audit leave an
artifact.

## Handing off to a build

The skill stops at a repo an agent can be told to build. It does not build it.

If you execute with a boss/worker/checker orchestrator such as `foreman`, note that such tools
generally **derive** a constitution from the entry-point file and **write their own** task
decomposition, rather than ingesting `LOOP_GOALS.md` directly. Phase 9 accounts for that: it marks
a liftable one-page `## Constitution core` inside the entry-point file, gives every goal a
worker-sized `worker-extract:` beside its full reading map, tags full-build exit criteria
`scope: boss` so concurrent checkers do not corrupt a shared working tree, seeds `foreman-notes.md`
at the repo root, and states the mapping between this package's ledger markers and the
orchestrator's verdicts.

This handoff is designed and is **not yet verified end to end**. It is tracked as an open question
in the lessons ledger (`U-AB4`). Treat your first handoff as an experiment and record what breaks.

## Operating principles baked in

- **Verify, never assume.** Every external claim (API, price, rate limit, platform capability) is
  checked against a primary source with URL and fetch date recorded. Unfetchable is recorded as
  "could not verify," never estimated silently. A remembered price is a guess wearing a citation.
- **Never fabricate.** No invented company names, emails, URLs, or legal entities. Those become
  explicit placeholders or open questions.
- **No placeholder data.** A fabricated value that renders identically to a real one is forbidden.
  Missing data surfaces as an explicit empty state and returns null upstream.
- **Fresh eyes for audits.** Audit agents get no authorship context, because authorship bias is
  real.
- **Every audit leaves an artifact.** `AUDIT_LOG.md` gets an entry even when nothing is found, in a
  fixed append format. An audit with no record is indistinguishable from an audit that never ran.
- **Negative-test every gate.** A check that has never gone red is passing vacuously, and a vacuous
  gate is worse than no gate: it converts an unexamined package into a confident GO. This applies
  to each tier of a grading check independently, not just to its overall pass and fail.
- **Decisions belong to the user.** Anything genuinely their call goes in the decisions table with
  a recommendation attached.

## Does it work?

Benchmarked against a no-skill baseline on two realistic prompts (a small landlord-maintenance
SaaS, and a nonprofit legacy-system rewrite), graded on 16 objective assertions:

| | Assertion pass rate |
|---|---|
| **With skill** | **94%** |
| Baseline (no skill) | 13% |

The baselines produced competent engineering documents and missed every workflow element: no build
playbook, silent assumptions instead of decision tables, security as prose, no audit of their own
output. One baseline *fabricated* details of a legacy system it never saw; the skill run flagged
the same unknown as a verification item.

> **Read this number with care.** It was measured before the Intake phase, the sizing gate, the
> `references/deliverables-*` acceptance contracts, and the second and third gate scripts existed.
> The benchmark has not been re-run since. The skill's own ledger records that it has never yet
> been run end to end on a real product (`U-AB1`), so the sizing gate in particular is reasoned,
> not measured. Treat 94% as evidence the approach beats unstructured prompting, not as a current
> measurement of this version.

---

# Installation

The skill is a folder containing `SKILL.md`, `references/`, and `scripts/`. Most agent tools load
that same shape; only the directory differs.

## Claude Code

```bash
git clone https://github.com/rwshiraishi/blueprint.git
mkdir -p ~/.claude/skills/app-blueprint
cp -R blueprint/SKILL.md blueprint/references blueprint/scripts ~/.claude/skills/app-blueprint/
chmod +x ~/.claude/skills/app-blueprint/scripts/*.sh
```

Project-scoped instead of global: use `.claude/skills/app-blueprint/` inside the repo.

Verify it loaded by starting Claude Code and asking it to list available skills, or just describe a
product. The skill triggers on preparation-shaped requests.

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
chmod +x ~/.codex/skills/app-blueprint/scripts/*.sh
```

Use `.codex/skills/app-blueprint/` inside a repo for project scope.

If you would rather have it always in context, append `SKILL.md` to your `AGENTS.md` instead. Note
that Codex's default `project_doc_max_bytes` is 32 KiB, so append the pipeline and load the
`references/` files on demand rather than pasting everything.

## Any agent that reads AGENTS.md

`AGENTS.md` is a cross-tool standard stewarded by the Agentic AI Foundation, and is read by Claude
Code, Codex, and a growing set of other tools. For anything that supports it but has no skills
directory:

```bash
cat blueprint/SKILL.md >> AGENTS.md
```

Then tell the agent to read the matching file in `references/` when it enters a phase. The phase to
reference map is in `SKILL.md`; that indirection is what keeps the always-on context small.

## Cursor, Windsurf, and other IDE agents

Copy `SKILL.md` into the tool's rules file (`.cursor/rules/`, `.windsurfrules`, or equivalent) and
keep `references/` in the repo. The skill is plain markdown with no runtime dependency beyond three
optional shell scripts, so it ports without modification.

## Requirements

Nothing, to author documents.

The three scripts need `bash`, `awk`, and a `grep` supporting `\b` word boundaries. GNU grep and
macOS/BSD grep both work, and `id-sweep.sh` checks for this at startup and fails loudly rather than
silently mismatching. Busybox grep is not sufficient.

---

# Usage

Describe the product. The skill triggers on preparation-shaped requests:

> "I want to build a SaaS for small landlords to manage maintenance requests. Prepare everything a
> coding agent needs to build it."

> "We have a 10-year-old PHP tool that's a mess. Plan a modern rewrite we can hand to an AI coding
> agent, with security done right this time."

> "Spec out an iOS app for tracking climbing sessions. I have no designs and no brand yet."

The agent will state its sizing tier, interview you at phase boundaries with concrete options
rather than open-ended questions, run the audits, and deliver the package. When it's done, point
your coding agent at the repo. It reads the entry-point file and begins.

---

# Repository contents

| Path | What |
|---|---|
| `SKILL.md` | The skill: trigger description, sizing gate, pipeline, phase to reference map, self-improvement loop |
| `references/elicitation.md` | Intake: triage, interview protocol, question bank, and eliciting a design direction from nothing |
| `references/deliverables-requirements.md` | Acceptance contract for the PRD and the Phase-0 audit |
| `references/deliverables-architecture.md` | Acceptance contract for the design spec, integrations, verification backlog, build plan, extensibility |
| `references/deliverables-design.md` | Acceptance contract for direction, tokens, components, screens, motion, design system, wireframes, prototype, per platform |
| `references/deliverables-security.md` | Acceptance contract for the threat model and fourteen domains of enforced rules |
| `references/deliverables-testing.md` | Acceptance contract for the TDD specification |
| `references/deliverables-build-goals.md` | Acceptance contract for build goals and state/data |
| `references/document-set.md` | The deliverables, their roles, the precedence chain, and the numbering conventions that are the single source of truth for gate coverage |
| `references/audits.md` | The adversarial audit playbook, the `AUDIT_LOG.md` append format, and the pre-flight readiness gate |
| `references/claude-md-template.md` | Fillable skeleton for the autonomous-build playbook, including the verbatim cold-resume block |
| `references/lessons.md` | Living ledger: how the skill performed, and what it still does not know about itself |
| `scripts/id-sweep.sh` | Gate: cross-references resolve |
| `scripts/goal-graph.sh` | Gate: build order is acyclic and rooted |
| `scripts/lessons-check.sh` | Gate: the self-improvement ledger is still being kept |
| `app-blueprint.skill` | Packaged skill for the Claude apps |

## Contributing

Issues and pull requests welcome. If you change a phase, update the matching acceptance contract in
`references/` in the same change. A phase whose contract still describes the old behavior is the
exact drift this skill exists to prevent.

If you add an identifier family, update three places together: the numbering conventions in
`document-set.md`, the grammar in `scripts/id-sweep.sh`, and the traceability tables that use it.
Adding it in only one place makes the new identifiers invisible to the pre-flight gate. This is
recorded as lesson `L-AB4` because it has already happened once.

If you add or change a gate, show it failing on a known-bad input before you trust it, and add a
fixture per branch rather than per outcome. A grading check whose middle tier can never be reached
still prints a verdict, and that tier's silence looks exactly like good news. This is lesson
`L-AB5`, and it has already happened twice.

## License

MIT. Use it, fork it, adapt the methodology to your stack.
