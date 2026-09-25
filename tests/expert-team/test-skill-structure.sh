#!/usr/bin/env bash
# Structural checks for skills/expert-team. Like tests/diagnosing-superpowers,
# this verifies only what a shell can check: frontmatter, roster/role file
# agreement, declared artifacts matching what each role actually writes, and
# required sections. Behavior is what a live dispatch review catches.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL_DIR="$REPO_ROOT/skills/expert-team"
SKILL_MD="$SKILL_DIR/SKILL.md"
ROLES_DIR="$SKILL_DIR/roles"
# writing-skills targets <500 words for non-frequently-loaded skills; this
# roster-plus-protocol skill is deliberately denser. Budget guards runaway
# growth, it is not an endorsement of the current size.
WORD_BUDGET=1200

PASSES=0
FAILURES=0

pass() { echo "  [PASS] $1"; PASSES=$((PASSES + 1)); }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

echo "expert-team structure"

if [ ! -f "$SKILL_MD" ]; then
  fail "SKILL.md exists"
  echo "  [PASS] $PASSES  [FAIL] $FAILURES"
  exit 1
fi
pass "SKILL.md exists"

# --- frontmatter ----------------------------------------------------------
frontmatter="$(awk 'NR==1 && $0!="---"{exit} NR>1 && $0=="---"{exit} NR>1{print}' "$SKILL_MD")"
if printf '%s\n' "$frontmatter" | grep -q '^name: expert-team$'; then
  pass "frontmatter name is expert-team"
else
  fail "frontmatter name is expert-team"
fi

description="$(printf '%s\n' "$frontmatter" \
  | awk '/^description:/{sub(/^description:[ ]*/,""); print; found=1; next} found && /^[ ]/{print} found && !/^[ ]/{exit}' \
  | tr '\n' ' ')"
if printf '%s' "$description" | grep -q '^Use when'; then
  pass "description starts with 'Use when'"
else
  fail "description starts with 'Use when' (got: ${description:0:60})"
fi
if [ "${#description}" -le 1024 ]; then
  pass "description under 1024 characters"
else
  fail "description under 1024 characters (${#description})"
fi
for banned in "dispatch" "then" "step"; do
  if printf '%s' "$description" | grep -qiw "$banned"; then
    fail "description contains workflow word '$banned'"
  else
    pass "description avoids workflow word '$banned'"
  fi
done

# --- word budget ----------------------------------------------------------
body_words="$(awk 'BEGIN{fm=0} NR==1 && $0=="---"{fm=1; next} fm==1 && $0=="---"{fm=2; next} fm==2{print}' "$SKILL_MD" | wc -w | tr -d ' ')"
if [ "$body_words" -le "$WORD_BUDGET" ]; then
  pass "SKILL.md body within $WORD_BUDGET words ($body_words)"
else
  fail "SKILL.md body within $WORD_BUDGET words ($body_words)"
fi

# --- required sections ----------------------------------------------------
for heading in "## Overview" "## Roster" "## Dispatch Protocol" \
               "## Artifact Conventions" "## Lifecycle" "## Common Mistakes" \
               "## Verification"; do
  if grep -q "^$heading" "$SKILL_MD"; then
    pass "SKILL.md has section '$heading'"
  else
    fail "SKILL.md has section '$heading'"
  fi
done

# --- roster <-> roles directory ------------------------------------------
roster_refs="$(grep -o 'roles/[A-Za-z0-9._-]*\.md' "$SKILL_MD" | sort -u)"
roster_count="$(printf '%s\n' "$roster_refs" | grep -c . || true)"
roles_count="$(find "$ROLES_DIR" -name '*.md' | wc -l | tr -d ' ')"
if [ "$roster_count" -eq "$roles_count" ]; then
  pass "roster lists every role file ($roster_count)"
else
  fail "roster lists every role file (roster=$roster_count, on-disk=$roles_count)"
fi

for ref in $roster_refs; do
  if [ -f "$SKILL_DIR/$ref" ]; then
    pass "roster role file exists: $ref"
  else
    fail "roster role file exists: $ref"
  fi
done

