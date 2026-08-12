---
name: harden
description: >-
  Release-grade shipping gate: turn a requested change into a verified local
  commit through the full pipeline (co-authored contract, independent review,
  formatter gate, dual security review on a frozen snapshot, gated staging),
  and verify the cumulative diff since the previous harden-verified point.
  Enter only on the user's explicit release call — an explicit $harden
  invocation is that call (decision 0004).
  A version number alone never selects harden.
  Never push, deploy, or release.
---

# harden

This skill inherits the full former `deliver` pipeline unchanged (decision
0002). In this document, "deliver"/"delivery" refers to this skill's own
process. Per decision 0004 this stage has exactly one entry: the user's
explicit release call — a command to run the shipping gate (「リリースして
v1.0.0 にしたい」 and its equivalents), not any sentence that merely contains
the word "release". An explicit `$harden` invocation is that call. `$deliver`
without an explicit stage never resolves here, and a version manifest already
past 1.0.0 does not select harden by itself.

Turn a request into a **verified local commit**. Choose the smallest reliable
route. Phases and subagents are tools, not completion criteria.

## Shipping-gate scope

harden verifies what is about to ship, not only the current task. The review
target is the **cumulative diff** from the previous harden-verified point to
the current frozen snapshot:

- The previous harden-verified point is the newest reachable commit whose
  message carries the `Harden-Verified: true` trailer. Every harden delivery
  commit must carry that trailer, so the gate's own commit becomes the next
  baseline.
- If no such commit exists (first harden), do not invent a baseline: the
  review target is the **entire tracked product state**.
- From that cumulative diff, always return exactly one semver recommendation
  with its reason: `major` (breaks the public contract), `minor`
  (backward-compatible capability), or `patch` (compatible fix or
  internal-only change). The recommendation informs the user's `bump-tag`
  decision; harden never edits version manifests, never tags, and never
  releases.
- This scope is not merely a semver input — it is wired through the pipeline.
  The delivery **mutation scope** (`scope`: what this task may change) and the
  **shipping verification scope** (`shipping_gate`: what must pass the gate)
  are separate ledger fields, and the second contains the first. Section 1
  resolves the baseline and cumulative paths, Section 2 classifies risk and
  security sensitivity from the cumulative diff, Sections 3–5a run checks,
  independent review, and the security manifest over it, and the
  `Harden-Verified` trailer in Section 6 asserts that the **entire cumulative
  range** passed — never only the current task diff.
- The baseline commit stays fixed after contract time, but the range endpoint
  and `cumulative_paths` follow the working tree: re-enumerate them
  from the current candidate snapshot before sending the implementation
  review, before the post-`formatter` security freeze, and after any
  security-closure fix before `committer`.
  Every mutation invalidates the previously enumerated candidate evidence.
  Re-evaluate risk, security sensitivity, and the semver recommendation
  against the final frozen cumulative diff, not the contract-time enumeration.
- A shipping-gate run whose verification passes with zero fix diff still
  advances the baseline: the explicit `$harden` authorization covers one
  **empty verification commit** (`git commit --allow-empty`) whose message
  carries the trailer. Without it the next harden would re-verify the same
  range forever.

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

Items 1–11 are the commit-readiness gate. After the commit, do not return the
final delivery receipt until the domain-knowledge inventory in Section 6a has
been attempted and recorded. A `pending` inventory is a soft failure and does
not undo an otherwise successful delivery.

