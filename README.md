# app-blueprint

**A Claude skill that turns "I want to build X" into a build-ready documentation package an
autonomous coding agent can execute start-to-finish.**

Point Claude at a product idea — or a legacy codebase you want to replace — and this skill walks
a ten-phase preparation pipeline that ends with a repo you can hand to Claude Code with one word:
*begin*.

---

## Why this exists

Builds don't usually fail in the implementation. They fail in the preparation: requirements that
can't be tested, designs nobody audited, security bolted on at the end, costs quoted from memory,
and a plan the coding agent has to improvise around. This skill packages a methodology developed
and battle-tested on a real multi-tenant SaaS build-prep — where adversarial audits of the
"finished" spec found six critical database flaws, a readiness audit of the "finished" package
found three run-killing gaps, and every one was fixed *before* a line of product code existed.

The core bet: **time spent making requirements adversarially-audited, tests-first, and
machine-checkable pays back multiples.** The output isn't documentation — it's the acceptance
oracle, the dependency graph, and the operating contract for the build itself.

## What it produces

A fourteen-document package (scaled to product size — a weekend tool gets pages, a SaaS gets the
full treatment):

```
repo/
├── CLAUDE.md                  ← entry point: auto-read by Claude Code; the build's operating contract
└── docs/
    ├── PRD.md                 ← testable requirements, open decisions with recommendations
    ├── DESIGN_SPEC.md         ← normative architecture, schema DDL, verified-price cost model
    ├── DESIGN_SYSTEM.md       ← design semantics: one-message-per-screen, locked tokens
    ├── DESIGN_TOKENS.md       ← every visual value, drop-in CSS, dark mode as token swap
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
wireframes) keeps fourteen documents from contradicting each other across edit passes.

## The ten phases

| # | Phase | The point |
|---|---|---|
| 0 | **Source audit** | Read the legacy code, not its README. Line-verified defects become named requirements and regression tests. |
| 1 | **PRD** | Testable FRs, numeric NFRs, and an open-decisions table — decisions surfaced, never silently assumed. |
| 2 | **Design spec + adversarial audits** | Write the spec, then *attack it* with fresh-context audit passes (database scale, system scale, consistency) before anyone builds. Verify the fixes separately — patches breed their own bugs. |
| 3 | **Design language** | Semantics → wireframes (traceability) → hi-fi (tokens, screens, motion), with precedence declared and deltas recorded. |
| 4 | **Security** | Threat model by actor × surface; rules that name a CI grep, lint, or test — never policy prose. |
| 5 | **Extensibility + scale** | Fixed kernel, enumerated extension surfaces; scaling designed for *both* axes — data volume and users/subscribers. |
| 6 | **TDD spec** | Failing-tests-first; real database with real security policies (mocked authz tests are worthless); regression tests named for Phase-0 defects. |
| 7 | **Goals + CLAUDE.md** | Machine-checkable exit criteria, dependency graph, invariant gate, grep-enforced anti-goals — and the never-stop playbook that routes blockers instead of halting. |
| 8 | **Pre-flight audit** | A mechanical ID sweep plus a readiness audit against your own package: broken refs, first-hour traps, world-class blind spots (i18n, billing, email deliverability, error tracking, SLAs…). Fix to GO. |
| 9 | **Repo layout** | CLAUDE.md at root, everything in flat `docs/` — a repo that bootstraps itself. |

## Operating principles baked in

- **Verify, never assume** — every external claim (API, price, platform capability) checked
  against a primary source, URL + date recorded. Unfetchable → "could not verify," never estimated silently.
- **Fresh eyes for audits** — audit agents get no authorship context; authorship bias is real.
- **Every audit leaves an artifact** — `AUDIT_LOG.md`, even when nothing is found. An audit with
  no record is indistinguishable from an audit that never ran.
- **Every rule carries its why and its enforcement** — an unenforced rule won't survive contact
  with the build.
- **Decisions belong to the user** — anything genuinely their call goes in the decisions table
  with a recommendation attached.

## Does it work?

Benchmarked against a no-skill baseline on two realistic prompts (a small landlord-maintenance
SaaS; a nonprofit legacy-system rewrite), graded on 16 objective assertions:

| | Assertion pass rate |
|---|---|
| **With skill** | **94%** |
| Baseline (no skill) | 13% |

The baselines produced competent engineering documents — and missed every workflow element:
no build playbook, silent assumptions instead of decision tables, security as prose, no audit of
their own output. One baseline *fabricated* details of a legacy system it never saw; the skill
run flagged the same unknown as a verification item.

## Installation

**Claude (Cowork / claude.ai):** open `app-blueprint.skill` in a conversation and click
**Save skill**, or upload it via Settings → Capabilities → Skills.

**Claude Code:** copy the skill folder into your skills directory:

```bash
mkdir -p ~/.claude/skills/app-blueprint
cp SKILL.md ~/.claude/skills/app-blueprint/
cp -r references ~/.claude/skills/app-blueprint/
```

## Usage

Just describe the product; the skill triggers on preparation-shaped requests:

> "I want to build a SaaS for small landlords to manage maintenance requests — prepare everything
> Claude Code needs to build it."

> "We have a 10-year-old PHP tool that's a mess. Plan a modern rewrite we can hand to an AI
> coding agent, with security done right this time."

Claude will interview you at phase boundaries (concrete options, not open-ended questions), run
the audits, and deliver the package. When it's done, point Claude Code at the repo:
it reads `CLAUDE.md` and begins.

## Repository contents

| Path | What |
|---|---|
| `SKILL.md` | The skill: trigger description + the ten-phase pipeline |
| `references/document-set.md` | The fourteen deliverables, their roles, the precedence chain, numbering conventions |
| `references/audits.md` | The adversarial audit playbook: DB scale, system scale, user scale, cost verification, security checklist, pre-flight readiness |
| `references/claude-md-template.md` | Skeleton for the autonomous-build playbook (never-stop protocol, blocker routing, parallelism, commit discipline) |
| `app-blueprint.skill` | Packaged skill — save-ready for Claude |

## License

MIT — use it, fork it, adapt the methodology to your stack.