while IFS= read -r on_disk; do
  rel="roles/$(basename "$on_disk")"
  if printf '%s\n' "$roster_refs" | grep -qx "$rel"; then
    pass "role file is in roster: $rel"
  else
    fail "role file is in roster: $rel (orphan - not dispatchable)"
  fi
done < <(find "$ROLES_DIR" -maxdepth 1 -name '*.md')

# --- declared artifacts match what each role writes -----------------------
# Each entry is "role-file.md|artifact-token". The token must appear in that
# role's roster row, so the coordinator's step-5 "verify the artifact exists"
# check cannot miss a file a role writes.
artifact_map=(
  "project-manager.md|docs/team/board.md"
  "doc-maintainer.md|docs/**"
  "daily-log.md|docs/team/daily-log.md"
  "errors-and-fixes.md|docs/team/errors-and-fixes.md"
  "architecture-expert.md|docs/team/architecture.md"
  "ui-ux-expert.md|docs/team/ui-ux-reviews.md"
  "ui-ux-expert.md|docs/team/mocks/*.html"
  "brainstormer-validator.md|docs/team/validation-reports.md"
  "flowchart-expert.md|docs/team/diagrams/*.dot"
  "flowchart-expert.md|docs/team/diagrams/INDEX.md"
  "finisher.md|docs/team/goals.md"
  "research-expert.md|docs/team/research.md"
  "tech-expert.md|docs/team/tech-review.md"
)
for entry in "${artifact_map[@]}"; do
  role="${entry%%|*}"
  artifact="${entry#*|}"
  row="$(grep "roles/$role" "$SKILL_MD" || true)"
  if printf '%s' "$row" | grep -qF -- "$artifact"; then
    pass "roster declares artifact '$artifact' for $role"
  else
    fail "roster declares artifact '$artifact' for $role"
  fi
done

# every docs/team path a role writes must be declared somewhere in SKILL.md
write_hits="$(grep -rhoE 'docs/team/[A-Za-z0-9.*_-]+' "$ROLES_DIR" | sort -u)"
undeclared=0
for path in $write_hits; do
  base="$(basename "$path")"
  if ! grep -qF -- "$base" "$SKILL_MD"; then
    fail "artifact path in roles/ declared in SKILL.md: $path"
    undeclared=$((undeclared + 1))
  fi
done
[ "$undeclared" -eq 0 ] && pass "all docs/team paths used by roles are declared in SKILL.md"

