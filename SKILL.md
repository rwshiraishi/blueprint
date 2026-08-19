---
name: app-blueprint
description: Produce a complete, build-ready documentation package for a new SaaS, web app, or mobile app — PRD, design spec, design system, wireframes-to-hi-fi pipeline, security threat model, extensibility contract, TDD test specification, machine-checkable build goals, and a CLAUDE.md playbook an autonomous coding agent can execute start-to-finish. Use this skill whenever the user wants to plan, spec, design, or prepare the build of a new product or a rewrite of an existing one — trigger on "PRD", "design spec", "design doc", "build plan", "roadmap for building", "prepare for development", "spec out this app", "rewrite this system", "turn this idea into an app", "get this ready for Claude Code", or when they share a legacy codebase and want a better version. Even a rough "help me build X" for a non-trivial product should use this skill for the preparation phase.
---

# App Blueprint — build-ready preparation for a new product

You are producing the preparation package that makes an autonomous or human build succeed: a
document set where every requirement is testable, every design decision carries its reason, every
claim about the outside world is verified, and the final artifact is a repo an agent can be pointed
at with "begin."

The core bet of this methodology: **the build fails or mediocritizes in the preparation, not the
implementation.** Time spent making requirements adversarially-audited, tests-first, and
machine-checkable pays back multiples. Your output is not "documentation" — it is the acceptance
oracle, the dependency graph, and the operating contract for the build itself.

## The pipeline

Ten phases. Run them in order; scale each to the product's size (a weekend tool gets a page per
phase; a multi-tenant SaaS gets the full treatment). Phases 0 and 8 are the ones teams skip and
regret: the source audit finds the real requirements, and the pre-flight audit finds what your own
documents broke.

### Sizing gate — run this first, before Phase 0

Pick the tier out loud in your first message and say why; do not drift upward
silently. The full fourteen-document treatment is a real cost, and paying it for
a weekend tool is the most common way this method wastes a week.

| Tier | Trigger | Output |
|---|---|---|
| **Sketch** | One user, no auth, no money, no data you'd miss | One `BUILD.md`: requirements, decisions, exit criteria. Phases 1, 6, 7 only. |
| **Standard** | Real users, auth, a database, no tenancy | Six documents: PRD, DESIGN_SPEC, SECURITY, TESTS_TDD, LOOP_GOALS, CLAUDE.md. All phases, one audit pass each. |
| **Full** | Multi-tenant, money, compliance, or a rewrite with a predecessor | The full set in `references/document-set.md`. Every phase, every audit, both verification passes. |

Escalate a tier only when a phase produces a finding the smaller tier cannot
hold, and say which finding forced it. Never escalate because the product
"feels important".

Read `references/document-set.md` before starting — it defines every deliverable, its role, and
the precedence chain that keeps fourteen documents from contradicting each other.

Each phase below is a summary. The **acceptance contract** — the exhaustive list of what a
deliverable must contain before it counts as done — lives in the reference files. Load the one for
the phase you are in; do not work from the summary alone, because the summary states intent and
intent is what produces a plausible, thin document.

| Phase | Load this before producing anything |
|---|---|
| Intake | `references/elicitation.md` |
| 0-1 Requirements | `references/deliverables-requirements.md` |
| 2, 5 Architecture | `references/deliverables-architecture.md` |
| 3 Design | `references/deliverables-design.md` |
| 4 Security | `references/deliverables-security.md` |
| 6 Testing | `references/deliverables-testing.md` |
| 7 Build goals | `references/deliverables-build-goals.md` |
| 2, 8 Audits | `references/audits.md` |

### Intake — establish what the user actually has

Most users arrive with a sentence, not a repo. There may be no PRD, no designs, no brand, no
codebase, and no competitor analysis. That is the normal case, not the degraded one, and the
package is only as good as what this step gathers.

Run `references/elicitation.md`. It carries the triage (what exists already), the interview
protocol (batched concrete option questions, never turn-by-turn interrogation), the question bank
with what each answer unlocks downstream, the protocol for eliciting a **design direction from
nothing** — references, anti-references, emotional register, density from actual usage context —
and the rule for handling "you decide" (a numbered decision with a recorded default, never a
silent assumption).

Two things this step must produce before Phase 1 can start: a pinned scope, and a design
direction with a stated point of view. Skipping the second is how a package that is technically
complete still produces a characterless product.

### Phase 0 — Source audit (when a predecessor system or codebase exists)

Read the actual code, not the README. Line-verify every claim you make (file:line citations in
working notes). Hunt specifically for: the gap between *documented* and *implemented* behavior
(published scoring formulas vs. the code's actual math), silent failure modes (truncation repaired
instead of rejected, empty results indistinguishable from errors), destructive defaults, missing
identity/audit, hardcoded values that should be configuration, and features that exist only in
marketing copy. Each defect becomes a named requirement or regression test in the new design —
that is the audit's product. Also inventory what the legacy system got *right*; parity lists come
from code, not memory. If the user can grant access to a deployed instance or screenshots, take
them — deployed behavior diverges from any snapshot.

