# New-project intake

Coordinator-run. No expert can do this: a subagent cannot interview the human, and
it inherits no session context. This is the third file you write yourself, next to
`docs/team/dispatch-log.md` and the **Decision:** lines.

## When

At kickoff, when the project has no `docs/team/brief.md`. If `NOTES.md` or
`README.md` exists, read it first and ask only what it leaves open. If
`brief.md` exists, skip intake and dispatch.

## One round, five questions

Ask all five in a single message. Each carries a default, so "just go" is a valid
answer — never ask a follow-up, and never re-ask a skipped one.

| # | Ask | Default if skipped |
|---|-----|--------------------|
| 1 | What is this, in two sentences? | their words, verbatim |
| 2 | Who uses it, and what do they do with it minute to minute? | just you |
| 3 | What must it NOT become? | no accounts, no network, no persistence |
| 4 | What will you personally check to call it working? | you use it for a day |
| 5 | Hard constraints — file count, dependencies, offline, look and feel? | none stated |

## Write it

Create `docs/team/` and write `docs/team/brief.md`, dated, one screen:

```
## YYYY-MM-DD — <project name>
What / Who / Not going / Done looks like / Constraints
Open questions: <defaults the human never confirmed, each marked [default]>
```

Marking `[default]` matters: it is how a later expert sees which facts no human
verified, instead of treating every line as a stated requirement.

## Then dispatch — don't ask permission

Same response: Finisher (`goals.md`) and Project manager (`board.md`), with the
brief as their **Read first** context. Tell the human the run started, and hand
them the Finisher's ambiguity list as the next thing they touch.

The cost is honest: five questions here is the cheapest input the whole run gets.
A kickoff built on a vaguer brief re-dispatches later, and re-dispatches are
budgeted.
