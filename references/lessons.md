# Lessons ledger (living document)

Appended after any blueprint package that reached a build — or that stalled
before one. Statuses:

- **CANDIDATE** — one observation, not yet acted on in SKILL.md.
- **PROMOTED** — two confirmations, or one airtight causal chain. Edit SKILL.md,
  date-stamp, record `landed-in`.
- **PROMOTED (transfer)** — a mechanism confirmed in a *sibling* skill whose
  failure mode is identical here, promoted on that evidence before this skill has
  observed it directly. Legitimate, and deliberately distinguished in the label so
  the difference stays visible: a transfer rests on someone else's run. The first
  blueprint run that touches a transferred lesson must record whether it held; a
  transfer that survives one real run drops the parenthetical and becomes plain
  PROMOTED, and one that fails is DEMOTED like any other.
- **DEMOTED** — counter-evidence; revert the edit, never silently delete.

Three of the five lessons below are transfers. That is a fact about this ledger's
age, not a defect: the skill is young and the sibling evidence is real. It stops
being acceptable the moment a blueprint run could have confirmed one and did not.

Guardrails: never weaken Phase 0 (source audit), Phase 8 (pre-flight), or the
fresh-agent rule for audits — those are the three mechanisms the whole method
rests on. Every rule cites its run. A phase that has never produced a finding
is not being run properly; record that as an UNANSWERED, not as a success.

The signal to record is **which phase caught the defect, and how late**. A
defect caught in Phase 8 that Phase 0 should have caught is the single most
useful entry in this file, because it names a hole in an earlier gate.

## L-AB1 — audit-with-no-artifact-did-not-happen — PROMOTED (transfer, mechanism identical)
- **Rule**: Every audit writes findings, fixes, non-fixes with reasons, and the
  verification verdict to `docs/AUDIT_LOG.md` — including audits that find
  nothing. A later session cannot distinguish a clean audit from a skipped one.
- **Evidence**: ECC self-audit (2026-08, `reference_ecc_audit_blind_spots`)
  reported PASS while five breaks were live; the audit left no per-check record,
  so nothing could be re-examined after the fact. Same shape here: fourteen
  documents, several audit passes, no durable trace.
- **Landed-in**: SKILL.md Phase 2, references/audits.md header.

## L-AB2 — negative-test-every-gate-before-trusting-it — PROMOTED (transfer)
- **Rule**: A check you just wrote must be shown to FAIL on a known-bad input
  before its PASS means anything. Applies to the ID sweep, the invariant gate,
  and every exit criterion in LOOP_GOALS.md.
- **Evidence**: `reference_ecc_audit_blind_spots` — checks that had never been
  negative-tested passed vacuously for weeks. `scripts/id-sweep.sh` was
  negative-tested at authoring time (2026-08-19): dangling `AD-3` → exit 1,
  resolved → exit 0.
- **Landed-in**: SKILL.md Phase 7 and Phase 8.

## L-AB3 — background-subagent-reports-are-lost — PROMOTED (harness)
- **Rule**: Spawn audit agents synchronously, or fan out via the Workflow tool
  with a findings schema. Never fire-and-forget a background Agent for a report
  you need back.
- **Evidence**: `feedback_subagent_report_delivery` — foreman Run 1 and
  novelty-hunt (2026-08-14) lost 4/4 background subagent reports; mechanical
  harvest recovered them. This skill delegates its heaviest phases to
  subagents, so it rides the same broken channel.
- **Landed-in**: SKILL.md Operating principles.

## UNANSWERED
- **U-AB1**: Does the full fourteen-document set outperform a five-document
  subset for a small product, or is the small-mode gate in SKILL.md just a
  guess? No run has compared them. Record document count and where the build
  actually stalled.
- **U-AB2**: Phase 8 "routinely finds blockers in even excellent packages" is
  asserted, not measured. Record the Phase-8 finding count per run; if it
  trends to zero, either the earlier phases improved or Phase 8 went vacuous —
  and those need distinguishing.
