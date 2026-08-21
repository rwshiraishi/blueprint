# CLAUDE.md — the autonomous build playbook

The entry-point file at repo root, and the only file Claude Code reads automatically. It is a
guardrail file: the build executes it and amends **only** the Build State section and the status
markers in `LOOP_GOALS.md`. A build that edits its own acceptance criteria has no acceptance
criteria.

It is also what `foreman`'s boss derives its constitution from, and foreman embeds that
constitution verbatim in **every** spawn. That is why §2 below is a separate, contiguous,
one-page `## Constitution core` — so the boss can lift it whole without carrying the document map,
the phase table, and the prerequisites into every worker's context. Keep §2 under ~80 lines.
Everything outside §2 is boss-only reading.

**Scale to the tier.** Sketch tier folds this whole file into `BUILD.md`'s header: §2 Constitution
core, §7 Definition of done, §8 Build state. Standard tier drops §3 (living README) to two lines
and keeps the rest. Full tier ships every section. What never drops at any tier: the never-stop
protocol, the cold-resume block, and the rule that the build edits only Build State and status
markers.

---

## The skeleton — fill the `{{...}}` placeholders, keep the section numbers

Section numbers are load-bearing: goals, audits, and the handoff message cite them.

````markdown
# {{PRODUCT_NAME}} — build playbook

## 1. What you are building

{{Two or three sentences, plain terms, no jargon: what it does and for whom.}}

**Stack (normative — deviations require an AD in `docs/DESIGN_SPEC.md`):**
{{language/runtime + version pin, framework + version, database + version, hosting,
  the two or three libraries that are load-bearing}}

**Failure modes this design makes unrepresentable:** {{the two or three classes of bug the
architecture rules out by construction rather than by checking — e.g. "a query that crosses a
tenant boundary does not type-check", "a price with no fetch date does not parse". If you cannot
name one, say so; that is a finding for Phase 2, not a blank to skip.}}

### Document map and precedence

| Document | Read it when | Wins on |
|---|---|---|
| `docs/PRD.md` | a requirement is ambiguous | intent |
| `docs/DESIGN_SPEC.md` | a mechanism is ambiguous | mechanism |
| `docs/DESIGN_SYSTEM.md` | a UI meaning is ambiguous | semantics |
| `docs/DESIGN_TOKENS.md` | a visual value is ambiguous | visual values |
| `docs/SCREENS.md`, `docs/MOTION.md` | building a screen | screen detail |
| `docs/WIREFRAMES.md` | tracing a screen element to its FR | FR traceability only |
| `docs/SECURITY.md` | touching auth, input, secrets, tenancy | overrides all on safety |
| `docs/TESTS_TDD.md` | before writing any code | what "correct" means |
| `docs/LOOP_GOALS.md` | choosing what to do next | build order |

**Precedence on any conflict:** PRD intent > DESIGN_SPEC mechanism > DESIGN_SYSTEM semantics >
visual files (TOKENS/SCREENS/MOTION) > wireframes. Within UI: safety semantics override visual
files; the tokens file overrides everything else visual. `docs/SECURITY.md` overrides all of it
where safety is at stake.

**Never load everything.** Each goal in `LOOP_GOALS.md` names its own reading map. Read that, not
this table.

---

## 2. Constitution core

> Lift this section verbatim as the `foreman` constitution. Keep it under ~80 lines: it is
> embedded in every worker and checker spawn, and context death is the most common worker failure.

**Stack conventions.** {{naming, file layout, import rules, error-handling shape — the things a
reviewer would otherwise flag on every PR}}

**Quality floor.** {{test coverage bar; a11y bar; the security rules from `docs/SECURITY.md` that
apply to every task, not just security tasks}}

**Forbidden shortcuts.** {{the specific ones for this build — e.g. no `any`, no `--no-verify`,
no mock/placeholder data, no hardcoded thresholds, no swallowed errors}}

**Verification command per task type.**

| Task type | The checker runs | Expects |
|---|---|---|
| {{unit logic}} | `{{cmd}}` | exit 0 |
| {{UI screen}} | `{{cmd}}` | exit 0 |
| {{migration}} | `{{cmd}}` | exit 0 |
| {{any task}} | `scripts/invariant-gate.sh` | exit 0 — **`scope: boss` only** |

