#!/usr/bin/env bash
# id-sweep.sh — mechanical cross-reference check for an app-blueprint package.
#
# Why this exists: successive edit passes rename and drop IDs invisibly. Phase 8
# requires a scripted sweep, not eyeballing, because eyeballing has never once
# caught a dangling FR reference in a fourteen-document set.
#
# Usage:  scripts/id-sweep.sh [docs-dir]     (default: ./docs, plus a sibling CLAUDE.md)
# Exit:   0 = every referenced ID has a definition.  1 = dangling IDs.  2 = usage/env error.
#
# CLASSIFICATION. Grep cannot perfectly tell "this line defines FR-AUTH-1" from
# "this line mentions FR-AUTH-1", so the script grades definitions instead of
# guessing, and tells you which calls were close:
#
#   STRONG  heading, list item, bold lead-in, or the "ID: text" / "ID — text" idiom.
#   WEAK    the ID sitting alone in a table cell. Definition tables and traceability
#           tables are structurally identical, so these are reported for eyeballing.
#   NONE    referenced only inside prose. Treated as undefined. This is the case the
#           tool exists to catch: a defining entry deleted by an edit pass, leaving
#           only the sentences that discuss it.
#
# A dangling ID fails the run. A weak-only ID warns but passes, because failing on
# every traceability table would get this script ignored, and an ignored gate is
# worse than no gate.

set -uo pipefail

DOCS="${1:-docs}"
ROOT="$(dirname "$DOCS")"
[ -d "$DOCS" ] || { echo "id-sweep: no such directory: $DOCS" >&2; exit 2; }

# \b is a GNU/BSD extension, not POSIX ERE. Busybox grep silently stops matching
# word boundaries, which would make every ID match every prefix. Fail loudly instead.
printf 'FR-AUTH-1\n' | grep -qE '\bFR-AUTH-1\b' 2>/dev/null || {
  echo "id-sweep: this grep does not support \\b word boundaries; install GNU grep." >&2; exit 2; }

FILES=$(find "$DOCS" -type f \( -iname '*.md' -o -iname '*.markdown' \
        -o -iname '*.html' -o -iname '*.htm' \) 2>/dev/null | sort)
[ -f "$ROOT/CLAUDE.md" ] && FILES=$(printf '%s\n%s' "$ROOT/CLAUDE.md" "$FILES")
FILES=$(printf '%s\n' "$FILES" | grep -c . >/dev/null && printf '%s\n' "$FILES" | grep .)
[ -n "$FILES" ] || { echo "id-sweep: no documents found under $DOCS" >&2; exit 2; }
NFILES=$(printf '%s\n' "$FILES" | grep -c .)

# ID grammar per references/document-set.md §Numbering conventions.
#
# Keep this in lockstep with that section. A family listed there but missing here is
# invisible to the gate, which is how a cross-reference check passes while references
# dangle (lesson L-AB4). Families whose prefix is ambiguous with ordinary prose —
# M<n> launch metrics, B<n>, S<n>, Q<n> — are deliberately NOT swept and are listed as
# hand-checked in document-set.md; adding them here would bury real findings in noise.
#
# G- accepts an optional trailing letter: a decomposed sub-goal is G-3.2a, and without
# the [a-z]? every sub-goal produced by an L-decomposition matched nothing at all.
ID='(FR-[A-Z0-9]+-[0-9]+|NFR-[A-Z0-9]+-[0-9]+|TS-[A-Z0-9]+-[0-9]+|EVAL-[A-Z0-9]+-[0-9]+|SCR-[A-Z0-9]+(-[0-9]+)?|UNTESTABLE-[0-9]+|ADR-[0-9]+|AD-[0-9]+|AG-[0-9]+|DR-[0-9]+|PI-[0-9]+|EC-[0-9]+|D-[A-Z]+-[0-9]+|D[0-9]+|G-[0-9]+\.[0-9]+[a-z]?)'
# One or more stacked markdown markers: heading, ordered/unordered bullet, checkbox,
# blockquote, bold/underline. Stacking matters — "- **FR-AUTH-1**:" is the single
# most common way people actually write these, and a single-marker regex misses it
# entirely.
#
# The table pipe is deliberately NOT a marker. Every markdown table row begins with
# one, so including it graded every first-column ID as STRONG — which made the entire
# WEAK bucket below unreachable and let a pure traceability table silently satisfy
# the gate for every ID in column 1. Negative-tested 2026-08-20: with the pipe in
# MARK, a docs/ dir containing only a traceability table reported "Weak-only: 0".
MARK='(#{1,6}|[0-9]+\.|[-*+]|\[[ xX]\]|>|\*\*|__)'