# --- role file sections ---------------------------------------------------
for role_file in "$ROLES_DIR"/*.md; do
  name="$(basename "$role_file")"
  for heading in "## Charter" "## Dispatch trigger" "## Prompt template" "## Output contract"; do
    if grep -q "^$heading" "$role_file"; then
      pass "$name has section '$heading'"
    else
      fail "$name has section '$heading'"
    fi
  done
done

# --- every prompt template carries the date slot --------------------------
# SKILL.md's Artifact Conventions rule: dates are explicit, never guessed.
# A role template without the slot silently invites a subagent to invent one.
for role_file in "$ROLES_DIR"/*.md; do
  name="$(basename "$role_file")"
  if grep -qE 'Today.s date: <YYYY-MM-DD' "$role_file"; then
    pass "$name prompt template carries the date slot"
  else
    fail "$name prompt template carries the date slot"
  fi
done

# --- research expert evidence rules ---------------------------------------
RESEARCH="$ROLES_DIR/research-expert.md"
if [ -f "$RESEARCH" ]; then
  if grep -q 'Evidence rules' "$RESEARCH"; then
    pass "research expert states evidence rules"
  else
    fail "research expert states evidence rules"
  fi
  for token in "unverified" "accessed date" "Never cite"; do
    if grep -qF -- "$token" "$RESEARCH"; then
      pass "research expert guards against '$token'"
    else
      fail "research expert guards against '$token'"
    fi
  done
  if grep -q 'superpowers:' "$RESEARCH" || grep -q 'Tech Expert' "$RESEARCH"; then
    pass "research expert states its boundary vs the tech expert"
  else
    fail "research expert states its boundary vs the tech expert"
  fi
fi

# --- every prompt template carries a mandatory Read-first block ------------
# Subagents inherit no session context, so an expert's knowledge ceiling is
# whatever its template tells it to read. A role without the block can only know
# what the coordinator happened to paste, and re-decides settled things silently.
for role_file in "$ROLES_DIR"/*.md; do
  name="$(basename "$role_file")"
  # only the fenced block under "## Prompt template" counts — mentioning reading
  # in the charter does not reach the subagent.
  tpl="$(awk '/^## Prompt template/{in_t=1; next}
               in_t && /^```/{ if (!in_fence) {in_fence=1; next} else {exit} }
               in_fence{print}' "$role_file")"
  if printf '%s\n' "$tpl" | grep -q '^Read first (mandatory'; then
    pass "$name prompt template has the Read-first block"
  else
    fail "$name prompt template has the Read-first block"
  fi
  # a block with one entry is a stub; upstream context is inherently multi-file
  n_refs="$(printf '%s\n' "$tpl" | sed -n '/^Read first (mandatory/,/^$/p' \
    | grep -c 'docs/' || true)"
  if [ "$n_refs" -ge 2 ]; then
    pass "$name Read-first block lists $n_refs artifacts"
  else
    fail "$name Read-first block lists >=2 artifacts (got $n_refs)"
  fi
done

# --- one writer per artifact ----------------------------------------------
# The roster's Artifact column is the ownership declaration. A path owned by two
# experts is the clobbering bug the parallel-dispatch rule depends on.
ownership="$(grep -E '^\| [0-9]+ \|' "$SKILL_MD" \
  | awk -F'|' '{print $5}' \
  | grep -oE 'docs/team/[A-Za-z0-9.*_/-]+' | sort | uniq -c | sort -rn)"
dupes="$(printf '%s\n' "$ownership" | awk '$1 > 1 {print $2, $1}')"
if [ -z "$dupes" ]; then
  pass "no artifact is owned by two roster rows"
else
  fail "no artifact is owned by two roster rows"
  printf '%s\n' "$dupes" | sed 's/^/    /'
fi

# --- dispatch log is coordinator-owned, never an expert's ------------------
# It is the record that separates a real dispatch from the coordinator doing the
# work itself; if a role wrote it, the record would be authored by the subject.
if grep -q 'docs/team/dispatch-log.md' "$SKILL_MD"; then
  pass "SKILL.md declares docs/team/dispatch-log.md"
else
  fail "SKILL.md declares docs/team/dispatch-log.md"
fi
log_writers="$(grep -rlE '^(Write|Update)[^:]*:?.*docs/team/dispatch-log' "$ROLES_DIR" || true)"
if [ -z "$log_writers" ]; then
  pass "no role writes dispatch-log.md (coordinator-owned)"
else
  fail "no role writes dispatch-log.md (coordinator-owned)"
  printf '%s\n' "$log_writers" | sed 's/^/    /'
fi
# unwrapped copy: markdown hard-wraps, so multi-word prose rules must be
# matched against flowed text or a re-wrap silently fails the check
skill_flow="$(tr '\n' ' ' < "$SKILL_MD" | tr -s ' ')"
for token in "One writer per file" "Announce and log" "in parallel" \
             "never in advance" "Wildcards need naming" \
             "in the same action you received it"; do
  if printf '%s' "$skill_flow" | grep -qF -- "$token"; then
    pass "SKILL.md states '$token'"
  else
    fail "SKILL.md states '$token'"
  fi
done

# --- roster artifact paths are fully qualified ----------------------------
# An abbreviated cell ("diagrams/INDEX.md" instead of "docs/team/diagrams/INDEX.md")
# makes the ownership check above blind: it only greps docs/team/ paths, so a
# shortened path silently declares no owner and the file looks unowned.
roster_paths="$(grep -E '^\| [0-9]+ \|' "$SKILL_MD" | awk -F'|' '{print $5}' \
  | grep -oE '`[^`]*`' | tr -d '`')"
bad_paths="$(printf '%s\n' "$roster_paths" \
  | grep -vE '^docs/|^$' || true)"
if [ -z "$bad_paths" ]; then
  pass "every roster artifact path is fully qualified"
else
  fail "every roster artifact path is fully qualified"
  printf '%s\n' "$bad_paths" | sed 's/^/    /'
fi

# --- the docs/** wildcard is bounded, not blanket -------------------------
# docs/** overlaps every single-owner artifact, so the ownership rule only holds
# if the doc maintainer's own file names the exclusions and sends wanted changes
# back as hand-off items. Found by a live run: a wildcard write reverted records
# the Finisher and Validator had already verified.
DM="$ROLES_DIR/doc-maintainer.md"
if grep -q '^## Ownership carve-out' "$DM"; then
  pass "doc-maintainer.md declares an Ownership carve-out"
else
  fail "doc-maintainer.md declares an Ownership carve-out"
fi
excluded="$(sed -n '/^## Ownership carve-out/,/^## /p' "$DM" \
  | grep -oE 'docs/team/[A-Za-z0-9.*_/-]+' | sort -u | wc -l | tr -d ' ')"
if [ "$excluded" -ge 8 ]; then
  pass "carve-out excludes $excluded team artifacts owned by other roles"
else
  fail "carve-out excludes >=8 owned team artifacts (got $excluded)"
fi
if printf '%s' "$(tr '\n' ' ' < "$DM" | tr -s ' ')" | grep -qF -- "hand-off item"; then
  pass "doc-maintainer.md routes cross-owner edits to hand-off items"
else
  fail "doc-maintainer.md routes cross-owner edits to hand-off items"
fi

# --- Lifecycle parallel groups respect Read-first --------------------------
# "+ X + Y" in the Lifecycle block claims X and Y can dispatch in the same wave.
# That claim is false whenever one of them must READ an artifact the other one
# writes: the reader then gets a missing or half-written file. Found by a live
# run — the flowchart expert reported architecture.md "missing" precisely
# because the two were dispatched in the same parallel group.
roster_artifact() { # $1 = role file basename -> its primary docs/team artifact
  grep "roles/$1" "$SKILL_MD" | grep -oE 'docs/team/[A-Za-z0-9.*_/-]+' | head -1
}
role_by_lifecycle_name() {
  case "$1" in
    "Project manager") echo project-manager.md ;;
    "Finisher") echo finisher.md ;;
    "Doc maintainer") echo doc-maintainer.md ;;
    "Daily log") echo daily-log.md ;;
    "Errors-and-fixes") echo errors-and-fixes.md ;;
    "Architecture") echo architecture-expert.md ;;
    "UI/UX") echo ui-ux-expert.md ;;
    "Brainstormer/validator") echo brainstormer-validator.md ;;
    "Flowchart") echo flowchart-expert.md ;;
    "Research expert") echo research-expert.md ;;
    "Tech expert") echo tech-expert.md ;;
    *) echo "" ;;
  esac
}
read_first_block() { # $1 = role file -> the Read-first list inside its template
  awk '/^## Prompt template/{in_t=1; next}
       in_t && /^```/{ if (!in_fence) {in_fence=1; next} else {exit} }
       in_fence{print}' "$ROLES_DIR/$1" \
    | sed -n '/^Read first (mandatory/,/^$/p'
}
# collect parallel groups: " + "-separated role names per Lifecycle line,
# with parenthetical annotations removed so "(options + evidence)" is not read
# as a parallel marker
lc_groups="$(awk '/^## Lifecycle/{in_lc=1} in_lc && /^```/{c++; next}
                  c==1{print} in_lc && c==2{exit}' "$SKILL_MD" \
  | sed 's/([^)]*)//g' \
  | grep '+' \
  | sed 's/^[a-z-]*: *//')"
