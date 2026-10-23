#!/usr/bin/env bash
# check-section-integrity — assert a filled artifact still carries every section the resolved
# template requires, in the template's order.
#
# WHY THIS EXISTS
# The kit tells the agent, in prose, "do not drop, rename, reorder, or summarise any section the
# resolved file contains". That rule is READ, not OBEYED — a real run dropped two sections from a
# spec and nothing noticed; a dogfood run before that had spec.md silently missing its appended
# sections. Section PRESENCE is text, so unlike "is this section any good" it is machine-checkable,
# and a machine-checkable rule should not rest on prose alone. This is that check.
#
# WHAT IT DOES NOT DO
# It cannot tell a well-filled section from a thin one, and it does not judge whether a section that
# says `Not applicable — <reason>` is telling the truth. That limit is deliberate and stated rather
# than hidden.
#
# STUBS
# One content property IS checkable: a heading with nothing rendered under it. That is the shape a
# section takes when it is added to satisfy this check rather than to say something, so it would be
# the first symptom of the check doing harm. A section counts as a stub when nothing renders between
# its heading and the next heading of the same or a higher level — blank lines, HTML comments and
# thematic breaks do not count as content (rumdl's MD082 draws the line in the same place). A parent
# heading whose content is its subsections is NOT a stub: MD082 flags those by default and offers
# `allow-parent-headings` to accept them, and the templates here use container headings
# (`## Requirements` → `### Functional Requirements`, `## Normative Status` → `### Which document
# wins`), so the allowance is always on.
#
# `Not applicable — <reason>` is accepted as content. Deliberately, a bare `N/A` is accepted too:
# rumdl counts it as rendered content, no reviewed tooling requires a justification after a
# non-applicability claim, and a checker that rejects the terse form earns a reputation for false
# positives — the fastest way for a check to be deleted. The rule that a reason is required lives
# in the template beside the section, where the author reads it.
#
# Usage: check-section-integrity.sh <project-root> <template-name> <artifact-file>
#   e.g. check-section-integrity.sh . spec-template specs/007-thing/spec.md
# Exit: 0 = conformant · 1 = missing, reordered, or stubbed sections · 2 = usage/setup error.
set -uo pipefail

PROJECT="${1:-}"; TEMPLATE="${2:-}"; ARTIFACT="${3:-}"
if [ -z "$PROJECT" ] || [ -z "$TEMPLATE" ] || [ -z "$ARTIFACT" ]; then
  echo "usage: $0 <project-root> <template-name> <artifact-file>" >&2
  echo "   e.g. $0 . spec-template specs/007-thing/spec.md" >&2
  exit 2
fi

RESOLVER="$PROJECT/.specify/scripts/bash/resolve-template.sh"
[ -f "$RESOLVER" ] || { echo "no resolve-template.sh under $PROJECT/.specify/scripts/bash" >&2; exit 2; }
[ -f "$ARTIFACT" ] || { echo "artifact not found: $ARTIFACT" >&2; exit 2; }

TMPD="$(mktemp -d)" || exit 2

if ! bash "$RESOLVER" "$TEMPLATE" > "$TMPD/template" 2>"$TMPD/err"; then
  echo "template '$TEMPLATE' did not resolve:" >&2
  sed 's/^/  /' "$TMPD/err" >&2
  rm -rf "$TMPD"; exit 2
fi

# Headings, normalised for comparison.
#
# A template heading carries guidance that is not part of the section's NAME, and the artifact is
# not supposed to copy it:
#   '### Key Entities *(include if feature involves data)*'       → italic note
#   '## Phase 1: Setup (Shared Infrastructure)'                   → descriptive parenthetical
#   '### Tests for User Story 1 (OPTIONAL - only if tests …) ⚠️'   → optional marker
# Comparing raw text made a fully conformant spec report '### Key Entities' as MISSING. A check
# that is wrong about something normal gets deleted, so the guidance is stripped from BOTH sides
# before comparing.
#
# Two things are excluded from `required` entirely:
#   - a heading containing '[' — a placeholder ('[PRINCIPLE_1_NAME]') or a removable block
#     ('[REMOVE IF USED]');
#   - a heading marked OPTIONAL — the template says the section may be absent, so demanding it
#     would assert the opposite of the document being validated.
normalize() {
  sed -e 's/[[:space:]]*$//' \
      -e 's/[[:space:]]*⚠️[[:space:]]*$//' \
      -e 's/[[:space:]]*([^)]*)[[:space:]]*$//' \
      -e 's/[[:space:]]*\*([^*]*)\*[[:space:]]*$//'
}

# A fenced code block is not document structure. `# Launch all models for User Story 1 together:`
# is a shell comment in a sample program, and counting it as a heading made this check report a
# working tasks.md as stubbed. An earlier repair edited the template to remove those comment lines
# instead — conforming the artifact to a defect in the check, which is the wrong direction.
strip_fences() {
  awk '/^[[:space:]]*```/ { fence = !fence; next } !fence { print }' "$1"
}

headings() {
  strip_fences "$1" | grep -E '^#{1,4}[[:space:]]' | sed -e '/\[/d' -e '/(OPTIONAL/d' | normalize
}