tmp=$(mktemp -d) || exit 2; trap 'rm -rf "$tmp"' EXIT
: > "$tmp/all"; : > "$tmp/strong"; : > "$tmp/weak"

while IFS= read -r f; do
  [ -n "$f" ] || continue
  grep -ohE "\b$ID\b" "$f" 2>/dev/null >> "$tmp/all"
  {
    # STRONG: one or more leading markers, then the ID.
    grep -ohE "^[[:space:]]*($MARK[[:space:]]*)+$ID\b" "$f" 2>/dev/null
    # STRONG: bare "ID: text" or "ID — text" definition idiom. Requires the separator,
    # so "AD-3 conflicts with AD-5" stays a reference rather than silently defining AD-3.
    grep -ohE "^[[:space:]]*$ID[[:space:]]*(:|—)" "$f" 2>/dev/null
  } | grep -ohE "\b$ID\b" 2>/dev/null >> "$tmp/strong"
  # WEAK: the ID alone in a table cell, any column.
  #
  # This splits rows into cells rather than pattern-matching the row, because grep -o
  # consumes the shared "|" delimiter: in "| FR-A-1 | TS-A-1 |" the first match ate
  # the pipe that column 2 needed, so every ID past the first column was invisible to
  # both buckets and got reported as DANGLING. Negative-tested 2026-08-20: the old
  # pattern failed a two-column traceability table on its own second column.
  awk '/^[[:space:]]*\|/ {
         line = $0
         gsub(/\\\|/, "\001", line)      # an escaped \| is cell CONTENT, not a separator
         n = split(line, cell, "|")
         for (i = 1; i <= n; i++) { gsub(/\001/, "|", cell[i]); print cell[i] }
       }' \
      "$f" 2>/dev/null \
    | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/^(\*\*|__|`)+//; s/(\*\*|__|`)+$//; s/^[[:space:]]+//; s/[[:space:]]+$//' \
    | grep -xE "$ID" 2>/dev/null >> "$tmp/weak"
done <<< "$FILES"

sort -u "$tmp/all"    > "$tmp/all.u"
sort -u "$tmp/strong" > "$tmp/strong.u"
sort -u "$tmp/weak"   > "$tmp/weak.u"
sort -u "$tmp/strong.u" "$tmp/weak.u" > "$tmp/def.u"

DANGLING=$(comm -23 "$tmp/all.u" "$tmp/def.u")
WEAKONLY=$(comm -23 "$tmp/weak.u" "$tmp/strong.u")

# Escape ERE metacharacters before reusing an ID as a search pattern, or the "."
# in G-1.1 matches any character and misattributes citations.
esc() { printf '%s' "$1" | sed 's/[][\.*^$(){}?+|/]/\\&/g'; }

cite() {
  local id pat; id="$1"; pat="$(esc "$id")"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    grep -nE "\b$pat\b" "$f" 2>/dev/null | head -3 \
      | awk -v p="$f" '{print "    " p ":" $0}'
  done <<< "$FILES"
}

echo "## ID sweep — $(date -u '+%Y-%m-%d %H:%M UTC')"
echo
echo "Scanned: $NFILES documents under $DOCS"
echo "Distinct IDs: $(grep -c . < "$tmp/all.u")   Strong: $(grep -c . < "$tmp/strong.u")   Weak-only: $(printf '%s\n' "$WEAKONLY" | grep -c .)"
echo

if [ -n "$WEAKONLY" ]; then
  echo "### WARN — defined only by a bare table cell"
  echo
  echo "Each of these appears alone in a table cell and nowhere stronger. That is what a"
  echo "definition table looks like, and also what a traceability table looks like. Confirm"
  echo "each one has a real defining entry."
  echo
  printf '%s\n' "$WEAKONLY" | grep . | sed 's/^/- `/; s/$/`/'
  echo
fi

if [ -n "$DANGLING" ]; then
  echo "### FAIL — referenced but never defined"
  echo
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    echo "- \`$id\` — cited in:"
    cite "$id"
  done <<< "$DANGLING"
  echo
  echo "Verdict: NO-GO until every ID above is defined or the reference is removed."
  exit 1
fi

echo "### PASS — every referenced ID resolves to a definition."
echo
echo "Verdict: GO on cross-references. This checks that IDs resolve, not that they are correct."
exit 0
