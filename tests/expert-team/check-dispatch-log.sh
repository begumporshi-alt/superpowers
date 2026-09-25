#!/usr/bin/env bash
# Machine-check a project's dispatch log against the coordinator rules in
# SKILL.md. test-skill-structure.sh can only prove the RULE is worded; this
# proves a RUN obeyed it — the only form those rules were written to take.
#
#   usage: check-dispatch-log.sh <path/to/docs/team/dispatch-log.md> [-d DATE] [-r N] [-a TEXT]
#
# -d restricts the check to one session's lines (a log accumulates across runs
#    and the re-dispatch allowance is a per-run budget); default: every line.
# -r re-dispatch allowance for the selected set (default 2, per SKILL.md).
# -a scopes to the lines AFTER the first line containing TEXT — how you point it
#    at one run when a project did two on the same date.
set -u

LOG="${1:-}"
if [ -z "$LOG" ]; then
  printf 'usage: %s <dispatch-log.md> [-d YYYY-MM-DD] [-r N] [-a TEXT]\n' "$0" >&2
  exit 2
fi
shift

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_MD="$SCRIPT_DIR/../../skills/expert-team/SKILL.md"
DATE_FILTER=""
ANCHOR=""
ALLOWANCE=2
while [ "$#" -gt 0 ]; do
  case "$1" in
    -d) DATE_FILTER="${2:-}"; shift 2 ;;
    -r) ALLOWANCE="${2:-}"; shift 2 ;;
    -a) ANCHOR="${2:-}"; shift 2 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
done

PASSES=0
FAILURES=0
pass() { printf '  [PASS] %s\n' "$1"; PASSES=$((PASSES + 1)); }
fail() { printf '  [FAIL] %s\n' "$1"; FAILURES=$((FAILURES + 1)); }

if [ ! -f "$LOG" ]; then
  fail "dispatch log exists ($LOG)"
  printf '  ------\n  [PASS] %d  [FAIL] %d\n' "$PASSES" "$FAILURES"
  exit 1
fi
pass "dispatch log exists"
if [ ! -f "$SKILL_MD" ]; then
  fail "SKILL.md roster resolvable for the role-name check"
  printf '  ------\n  [PASS] %d  [FAIL] %d\n' "$PASSES" "$FAILURES"
  exit 1
fi

# Roster role names, taken from the roster table's `roles/<name>.md` cells so a
# renamed role cannot pass here and drift. The coordinator writes its own rows
# (Decision relays, log bookkeeping), so it is a legal name absent from the roster.
roster_names="$(grep -oE 'roles/[A-Za-z0-9._-]*\.md' "$SKILL_MD" \
  | sed 's|^roles/||; s|\.md$||' | sort -u)"
roster_names="$(printf '%s\ncoordinator\n' "$roster_names" | sort -u)"

if [ -n "$DATE_FILTER" ]; then
  lines="$(grep -E "^$DATE_FILTER \|" "$LOG" || true)"
else
  lines="$(grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2} \|' "$LOG" || true)"
fi
if [ -n "$ANCHOR" ]; then
  anchor_at="$(printf '%s\n' "$lines" | grep -nF -- "$ANCHOR" | head -1 | cut -d: -f1)"
  if [ -z "$anchor_at" ]; then
    fail "anchor text not found in the log: $ANCHOR"
    printf '  ------\n  [PASS] %d  [FAIL] %d\n' "$PASSES" "$FAILURES"
    exit 1
  fi
  lines="$(printf '%s\n' "$lines" | tail -n +"$((anchor_at + 1))")"
fi

if [ -z "$lines" ]; then
  fail "at least one dated dispatch line (filter: ${DATE_FILTER:-all}${ANCHOR:+ after: $ANCHOR})"
  printf '  ------\n  [PASS] %d  [FAIL] %d\n' "$PASSES" "$FAILURES"
  exit 1
fi
n_total="$(printf '%s\n' "$lines" | grep -c .)"
scope=""
[ -n "$DATE_FILTER" ] && scope=" date=$DATE_FILTER"
[ -n "$ANCHOR" ] && scope="$scope after \"$ANCHOR\""
pass "$n_total dated dispatch line(s) in scope${scope}"

