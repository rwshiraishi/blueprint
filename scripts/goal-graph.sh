#!/usr/bin/env bash
# goal-graph.sh — dependency-graph check for an app-blueprint LOOP_GOALS.md.
#
# Why this exists: LOOP_GOALS.md's never-stop protocol is a graph query — on a
# blocker the agent needs "the unblocked set", which is only computable if the
# graph is sound. A cycle makes it empty; a dangling dependency makes it wrong.
# Neither is visible to the eye across forty goals, and the pre-flight audit is
# far too late to find one: by then every goal ID in the package is wired to it.
#
# Reads the `G-x.y` headers and `Depends on:` fields defined in
# references/deliverables-build-goals.md §1.1. Continuation lines are supported —
# the worked example wraps its dependency list across three lines.
#
# Usage:  scripts/goal-graph.sh [path/to/LOOP_GOALS.md]   (default: docs/LOOP_GOALS.md)
#         scripts/goal-graph.sh --check [path]            (same; flag accepted for symmetry)
# Exit:   0 = acyclic, every dependency defined, at least one root.
#         1 = cycle, dangling dependency, self-dependency, or no root.
#         2 = usage/env error.
#
# Negative-tested 2026-08-20: a two-goal cycle exits 1 naming both goals; a
# dependency on an undefined goal exits 1 naming it; a rootless graph exits 1.

set -uo pipefail

[ "${1:-}" = "--check" ] && shift
FILE="${1:-docs/LOOP_GOALS.md}"
[ -f "$FILE" ] || { echo "goal-graph: no such file: $FILE" >&2; exit 2; }
command -v awk >/dev/null 2>&1 || { echo "goal-graph: awk not found" >&2; exit 2; }

awk '
# ORDER MATTERS. The continuation rule must come first: a wrapped dependency line
# ("                G-2.6 (job table)") is indented and starts with a goal ID, so the
# header rule below would otherwise read it as a second declaration of that goal.
# Negative-tested 2026-08-20: without this ordering a healthy 5-goal graph reported
# 6 goals and a spurious "declared twice".
collecting == 1 && /^[[:space:]]+[^[:space:]]/ && !/^[[:space:]]*[A-Za-z][A-Za-z ]*:/ {
  collect($0); next
}
collecting == 1 { collecting = 0 }

# A goal is declared by its ID at the start of a line, optionally behind markdown
# markers (### G-3.2 — title, or a bare "G-3.2  title" inside a fenced block).
# Never indented — indentation means continuation, handled above.
# Sub-goals from an L-decomposition take a trailing letter: G-3.2a.
/^(#{1,6}[[:space:]]*)?G-[0-9]+\.[0-9]+[a-z]?([[:space:]]|$|—|-|:)/ {
  if (match($0, /G-[0-9]+\.[0-9]+[a-z]?/)) {
    cur = substr($0, RSTART, RLENGTH)
    if (cur in declared) { dup[cur] = 1 }
    declared[cur] = 1
    order[++n] = cur
    collecting = 0
  }
  next
}

# "Depends on: G-1.4 (...), G-2.1 (...)" — begin collecting.
/^[[:space:]]*Depends on:/ {
  if (cur == "") { stray = stray sprintf("  line %d: Depends on before any goal header\n", NR); next }
  line = $0
  sub(/^[[:space:]]*Depends on:/, "", line)
  collect(line)
  collecting = 1
  next
}

function collect(text,   rest, tok) {
  if (text ~ /[Nn]one/) { hasnone[cur] = 1 }
  rest = text
  while (match(rest, /G-[0-9]+\.[0-9]+[a-z]?/)) {
    tok = substr(rest, RSTART, RLENGTH)
    if (tok == cur) { selfdep[cur] = 1 }
    else { deps[cur] = deps[cur] " " tok }
    rest = substr(rest, RSTART + RLENGTH)
  }
}

END {
  if (n == 0) { print "goal-graph: no G-x.y goals found in the file." > "/dev/stderr"; exit 2 }

  fail = 0
  printf "## Goal graph — %s\n\n", FILENAME
  printf "Goals: %d\n\n", n

  for (g in dup) { printf "### FAIL — goal declared twice\n\n- `%s`\n\n", g; fail = 1 }
  if (stray != "") { printf "### FAIL — orphan dependency block\n\n%s\n", stray; fail = 1 }

  # Dangling dependencies.
  dangling = ""
  for (g in deps) {
    m = split(deps[g], d, " ")
    for (i = 1; i <= m; i++)
      if (d[i] != "" && !(d[i] in declared))
        dangling = dangling sprintf("- `%s` depends on `%s`, which is never defined\n", g, d[i])
  }
  if (dangling != "") { printf "### FAIL — dependency on an undefined goal\n\n%s\n", dangling; fail = 1 }

  sd = ""
  for (g in selfdep) sd = sd sprintf("- `%s` depends on itself\n", g)
  if (sd != "") { printf "### FAIL — self-dependency\n\n%s\n", sd; fail = 1 }

  # Roots: no dependencies, or an explicit "none".
  roots = 0
  for (i = 1; i <= n; i++) {
    g = order[i]
    if (!(g in deps) || deps[g] ~ /^[[:space:]]*$/ || (g in hasnone && deps[g] ~ /^[[:space:]]*$/)) roots++
  }
  if (roots == 0) {
    print "### FAIL — no root goal\n\nEvery goal depends on another. The first hour has nowhere to start.\n"
    fail = 1
  }

  # Cycle detection by repeated removal of satisfied goals (Kahn).
  #
  # Iterate order[] by index, never `for (g in remaining)`: deleting from an array
  # while iterating it is undefined in awk, and in testing it skipped elements and
  # reported a cycle in a provably acyclic graph. Negative-tested 2026-08-20.
  for (i = 1; i <= n; i++) remaining[order[i]] = 1
  changed = 1
  while (changed) {
    changed = 0
    for (i = 1; i <= n; i++) {
      g = order[i]
      if (!(g in remaining)) continue
      ok = 1
      m = split(deps[g], d, " ")
      for (j = 1; j <= m; j++) if (d[j] != "" && (d[j] in remaining)) { ok = 0; break }
      if (ok) { delete remaining[g]; changed = 1 }
    }
  }
  cyc = ""
  for (i = 1; i <= n; i++) { g = order[i]; if (g in remaining) cyc = cyc sprintf("- `%s` (depends on:%s)\n", g, deps[g]) }
  if (cyc != "") {
    printf "### FAIL — cycle\n\nThese goals can never become unblocked, so the never-stop protocol\nhas an empty unblocked set and the build stops:\n\n%s\n", cyc
    fail = 1
  }

  if (fail) { print "Verdict: NO-GO on the goal graph."; exit 1 }
  printf "### PASS — acyclic, every dependency defined, %d root goal(s).\n\n", roots
  # This exact line is the documented exit-criterion match string in
  # references/deliverables-build-goals.md. Changing its wording breaks every
  # goal whose criteria grep for it.
  printf "DAG: OK, %d goals, 0 cycles\n\n", n
  print "Verdict: GO. This checks graph soundness, not whether the order is sensible."
  exit 0
}
' "$FILE"
