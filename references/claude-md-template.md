# CLAUDE.md template — the autonomous build playbook

The entry-point file at repo root. Adapt each section; keep the skeleton. It is a guardrail file:
the build executes it and amends only the Build State section.

## Skeleton

1. **What you are building** — three paragraphs (product in plain terms; stack, normative;
   failure modes this design makes unrepresentable), then the document map table with the
   precedence chain and a fresh-session read order ("never load everything; each goal names its
   reading").

2. **Operating rules — the never-stop protocol**
   - *The loop*: per goal — read cited sections → write failing tests first (confirm they fail on
     the intended assertion, commit them) → implement until green (fix the code, never the test;
     weakening a test requires an ADR) → run the invariant gate → run the goal's exit criteria
     verbatim, green twice → update living docs → commit with goal ID → push. Never `--no-verify`.
   - *Blocker routing*: (a) try the documented fallback; (b) write BLOCKERS.md (what was tried,
     verbatim output, what a human must provide) and continue with the next unblocked goal —
     computable from the dependency graph; (c) stop only at zero unblocked goals, leaving a
     STATUS.md a human can act on in five minutes. Three no-progress loops on one goal = blocker.
     Security-ambiguous and spend-relevant changes are always blockers, never judgment calls.
   - *Cloud-independence*: everything local runs against containers/emulators; credential-gated
     steps are implemented + fixture-tested, live verification deferred to BLOCKERS.md. A
     credential gap blocks a verification step, never a phase. Cap any paid-API spend per session.
   - *Parallelism*: fan out subagents for goals that don't share packages (one git worktree each);
     kernel changes are single-writer; verifier agents with no authorship context re-run exit
     criteria adversarially; the orchestrator alone merges, gates, commits, pushes.
   - *Scope discipline*: discovered work → BACKLOG.md, not a detour. New dependencies pass the
     supply-chain rule first.
   - *Session hygiene*: on refresh read this file + STATUS/BLOCKERS + current goal only. Git
     history is memory: goal IDs in every commit subject.

3. **README.md as a living map** — updated before every commit: architecture diagrams (Mermaid)
   for back end and front end, directory tree with purposes, sequence diagrams for core workflows,
   entity state diagrams, quickstart. A diagram that no longer matches the code is a failing test,
   fixed in the same commit.

4. **Prerequisites** — human-provided items table (cloud project, auth, tokens, secrets, human
   labeling labor), each mapped to the goals that need it and the "absent ⇒" degradation. None may
   block the early phases.

5. **The build sequence** — condensed phase table with verbatim exit-gate commands; full detail
   lives in the goals file, never duplicated.

6. **Non-negotiables** — ONE merged numbered list (security rules, UI rules, domain epistemics,
   TDD, modularity, naming), each line: rule + where a machine enforces it.

7. **Definition of done** — the launch bar as verifiable statements (all P0 goals green twice,
   gate green, security suites green, a11y clean, screens match the visual spec, eval bars met or
   credential-blocked-with-evidence, deployed or BLOCKERS.md says exactly why not).

8. **Build state** *(the only section the build maintains — ten lines: current goal, remote, last
   pushed commit, open blockers, README-verified date)*.

## The commit protocol (write it exactly)

One pushed commit per completed goal or major feature; update README + Build State first; never
batch goals; never leave a completed goal unpushed while starting the next; remote unreachable →
commit locally + BLOCKERS.md entry + push at next opportunity.
