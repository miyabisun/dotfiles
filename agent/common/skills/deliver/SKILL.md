---
name: deliver
description: >-
  Deliver a requested change as a verified local commit without requiring the
  user to babysit implementation and review turns. Use only when the user
  explicitly invokes deliver or explicitly asks to finish a task through a
  verified commit. Optimize for outcomes and evidence rather than a fixed
  phase sequence. Never push, deploy, or release.
---

# deliver

Turn a request into a **verified local commit**. Choose the smallest reliable
route. Phases and subagents are tools, not completion criteria.

## Inputs

| Arg | Required | Meaning |
|---|---|---|
| `task` | yes | Requested outcome |
| `constraints` | no | Additional scope, compatibility, or validation constraints |

Free text alone means `task`.

Invoking this skill explicitly authorizes one new local commit containing only
the delivered task. It never authorizes push, merge, deploy, release, amend,
history rewriting, or discarding working-tree changes.

## Definition of delivered

Do not commit until all applicable statements are true:

1. The observable result satisfies the request and repository conventions.
2. Acceptance criteria are concrete enough to return pass/fail.
3. Relevant behavior, type, test, and build checks exist and have succeeded.
4. Behavior changes have meaningful regression coverage where practical.
5. Tests exercise production behavior rather than restating the implementation.
6. Every applicable acceptance criterion has recorded evidence.
7. No unresolved blocking review, QA, security, test, build, formatter, or lint finding remains.
8. The diff is task-scoped and does not absorb unrelated pre-existing work.
9. A fresh independent `formatter` receipt accounts for every eligible file and
   records successful applicable checks or a justified `not_applicable` result.

Documentation-only or metadata-only changes do not require invented product
tests. Validate their syntax, links, generated output, or consumer behavior as
appropriate and explain why broader tests are not applicable.

Treat large-scale simplification or refactoring as its own `deliver` task with
explicit scope, behavior-preservation criteria, benchmarks, and regression
checks; never append it as routine cleanup to an unrelated delivery.

## Operating model

Maintain a compact delivery ledger in the parent context:

```json
{
  "criteria": [{"requirement": "...", "evidence": "pending", "pass": false}],
  "checks": [{"command": "...", "result": "pending"}],
  "risk": "low|standard|high",
  "open_issues": [],
  "scope": ["paths or components"],
  "formatter": {"result": "pending", "applicability": "pending", "eligible_files": []}
}
```

Update it from actual tool and agent results. Never fabricate a command result,
review approval, browser measurement, or Red/Green observation.

### 1. Establish the contract

Read the repository and translate the request into observable acceptance
criteria, scope, verification commands, and important failure modes.

- Reuse explicit user criteria unchanged unless they conflict or cannot be tested.
- Include concrete input/output examples when they remove ambiguity.
- Inspect referenced files, fields, APIs, and scripts before assuming they exist.
- If materially different outcomes remain plausible, stop and ask a concise
  question. Do not spend agents or tokens implementing guesses.
- For non-trivial behavior, prefer a failing regression test before the fix.
- A separate strategist is optional; use it only when the contract itself is
  difficult, cross-cutting, UI-heavy, externally integrated, or high risk.

### 2. Choose proportional execution

Classify by the highest applicable risk:

| Risk | Typical work | Minimum route |
|---|---|---|
| `low` | docs, comments, narrow config, mechanical rename | implement → focused validation → diff self-review → `formatter` → commit |
| `standard` | ordinary bug fix, feature, refactor, multi-file behavior | implement → relevant checks → independent `rev` → `formatter` → commit |
| `high` | auth, permissions, secrets, destructive data, migration, payments, concurrency, public compatibility | contract specialist as useful → implement → full behavior checks → independent `rev` + `sec` → `formatter` → commit |

UI behavior additionally requires `ui-checker` evidence for observable visual
and interaction criteria. Use `designer` only when visual/product decisions are
actually unresolved.

The parent may implement directly or delegate to `dev`. Delegate when isolation,
parallel exploration, context preservation, or specialist instructions improve
the result. Do not spawn agents merely to satisfy a named phase.

Runtime role locations:

- Claude Code: `~/.claude/agents/<role>.md`
- Cursor: `~/.cursor/agents/<role>.md`
- Codex: configured `agents.<role>` backed by `~/.agents/agents/<role>.md`

### 3. Implement and close the evidence loop

Implement the smallest coherent change that can satisfy the ledger.

After each substantive attempt:

1. Run the narrowest useful check for quick feedback.
2. Fix failures caused by the task.
3. Run the complete applicable behavior, type, test, and build checks before review.
4. Exercise every acceptance criterion and attach the observed result.
5. Inspect `git diff` and `git status` for scope contamination.

