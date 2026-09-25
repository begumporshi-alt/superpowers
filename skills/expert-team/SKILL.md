---
name: expert-team
description: Use when a task needs specialized role oversight - project management, documentation, daily and error logs, architecture, UI/UX, external research and comparative option analysis, technology selection, feature validation, flowcharts, or final-goal acceptance.
---

# Expert Team

## Overview

**Core principle:** One expert per concern, dispatched as a subagent with a
self-contained prompt, producing a persistent artifact that outlives the session.

**REQUIRED BACKGROUND:** You MUST understand
`superpowers:dispatching-parallel-agents` before using this skill — it defines
isolated, self-contained subagent context. On Cline, use
`spawn_agent`.

You are the coordinator. You do not role-play the experts — dispatch them, so each
gets isolated context and yours stays free. Charters, templates and dispatch
triggers live in `roles/`.

## Roster

| # | Expert | File | Artifact |
|---|--------|------|----------|
| 1 | Project manager | `roles/project-manager.md` | `docs/team/board.md` |
| 2 | Doc maintainer | `roles/doc-maintainer.md` | `docs/**` |
| 3 | Daily log maintainer | `roles/daily-log.md` | `docs/team/daily-log.md` |
| 4 | Errors & fixes | `roles/errors-and-fixes.md` | `docs/team/errors-and-fixes.md` |
| 5 | Architecture expert | `roles/architecture-expert.md` | `docs/team/architecture.md` + specs |
| 6 | UI/UX expert | `roles/ui-ux-expert.md` | `docs/team/ui-ux-reviews.md` + `docs/team/mocks/*.html` |
| 7 | Brainstormer & validator | `roles/brainstormer-validator.md` | `docs/team/validation-reports.md` |
| 8 | Flowchart expert | `roles/flowchart-expert.md` | `docs/team/diagrams/*.dot` + `docs/team/diagrams/INDEX.md` |
| 9 | Finisher | `roles/finisher.md` | `docs/team/goals.md` |
| 10 | Research expert | `roles/research-expert.md` | `docs/team/research.md` |
| 11 | Tech expert | `roles/tech-expert.md` | `docs/team/tech-review.md` |

## Dispatch Protocol

1. **Select the expert(s).** From the roster above. Each expert owns exactly one
   artifact and is its only writer, so independent tasks dispatch **in
   parallel** (multiple calls in one response). Sequence any pair whose
   **Read first** names an artifact the other writes in the same wave — the
   reader finds it missing (Research → Tech, Architecture → Flowchart).
   **Budget re-dispatches.** A role dispatched twice for one finding is a
   re-dispatch: it needs a `re-dispatch: <what changed>` log line, and two is a
   run's whole allowance. Past it, report the open item — a third pass usually
   cleans up the coordinator's hand-off, not the expert's work.
2. **Build a self-contained prompt.** Start from the role file's prompt template
   and keep its **Read first** block. It inherits NO session context: give it the
   absolute project path, goal, constraints, output format, and artifact paths.
3. **Announce and log.** Say "Dispatching <expert> to <purpose>," then append a
   line to `docs/team/dispatch-log.md`:
   `YYYY-MM-DD | <expert> | <task> | <artifact path> | pending`. Write that line in
   the same action as the dispatch, never in advance — a `pending` line claims work
   is already running. After review, replace `pending` with `accepted`,
   `rejected: <reason>`, or `failed: <reason>`.
4. **Retry transient failures once.** An infra error (auth, network, tool) with no
   artifact: re-dispatch once, then report honestly — never role-play the work.
5. **Review and integrate.** Verify each artifact exists at its path with
   today's date, resolve conflicts between parallel experts, correct what's wrong.
   **If a proposal offers options for a human decision (UI/UX mock options, a
   research shortlist), present them and wait for the choice** — never pick on the
   human's behalf. Then relay each answer into the artifact that asked, as a
   **Decision:** line, in the same action you received it. A verdict recorded in
   only one asking artifact is not recorded.
6. **Write back.** Read `LESSONS.md` before dispatching; paste any lesson about the
   role you are using into its prompt constraints. After a run exposes a process
   defect, append a dated entry. A lesson that must change behavior on every
   dispatch gets promoted into this file or the role file, leaving the pointer.

