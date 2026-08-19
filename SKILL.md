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

Read `references/document-set.md` before starting — it defines every deliverable, its role, and
the precedence chain that keeps fourteen documents from contradicting each other.

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
your own package — including a **mechanical cross-reference sweep** (script a grep: every FR/AD/
D/G/test-suite ID referenced anywhere must be defined somewhere; the sweep's output goes in
`AUDIT_LOG.md`): broken references, the first-hour trap, contradictions introduced by successive
edits, world-class blind spots (i18n, billing, email deliverability, error tracking, status page,
legal artifacts, demo data, SLAs). Fix to GO. This audit routinely finds blockers in even
excellent packages — successive edit passes break cross-references invisibly.

### Phase 9 — Repo layout and delivery

Final structure: `CLAUDE.md` at repo root (auto-read by Claude Code), everything else in `docs/`
— flat, no wrapper folders, no "handoff" subdirectories (absorb received artifacts into
first-class docs and delete their packaging). Deliver files as they're produced, not batched.

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