**Scope tags.** Every exit criterion is `scope: task` or `scope: boss`. Anything that triggers a
full build is `boss`: foreman runs the full build once, boss-side, after all workers finish,
because two concurrent builds against one working tree corrupt artifacts and produce false FAILs.

**Status mapping** (this package's ledger ↔ foreman's verdicts):

| Ledger | Meaning | Set by |
|---|---|---|
| `[ ]` | not started | — |
| `[~]` | in progress | the agent taking the goal |
| `[x]` | all exit criteria green twice | a checker PASS |
| `[!]` | blocked — see `BLOCKERS.md` | a checker FAIL that a retry did not clear |
| `[-]` | dropped, with the reason recorded in the goal | a human |

A checker's `{verdict, evidence, repro_command}` is the authority. The marker is a summary of it,
never a substitute.

---

## 3. Operating rules — the never-stop protocol

**The loop, per goal:**

1. Read only the sections the goal's reading map names.
2. Write the failing tests first. Confirm each fails **on the intended assertion**, not on a
   typo or a missing import. Commit them red.
3. Implement until green. Fix the code, never the test. Weakening a test requires an ADR in
   `docs/AUDIT_LOG.md` and a human review — record it, do not just do it.
4. Run `scripts/invariant-gate.sh`.
5. Run the goal's exit criteria **verbatim**, and get green **twice** with caches cleaned between
   runs. A criterion green once may be green on a stale artifact.
6. Update the living docs the goal touched.
7. Commit with the goal ID in the subject. Push. Never `--no-verify`.

**Blocker routing:**

- (a) Try the documented fallback for that goal.
- (b) If it does not clear: append to `BLOCKERS.md` — what was tried, the **verbatim** output,
  and exactly what a human must provide — then move to the next unblocked goal, computed from the
  dependency graph.
- (c) Stop only when zero goals are unblocked, leaving a `STATUS.md` a human can act on in five
  minutes.

Three no-progress loops on one goal is a blocker, not a fourth attempt. **Security-ambiguous and
spend-relevant decisions are always blockers, never judgment calls.**

**Cloud independence.** Everything local runs against containers or emulators. Credential-gated
steps are implemented and fixture-tested; live verification is deferred to `BLOCKERS.md`. A
credential gap blocks a verification step, never a phase. Cap paid-API spend per session at
{{AMOUNT}}.

**Parallelism.** Fan out subagents only for goals that share no packages, one git worktree each.
Kernel changes ({{name the kernel files}}) are single-writer. Verifier agents get no authorship
context and re-run exit criteria adversarially. The orchestrator alone merges, gates, commits, and
pushes.

**Scope discipline.** Discovered work goes to `BACKLOG.md`, not into the current goal. New
dependencies pass the supply-chain rule in `docs/SECURITY.md` before they are added.

### 3.1 Cold resume — copy this block verbatim, do not paraphrase

> An agent that has just lost its context cannot infer a recovery procedure from principles. This
> is written as steps because it will be executed by someone who knows nothing else.

```
1. Read §8 Build State in this file. Note the current goal ID and the last pushed commit.
2. Read docs/LOOP_GOALS.md §Progress ONLY. Find the [~] goal. If none, take the first
   unblocked [ ] goal from the dependency graph.
3. Read BLOCKERS.md. If the goal from step 2 appears there, take the next unblocked goal.
4. Read that goal's entry: its step ledger, its reading map, its exit criteria.
5. Read ONLY the sections the reading map names. Do not read this file further.
6. VERIFY BEFORE CONTINUING. Re-run every exit criterion already marked green for this
   goal. A marker records what the last session believed; the command reports what is true.
   Any green marker whose command now fails is wrong: reset it to [ ] and redo that step.
7. Resume at the first step of the ledger that is not green.
```

Git history is memory. Every commit subject carries its goal ID.

---

## 4. README.md as a living map

Updated **before** every commit, never after: architecture diagrams (Mermaid) for back end and
front end, a directory tree with the purpose of each entry, sequence diagrams for the core
workflows, entity state diagrams, and a quickstart that a new machine can follow. A diagram that
no longer matches the code is a failing test, fixed in the same commit that broke it.

---

## 5. Prerequisites — what a human must provide