Use repository-native commands discovered from manifests, CI, `AGENTS.md`, and
project documentation. Do not substitute a made-up smoke test for an existing
authoritative suite. If an authoritative check cannot run, exhaust safe local
alternatives, then stop without committing and report the exact blocker.


### 4. Review only where it buys confidence

For `standard` and `high` work, give `rev` the original request, acceptance
criteria, relevant diff, and executed checks. The implementer must not act as
the independent approver.

The review result must be structured:

```json
{"approved": true, "issues": [], "summary": "..."}
```

Blocking issues must include target, harm, and a concrete fix. Send the fixed
list to `debugger` or fix it in the parent, rerun affected checks, and use
`inspector` to verify list closure. Request a fresh full `rev` only when fixes
materially changed design or behavior beyond that list.

Additional gates:

- Complex/high-risk contract: when `strategist` creates or changes the contract
  or tests, require `strategy-rev.approved=true` before treating that evidence
  design as authoritative.
- UI: every criterion has `ui-checker.evidence`; missing evidence is failure.
- Security-sensitive: `sec.approved=true` and no Critical/High issue.

Do not impose a fixed retry count while new evidence shows progress. Stop when
the same blocking condition repeats and no safe in-scope action can advance it.

### 5. Normalize and lint through one accountable gate

After implementation, fixes, and required semantic reviews are complete, invoke
the independent `formatter` immediately before `committer`. The parent, `dev`,
and `rev` do not substitute their own formatter/linter claims for this receipt.

Give `formatter` the exact files eligible for commit. It must:

1. classify every eligible file as implementation source or excluded;
2. exclude documentation, example/sample/template configuration, generated,
   vendor, third-party, lockfiles, and unsupported configuration by default;
3. use formatter check/diff mode to prove a write command can only change
   classified implementation source before running it;
4. run formatter checks and linters only when their actual scan scope excludes
   documentation, examples, and non-eligible files; and
5. return exact commands/results plus every classification and reason.

Documentation includes `README*`, `CHANGELOG*`, `LICENSE*`, `docs/**`, and
`**/*.md`. Example configuration includes `*.example`, `*.sample`, `*.template`,
and `.env.example`. Do not introduce tooling merely to format or lint these files.
Only an explicit user request for documentation formatting overrides this rule.

If every eligible file is excluded, accept an independent
`applicability=not_applicable` receipt that accounts for every path. If
implementation source is applicable but authoritative tooling is absent, stop
without committing; tooling bootstrap requires a separate explicitly authorized
task.

A lint violation is implementation work. `formatter` must not auto-fix it; return
it to `dev` (or the parent implementation path), rerun affected checks and review,
then invoke `formatter` again. A formatter or linter failure blocks delivery even
when it predates the task or is outside the changed files. If resolving it exceeds
the authorized scope, stop without committing and report the required cleanup.

Pass the receipt to `committer` without replacing it with a parent-authored
summary. Missing classifications, applicable results, exclusion reasons, eligible
files, or independent formatter approval block the commit.

### 6. Commit through the gate

Before invoking `committer`, re-read the ledger and verify:

```text
all criteria pass
AND all checks pass
AND all required independent gates approve
AND open_issues is empty
AND diff is task-scoped
AND formatter.approved is true
AND formatter receipt accounts for every eligible file
```

Give `committer` the task, scope, evidence summary, and exact files eligible for
staging together with the formatter receipt. The explicit invocation of `deliver`
is the commit authorization.
Create exactly one new Conventional Commit. Never push.

If unrelated changes overlap files that must be committed and safe partial
staging cannot isolate the task with confidence, stop and ask the user instead
of committing mixed work.

## Output

On success, return a concise delivery receipt:

```json
{
  "delivered": true,
  "commit": "<hash> <subject>",
  "criteria": [{"requirement": "...", "evidence": "...", "pass": true}],
  "checks": [{"command": "...", "result": "pass"}],
  "reviews": [{"gate": "rev|ui|sec", "result": "approved|not-applicable"}],
  "formatter": {"result": "approved", "applicability": "checked|not_applicable"}
}
```

On failure, do not commit. Return `delivered=false`, completed evidence, open
issues, and the exact user decision or external change needed.

## Hard rules

- Optimize for verified outcomes, not phase attendance.
- Never claim completion from an agent's prose alone; require evidence.
- Never weaken, delete, skip, or rewrite valid tests merely to turn them green.
- Never invoke `committer` without an independent `formatter` receipt accounting
  for every eligible file and every applicable check.
- Never use destructive working-tree commands (`checkout`, `restore`, destructive
  `reset`, `clean`, or `stash`) to manage agent work.
- Preserve unrelated user changes.
- Never commit secrets or environment files.
- Never push, merge, deploy, or release.
