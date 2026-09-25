# Lessons — expert-team write-back

The channel through which a run teaches the skill. `SKILL.md` is at its word
budget, so a lesson starts here; only a lesson that must change behaviour on
every dispatch gets promoted into `SKILL.md` or a role file, and when it does the
entry below keeps a pointer to where the rule now lives.

## How to use it

- **Before dispatching:** read this file. A lesson about the role you are about to
  use belongs in that role's prompt template constraints, pasted in.
- **After a run:** append one dated entry per process defect the run actually
  revealed — not per error in the project's code, which goes to
  `docs/team/errors-and-fixes.md`.
- **Promote, don't duplicate.** When the lesson becomes a standing rule, put the
  rule in `SKILL.md` or the role file, then mark this entry `Promoted →` with its
  location. Never leave the same rule worded two ways; the next coordinator will
  reconcile them badly.
- An entry without evidence of a real run is a theory. Theories do not get
  written here.

## Entry format

```
## YYYY-MM-DD — <defect in one clause>
Run: <which project/phase produced this>
Observed: <what actually happened, with the artifact or line that shows it>
Cost: <what it took to notice — another dispatch, a re-run, a human question>
Rule: <the change, and where it landed>
Status: standing | Promoted → <file/section>
```

## Entries

## 2026-09-25 — kickoff wave was declared parallel but its two roles read each other
Run: size-report validation, kickoff phase
Observed: Finisher reads `board.md` and Project manager reads `goals.md`, so the
  declared "kickoff: parallel" group made each reader find the other's file
  missing. Both reported the absence rather than inventing contents.
Cost: one wasted wave; discovered only because the roles reported honestly.
Rule: `kickoff: Finisher → Project manager`.
Status: Promoted → SKILL.md, Lifecycle

## 2026-09-25 — a flowchart was dispatched in the same wave as the architecture it reads
Run: size-report validation, design phase
Observed: the flowchart expert returned `architecture.md` MISSING. It had been put
  in the same parallel group as the architecture expert, its only author.
Cost: a re-dispatch of the flowchart expert.
Rule: "Sequence any pair where one role's **Read first** names an artifact the
  other writes in the same wave." Now machine-checked: a Lifecycle parallel group
  whose members' Read-first lists name each other's artifacts fails the suite.
Status: Promoted → SKILL.md, Dispatch Protocol step 1 + test derived check

## 2026-09-25 — coordinator pre-wrote pending dispatch lines
Run: size-report validation, build phase
Observed: `dispatch-log.md` gained `pending` lines for three experts before any of
  them ran; the project manager then read that log and put all three on the board
  as in-progress work that had not started.
Cost: a board correction dispatch, and the coordinator's own record became
  untrustworthy for the rest of the run.
Rule: the log line is written in the same action as the dispatch, never in
  advance. Verification item 1 now checks for a pre-written `pending`.
Status: Promoted → SKILL.md, Dispatch Protocol step 3 + Verification item 1

## 2026-09-25 — a human verdict landed in only one of the artifacts that asked for it
Run: size-report validation, UI/UX decision
Observed: three verdicts were elicited; only the output-shape one was relayed,
  into `ui-ux-reviews.md`. `goals.md` still read "pending human
  confirmation", so the project manager filed a blocker, and the Finisher refused
  to write a Decision line it could not find evidence for.
Cost: two Finisher dispatches plus a project-manager blocker to fix one omission.
Rule: relay each verdict into every artifact that asked, in the same action it
  arrives. The gate's refusal was correct behaviour, not friction.
Status: Promoted → SKILL.md, Dispatch Protocol step 5

## 2026-09-25 — the docs wildcard let one role revert another role's verified record
Run: size-report validation, pre-done phase
Observed: the doc maintainer's target is `docs/**`, which contains every single-owner
  artifact. It edited files owned by the Finisher and the validator, whose records
  had already been verified, and the ownership-uniqueness test could not see the
  overlap because it only compares exact declared paths.
Cost: a reconciliation dispatch to each owning role.
Rule: the doc maintainer's file now names the exclusions and returns numbered
  hand-off items instead of editing. Machine-checked: a role template that
  declares write access to another row's artifact fails — including the empty
  path that the `docs/**` row produces, which prefix-matched everything and made
  the first version of that check blind.
Status: Promoted → roles/doc-maintainer.md (Ownership carve-out) + test check