# Headings whose section renders nothing before the next heading of the same or a higher level.
# A heading followed by a DEEPER heading is a container, not a stub — see the STUBS note above.
stubs() {
  awk '
    function level(s,   n) { n = 0; while (substr(s, n + 1, 1) == "#") n++; return n }
    BEGIN { pending = ""; plevel = 0; open = 0; inhtml = 0; infence = 0 }
    {
      line = $0
      # A fenced block is rendered content, so it fills the section it sits in — but its `#`
      # comment lines are not headings and its blank lines are not the end of the section.
      if (infence) {
        if (line ~ /^[ \t]*```/) infence = 0
        next
      }
      if (line ~ /^[ \t]*```/) { open = 1; infence = 1; next }
      if (line ~ /^#{1,6}[ \t]/) {
        lvl = level(line)
        if (pending != "" && !open && lvl <= plevel) print pending
        pending = line; plevel = lvl; open = 0; inhtml = 0
        next
      }
      if (inhtml) { if (line ~ /-->/) inhtml = 0; next }
      if (line ~ /^[ \t]*<!--/ && line !~ /-->/) { inhtml = 1; next }
      gsub(/^[ \t]+|[ \t]+$/, "", line)
      if (line == "") next
      if (line ~ /<!--/) next
      if (line ~ /^-{3,}$|^\*{3,}$|^_{3,}$/) next
      open = 1
    }
    END { if (pending != "" && !open) print pending }
  ' "$1"
}

headings "$TMPD/template" > "$TMPD/required"
headings "$ARTIFACT"      > "$TMPD/found"

# Problem framing is appended by the addendum but belongs above the append point: a spec that opens
# with Requirements buries the reason it exists. Its presence is still required; only ORDER is waived.
# (Added to the list above, beside the other sections the kit instructs you to relocate.)
stubs "$ARTIFACT" > "$TMPD/stubs"

# Only headings the template actually requires are this check's business: a stub in a section the
# template marks OPTIONAL is an empty optional section, which may simply be deleted.
awk 'NR == FNR { req[$0] = 1; next } ($0 in req)' "$TMPD/required" "$TMPD/stubs" > "$TMPD/stubs-req"

# The comparison needs the normalised form on both sides; stub lines print raw.
normalize < "$TMPD/stubs-req" > "$TMPD/stubs-norm"
mv "$TMPD/stubs-norm" "$TMPD/stubs-req"

total=$(wc -l < "$TMPD/required" | tr -d ' ')
if [ "$total" -eq 0 ]; then
  # A resolver that silently returns a placeholder-only document must not read as "conformant".
  echo "  ERROR    template '$TEMPLATE' resolved with no required headings — refusing to report success" >&2
  rm -rf "$TMPD"; exit 2
fi

missing=0; disordered=0; cursor=0; index=0
while IFS= read -r want; do
  index=$((index + 1))
  # Find the FIRST occurrence strictly after the cursor. Searching from the top every time made a
  # repeated heading look reordered: tasks-template contains '### Worked example' twice, and the
  # second requirement found the first occurrence again, behind the cursor. Consuming occurrences
  # in order fixes that, and still detects a genuine move — which leaves `appears` set while
  # finding nothing ahead of the cursor.
  at=0; appears=0; n=0
  while IFS= read -r have; do
    n=$((n + 1))
    if [ "$have" = "$want" ]; then
      appears=1
      if [ "$n" -gt "$cursor" ]; then at=$n; break; fi
    fi
  done < "$TMPD/found"

  if [ "$at" -ne 0 ]; then
    cursor=$at
  elif [ "$appears" -eq 0 ]; then
    printf '  MISSING  %s\n' "$want"
    missing=$((missing + 1))
  else
    # Some sections are INSTRUCTED to move. The commands require `Document Status` directly after
    # the core metadata, and `Normative Status` / `Which document wins` / `Requirements Syntax
    # (EARS)` follow it — all ahead of where append-only composition puts them. Penalising the
    # reordering the kit itself mandates would make this check report failure on every conformant
    # spec, and a check that is wrong about something normal gets removed. Presence is still
    # required; only ORDER is waived for these four.
    # Names here are the NORMALISED form (guidance stripped), e.g. '## Requirements Syntax
    # (EARS)' arrives as '## Requirements Syntax'.
    case "$want" in
      "## Document Status"|"## Normative Status"|"### Which document wins"|"## Requirements Syntax"|"## Problem / Opportunity")
        : ;;   # ordering waived by instruction; presence already verified above
      *)
        printf '  ORDER    %s  (found before an earlier-required section)\n' "$want"
        disordered=$((disordered + 1)) ;;
    esac
  fi
done < "$TMPD/required"

stubbed=0
if [ -s "$TMPD/stubs-req" ]; then
  while IFS= read -r stub; do
    [ -n "$stub" ] || continue
    printf '  STUB     %s  (a heading with nothing under it)\n' "$stub"
    stubbed=$((stubbed + 1))
  done < "$TMPD/stubs-req"
fi

rm -rf "$TMPD"

if [ "$missing" -eq 0 ] && [ "$disordered" -eq 0 ] && [ "$stubbed" -eq 0 ]; then
  printf '  ok       %s: all %s required sections present, in template order, none empty\n' "$ARTIFACT" "$total"
  exit 0
fi
printf '  FAIL     %s: %s missing, %s out of order, %s stubbed (of %s required)\n' \
  "$ARTIFACT" "$missing" "$disordered" "$stubbed" "$total"
exit 1