group_violations=0
while IFS= read -r line; do
  [ -z "$(printf '%s' "$line" | tr -d ' ')" ] && continue
  printf '%s\n' "$line" | grep -q '+' || continue
  members="$(printf '%s' "$line" | tr '+' '\n' | sed 's/^ *//; s/ *$//; s/[0-9]*: *//' | grep .)"
  while IFS= read -r a; do
    fa="$(role_by_lifecycle_name "$a")"; [ -z "$fa" ] && continue
    while IFS= read -r b; do
      [ "$a" = "$b" ] && continue
      fb="$(role_by_lifecycle_name "$b")"; [ -z "$fb" ] && continue
      art="$(roster_artifact "$fb")"; [ -z "$art" ] && continue
      if read_first_block "$fa" | grep -qF -- "$art"; then
        fail "same wave, but $a reads $art (written by $b)"
        group_violations=$((group_violations + 1))
      fi
    done <<< "$members"
  done <<< "$members"
done <<< "$lc_groups"
if [ "$group_violations" -eq 0 ]; then
  pass "every Lifecycle parallel group is Read-first-independent"
fi

# --- no role declares write access to another role's artifact -------------
# Single ownership is what makes parallel dispatch safe; a role whose template
# claims someone else's file re-introduces the clobber. Found by a live run: the
# doc maintainer's docs/** wildcard let it edit the Finisher's goals.md and the
# validator's report, silently reverting records those roles had verified.
cross_owner_writes=""
for role_file in "$ROLES_DIR"/*.md; do
  name="$(basename "$role_file")"
  own="$(roster_artifact "$name")"
  targets="$(grep -iE '^(write|update)' "$role_file" \
    | grep -oE 'docs/team/[A-Za-z0-9.*_/-]+' | sort -u || true)"
  other_role_art="$(grep -E '^\| [0-9]+ \|' "$SKILL_MD" \
    | grep -oE 'docs/team/[A-Za-z0-9.*_/-]+' | sort -u)"
  while IFS= read -r t; do
    [ -z "$t" ] && continue
    # an empty $own is the docs/** wildcard row: it prefixes nothing, so it must
    # not be allowed to swallow every target the role declares
    if [ -n "$own" ] && [ "${t#"$own"}" != "$t" ]; then
      continue                                 # its own artifact and subpaths
    elif [ "$t" = "docs/team/dispatch-log.md" ]; then
      cross_owner_writes="$cross_owner_writes$name -> $t (coordinator-owned)"
    elif printf '%s\n' "$other_role_art" | grep -qxF -- "$t"; then
      cross_owner_writes="$cross_owner_writes$name -> $t (owned by another row)"
    fi
  done <<< "$targets"
done
if [ -z "$cross_owner_writes" ]; then
  pass "no role template claims write access to another owner's artifact"
else
  fail "no role template claims write access to another owner's artifact"
  printf '%s\n' "$cross_owner_writes" | sed 's/^/    /'
fi

# --- sibling skill refs use the superpowers: prefix -----------------------
bare_refs="$(grep -rnoE '`(brainstorming|dispatching-parallel-agents|verification-before-completion|systematic-debugging|test-driven-development|writing-plans|executing-plans|subagent-driven-development|requesting-code-review|finishing-a-development-branch|using-git-worktrees|writing-skills)`' "$SKILL_DIR" || true)"
if [ -z "$bare_refs" ]; then
  pass "cross-skill refs use the superpowers: prefix form"
else
  fail "cross-skill refs use the superpowers: prefix form"
  printf '%s\n' "$bare_refs" | head -10 | sed 's/^/    /'
fi
if grep -rq 'superpowers:verification-before-completion' "$SKILL_DIR"; then
  pass "at least one sibling ref present and prefixed"
else
  fail "at least one sibling ref present and prefixed"
fi

# --- no machine-specific paths or names -----------------------------------
leaks="$(grep -rn -E '/Users/|/home/' "$SKILL_DIR" "$SCRIPT_DIR" \
  --exclude=test-skill-structure.sh 2>/dev/null || true)"
if [ -z "$leaks" ]; then
  pass "no machine-specific paths in shipped files"
else
  fail "no machine-specific paths in shipped files"
  printf '%s\n' "$leaks" | head -10 | sed 's/^/    /'
fi

echo "  ------"
echo "  [PASS] $PASSES  [FAIL] $FAILURES"
[ "$FAILURES" -eq 0 ] || exit 1
