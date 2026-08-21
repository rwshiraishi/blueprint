#!/usr/bin/env bash
# lessons-check.sh — health gate for this skill's self-improvement ledger.
#
# Why this exists: SKILL.md tells the agent to append a run record after every
# package, and to promote lessons on evidence. That was a request with no machine
# behind it — which this skill's own doctrine calls a wish, not a rule. A ledger
# nobody validates rots in three specific ways, all silent:
#
#   1. A lesson reaches PROMOTED with no `Landed-in`, so it was never actually
#      applied to SKILL.md. The ledger claims a change the skill does not have.
#   2. Run records omit the numbers, so U-AB1 (does the tier gate hold?) and
#      U-AB2 (does Phase 8 still find things?) stay unanswerable forever and the
#      skill improves by anecdote.
#   3. A transfer sits at PROMOTED (transfer) across many real runs without ever
#      being confirmed or demoted, so borrowed evidence hardens into fact.
#
# Usage:  scripts/lessons-check.sh [path/to/lessons.md]   (default: references/lessons.md)
#         scripts/lessons-check.sh --metrics [path]       (numbers only, for a run record)
# Exit:   0 = ledger healthy.  1 = structural defect.  2 = usage/env error.
#
# Negative-tested 2026-08-20, one fixture per branch: PROMOTED without Landed-in
# exits 1; a lesson missing Rule or Evidence exits 1; a run record missing a
# required field exits 1; a ledger with no UNANSWERED section exits 1; a stale
# transfer warns; a healthy ledger exits 0.

set -uo pipefail

METRICS_ONLY=0
[ "${1:-}" = "--metrics" ] && { METRICS_ONLY=1; shift; }
FILE="${1:-references/lessons.md}"
[ -f "$FILE" ] || { echo "lessons-check: no such file: $FILE" >&2; exit 2; }

# Fields every run record must carry. These are exactly the numbers that answer
# the open UNANSWERED questions; a run record without them is a diary entry.
REQUIRED_RUN_FIELDS="Tier|Tier held|Documents|Audit findings|Phase 8 blockers|What the phases caught|Which gate should have caught it earlier|Change made|Outcome"

awk -v required="$REQUIRED_RUN_FIELDS" -v metrics_only="$METRICS_ONLY" '
function flush_block() {
  if (kind == "lesson") {
    if (!(id in has_rule))     miss = miss sprintf("- `%s` has no **Rule:** line\n", id)
    if (!(id in has_evidence)) miss = miss sprintf("- `%s` has no **Evidence:** line\n", id)
    if (status ~ /PROMOTED/ && !(id in has_landed))
      nolanded = nolanded sprintf("- `%s` is %s but records no **Landed-in:** — the ledger claims an edit the skill may not have\n", id, status)
    if (status ~ /transfer/) transfers[id] = 1
    if (status ~ /DEMOTED/) demoted++
    else if (status ~ /PROMOTED/) promoted++
    else if (status ~ /CANDIDATE/) candidate++
  } else if (kind == "run") {
    n = split(required, req, "|")
    for (k = 1; k <= n; k++)
      if (!((id SUBSEP req[k]) in field))
        runmiss = runmiss sprintf("- `%s` is missing the **%s** field\n", id, req[k])
  }
  kind = ""; id = ""; status = ""
}

/^##[[:space:]]+L-[A-Za-z0-9]+/ {
  flush_block()
  kind = "lesson"
  match($0, /L-[A-Za-z0-9]+/); id = substr($0, RSTART, RLENGTH)
  lessons++
  if ($0 ~ /DEMOTED/)          status = "DEMOTED"
  # Any parenthesised qualifier on PROMOTED means the evidence was borrowed from a
  # sibling skill or the harness rather than observed in a blueprint run:
  # "(transfer)", "(transfer, mechanism identical)", "(harness)" are all the same class.
  else if ($0 ~ /PROMOTED[[:space:]]*\(/) status = "PROMOTED (transfer)"
  else if ($0 ~ /PROMOTED/)    status = "PROMOTED"
  else if ($0 ~ /CANDIDATE/)   status = "CANDIDATE"
  else nostatus = nostatus sprintf("- `%s` has no status (CANDIDATE / PROMOTED / DEMOTED) in its heading\n", id)
  next
}