When there is no predecessor, this phase does not disappear — it retargets. Audit the
competitive set, the user's current manual process, or the adjacent tools they use today, and
produce the same artifact: evidence that becomes named requirements. A greenfield product with no
Phase 0 enters Phase 1 on assumptions alone, which is the most expensive way to start.

### Phase 1 — Requirements (PRD)

Interview the user with concrete option questions (AskUserQuestion where available): audience of
the docs, greenfield vs. hardening, scope tiers, known pain points. Then write the PRD:
functional requirements in numbered groups (`FR-XXX-n`) with priorities, each one **testable as
written**; NFRs with numbers, not adjectives; launch metrics; personas; risks; and an **open
decisions table** (D1…Dn) with options and a recommendation each — decisions the user must make
are surfaced, never silently assumed. Research the domain and competitors for real (web search,
not priors); verify data sources, APIs, and standards actually exist and are accessible today.

### Phase 2 — Design spec + adversarial audits

The normative "how": architecture decisions as an AD table (decision / alternatives / reasoning),
full schema DDL, pipeline/service design with code-level sketches, API surface, cost model from
**verified list prices** — fetch them, and record the source URL and fetch date beside every
figure (a date stamped on a remembered price is the failure mode this rule exists to prevent), capacity plan, build
plan. Then — this is the step that separates good from world-class — **attack your own spec**
with independent adversarial audit passes before anyone builds it. Run the audits in
`references/audits.md` (database scale, system scale, consistency/cross-reference). Fix findings
in the spec itself, then have a *fresh* verification pass check the fixes — patches introduce
their own bugs at a startling rate. Record what each audit got right alongside what it found, so
later editors don't "fix" the good parts. **Every audit leaves an artifact**: write findings,
fixes, and the verification pass's verdict to `docs/AUDIT_LOG.md` as you go — an audit that
leaves no record is indistinguishable from an audit that never ran, and the pre-flight check
treats it that way.

### Phase 3 — Design language and screens

Three layers, in order:
1. **Design system** (semantic authority): principles derived from the product's epistemics — the
   most important is P0: *every screen leads with one message, and that message wins* (a headline
   band in the largest type on screen; progressive disclosure for everything else; density opt-in,
   never default). Encode safety-critical semantics (status colors, confidence encodings) as
   locked tokens tenants cannot theme.
2. **Wireframes** (structural record): gray-box screens where every element carries a numbered
   annotation citing the requirement it implements. This is the traceability layer.
3. **Hi-fi visual design**: tokens file (every value, drop-in CSS), per-screen spec with exact
   copy, motion contract (calm default, expressive opt-in, reduced-motion kills all), runnable
   prototype, reference screenshots. Declare precedence explicitly: semantics > visual values >
   wireframes — and record the deltas when hi-fi deliberately diverges from wireframes.

### Phase 4 — Security (forefront, not afterthought)

A threat model by actor × surface including domain-specific threats, then **enforced rules where
every rule names its machine enforcement** — a CI grep, a lint rule, a test suite, a database
privilege — never policy prose. See `references/audits.md` §Security for the checklist (SQLi,
SSRF, XSS/CSP, injection corpora, authn-by-default, rate/cost-DoS, secrets, supply chain, and
LLM-specific: channel separation, model output as untrusted input).

### Phase 5 — Extensibility and scale

Two short documents that prevent expensive mistakes: an **extensibility contract** (fixed kernel +
enumerated extension surfaces; custom work lands in a surface or does not land; what is
deliberately NOT extensible) and explicit **scaling designs for both axes** — data volume AND
users/subscribers (read path, realtime fan-out, tenant packing, entitlements, billing decision).

### Phase 6 — TDD specification

The acceptance oracle: failing-tests-first protocol, real-infrastructure test substrate (real
database with real security policies — mocked authorization tests are worthless), property tests
for algorithmic claims, regression tests named for every Phase-0 defect, golden sets and eval
gates for any ML/LLM component, and the rule that weakening a test requires a human-reviewed ADR.

### Phase 7 — Build goals + the CLAUDE.md playbook

Convert the build plan into **goals with machine-checkable exit criteria** — literal commands with
expected outcomes, never prose — plus a dependency graph, an invariant gate run on every loop, and
grep-enforced anti-goals. Then write CLAUDE.md from `references/claude-md-template.md`: the entry
point that makes the repo self-bootstrapping (document map with precedence, never-stop protocol
with blocker routing, cloud-independence rule, multi-agent parallelism, commit/push discipline
with a living README requirement, prerequisites table, definition of done).

### Phase 8 — Pre-flight readiness audit

