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
10. Every introduced configuration knob, dependency, abstraction, and code path
    is justified by an acceptance criterion, a test, or a named consumer.
    Remove mechanisms that exist only for hypothetical future needs before
    requesting review; prefer a constant over a configuration option unless a
    consumer needs to vary it without rebuilding.
11. Behavior that tests exercise only through mocks or stubs (external API
    semantics, boundary inclusivity, error contracts, default values) is
    verified against authoritative documentation or a real call, or explicitly
    recorded as an unverified risk in the delivery receipt.

Documentation-only or metadata-only changes do not require invented product
tests. Validate their syntax, links, generated output, or consumer behavior as
appropriate and explain why broader tests are not applicable. Documentation
must also be operationally true: execute documented setup, quickstart, and
example commands from a clean state when feasible (including any committed
`.env.example` defaults and container run instructions), and verify factual
claims (spec or RFC identifiers, URLs, API semantics, defaults) against their
sources rather than writing them from memory. Route substantive user-facing
documentation authoring (a new README, docs/**, example configuration) to the
`docs` role rather than writing it incidentally in the parent or `dev`; its
receipt of executed commands and claim sources is the documentation evidence,
and `rev` reviews it like any other deliverable. Trivial doc edits (typo,
one-line sync with a code change) may stay with the implementer.

Treat large-scale simplification or refactoring as its own `deliver` task with
explicit scope, behavior-preservation criteria, benchmarks, and regression
checks; never append it as routine cleanup to an unrelated delivery.

## Operating model

Maintain a compact delivery ledger in the parent context:

```json
{
  "source_request": {
    "original": "user-authored task text",
    "fidelity": "verbatim|reconstructed",
    "material_followups": []
  },
  "criteria": [{"requirement": "...", "evidence": "pending", "pass": false}],
  "checks": [{"command": "...", "result": "pending"}],
  "risk": "low|standard|high",
  "open_issues": [],
  "scope": ["paths or components"],
  "maintenance": [{"path": "...", "reason": "...", "kind": "format|lint|tooling"}],
  "counterpart": {
    "runtime": "claude|codex|none",
    "pane": "%N|null",
    "planning_review": {"message_id": "#N|null", "result": "pending|approved|unavailable"},
    "implementation_review": {"message_id": "#N|null", "result": "pending|approved|fallback"}
  },
  "formatter": {"result": "pending", "applicability": "pending", "requested_files": [], "added_files": []}
}
```

Update it from actual tool and agent results. Never fabricate a command result,
review approval, browser measurement, or Red/Green observation.

### 1. Establish the contract

Read the repository and translate the request into observable acceptance
criteria, scope, verification commands, and important failure modes.

- Before translating the request, capture the user-authored task text in
  `source_request` without translation, summarization, paraphrase, or other
  rewriting. Append later user-authored corrections or constraints verbatim
  when they materially change the task; do not include assistant summaries or
  unrelated conversation.
- If compaction or missing context makes the exact text unavailable, set
  `fidelity: reconstructed` and label it `Original user request
  (reconstructed, verbatim unavailable)` wherever it is shared. Never present
  a reconstruction as verbatim.
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

### 1a. Cross-check the plan with the counterpart

Before implementation, use `agent-talk who` to look for the opposite interactive
application in the current tmux session:

- Claude Code's counterpart is Codex.
- Codex's counterpart is Claude Code.

An idle or busy registered pane both mean the counterpart exists. Absence means
that no counterpart pane is registered in the current session; do not start one.
Use agent-talk's same-window-then-same-session resolution order, record the
selected pane ID in the ledger, and address that exact pane directly for every
later request. If multiple equally eligible panes remain, show the candidates and
ask the user which one to use; ambiguity is not absence.

When a counterpart exists, send it a review brief with the following clearly
separated material:

- `Original user request (verbatim)`: the captured task text in its original
  language, without translation, summarization, or paraphrase; use the
  reconstructed label above when exact text is unavailable.
- `Material user follow-ups (verbatim)`, when any materially changed the task.
- The proposed contract, acceptance criteria, execution route, important risks,
  and unresolved questions.

Instruct the counterpart to compare the proposal against the user text, not
merely judge whether the proposal is internally sound. It must report omitted
requirements, contradictory interpretations, unauthorized scope expansion, and
ideas that may be good in isolation but do not answer the request. Require a
structured result:

```json
{"approved": true, "request_alignment": {"pass": true, "issues": []}, "issues": [], "summary": "..."}
```

Do not begin implementation until both `approved` and
`request_alignment.pass` are true. Incorporate blocking findings before
implementation. Because agent-talk replies arrive in a later turn, finish useful
read-only preparation, report that delivery is waiting for the counterpart, and
end the turn. Resume from the ledger when the reply prompt arrives. A counterpart
review request received while this delivery is waiting may be handled normally;
it does not count as starting implementation.

Do not treat a delayed reply or a busy pane as absence. Fall back to the existing
risk-based review route only when agent-talk reports delivery failure, the fixed
pane disappears, or the user explicitly directs delivery to continue without the
counterpart. Record the objective reason and fallback in the ledger and receipt.
If agent-talk is unavailable or the current runtime has no defined counterpart,
record `counterpart.runtime: none` with the reason and use the existing route.
If no counterpart exists during planning, record that once and use the existing
review route for the whole delivery.

### 2. Choose proportional execution

Classify by the highest applicable risk:

| Risk | Typical work | Minimum route |
|---|---|---|
| `low` | docs, comments, narrow config, mechanical rename | implement → focused validation → diff self-review → `formatter` → commit |
| `standard` | ordinary bug fix, feature, refactor, multi-file behavior | implement → relevant checks → independent `rev` → `formatter` → commit |
| `high` | auth, permissions, secrets, destructive data, migration, payments, concurrency, public compatibility | contract specialist as useful → implement → full behavior checks → independent `rev` + `sec` → `formatter` → commit |

When planning selected a counterpart, replace only the general semantic review
in this table: replace low-risk diff self-review and standard/high-risk `rev`
with the counterpart implementation review described below. Do not replace
`strategy-rev`, `ui-checker`, `sec`, `formatter`, or `committer`.

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

When planning selected a counterpart, give the same fixed pane the separately
labeled original user request and material follow-ups under the fidelity rules
above, acceptance criteria, relevant diff, and executed checks after
implementation. This counterpart review replaces low-risk diff self-review and
standard/high-risk `rev`; the implementer must not act as the independent
approver. Otherwise, preserve the risk-based route and give `rev` the same user
text and implementation material for standard and high work. In either case,
instruct the reviewer to compare the implementation with both the source request
and the derived contract, report the request-alignment failures listed in Section
1a, and review beyond correctness for:
internal consistency (the same operation implemented in more than one way,
error codes or messages reused for unrelated conditions), proportionality
(mechanism heavier than the requirement, unconsumed configuration or code),
and mock-only evidence for external-system behavior.

The review result must be structured:

```json
{"approved": true, "request_alignment": {"pass": true, "issues": []}, "issues": [], "summary": "..."}
```

Blocking issues must include target, harm, and a concrete fix. Send the fixed
list to `debugger` or fix it in the parent, rerun affected checks, and use
`inspector` to verify list closure. Request a fresh full `rev` only when fixes
materially changed design or behavior beyond that list.

Apply the same closure rule to counterpart findings: verify the fixed list
locally, and request a fresh counterpart review only when the fixes materially
changed design or behavior. Do not advance to `formatter` until the required
review has both `approved` and `request_alignment.pass` set to true. If the fixed
pane objectively becomes unavailable, use the fallback route recorded under
section 1a rather than silently self-approving.

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
AND all required independent gates, including counterpart review when selected, approve
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
  "reviews": [{"gate": "peer|rev|ui|sec", "result": "approved|not-applicable", "message_id": "#N|null"}],
  "maintenance": [{"path": "...", "reason": "...", "kind": "format|lint|tooling"}],
  "formatter": {"result": "approved", "applicability": "checked|not_applicable", "added_files": []}
}
```

On failure, do not commit. Return `delivered=false`, completed evidence, open
issues, and the exact user decision or external change needed.

## Hard rules

- Optimize for verified outcomes, not phase attendance.
- Own safe local closure; do not expose routine internal handoffs as user blockers.
- When a counterpart was selected, do not implement before its planning review
  or normalize and commit before its implementation review.
- Never claim completion from an agent's prose alone; require evidence.
- Never state spec identifiers, external URLs, or third-party API semantics
  from memory; verify them or mark them as unverified in the receipt.
- Never weaken, delete, skip, or rewrite valid tests merely to turn them green.
- Never invoke `committer` without an independent `formatter` receipt accounting
  for every eligible file and every applicable check.
- Never use destructive working-tree commands (`checkout`, `restore`, destructive
  `reset`, `clean`, or `stash`) to manage agent work.
- Preserve unrelated user changes.
- Never commit secrets or environment files.
- Never push, merge, deploy, or release.