Documentation-only or metadata-only changes do not require invented product
tests. Validate their syntax, links, generated output, or consumer behavior as
appropriate and explain why broader tests are not applicable. Documentation
must also be operationally true: execute documented setup, quickstart, and
example commands from a clean state when feasible (including any committed
`.env.example` defaults and container run instructions), and verify factual
claims (spec or RFC identifiers, URLs, API semantics, defaults) against their
sources rather than writing them from memory. Route substantive user-facing
documentation authoring (a new README, docs/**, example configuration) to the
`docs` role rather than writing it incidentally in the parent or `dev`. Give
that role the `source_request` original text, material follow-ups, and
fidelity label under the rules above: a domain premise that shaped the design
usually has no source other than the user's own words. Its receipt of executed
commands and claim sources is the documentation evidence, and `rev` reviews it
like any other deliverable. Trivial doc edits (typo, one-line sync with a code
change) may stay with the implementer.

Treat large-scale simplification or refactoring as its own `deliver` task with
explicit scope, behavior-preservation criteria, benchmarks, and regression
checks; never append it as routine cleanup to an unrelated delivery.

## Operating model

Maintain a compact delivery ledger in the **parent conversation context only**.
判断履歴・TODO・plan・ledger・review log を **project repo へ file として残さない** —
経緯は receipt と knowledge が持つ (GLOBAL.md「Project Memory Boundary」)。
Ledger fields:

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
  "shipping_gate": {"baseline": "commit|entire-tracked-state", "range": "<baseline>..<frozen>", "cumulative_paths": [], "semver_recommendation": null, "reason": null},
  "maintenance": [{"path": "...", "reason": "...", "kind": "format|lint|tooling"}],
  "worker": {"runtime": "claude|codex|grok", "designation": "trigger-pane"},
  "reviewers": [{
    "runtime": "claude|codex",
    "pane": "w1:p2|null",
    "planning": {
      "counterpart_proposal": {"message_id": "#N|null", "result": "pending|received|unavailable"},
      "reconciliation": {"message_id": "#N|null", "result": "pending|aligned|user_decision"}
    },
    "implementation_review": {"message_id": "#N|null", "result": "pending|approved|fallback"}
  }],
  "formatter": {"result": "pending", "applicability": "pending", "requested_files": [], "added_files": []},
  "knowledge_inventory": {"status": "pending", "message_id": null, "reason": "not_run", "preflight": null},
  "review_snapshot": {"id": null, "paths": [], "hashes": {}, "git_status": null, "diff_identity": null, "checks": []},
  "security_review": {
    "applicable": false,
    "local": {"runtime": "...", "independence": "independent|implementer", "receipt": null},
    "reviewers": [{"runtime": "...", "independence": "independent|implementer", "receipt": null}],
    "union_findings": [],
    "open_critical_high": [],
    "approved_snapshot_id": null,
    "fallback_reason": null
  }
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
- Resolve the shipping-gate baseline at contract time: locate the newest
  reachable commit whose message carries the `Harden-Verified: true` trailer
  (record `entire-tracked-state` when none exists), enumerate the cumulative
  diff paths from that baseline, and fill the ledger's `shipping_gate` field.
  The baseline commit is fixed here; the enumerated range endpoint and paths
  are provisional and are re-enumerated at every later gate.
  Later sections read this field; a harden that never resolved it cannot
  attach the trailer.
- Before asking the user to approve anything, search for authorization that
  already exists: the invoking request, earlier user statements, and this
  skill's own invocation. Record what you find as authority evidence and
  proceed. Do not re-ask for permission the user has already given.
- If materially different outcomes remain plausible, do not stop at a refusal.
  Run one `discuss` round to close the open question, then re-decide whether
  implementation can start. Return to the user only for an authority gap, and
  only with the single decision that would unblock the work. Do not spend agents
  or tokens implementing guesses, and never treat unease as a blocker.
- For non-trivial behavior, prefer a failing regression test before the fix.
- A separate strategist is optional; use it only when the contract itself is
  difficult, cross-cutting, UI-heavy, externally integrated, or high risk.
- Only when this delivery is judged to require editing browser-rendered frontend sources (HTML, CSS, JavaScript, or Svelte), first read the complete
  `frontend-design` skill and apply its UI-surface boundary, Project design
  authority, and implementation rules. File extension or "usability" alone is not enough. CLI/TUI, terminal-only tools, Node backend-only JavaScript,
  config, docs, and test-only changes are out of scope. If you cannot confirm those frontend sources need changes, do not use this skill. Invoke
  `designer` only for unresolved visual or interaction decisions or a change
  to the design contract, and include its brief in the acceptance criteria.

### 1a. Co-author the contract with the counterpart

Before implementation, decide the reviewer set. The worker is
always the runtime of the pane where this skill was invoked: the skill's
effect and the user's authorization stay in the invoking pane, and a peer
message carries no user authority, so
implementation can never be delegated to another pane.
There is no default worker and no designation wait.
To have a different runtime do the work, the user fires the skill in that
runtime's pane.

- Worker grok → the reviewer set is Claude Code and Codex (both).
- Worker Claude Code → the reviewer is Codex; worker Codex → Claude Code.

`list_peers` resolves reviewer panes only; it plays no part in choosing the
worker.

An idle or busy registered pane both mean the reviewer exists. Absence means
that no such pane is registered in the current session; do not start one.
Judge absence and record fallback per reviewer; never silently reassign the
worker because a reviewer is missing. Use agent-talk's
same-window-then-same-session resolution order, record every selected reviewer
pane ID in the ledger, and address those exact panes directly for every later
request. If multiple equally eligible panes remain, show the candidates and
ask the user which one to use; ambiguity is not absence.

With two reviewers, send both planning briefs in the same turn and draft the
local proposal before reading either reply; reconcile each returned proposal
against the original request individually before integrating. From here on,
every "counterpart" instruction in this document applies to each member of
the reviewer set.

Both sides propose a contract independently, then reconcile. Reviewing a
finished proposal fixes the counterpart on hunting for errors in one framing;
proposing independently explores a second design space as well.

Immediately after capturing `source_request`, and before finalizing the local
contract, send the fixed counterpart pane the following clearly separated
material:

- `Original user request (verbatim)`: the captured task text in its original
  language, without translation, summarization, or paraphrase; use the
  reconstructed label above when exact text is unavailable.
- `Material user follow-ups (verbatim)`, when any materially changed the task.
- Verified repository facts, protected paths, and objective environment
  constraints.
- A request for an independent proposal containing acceptance criteria, scope,
  verification commands, risks, and unresolved questions.

Do not include a proposed contract in this first brief. Draft the local proposal
in the same turn that sends the brief: the counterpart reply cannot arrive until
a later turn, so this ordering is structurally enforced rather than a matter of
discipline. Finish other useful read-only preparation, report that delivery is
waiting for the counterpart, and end the turn. A counterpart request received
while this delivery is waiting may be handled normally; it does not count as
starting implementation.

Reconcile both proposals against the original request by source-request
fidelity, verified repository evidence, testability, and smallest sufficient
scope. Record material differences, the selected resolution, and its evidence.
Send the integrated contract and that reconciliation record to the same pane for
one check that asks two questions, not one:

1. does a material mismatch remain between the integrated contract and the
   counterpart proposal; and
2. naming it now, does the integrated contract contain a defect that neither
   proposal surfaced — an untestable success criterion, a missing failure mode,
   an exit contract that cannot hold, or evidence that cannot be produced?

```json
{"aligned": true, "material_mismatches": [], "corrections": [], "summary": "..."}
```

A `corrections` entry from the second question is closed locally with focused
evidence; it does not restart planning. Do not implement while a material
mismatch remains. Never resolve a disagreement by runtime precedence: decide it
with repository evidence or a focused check, choose the smaller mechanism when
only preference separates the options, and ask the user when materially
different product outcomes remain. The normal protocol is one
independent-proposal exchange and one reconciliation exchange; do not turn
planning into an open-ended approval loop. When a material conflict survives
both exchanges, escalate it into one `discuss` round rather than back to the
user: `discuss` must land on Ready, Ready with reduced scope, or a named
authority gap. Only the authority gap returns to the user, and it names the one
decision that unblocks the work.

A counterpart planning exchange does not replace `strategist` or `strategy-rev`.
Use `strategist` when the contract itself needs specialist design (migration,
complex state transitions, external integration), and `strategy-rev` to verify a
contract or test design that `strategist` created or changed.

Do not treat a delayed reply or a busy pane as absence. Fall back to the existing
risk-based review route only when agent-talk reports delivery failure, the fixed
pane disappears, or the user explicitly directs delivery to continue without the
counterpart. Judge this per reviewer: one reviewer's absence never cancels the
other's rounds and never reassigns the worker. Record the objective reason and
fallback in the ledger and receipt.
If agent-talk is unavailable or a reviewer runtime has no registered pane,
record an empty or reduced `reviewers` entry with the reason and use the
existing route for that reviewer's share of the gates.

### 1b. Reconcile Project drift with home-development-rules

The first reference in a delivery is **共通開発ルール（home-development-rules）**;
after that, use the Japanese name when the context is clear and the slug for
machine references. This is a plain scope label, not a brand. Until a dedicated
`home-development-rules` document is introduced, the slug identifies the base
rules distributed as `~/.claude/CLAUDE.md` or `~/.codex/AGENTS.md` (in this
repository, `agent/common/rules/GLOBAL.md`). Those base rules are the default for
all Projects. An explicit Project override wins only for its recorded diff, and
`DESIGN.md` is the subordinate difference convention for UI/UX presentation.

When an affected Project differs from the common rules, treat it as an obvious
mistake that this delivery may align automatically only when these 5 conditions
are all true:

1. The canonical policyに明文規則がある.
2. The violation is grep、build、lintなどで機械検出できる.
3. The fix is 局所的かつ挙動保存で、API、schema、UXを変えない.
4. The Project overrideがその逸脱を明示していない.
5. The fix is 今回のdeliver scope内で完結する.

5条件をすべて満たす場合だけ、the parent owns the bounded alignment as part
of delivery closure and records the evidence and affected path. Otherwise use
exactly one of these routes:

- base ruleが沈黙している事項はdriftではなくProjectの自由; do not invent a
  default or an override.
- A base rule自体の穴、矛盾、適用不能 is a policy defect; do not work around it
  silently and ユーザーへ相談する.
- A 正当なProject固有理由 is not a mistake; Project overrideとして記録する.
- If the mismatch is scope外なら自動修正せず、最終報告へ推奨として記録する.

A Project override contains only the difference from the base. Put it in the
AGENTS.md本体、またはAGENTS.mdから明示リンクされる単一file so every runtime
can discover it in one hop; base全文をcopyしない. Record the canonical path and
section, base側commit hashまたは日付, override理由、scope、影響、再評価条件.
Use `home-development-rules#<existing-rule-id>` only after the canonical rule
already supplies that stable ID. 存在しないrule IDをinventしない; until then,
use the slug plus canonical path and section without a fragment.

### 2. Choose proportional execution

Classify by the highest applicable risk:

| Risk | Typical work | Minimum route |
|---|---|---|
| `low` | docs, comments, narrow config, mechanical rename | implement → focused validation → diff self-review → `formatter` → commit |
| `standard` | ordinary bug fix, feature, refactor, multi-file behavior | implement → relevant checks → independent `rev` → `formatter` → commit |
| `high` | auth, permissions, secrets, destructive data, migration, payments, concurrency, public compatibility | contract specialist as useful → implement → full behavior checks → independent `rev` → `formatter` → security gate when security-sensitive → commit |

Treat every security-sensitive change as high risk. A high-risk change that is
purely non-security (concurrency, public compatibility, a large migration with no
threat path) uses the high route without a security gate; a security-adjacent
change with no reachable threat path is not security-sensitive.

Classify risk and security sensitivity from the **cumulative shipping diff**
(`shipping_gate.range`), not from the current task diff alone: a sensitive
change committed earlier (for example by a polish that recommended this
review) and not yet harden-verified makes this delivery security-sensitive
even when the current task is benign.

When planning selected a counterpart, replace only the general semantic review
in this table: replace low-risk diff self-review and standard/high-risk `rev`
with the counterpart implementation review described below. Do not replace
`strategy-rev`, `ui-checker`, `sec`, `formatter`, or `committer`. For
security-sensitive work, keep the implementation runtime's independent `sec` gate
and add an independent security review from every reviewer pane (worker grok
therefore produces three receipts: local + Claude + Codex). All of them
review the same frozen snapshot, and their findings form one blocking union.

The security gate runs after `formatter`, not before it: freezing a snapshot and
then letting `formatter` rewrite the source would mean the reviewed bytes are not
the committed bytes.

```text
high, non-security:   implement → full checks → counterpart implementation
                      review → formatter → committer → commit
security-sensitive:   implement → full checks → reviewer implementation
                      review → formatter → freeze the final snapshot →
                      local sec + every reviewer sec independently →
                      reconcile the union → committer → commit
```

The implementing agent's own inspection never substitutes for any independent
security receipt.

UI behavior additionally requires `ui-checker` evidence for every observable
visual and interaction criterion. Exercise affected states, viewports, and
input methods in a 実ブラウザ, including loading/empty/error, keyboard/focus,
touch, overflow, contrast, and reduced motion when relevant. `designer` remains
limited to unresolved visual/product decisions; `frontend-design` is an
implementation capability, not an approval gate.

The parent may implement directly or delegate to `dev`. Delegate when isolation,
parallel exploration, context preservation, or specialist instructions improve
the result. Do not spawn agents merely to satisfy a named phase.

Runtime role locations:

- Claude Code: `~/.claude/agents/<role>.md`
- Cursor: `~/.cursor/agents/<role>.md`
- Codex: configured `agents.<role>` backed by `~/.agents/agents/<role>.md`
- Grok: `~/.grok/agents` mirrors the shared role definitions, but a full harden
  with grok as the worker (formatter / committer / sec role spawning) has not
  been exercised yet. The first grok-led harden must capture that capability
  evidence in its receipt, or stop at the named gap and return it to the user.

### 3. Implement and close the evidence loop

Implement the smallest coherent change that can satisfy the ledger.

After each substantive attempt:

1. Run the narrowest useful check for quick feedback.
2. Fix failures caused by the task.
3. Run the complete applicable behavior, type, test, and build checks before
   review, against the full tracked state — the checks must exercise the
   cumulative shipping diff (`shipping_gate.range`), not only the current
   task's files.
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
  overlapping user work. Before doing so, run one `discuss` round; ask only if
  it reports an authority gap.
- A repository rule that blocks authorized work is itself work to route. Check
  who authored it. An agent-authored description of product state is updated as
  a consequence of the authorized change, in the same commit, under the
  exact-conformance conditions in `discuss`. A binding instruction still binds
  the current turn regardless of who wrote it: update the control surface with
  authority evidence first, then implement.

An agent response equivalent to “outside my responsibility” is an internal
handoff, not a user-visible blocker. The parent must reassign or perform safe
in-scope closure while a reliable local path remains.


### 4. Review only where it buys confidence

Re-enumerate `shipping_gate` from the current candidate snapshot before
sending any implementation review; a review of the contract-time enumeration
does not cover paths the implementation added later.
When planning selected a counterpart, give the same fixed pane the separately
labeled original user request and material follow-ups under the fidelity rules
above, acceptance criteria, the current task diff plus the cumulative shipping
diff (`shipping_gate.range`), and executed checks after
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
mock-only evidence for external-system behavior, and the shared review
standards (decision 0002, aligned with spike/polish):

- test honesty (blocking): read the tests;
  tautological tests that restate the implementation,
  expected values hardcoded to fit output, weakened or skipped assertions,
  and any dishonest shortcut are strict blockers that must be fixed.
- DRY: harmful duplication introduced by this diff that a local extraction
  removes without new mechanism is blocking; intentional duplication or
  duplication whose removal needs new abstraction becomes a non-blocking TODO.
- over-applied YAGNI (non-blocking): a dropped case that may be needed returns
  as the question "Is this case actually needed?" in the receipt for the user.

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
- Security-sensitive: the local security receipt and every required reviewer
  security receipt approve the same frozen snapshot, the union of all blocking
  findings is empty, required security criteria have evidence, and no
  Critical/High issue remains. Then `committer` verifies that the staged
  snapshot is that same snapshot.
- If a security side is objectively unavailable, judge and record it per
  receipt; use the remaining independent reviews as an explicitly recorded
  reduced-independence fallback, and never present the reduced set as full
  approval.

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

### 5a. Freeze and run the independent security reviews

For security-sensitive work, freeze the final post-`formatter` snapshot before
any security review starts. Re-enumerate the range and `cumulative_paths`
from that frozen snapshot first — the manifest lists the fresh enumeration,
never the contract-time one — then record the manifest in `review_snapshot`:

- the reviewed paths — every path in `shipping_gate.cumulative_paths`, with
  protected and unrelated paths listed separately;
- a content hash per reviewed file;
- `git status --short`;
- the identity of the reviewed diff;
- the checks already executed.

Do not mutate the reviewed files while any security review is in flight.

Run one review per required receipt against that exact manifest, independently
and in parallel where possible:

- the implementation runtime's independent `sec` role; and
- each reviewer pane, instructed to read `agent/common/agents/sec.md`
  completely and apply that same canonical role rather than a brief-local
  paraphrase. Worker grok therefore needs three receipts (local + Claude +
  Codex); worker claude or codex needs two.

Give the local sec role and every reviewer pane the original request,
integrated contract, trust boundaries, external inputs, privileged or secret
sinks, the current task diff plus the cumulative shipping diff
(`shipping_gate.range`), executed checks, and the manifest. Do not reveal any reviewer's initial findings to
another before every initial receipt exists.

Treat the results as a union, not a vote. Do not average severities, outvote
a finding, or silently drop one. Every blocking finding from any side must be
fixed, or dismissed with concrete evidence accepted by the reviewer that raised
it. When two findings conflict with each other, or one conflicts with a
requirement the user stated, build one integrated correction that satisfies both
constraints instead of discarding either; ask the user only when evidence cannot
resolve a material product or security trade-off.

Every receipt is an equal blocker. Record independence metadata — a reviewer
that authored the production change is not an independent receipt for it, and a
cross-runtime review carries stronger independence — but never use that metadata
to weigh one side's findings down.

After fixes, issue a new manifest — re-enumerate the range and
`cumulative_paths` from the new frozen snapshot each time, so a
security-closure fix that touched a new path can never ship outside the
reviewed scope. Use a focused closure review from every side
when the threat model and design are unchanged; rerun every full review when a
fix changes a trust boundary, parser, authorization rule, secret flow,
destructive operation, or other material security semantics. Do not advance to
`committer` until every required receipt identifies the same current manifest,
every one has `approved=true`, the blocking union is empty, and no
Critical/High issue remains.

Do not impose a round cap on this gate. Continue focused closure while fixes keep
producing new evidence; when the same conflict repeats with no new evidence,
return the product or security trade-off to the user instead of trading turns.

### 6. Stage through the gate and commit in the parent

Before invoking `committer`, re-read the ledger and verify:

```text
all criteria pass
AND all checks pass
AND all required independent gates, including counterpart review when selected, approve
AND open_issues is empty
AND diff is requested work plus disclosed bounded maintenance
AND formatter.approved is true
AND formatter receipt accounts for every requested and formatter-added file
AND for security-sensitive work, every required security receipt approves the current frozen snapshot
AND the shipping-gate verification covered the entire cumulative range (`shipping_gate.range`)
```

Give `committer` the task, scope, maintenance ledger, evidence summary, exact
files eligible for staging, the formatter receipt, and the security manifest when
one exists. Require the proposed commit message to end with the
`Harden-Verified: true` trailer — that commit becomes the next shipping-gate
baseline, and the trailer asserts that the entire cumulative range passed this
gate, never only the current task diff. Stage only the current task's eligible
files; the earlier commits in the range are already history and need no
restaging. When verification passes with **zero eligible files**, `committer`
returns an approved receipt with an empty staged list and a proposed empty
verification commit message carrying the trailer, and the parent executes
exactly one `git commit --allow-empty` with it — the baseline must advance
even when nothing needed fixing. `committer` reports
`staged_snapshot_matches_security_manifest: true|false`; a false value blocks the
commit because the approved bytes and the staged bytes differ. The user's
release call (the explicit `$harden` invocation) is the commit authorization,
but commit execution stays with the
parent agent that directly retains that authorization and the source request.

`committer` independently inspects the evidence and diff, stages only the exact
eligible files, checks the complete cached diff, and returns a structured
staging receipt with the staged files and proposed Conventional Commit message.
It must not execute `git commit`.

After an approved staging receipt, the parent must complete this sequence
without asking the user to repeat or reconfirm the existing authorization:

1. Compare the receipt's staged file list with both the eligible file list and
   `git diff --cached --name-only`; inspect `git diff --cached --check` and the
   complete cached diff.
2. Use the receipt's proposed subject and body verbatim. If either needs to
   change, request a fresh `committer` receipt instead of rewriting it.
3. Execute exactly one new local `git commit` directly in the parent context.
   Never delegate this boundary operation to a child agent.
4. Verify the result with `git status --short` and `git log -1 --stat`, and
   include the resulting hash and subject in the delivery receipt.

An approval or sandbox failure at the parent's commit call is a runtime policy
failure, not missing user authorization. Do not route the same commit through a
child or ask the user for duplicate confirmation. Follow the runtime's normal
safe escalation path once; if policy still denies the authorized call, report
the exact denial as an external runtime constraint. Never push.

If unrelated changes overlap files that must be committed and safe partial
staging cannot isolate the task with confidence, stop and ask the user instead
of committing mixed work.

### 6a. Inventory domain knowledge after commit

commit後、final receipt前, capture `git rev-parse HEAD` and `git status --short`,
then invoke the dedicated `knowledge-inventory` role exactly once. Give it the
source request and material follow-ups with fidelity labels, the final commit
hash and diff summary, executed checks and evidence, and candidates from this
delivery only:

- domain facts and invariants;
- decisions and rejected or deprecated alternatives;
- open questions and deferred choices;
- common-rule drift and Project overrides; and
- reusable cross-Project lessons.

Do not turn the inventory into a whole-Project backlog sweep. The role follows
the existing `agent-knowledge-intake.md` playbook and returns exactly one of:

- `sent`: it found durable knowledge, sanitized one batch, sent it once, and
  captured the broker `message_id`;
- `not_applicable`: it found nothing worth preserving, gives a one-line reason,
  and sends no empty batch; or
- `pending`: the explicit `knowledge/codex` target was unavailable or ambiguous,
  sending failed, or the safety scan could not be made clean. Record the reason,
  but 自動再送queueを作らない.

The default route is one notification-style `send_message` to
`knowledge/codex` with `no_reply`, not a required
acknowledgement exchange. There is 1 deliverにつき最大1 batch and no retry in the
same delivery. The MCP server runs in-process, so no sandbox widening and no
approved command path are involved. The inventory role must not run git in
arona-knowledge, write directly
to its bundles by default, decide whether development is complete, choose
routing or release actions, or mutate the delivered repository.

After the role returns, prove the repository was not changed by comparing the
棚卸し前後のHEAD hashと`git status --short`を比較する. A changed HEAD or worktree
is a blocking inventory defect to investigate, but an unreachable knowledge
session or failed safe send remains `pendingでもdelivery本体の成功を取り消さない`.
Never amend the delivery commit to add the inventory result.

The role must preserve provenance: when `source_request.fidelity=verbatim`, keep
the user statement distinct from agent inference; when fidelity is
`reconstructed`, never quote it as a human statement and say that the original
text was unavailable. Before its sole send, it serializes the exact candidate
body, excludes raw `.env*` sources and values, mechanically scans and redacts
credential, token, private-key, private/local host, and internal-endpoint
candidates, enumerates other URLs/hosts for classification, and rescans. If the
second scan is not clean, it sends nothing and returns `pending` with the reason.
Remove or redact only the unsafe items; do not discard unrelated safe knowledge.

For the first live use of a newly introduced inventory/redaction path, the
parent must inspect the serialized candidate and scan result before authorizing
the send, and record that preflight in the delivery receipt. This one-time
preflight does not weaken the independent security reviews of the committed
implementation.

## Output

On success, return a concise delivery receipt:

```json
{
  "delivered": true,
  "commit": "<hash> <subject>",
  "criteria": [{"requirement": "...", "evidence": "...", "pass": true}],
  "checks": [{"command": "...", "result": "pass"}],
  "reviews": [{"gate": "planning|peer|rev|ui|sec-local|sec-reviewer", "runtime": "claude|codex|grok|null", "result": "approved|not-applicable", "message_id": "#N|null"}],
  "security_snapshot": "<manifest id>|not-applicable",
  "shipping_gate": {"baseline": "<commit>|entire-tracked-state", "semver_recommendation": "major|minor|patch", "reason": "..."},
  "knowledge_inventory": {"status": "sent|not_applicable|pending", "message_id": "#N|null", "reason": "string|null", "preflight": "inspected|not_required|null"},
  "maintenance": [{"path": "...", "reason": "...", "kind": "format|lint|tooling"}],
  "formatter": {"result": "approved", "applicability": "checked|not_applicable", "added_files": []}
}
```

On failure, do not commit. Return `delivered=false`, completed evidence, open
issues, and the exact user decision or external change needed.

## Hard rules

- Optimize for verified outcomes, not phase attendance.
- Own safe local closure; do not expose routine internal handoffs as user blockers.
- When a counterpart was selected, do not implement before the contract is
  reconciled with it, or normalize and commit before its implementation review.
- Never send a proposed contract in the first planning brief, and never read the
  counterpart proposal before drafting the local one.
- For security-sensitive work, never treat one security reviewer as a substitute
  for another while its runtime is available; require every required approval on
  the same frozen snapshot.
- Never expose one security reviewer's initial findings to another before every
  initial receipt exists.
- Never average, outvote, or silently drop a security finding; reconcile the
  union with evidence.
- Never count the implementing agent's self-review as an independent security
  receipt.
- Any mutation after the security freeze invalidates every receipt; issue a new
  manifest and review again.
- Never claim completion from an agent's prose alone; require evidence.
- Never state spec identifiers, external URLs, or third-party API semantics
  from memory; verify them or mark them as unverified in the receipt.
- Never weaken, delete, skip, or rewrite valid tests merely to turn them green.
- Never invoke `committer` without an independent `formatter` receipt accounting
  for every eligible file and every applicable check.
- Never delegate `git commit` to `committer` or another child agent; after an
  approved staging receipt, the authorization-holding parent must commit.
- Never use destructive working-tree commands (`checkout`, `restore`, destructive
  `reset`, `clean`, or `stash`) to manage agent work.
- Preserve unrelated user changes.
- Never commit secrets or environment files.
- Never push, merge, deploy, or release.
- Never run the post-commit knowledge inventory before the parent-owned commit,
  send more than one intake batch, retry automatically, or amend the commit with
  its result.
- Never put credential, token, private-key, `.env`-derived value, private host,
  or internal endpoint material into the persistent agent-talk journal.
