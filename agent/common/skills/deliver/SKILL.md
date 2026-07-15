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

Invoking this skill explicitly authorizes one new local commit containing the
delivered task and bounded maintenance required to leave the affected code in
a verified repository-conformant state. It never authorizes push, merge,
deploy, release, amend, history rewriting, or discarding working-tree changes.

## Definition of delivered

Do not commit until all applicable statements are true:

1. The observable result satisfies the request and repository conventions.
2. Acceptance criteria are concrete enough to return pass/fail.
3. Relevant behavior, type, test, and build checks exist and have succeeded.
4. Behavior changes have meaningful regression coverage where practical.
5. Tests exercise production behavior rather than restating the implementation.
6. Every applicable acceptance criterion has recorded evidence.
7. No unresolved blocking review, QA, security, test, build, formatter, or lint finding remains.
8. The diff contains only the requested outcome and disclosed bounded maintenance;
   it does not absorb unrelated feature work or user-owned changes.
9. A fresh independent `formatter` receipt accounts for requested files and any
   formatter-added implementation files, with successful applicable checks or a
   justified `not_applicable` result.

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
  "maintenance": [{"path": "...", "reason": "...", "kind": "format|lint|tooling"}],
  "formatter": {"result": "pending", "applicability": "pending", "requested_files": [], "added_files": []}
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
- Snapshot initial `git status` and relevant diffs before mutation; record
  pre-existing user paths as protected so later formatter or maintenance work
  cannot absorb them.
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
authoritative suite. If an authoritative check fails, treat the result as work
to route and close, not as a reason to return immediately to the user.

### 3a. Own closure

`deliver` is the closure owner. Subagents are specialists, not authorities that
can redefine scope or hand routine cleanup back to the user. When a check or
specialist finds adjacent work, classify and route it:

- Automatically include deterministic formatter output for first-party
  implementation source in the affected formatter workspace.
- Route bounded lint fixes through `dev` or the parent when they are conventional,
  locally verifiable, and do not change public behavior, APIs, runtime
  dependencies, data, security posture, or user-owned work.
- When applicable source lacks formatter/linter tooling, route a conventional
  implementation through `dev`; development-only dependencies, configuration,
  scripts, and lockfile updates are bounded maintenance when the repository's
  stack has a clear standard choice and the result is locally verifiable.
- Record every added path and reason in `maintenance`, rerun affected checks,
  and repeat the relevant review only when semantics changed.
- Ask the user only when closure requires a materially different product choice,
  ambiguous or broad runtime/toolchain policy, public compatibility change,
  destructive or external action, secret handling, or modification of
  overlapping user work.

An agent response equivalent to “outside my responsibility” is an internal
handoff, not a user-visible blocker. The parent must reassign or perform safe
in-scope closure while a reliable local path remains.


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

Give `formatter` the requested commit files, protected pre-existing user paths,
and the affected formatter workspaces. It must:

1. classify every requested file as implementation source or excluded;
2. exclude documentation, example/sample/template configuration, generated,
   vendor, third-party, lockfiles, and unsupported configuration by default;
3. inspect formatter check/diff output before write mode and allow additional
   paths only when they are first-party implementation source in an affected
   formatter workspace and do not overlap protected user changes;
4. apply that mechanical formatting instead of rejecting it merely because a
   path was not in the original task diff;
5. run read-only formatter checks and linters across affected first-party
   implementation workspaces while excluding documentation, examples,
   generated, and vendor files; and
6. return exact commands/results, requested classifications, and every
   formatter-added path with its reason.

Documentation includes `README*`, `CHANGELOG*`, `LICENSE*`, `docs/**`, and
`**/*.md`. Example configuration includes `*.example`, `*.sample`, `*.template`,
and `.env.example`. Do not introduce tooling merely to format or lint these files.
Only an explicit user request for documentation formatting overrides this rule.

If every requested file is excluded, accept an independent
`applicability=not_applicable` receipt that accounts for every path. If
implementation source is applicable but authoritative tooling is absent,
`formatter` reports it to the closure owner. `deliver` routes conventional,
locally verifiable tooling bootstrap as bounded maintenance; it asks the user
only when the choice changes dependency or repository policy materially.

A lint violation is implementation work. `formatter` must not auto-fix it; return
it to the closure owner, which routes a bounded fix to `dev` or the parent,
records it as maintenance, reruns affected checks and review, then invokes
`formatter` again. Pre-existing or initially out-of-diff findings are not by
themselves blockers. Stop only when the closure policy above requires a user
decision or no safe local path remains.

Pass the receipt to `committer` without replacing it with a parent-authored
summary. Missing classifications, applicable results, exclusion reasons,
requested files, formatter-added files, or independent formatter approval block
the commit.

### 6. Commit through the gate

Before invoking `committer`, re-read the ledger and verify:

```text
all criteria pass
AND all checks pass
AND all required independent gates approve
AND open_issues is empty
AND diff is requested work plus disclosed bounded maintenance
AND formatter.approved is true
AND formatter receipt accounts for every requested and formatter-added file
```

Give `committer` the task, scope, maintenance ledger, evidence summary, and exact
files eligible for staging together with the formatter receipt. The explicit
invocation of `deliver` is the commit authorization.
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
  "maintenance": [{"path": "...", "reason": "...", "kind": "format|lint|tooling"}],
  "formatter": {"result": "approved", "applicability": "checked|not_applicable", "added_files": []}
}
```

On failure, do not commit. Return `delivered=false`, completed evidence, open
issues, and the exact user decision or external change needed.

## Hard rules

- Optimize for verified outcomes, not phase attendance.
- Own safe local closure; do not expose routine internal handoffs as user blockers.
- Never claim completion from an agent's prose alone; require evidence.
- Never weaken, delete, skip, or rewrite valid tests merely to turn them green.
- Never invoke `committer` without an independent `formatter` receipt accounting
  for every eligible file and every applicable check.
- Never use destructive working-tree commands (`checkout`, `restore`, destructive
  `reset`, `clean`, or `stash`) to manage agent work.
- Preserve unrelated user changes.
- Never commit secrets or environment files.
- Never push, merge, deploy, or release.