- **U-AB3**: Does Phase 0 (source audit) pay off on greenfield products where
  there is no predecessor? Currently it is skipped entirely. Unknown whether a
  substitute (audit the competitor, audit the user's current manual process)
  recovers the value.

## L-AB4 — a new ID family is invisible to the gate until the grammar knows it — PROMOTED
- **Rule**: Introducing an ID family (`TS-`, `DR-`, anything new) means updating three places in
  the same change: the numbering conventions in `document-set.md`, the grammar in
  `scripts/id-sweep.sh`, and the traceability tables that use it. Adding the family in only one is
  how a cross-reference gate passes while references dangle.
- **Evidence**: 2026-08-19, building this skill's own deliverable specs. The testing spec
  introduced `TS-<GROUP>-<n>` suite IDs and the requirements spec introduced `DR-<n>` defect IDs.
  Neither was in the sweep's grammar, so 20+ suite IDs across three documents were invisible to
  the gate — it would have reported a clean PASS over them. Caught because the authoring agent
  flagged the mismatch, not because any check found it. That is the wrong way to catch it.
- **Landed-in**: `document-set.md` §Numbering conventions (now states the coupling explicitly),
  `scripts/id-sweep.sh` grammar.

## Run 1 — 2026-08-19 — building the skill's own reference layer
- **Tier**: Full, on the skill itself rather than a product.
- **Tier held**: N/A — not a product run, so the sizing gate was never exercised. This is why
  U-AB1 is still open after two runs.
- **Documents**: 0 product documents. 11 reference files produced instead.
- **Audit findings**: 2 HIGH in `id-sweep.sh`, 1 grammar gap (L-AB4). No package audits ran,
  because no package existed.
- **Phase 8 blockers**: N/A — no package to run pre-flight against.
- **Outcome**: no build. The reference layer shipped; the method itself remains unmeasured.
- **What the phases caught**: The pre-flight class of defect showed up twice before any package
  existed. (a) Two HIGH bugs in `id-sweep.sh` — definitions written as `- **FR-1**:`, `1. FR-2`,
  or in a table cell were not recognised at all (0 of 3), and a prose sentence beginning with an
  ID counted as defining it, so a genuine dangling reference passed. (b) The L-AB4 grammar gap.
- **Which gate should have caught it earlier**: Both were negative-testable at authoring time.
  The first version of the script was tested only on the shape its author had in mind, which is
  the definition of a vacuous check. L-AB2 existed in this file already and was still not applied
  hard enough — a lesson recorded is not a lesson enforced.
- **Change made**: the sweep now grades definitions STRONG/WEAK/NONE rather than guessing, because
  a definition table and a traceability table are structurally identical and a tool that guesses
  between them will either false-fail constantly or false-pass silently.
- **Open**: U-AB1 (does the tier gate hold?) is still unanswered — this run picked Full and never
  tested the smaller tiers.

## L-AB5 — a classifier whose buckets overlap silently loses one of them — PROMOTED
- **Rule**: When a check grades evidence into tiers, prove *each tier fires* on a fixture built
  for it, not just that the check passes and fails overall. A tier that can never be reached is
  invisible: the run still prints a verdict, and the missing tier looks like "nothing to report".
  Add this to L-AB2 — negative-testing a gate means one fixture per branch, not one per outcome.
- **Evidence**: 2026-08-20 review of `scripts/id-sweep.sh`. Run 1 rebuilt the script to grade
  definitions STRONG/WEAK/NONE precisely because definition tables and traceability tables are
  structurally identical. The rebuild then put the table pipe `|` into the STRONG marker class.
  Every markdown table row starts with one, so:
  (a) every first-column ID was graded STRONG — a pure traceability table silently "defined"
      every ID in column 1, and the WEAK bucket the rebuild existed to create never fired once
      (fixture: a docs/ dir containing only a traceability table reported `Weak-only: 0`);
  (b) `grep -o` consumed the shared `|` delimiter, so every ID in column 2 and beyond was
      matched by neither bucket and was reported DANGLING — a false NO-GO on the FR↔test
      traceability table that `TESTS_TDD.md` is *required* to contain.
  Both directions were wrong at once, and the script's own header comment described at length a
  behaviour it did not have.
- **Which gate should have caught it earlier**: Run 1's negative test. It exercised
  dangling → exit 1 and resolved → exit 0, which are the two *outcomes*; it never exercised the
  WEAK *branch*, which is the thing the rebuild added.
- **Change made**: `|` removed from the marker class; table rows are now split into cells with
  awk and each cell graded independently. Negative-tested per branch: traceability-only table →
  4 weak-only warnings, exit 0; prose-only ID → exit 1 naming it; mixed fixture → strong,
  weak, and dangling all populated in one run.
- **Landed-in**: `scripts/id-sweep.sh` (MARK class, WEAK block, both with the fixture recorded
  in-comment).

## Run 2 — 2026-08-20 — external review of the skill as shipped
- **Tier**: N/A — reviewed the skill, did not run a package through it.
- **Tier held**: N/A. Two runs in, the sizing gate has still never been exercised on a real
  product. U-AB1 remains the oldest open question and the one most likely to be wrong.
- **Documents**: 0 product documents. 3 reference reviewers read 8 files.
- **Audit findings**: 34 total across three independent reviewers — 6 CRITICAL, 22 MAJOR,
  6 MINOR after dedup. 4 of 4 spot-checked claims verified true against the filesystem.
- **Phase 8 blockers**: N/A — no package. But the review found the *class* Phase 8 hunts
  (dangling references, phantom sections, a definition-of-done line certifying a false claim)
  present in the skill's own files, which is weak evidence that Phase 8 earns its place.
- **What the phases caught**: nothing — no phase ran. Every defect below was found by an
  external reviewer or by executing a script, which is itself the finding: the skill had no
  self-check that reads its own files.
- **Outcome**: no build. 3 scripts now ship (was 1); routing fixed; 6 CRITICAL corrected.
- **What the review caught**: (a) L-AB5 above, the vacuous WEAK bucket plus the false-FAIL on
  table columns 2+. (b) A wiring defect outside the skill's own files: `app-blueprint` had zero
  membership in `catalog/subjects.json`, so the routing hook's subject layer could not reach it,
  and the hardcoded discovery-spine rule for `\bprd\b` routed to `code-to-prd` — the skill this
  one's own Boundaries section names as its Phase 0 in isolation. Six of the trigger phrases
  printed in this skill's `description:` frontmatter did not surface it. Measured before the fix:
  1 of 6 fired.
- **Which gate should have caught it earlier**: nothing in this skill checks that the triggers it
  advertises actually route to it. A skill's description is a claim about the harness, and it was
  never tested against the harness.
- **Change made**: added to `product-discovery` (member + entry point) and `eng-workflow`
  (member); added `app-blueprint` to the discovery-spine rule ahead of `code-to-prd` with a
  reason string that distinguishes them; added a new-build-intent rule. Re-measured: 6 of 6
  trigger phrases fire, 0 leaks on four unrelated control prompts, `test-routing.sh` 86/86.
- **Open**: U-AB1, U-AB2, U-AB3 all still unanswered — this run produced no package.
- **Also caught, in the gates written during this very review** — which is the point of L-AB5 and
  is recorded here rather than excused: (a) `goal-graph.sh`, newly written, deleted from an awk
  array while iterating it and reported a cycle in a provably acyclic five-goal graph; (b) the same
  script read a *wrapped* `Depends on:` continuation line as a second declaration of the goal it
  named, reporting "6 goals" and a spurious duplicate; (c) an independent reviewer found that
  `id-sweep.sh`'s new cell-split treated a markdown-escaped `\|` as a column separator, failing one
  half of the pair as dangling while the other half silently passed. All three were found by
  running per-branch fixtures, none by reading. Three gate bugs in two scripts in one session, in a
  skill whose whole thesis is that gates must be negative-tested, is the strongest available
  evidence for L-AB2 and L-AB5 — and evidence that writing the lesson does not discharge it.
  Every branch of both scripts now has a fixture, and each fixture was observed red before green.
- **New**: **U-AB4** — no run has yet confirmed that `foreman` consumes the `CLAUDE.md` and
  `LOOP_GOALS.md` shapes Phase 7 emits. The handoff is asserted in SKILL.md Phase 9 and has never
  been executed end to end. Until one package is handed over and starts, treat the handoff as
  designed-but-unverified.
