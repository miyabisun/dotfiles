---
name: consolidate
description: >-
  Consolidate genuinely duplicated concepts and production logic into clear
  ownership while preserving behavior, compatibility, and performance. Use
  only when the user explicitly invokes consolidate or requests a substantial
  DRY-focused refactor delivered as a verified local commit. Inventory and
  classify duplication, reject false similarities, migrate safely, verify the
  result independently, and never push, deploy, or release.
---

# consolidate

Deliver a behavior-preserving consolidation as one verified local commit.
Optimize for change locality and clear ownership, not deleted line count.

An explicit `$consolidate` invocation grants one local commit. Apply the
inventory, review, formatter, and parent-owned commit rules in this file.
Do not invent an extra shipping stage or demand another invocation.

## Inputs

| Arg | Required | Meaning |
|---|---|---|
| `target` | yes | Subsystem, concept, pattern, or duplication to investigate |
| `constraints` | no | Compatibility, performance, layering, or migration limits |

Free text alone means `target`.

## Definition of consolidated

Require all applicable outcomes:

1. An inventory identifies concrete duplicate sites and their callers.
2. Each site is classified as `merge`, `share-primitive`, or `keep-separate`
   with evidence.
3. Merged sites represent the same domain concept, invariants, and reasons to
   change—not merely similar syntax.
4. The consolidated implementation has one clear owner and dependency direction.
5. Old production paths and obsolete adapters are removed when safe; no shadow
   implementation remains accidentally active.
6. Observable behavior, public compatibility, error semantics, and relevant
   performance are preserved unless the request explicitly changes them.
7. The new abstraction does not replace duplication with flags, branching,
   leaky generic types, dependency cycles, or a miscellaneous utility dumping ground.
8. Regression tests and independent review prove the result.

## Consolidation inventory

Record this inventory in the conversation receipt:

```json
{
  "inventory": [
    {
      "sites": ["path:symbol", "path:symbol"],
      "decision": "merge|share-primitive|keep-separate",
      "reason": "shared concept and change coupling, or reason to remain separate",
      "owner": "target module or package"
    }
  ],
  "baseline": ["behavior, API, performance, and dependency evidence"],
  "retired_paths": ["removed duplicate implementation"],
  "architecture_checks": ["dependency and ownership evidence"]
}
```

Never manufacture an inventory from names alone. Trace definitions, callers,
data flow, errors, tests, and change boundaries.

## 1. Discover and classify

Search the target broadly enough to find semantic siblings, then read each
candidate in context. Record:

- public and internal callers;
- inputs, outputs, side effects, errors, ordering, and lifecycle;
- domain invariants and ownership;
- tests and fixtures;
- dependency direction and release/version boundaries;
- performance-sensitive paths.

Use this decision test:

```text
same concept
AND same invariants
AND same reasons to change
AND a natural owner exists
AND sharing reduces future coordinated edits
AND the shared API is simpler than the duplicates
```

If it fails, choose `share-primitive` or `keep-separate`. Do not force DRY across
independent bounded contexts, platform policies, lifecycle differences, or code
that only looks alike today.

For a broad or ambiguous target, use `leader` to bound the outcome. Use
`strategist` and `strategy-rev` when existing coverage cannot independently
prove behavior preservation or when public compatibility/performance is at risk.

## 2. Establish the baseline

Before changing production logic:

1. Run existing focused and authoritative suites.
2. Add characterization tests for uncovered behavior worth preserving.
3. Record public API/schema snapshots when applicable.
4. Record representative error and edge-case behavior.
5. Record benchmarks or resource measurements for performance-sensitive code.
6. Capture dependency/layering state with existing architecture tools or
   repository-native queries.

Do not encode accidental private structure in characterization tests. If the
baseline is already failing, separate pre-existing failure from task-caused
failure and do not claim a green starting point.

## 3. Design ownership before abstraction

For each `merge` decision, specify:

- canonical owner and why it owns the concept;
- smallest stable API required by real consumers;
- dependency direction after migration;
- migration order and deletion point;
- compatibility adapter, only when genuinely required;
- proof that consumers retain their behavior.

Reject designs that introduce boolean mode arguments, consumer-specific
branches in the shared core, vague `utils` ownership, circular dependencies, or
an abstraction that has no simpler vocabulary than its callers.

## 4. Migrate in coherent slices

Implement the smallest safe sequence:

1. Introduce or select the canonical implementation.
2. Migrate consumers with focused checks after each coherent slice.
3. Remove retired implementations, dead adapters, and obsolete tests.
4. Search for remaining references and parallel production paths.
5. Run the full applicable suite and architecture/performance checks.

Temporary adapters must have a documented removal condition and should be
removed in the same delivery whenever compatibility permits. Never leave two
writable sources of truth.

The parent may implement directly or delegate bounded migrations to `dev`.
Parallelize only independent consumer groups; never let parallel agents edit the
canonical owner or shared contract concurrently.

## 5. Verify the consolidation

Require independent `rev` even if the textual diff is small. Give it the
original target, inventory, baseline, ownership design, retired paths, complete
diff, and executed checks. Require it to answer:

- Were any `keep-separate` sites incorrectly merged?
- Does the owner match the domain and dependency direction?
- Did duplication move into flags, branches, adapters, or tests?
- Can one behavioral change now be made in one authoritative place?
- Are old production paths actually unreachable or deleted?
- Are compatibility, errors, concurrency, and performance preserved?

Do not stop or demand extra ceremony because a consolidation crosses trust,
auth, tenant, serialization, SQL, URL, filesystem, command, secret, or
destructive-data boundaries. Continue inside this skill. Stop only under
GLOBAL.md 「Stopping work」.

After fixes, rerun affected characterization/full checks and inspect retired
path searches again. Material ownership or API redesign requires a fresh full
`rev`; list-only fixes may use `inspector` for closure.

## 6. Commit and report

After review passes, the parent runs the applicable repo-native
formatter/linter and records this structured receipt in the conversation
(not a one-line summary):

```json
{
  "approved": true,
  "applicability": "checked|not_applicable",
  "requested_files": ["path"],
  "formatter_added_files": [],
  "check": "pass|n/a",
  "reason": ""
}
```

This parent-measured receipt is the formatter receipt. An independent
formatter role is not required. Mechanical formatter output elsewhere in an
affected first-party implementation workspace is bounded maintenance, not an
automatic reason to stop consolidation.

Pass that structured receipt—not a parent summary—to `committer`.
Invoke `committer` only after that receipt and every consolidation condition pass.
Provide the requested files, disclosed maintenance files, and the explicit
`$consolidate` authorization. After its approved staging receipt, follow the
parent-owned commit sequence: verify the staged files and cached diff against
the receipt, use the proposed message verbatim, and create exactly one local Conventional Commit in the parent context, then verify it.
Never push.

Extend the conversation receipt with:

```json
{
  "consolidated": true,
  "decisions": [{"sites": [], "decision": "merge", "owner": "...", "reason": "..."}],
  "retired_paths": [],
  "preservation_evidence": [],
  "architecture_evidence": [],
  "formatter": {"result": "approved", "applicability": "checked|not_applicable"},
  "commit": "<hash> <subject>"
}
```

If investigation finds no sound consolidation, do not make cosmetic changes or
commit an empty refactor. Return `consolidated=false` with the inventory and the
evidence for keeping the implementations separate.
