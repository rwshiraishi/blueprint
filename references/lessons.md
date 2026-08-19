# Lessons ledger (living document)

Appended after any blueprint package that reached a build — or that stalled
before one. Statuses: CANDIDATE (one observation, or a transfer from a sibling
skill not yet confirmed in a blueprint run) → PROMOTED (two confirmations, or
one airtight causal chain; edit SKILL.md, date-stamp, record `landed-in`) →
DEMOTED (counter-evidence; revert the edit, never silently delete).

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