col() { awk -F'|' -v n="$1" '{print $n}' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'; }

# --- every line is well-formed (5 declared fields) ------------------------
malformed="$(printf '%s\n' "$lines" | awk -F'|' 'NF != 5 {print "    line: " $0}' || true)"
if [ -z "$malformed" ]; then
  pass "every line has the 5 declared fields (date|expert|task|artifact|outcome)"
else
  fail "every line has the 5 declared fields"
  printf '%s\n' "$malformed"
fi

# --- expert column names a roster role -----------------------------------
bad_roles=""
while IFS= read -r role; do
  [ -z "$role" ] && continue
  printf '%s\n' "$roster_names" | grep -qxF -- "$role" || bad_roles="$bad_roles $role"
done <<EOF
$(printf '%s\n' "$lines" | col 2 | sort -u)
EOF
if [ -z "$bad_roles" ]; then
  pass "every expert column names a roster role (or the coordinator)"
else
  fail "every expert column names a roster role (unknown:$bad_roles)"
  printf '    an unrecognised name is work no roster row can be checked against\n'
fi

# --- nothing still claims to be running ----------------------------------
pending_rows="$(printf '%s\n' "$lines" | awk -F'|' '{o=$5; gsub(/^[ \t]+/,"",o); gsub(/[ \t]+$/,"",o);
              if (o=="pending" || o ~ /^pending($| —|- )/) print "    " $0}' || true)"
if [ -z "$pending_rows" ]; then
  pass "no line still reads pending — every dispatch has a recorded outcome"
else
  fail "one or more lines still read pending (outcome never recorded)"
  printf '%s\n' "$pending_rows"
fi

# --- rejected/failed/cancelled must carry a reason -----------------------
bare_rows="$(printf '%s\n' "$lines" | awk -F'|' '{o=$5; gsub(/^[ \t]+/,"",o); gsub(/[ \t]+$/,"",o);
              if (o=="rejected" || o=="failed" || o=="cancelled") print "    " $0}' || true)"
if [ -z "$bare_rows" ]; then
  pass "every rejected/failed/cancelled outcome states a reason"
else
  fail "a rejected/failed/cancelled outcome states no reason"
  printf '%s\n' "$bare_rows"
fi

# --- re-dispatch discipline (SKILL.md step 1 "Budget re-dispatches") ----
# Coordinator rows are bookkeeping, not expert runs, so they sit outside the
# budget entirely.
dispatch_lines="$(printf '%s\n' "$lines" | awk -F'|' '{r=$2; gsub(/^[ \t]+/,"",r); gsub(/[ \t]+$/,"",r);
                     if (r != "coordinator") print}' || true)"
n_dispatches="$(printf '%s\n' "$dispatch_lines" | grep -c . || true)"
roles_used="$(printf '%s\n' "$dispatch_lines" | col 2 | sort -u | grep -c . || true)"

unmarked=""
while IFS= read -r role; do
  [ -z "$role" ] && continue
  role_lines="$(printf '%s\n' "$dispatch_lines" | awk -F'|' -v r="$role" \
    '{c=$2; gsub(/^[ \t]+/,"",c); gsub(/[ \t]+$/,"",c); if (c==r) print}' || true)"
  cnt="$(printf '%s\n' "$role_lines" | grep -c . || true)"
  [ "$cnt" -le 1 ] && continue
  extras="$(printf '%s\n' "$role_lines" | tail -n +2)"
  marked="$(printf '%s\n' "$extras" | grep -ci 're-dispatch' || true)"
  missing=$((cnt - 1 - marked))
  if [ "$missing" -gt 0 ]; then
    unmarked="$unmarked $role(${missing})"
  fi
done <<EOF
$(printf '%s\n' "$dispatch_lines" | col 2 | sort -u)
EOF
if [ -z "$unmarked" ]; then
  pass "every repeat dispatch carries a re-dispatch marker naming what changed"
else
  fail "repeat dispatch(es) with no re-dispatch marker:$unmarked"
fi

n_redispatches=$((n_dispatches - roles_used))
if [ "$n_redispatches" -le "$ALLOWANCE" ]; then
  pass "re-dispatch count $n_redispatches within the allowance of $ALLOWANCE"
else
  fail "re-dispatch count $n_redispatches exceeds the allowance of $ALLOWANCE"
  printf '    past the cap SKILL.md says report the open item — chasing it is the run cost, not the win\n'
fi

budget=$((roles_used + 2))
if [ "$n_dispatches" -le "$budget" ]; then
  pass "dispatch count $n_dispatches ≤ roles($roles_used) + 2 = $budget — Verification item 8"
else
  fail "dispatch count $n_dispatches exceeds roles($roles_used) + 2 = $budget"
fi

printf '  ------\n  [PASS] %d  [FAIL] %d\n' "$PASSES" "$FAILURES"
[ "$FAILURES" -eq 0 ] || exit 1