## 2026-09-25 — clean-looking output hid the two worst defects
Run: size-report validation, acceptance gate
Observed: a directory the tool could not read, and a symlink passed as the
  directory argument, each printed a valid CSV header, reported the directory as
  empty, and exited 0. The crash in the same script was fixed the hour it was
  found; these survived every doc pass and stopped the acceptance verdict at NOT
  DONE.
Cost: the acceptance gate had to be run by a role with no stake in the earlier
  "done".
Rule: run the failure case, don't read the code about it. A structural check
  cannot catch a wrong answer that is well-formed.
Status: standing

## 2026-09-25 — an expert re-ran the coordinator's claims and two were wrong
Run: size-report validation, several waves
Observed: prompts asserted "every error is journaled" and "the three answers are in
  `ui-ux-reviews.md`". The journal had one entry and one of the three answers
  existed. Both experts reported the mismatch instead of adopting the claim.
Cost: none, because the roles read first and answered from files.
Rule: a coordinator prompt states what it believes and points at the evidence; it
  never states a result as a fact for the expert to accept.
Status: standing

## 2026-09-25 — a new invariant check passed while blind
Run: test suite for this skill
Observed: the cross-owner write check reported green against a deliberate
  violation, because the wildcard role's artifact path was empty and the prefix
  test accepted every target.
Cost: caught by mutation, before it could hide a real violation.
Rule: no structural check lands without breaking the invariant it guards and
  watching it go red.
Status: standing

## 2026-09-25 — validation scope outran the claim being tested
Run: this skill's own validation
Observed: a two-file fixture would have proven the read-first and dispatch-log
  rules. Instead a working CLI was built, which generated its own bug fixes and
  fourteen dispatches, several re-dispatching the same role to clean up after the
  coordinator.
Cost: two rounds of "what is happening" from outside the run, and a session far
  longer than the claim required.
Rule: state the single claim, pick the cheapest fixture that can falsify it, and
  cap re-dispatch at one pass per role — later findings get reported, not chased.
Status: Promoted (the cap) → SKILL.md, Dispatch Protocol step 1
  "Budget re-dispatches" + Verification item 8. The cheapest-fixture rule stays
  standing: no structural check can measure it

## 2026-09-25 — decisions carry dates, not IDs, so restating one costs a reconstruction
Run: size-report validation, pre-done phase
Observed: the board's T2 "verdict recorded" criterion was met only by reconstructing
  which rule governs row selection out of three files ("largest-first per
  architecture D4 + Option-E-era ui-ux decision trail"). Nothing names a decision, so
  every restatement re-derives it from prose.
Cost: a project-manager refresh and a Finisher correction pass over the same record.
Rule: give every human **Decision:** line a stable ID (`D-1`, `D-2`, …) in its
  canonical artifact, and have downstream files cite the ID, not the date. NOT YET
  IMPLEMENTED — recorded here so the idea does not die with the session.
Status: backlog → decision ledger, not yet in SKILL.md

## 2026-09-25 — the board was true for eleven minutes
Run: size-report validation, second session (decision ratification)
Observed: the Lifecycle puts the project manager first in the pre-done wave, so the
  refreshed board declared T7/T8 `todo` and quoted the diagram as still stale —
  while the flowchart and README fixes landed at 18:42 and 18:46, minutes after the
  board's own 18:33 write. Two roles then reported the contradiction rather than
  resolving it, because it was not their file.
Cost: one re-dispatch of the project manager to close out its own board.
Rule: a board that *reports on* work has to be written after that work. Kickoff
  build and end-of-run close-out are different dispatches of the same role; the
  Lifecycle's leading position belongs to the first one only.
Status: standing

## 2026-09-25 — a pre-code diagram was patched discrepancy-by-discrepancy and stayed wrong
Run: size-report validation, flowchart role, three dispatches in one day
Observed: `cli-run-flow.dot` was drawn before any source existed. Each later dispatch
  fixed exactly the item it was given — the OQ8 edge, then the missing mktemp node — and
  both left the drawn *order* of the validation gates untouched, so the file kept claiming
  `usageerr` was reached first after two "reconciled vs shipped code" passes. The third
  dispatch read the script end to end and found four ordering errors, including one nobody
  had reported.
Cost: three dispatches on one file where a structural re-read was the actual work; and the
  intermediate versions were confidently wrong, which is worse than an obviously stale one.
Rule: when an artifact's job is to describe shipped code, a dispatch re-derives the whole
  structure from the source in one pass — a hand-off naming one discrepancy is an item to
  *check while re-deriving*, not the scope of the run.
Status: standing
