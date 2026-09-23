---
name: expert-team
description: Use when a task needs specialized role oversight - project management, documentation, logs, error tracking, architecture, UI/UX, feature validation, flowcharts, or final-goal acceptance. Dispatches focused subagents as an expert team, one per concern.
---

# Expert Team

## Overview

**Core principle:** One expert per concern, dispatched as a focused subagent with a
self-contained prompt, producing a persistent artifact that outlives the session.

You are the coordinator. You do not role-play the experts yourself for substantive
work — you dispatch them (via the `dispatching-parallel-agents` pattern; on Cline use
`spawn_agent`) so each gets isolated context and your own context stays free for
coordination. The main agent only writes trivial artifacts directly (e.g. appending
today's one-line log entry) when dispatching would cost more than the work itself.

Each expert's charter, dispatch prompt template, and output contract live in `roles/`.

## Roster

| # | Expert | File | Artifact | Dispatch when |
|---|--------|------|----------|---------------|
| 1 | Project manager | `roles/project-manager.md` | `docs/team/board.md` | Project start; scope change; status checkpoints |
| 2 | Doc maintainer | `roles/doc-maintainer.md` | Updates `docs/**` | Before declaring any feature done |
| 3 | Daily log maintainer | `roles/daily-log.md` | `docs/team/daily-log.md` | End of each work session / milestone |
| 4 | Errors & fixes | `roles/errors-and-fixes.md` | `docs/team/errors-and-fixes.md` | Immediately after any non-trivial error is fixed |
| 5 | Architecture expert | `roles/architecture-expert.md` | `docs/team/architecture.md` + specs | Design decisions; structural changes |
| 6 | UI/UX expert | `roles/ui-ux-expert.md` | `docs/team/ui-ux-reviews.md` | Any user-facing UI change; review checkpoints |
| 7 | Brainstormer & feature validator | `roles/brainstormer-validator.md` | `docs/team/validation-reports.md` | Before planning; when validating existing features |
| 8 | Flowchart expert | `roles/flowchart-expert.md` | `docs/team/diagrams/*.dot` | Explaining or designing any multi-step flow |
| 9 | Finisher | `roles/finisher.md` | `docs/team/goals.md` | Project kickoff (set objectives) + completion (acceptance gate) |
| 10 | Tech expert | `roles/tech-expert.md` | `docs/team/tech-review.md` | Post-brainstorm stack recommendation; any new non-trivial dependency; tech review checkpoint |

## Dispatch Protocol

1. **Select the expert(s).** Use the roster table above. If work spans multiple
   experts and their tasks are independent, dispatch them **in parallel** (multiple
   dispatch calls in one response). If they share state (e.g. both editing
   `board.md`), dispatch sequentially.
2. **Build a self-contained prompt.** Start from the role file's prompt template.
   The subagent inherits NO session context — give it everything: project path
   (absolute), goal, relevant file paths, constraints, and the exact output format
   it must return.
3. **Announce:** "Dispatching <expert> to <purpose>."
4. **Retry transient failures once.** If a dispatch call fails with an
   infrastructure error (auth, network, tool unavailable) and produced no
   artifact, re-dispatch the same prompt once. If it fails again, report the
   failure to the human honestly — never silently role-play the expert's
   substantive work yourself to cover for it.
5. **Review and integrate.** Read each returned summary, verify its artifact was
   actually written at the expected path, check for conflicts between parallel
   experts' outputs, and correct anything wrong before moving on.

### Prompt template skeleton

```text
You are the <role name> for this project.

Project root: <absolute path>
Today's date: <YYYY-MM-DD — today's actual date; use it for every dated heading/entry>
Goal: <what this dispatch must accomplish>
Context: <only what the expert needs — files to read, recent changes, the feature/bug in question>

Constraints:
- Stay inside your charter (see role duties below)
- Write your artifact to <absolute artifact path> (append, don't clobber history)
- Do NOT modify source code

Your charter:
<paste charter section from the role file>

Return: <output contract from the role file>
```

## Artifact Conventions

- Root: `<project>/docs/team/`. Create directories on first use.
- Logs (`daily-log`, `errors-and-fixes`) are **append-only** — new dated entries at
  the top of their section, never rewrite history.
- Reports (`ui-ux-reviews`, `validation-reports`) are dated:
  `## YYYY-MM-DD — <topic>`.
- **Dates are explicit, never guessed:** every dispatch prompt carries today's
  real date (see prompt template). A subagent that invents a date (including
  tomorrow's) corrupts cross-artifact consistency — check dates during
  step 5 review.
- Diagrams are Graphviz `.dot` (Superpowers' native format) in `docs/team/diagrams/`.
- Artifacts must be truthful: no aspirational status. "Done" means verified done.

## Lifecycle

```
kickoff:     Finisher (goals.md) + Project manager (board.md)
design:      Brainstormer/validator → Tech expert (stack) → Architecture + UI/UX + Flowchart (parallel)
build:       Errors-and-fixes after each fix; Daily log at session end
pre-done:    Project manager (board refresh) → Doc maintainer → Finisher (acceptance check against goals.md)
```

The Finisher's acceptance check runs **after** `verification-before-completion` has
passed — it answers "did we build the right thing," not "does the code work."

## Common Mistakes

**❌ Role-playing instead of dispatching:** Acting as the architecture expert
yourself burns context and loses the fresh-eyes benefit. Dispatch.
**❌ Leaking context:** Giving a subagent "read the conversation" instructions —
it can't. Paste what it needs.
**❌ Two experts, one file:** Parallel dispatch to experts that write the same
artifact will clobber each other. Sequence them.
**❌ Dispatching trivia:** Appending one log line does not need a subagent. Write it.
**❌ Skipping the Finisher:** Tests green ≠ objective met. The Finisher gates the
objective; `verification-before-completion` gates the code.

## Verification

Before declaring team work complete:
1. Every dispatched expert returned a summary — no silent failures.
2. Expected artifacts exist at their paths with today's entries.
3. No two artifacts contradict each other (dates, statuses, decisions).