/^##[[:space:]]+Run[[:space:]]+[0-9]+/ {
  flush_block()
  kind = "run"
  match($0, /Run[[:space:]]+[0-9]+/); id = substr($0, RSTART, RLENGTH)
  gsub(/[[:space:]]+/, " ", id)
  runs++
  if ($0 !~ /[0-9]{4}-[0-9]{2}-[0-9]{2}/)
    undated = undated sprintf("- `%s` has no YYYY-MM-DD date in its heading\n", id)
  next
}

/^##[[:space:]]+UNANSWERED/ { flush_block(); kind = "unanswered"; next }
/^##[[:space:]]/            { flush_block(); kind = "other"; next }

kind == "lesson" && /^[[:space:]]*-[[:space:]]*\*\*Rule\*\*/     { has_rule[id] = 1 }
kind == "lesson" && /^[[:space:]]*-[[:space:]]*\*\*Evidence\*\*/ { has_evidence[id] = 1 }
kind == "lesson" && /^[[:space:]]*-[[:space:]]*\*\*Landed-in\*\*/{ has_landed[id] = 1 }

kind == "run" && /^[[:space:]]*-[[:space:]]*\*\*[^*]+\*\*/ {
  if (match($0, /\*\*[^*]+\*\*/)) {
    f = substr($0, RSTART + 2, RLENGTH - 4)
    sub(/:$/, "", f)
    field[id, f] = 1
  }
}

kind == "unanswered" && /^[[:space:]]*-[[:space:]]*\*\*U-/ { unanswered++ }

END {
  flush_block()
  fail = 0

  if (metrics_only) {
    printf "lessons=%d promoted=%d transfers=%d candidate=%d demoted=%d runs=%d unanswered=%d\n",
           lessons, promoted, length(transfers), candidate, demoted, runs, unanswered
    exit 0
  }

  printf "## Lessons ledger check — %s\n\n", FILENAME
  printf "Lessons: %d  (promoted %d, of which transfers %d · candidate %d · demoted %d)\n",
         lessons, promoted, length(transfers), candidate, demoted
  printf "Runs recorded: %d    Open UNANSWERED: %d\n\n", runs, unanswered

  if (lessons == 0) { print "### FAIL — no lessons found. Is this the right file?"; exit 1 }

  if (nostatus  != "") { printf "### FAIL — lesson with no status\n\n%s\n", nostatus;  fail = 1 }
  if (miss      != "") { printf "### FAIL — lesson missing a required field\n\n%s\n", miss; fail = 1 }
  if (nolanded  != "") { printf "### FAIL — promoted without Landed-in\n\n%s\n", nolanded; fail = 1 }
  if (undated   != "") { printf "### FAIL — run record with no date\n\n%s\n", undated;  fail = 1 }
  if (runmiss   != "") {
    printf "### FAIL — run record missing a required field\n\n%s", runmiss
    print  "\nThese fields are the ones that answer the UNANSWERED questions. A run"
    print  "record without them cannot move the ledger forward.\n"
    fail = 1
  }

  if (unanswered == 0 && runs > 0) {
    print "### FAIL — no UNANSWERED section\n"
    print "A ledger with no open questions is claiming the method is fully understood."
    print "Record what this skill still does not know about itself.\n"
    fail = 1
  }

  # WARN, never FAIL: borrowed evidence that real runs should have settled by now.
  if (length(transfers) > 0 && runs >= 3) {
    printf "### WARN — transfers unconfirmed after %d runs\n\n", runs
    print  "Each rests on a sibling skill, not on this one. After three real"
    print  "runs at least one should have been confirmed (drop the parenthetical) or"
    print  "demoted:\n"
    for (t in transfers) printf "- `%s`\n", t
    print ""
  }
  if (runs == 0) {
    print "### WARN — no run records yet\n"
    print "Every lesson here rests on authoring-time reasoning or borrowed evidence."
    print "The ledger cannot measure the method until a package runs through it.\n"
  }

  if (fail) { print "Verdict: NO-GO on the lessons ledger." ; exit 1 }
  print "### PASS — ledger is structurally sound.\n"
  print "Verdict: GO. This checks that the ledger is well-formed, not that its lessons are true."
  exit 0
}
' "$FILE"