| Item | Needed by | Absent ⇒ |
|---|---|---|
| {{cloud project / billing}} | {{G-x.y}} | {{which verification defers, and to where}} |
| {{auth provider credentials}} | {{G-x.y}} | {{...}} |
| {{API token}} | {{G-x.y}} | {{...}} |

**None of these may block the early phases.** If one does, that is a build-order defect: reorder
the goals.

---

## 6. The build sequence

| Phase | Delivers | Exit gate (verbatim command) |
|---|---|---|
| {{1}} | {{scaffold}} | `{{cmd}}` |
| {{2}} | {{kernel}} | `{{cmd}}` |

Full detail lives in `docs/LOOP_GOALS.md`. Never duplicate a goal's exit criteria here — two
copies drift and the build follows the wrong one.

---

## 7. Non-negotiables

One merged, numbered list. Every line is a rule **and** the machine that enforces it. A rule with
no enforcement is a wish.

1. {{rule}} — enforced by `{{grep / lint rule / test suite / DB privilege / CI job}}`
2. {{rule}} — enforced by `{{...}}`

---

## 8. Definition of done

- [ ] Every P0 goal is `[x]`, green twice.
- [ ] `scripts/invariant-gate.sh` exits 0.
- [ ] Every security suite in `docs/SECURITY.md` §{{n}} passes in CI.
- [ ] Accessibility checks clean at the bar in `docs/DESIGN_SYSTEM.md`.
- [ ] Every screen matches `docs/SCREENS.md` and `docs/DESIGN_TOKENS.md`.
- [ ] Eval bars met, or credential-blocked with the evidence recorded in `BLOCKERS.md`.
- [ ] Deployed, or `BLOCKERS.md` states exactly why not and what a human must do.
- [ ] `README.md` diagrams match the code as of the last commit.

---

## 9. Build state *(the only section of this file the build maintains)*

```
Current goal:        {{G-x.y}}
Remote:              {{url}}
Last pushed commit:  {{sha}} — {{subject}}
Open blockers:       {{count}} — see BLOCKERS.md
README verified:     {{YYYY-MM-DD}}
```

The durable per-goal record lives in `docs/LOOP_GOALS.md` §Progress and each goal's step ledger,
committed alongside the work it describes. `STATUS.md` is a regenerated report and **loses to the
ledger** on any disagreement.

---

## 10. Commit protocol

One pushed commit per completed goal or major feature. Update `README.md` and §9 Build State
first, in the same commit. Never batch goals into one commit. Never leave a completed goal
unpushed while starting the next. If the remote is unreachable: commit locally, add a
`BLOCKERS.md` entry, and push at the next opportunity. Never `--no-verify` — a failing pre-commit
hook is a defect to fix, not a gate to skip.
````

---

## Definition of done for CLAUDE.md

- [ ] Every `{{placeholder}}` is filled. `grep -c '{{' CLAUDE.md` returns 0.
- [ ] §2 Constitution core is contiguous, self-contained, and under 80 lines
      (`sed -n '/## 2. Constitution core/,/## 3./p' CLAUDE.md | wc -l`), and names a verification
      command for every task type that appears in `LOOP_GOALS.md`.
- [ ] §2's scope-tag rule is present, and every full-build criterion in `LOOP_GOALS.md` is tagged
      `scope: boss`.
- [ ] §2's status-mapping table covers all five ledger markers.
- [ ] §3.1 cold resume is present as a fenced block of numbered steps, and step 6 (re-verify green
      markers) is present verbatim. It is not paraphrased into prose.
- [ ] The precedence chain in §1 matches `document-set.md` §Precedence chain word for word.
- [ ] Every document named in the §1 map exists on disk.
- [ ] Every `G-x.y` cited anywhere in this file is defined in `LOOP_GOALS.md`
      (`scripts/id-sweep.sh docs` covers this — CLAUDE.md is in its scan set).
- [ ] Every §7 non-negotiable names a machine, not a policy. Grep the section for a line with no
      backtick-quoted enforcement and fix it.
- [ ] §5 prerequisites: no item is needed by a phase-1 goal.
- [ ] §8 definition of done contains no line whose truth requires a judgment call.
- [ ] `foreman-notes.md` exists at repo root (build commands, shared-tree hazards, parallel-safe
      goals). It is the one file exempt from the flat-`docs/` rule.