### Prompt template skeleton

Each role file carries the full template; slot order is fixed:
`You are the <role>` → `Project root` → `Today's date` (the real one) → `Goal` →
`Context` → **`Read first`** (the role's artifact paths) → `Constraints` →
`Your charter` → `Return`.

## Artifact Conventions

- Root: `<project>/docs/team/`. Create directories on first use.
- **One writer per file.** Each artifact belongs to one expert, and only that
  expert's dispatch writes it. Your exceptions: you own the append-only
  `docs/team/dispatch-log.md` (one line per dispatch), which makes "the
  architecture expert reviewed this" a checkable claim; and you append the
  **Decision:** line an artifact asked the human for. Everything else is
  parallel-safe.
- **Wildcards need naming.** The doc maintainer's target is `docs/**`, which
  overlaps other roles' files, so its dispatch names the exact files it may write.
  A change it needs in someone else's file becomes a numbered hand-off item for
  that role's next dispatch, never an edit.
- Logs (`daily-log`, `errors-and-fixes`) are **append-only** — new dated entries at
  the top of their section, never rewrite history.
- Reports (`ui-ux-reviews`, `validation-reports`) are dated:
  `## YYYY-MM-DD — <topic>`.
- **Dates are explicit, never guessed:** every dispatch prompt carries today's real
  date; an invented one corrupts cross-artifact consistency — check at step 5.
- Diagrams are Graphviz `.dot` in `docs/team/diagrams/`.
- Artifacts must be truthful: no aspirational status. "Done" means verified done.

## Lifecycle

```
kickoff:     Finisher (goals.md) → Project manager (board.md)
design:      Brainstormer/validator → Research expert (options + evidence) →
             Tech expert (adjudicates the shortlist) →
             Architecture + UI/UX (parallel) → Flowchart
build:       Errors-and-fixes after each fix; Daily log at session end
pre-done:    Project manager (board refresh) → Doc maintainer → Finisher (acceptance check against goals.md)
```

The Finisher's acceptance check runs **after** `superpowers:verification-before-completion`
has passed — "did we build the right thing," not "does the code work."

## Common Mistakes

**❌ Role-playing instead of dispatching:** Doing the architecture expert's work
yourself burns context and loses fresh eyes. Dispatch.
**❌ Trimming the Read-first list** because you think you know those artifacts:
that is how an expert re-decides something already settled.
**❌ Two experts, one file:** Parallel writes clobber the artifact; if two roles
want one file, the ownership split is wrong.
**❌ Dispatching trivia:** One log line doesn't need a subagent. Write it.
**❌ Skipping the Finisher:** Tests green ≠ objective met — it gates the objective,
`superpowers:verification-before-completion` gates the code.
**❌ Tech expert without a shortlist:** Adjudicating the two options already in
your head is confirmation, not a decision. Research first.
**❌ Accepting unsourced research:** Claims with no locator make a vibe report.
Reject and re-dispatch, or tag every claim `[unverified]` downstream.
**❌ Accepting generic UI:** A palette swap, an option with no named signature
element, or a mock never opened in a browser is default output, not design work.
Reject and re-dispatch with the direction axis named.

## Verification

Before declaring team work complete:
1. Every dispatched expert returned a summary and has an `accepted` line in
   `docs/team/dispatch-log.md` — no silent failures, nothing unverifiable, and no
   `pending` line written before its dispatch.
2. Expected artifacts exist at their paths with today's entries, including the
   secondary roster paths (`mocks/*.html`, `diagrams/INDEX.md`).
3. No two artifacts contradict each other (dates, statuses, decisions).
4. No option is still awaiting a human pick. Every "Option A/B/C" proposal has a
   recorded **Decision:** line, or it is an open blocker, not finished work.
5. Research findings used downstream carry locators; anything tagged
   `[unverified]` was either verified since or is explicitly out of the decision.
6. Hand-off items are closed in their owning role's artifact, or reported open.
7. Every process defect this run revealed has a `LESSONS.md` entry, or the run
   revealed none.
8. Dispatch count ≤ roles + 2, extras carrying `re-dispatch:` lines
   (`check-dispatch-log.sh`).
