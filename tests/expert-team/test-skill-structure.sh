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