Before declaring done, run the readiness audit from `references/audits.md` §Pre-flight against
your own package. Start with the **mechanical cross-reference sweep**: run `scripts/id-sweep.sh
docs`, which exits nonzero on any FR/NFR/AD/D/G ID referenced but never defined, and append its
output to `AUDIT_LOG.md`. Then check by hand: broken references, the first-hour trap,
contradictions introduced by successive edits, and world-class blind spots (i18n, billing, email
deliverability, error tracking, status page, legal artifacts, demo data, SLAs). Fix to GO. This
audit routinely finds blockers in even excellent packages — successive edit passes break
cross-references invisibly.

Before you trust any gate you wrote for this package — the sweep, the invariant gate, a goal's
exit command — show it FAILING on a known-bad input first. A check that has never gone red is
passing vacuously, and a vacuous gate is worse than no gate: it converts an unexamined package
into a confident GO.

### Phase 9 — Repo layout and delivery

Final structure: `CLAUDE.md` at repo root (auto-read by Claude Code), everything else in `docs/`
— flat, no wrapper folders, no "handoff" subdirectories (absorb received artifacts into
first-class docs and delete their packaging). Deliver files as they're produced, not batched.

Then hand off. This skill stops at a repo an agent can be told to build; it does not build it.
The executor is the `foreman` skill — its boss/worker/checker loop reads `CLAUDE.md` and
`LOOP_GOALS.md` as its constitution and goal list, which is exactly what Phase 7 produced. Say so
explicitly in your final message rather than leaving the user to guess what "begin" means.

## Operating principles (apply throughout)

- **Verify, never assume.** Every external claim — an API exists, a price, a platform capability,
  a library feature — is checked against a primary source *dated today*. Findings that break your
  design are the most valuable ones; rewrite, don't rationalize.
- **Delegate heavy phases to subagents** and run independent ones in parallel; keep audits in
  *fresh* agents with no authorship context — authorship bias is real.
- **Every rule carries its why and its enforcement.** If you write ALWAYS/NEVER without a reason
  and a mechanism, the rule will not survive contact with the build.
- **Surface decisions; don't bury them.** Anything genuinely the user's call goes in the open
  decisions table with a recommendation. Ask with concrete options at phase boundaries, not
  mid-flow.
- **Sanitize on request, thoroughly.** If the user needs provenance removed (predecessor names,
  organizations), scrub with grep-verified zero hits and rewrite lessons as generic anti-patterns
  — keep the technical content, drop the identity.
- **Update, re-verify, re-deliver.** When any document changes, fix its cross-references, re-run
  the relevant audit, and re-sync every delivery location.

## Boundaries — when this skill is the wrong one

Several skills trigger on "plan", "PRD", and "roadmap". Pick by what the output
*is*, not by the word the user typed.

- `blueprint` — output is a **step list** for agents to execute across sessions.
  No PRD, no design system, no threat model. Use it when the product already
  exists and the work is a multi-PR change.
- `spec-driven-workflow` — output is a **spec for one feature** inside a repo
  that already has its architecture settled.
- `code-to-prd` — output is a PRD **reverse-engineered from existing code**.
  That is this skill's Phase 0 in isolation; use it when the audit *is* the ask.
- `product-manager-toolkit` — output is PM artifacts (positioning, roadmaps,
  prioritization) with no build contract attached.
- `saas-launch-gate` / `web-quality-gate` / `app-quality-gate` — these run at the
  **end** of a build. This skill runs before one. They are not alternatives.
- `foreman` — **executes** what this skill produces. Downstream, never instead of.
- `council` — the user has not decided *whether* to build it. Settle that first;
  a blueprint for a product that gets cancelled is the most expensive artifact
  in this list.

This skill is the right one only when the output must be a **complete build
contract** — requirements, design, security, tests, and machine-checkable goals
that someone else (agent or human) can execute without you in the room.

## Self-Improvement Loop

After any package that reached a build — or that stalled before one — append a
run section to `references/lessons.md`. Record, at minimum: the tier you picked
and whether it held; how many findings each audit produced; **which phase caught
each defect and which earlier phase should have**; whether Phase 8 found
blockers; and, if the build stalled, the document that was missing or wrong.

The promotion rules live at the top of that file: CANDIDATE on one observation;
PROMOTED into SKILL.md on two confirmations or one airtight causal chain, date
stamped with `landed-in` recorded; DEMOTED with counter-evidence by reverting
the edit, never by silent deletion.

Guardrails on what may never be weakened by a lesson: Phase 0's line-verified
source audit, Phase 8's pre-flight gate, the fresh-agent rule for every audit,
and the requirement that every audit leave an `AUDIT_LOG.md` artifact. Those
four are the mechanisms the method rests on; a lesson that trims them is
measuring its own convenience, not the method's performance.

A phase that has never once produced a finding is not evidence the phase is
unnecessary — it is evidence the phase is being run vacuously. Record it as an
UNANSWERED and investigate before deleting anything.
