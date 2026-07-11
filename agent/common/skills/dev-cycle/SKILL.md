---
name: dev-cycle
description: >-
  Top-level delivery cycle: leader triage → optional designer → backend-team
  and/or frontend-team → committer. Use when the user asks for dev-cycle, wants
  a feature finished end-to-end without babysitting teams, or says "作って完成まで".
disable-model-invocation: true
---

# dev-cycle

You are the **top orchestrator**. Do not implement yourself. Stop on reject /
clarify — do not guess. Delegate teams via the `backend-team` and
`frontend-team` skills (read and follow those SKILL.md files completely).

## Input

| Arg | Required | Meaning |
|---|---|---|
| `task` | yes | User request |

Free text alone → `task`.

## Agents & skills

| Step | How |
|---|---|
| leader / designer / committer | Subagent (`Agent` / `Task`) + role file under `~/.claude/agents/` or `~/.cursor/agents/` |
| backend / frontend delivery | **Invoke skill** `backend-team` / `frontend-team` (Skill tool, or Read + follow `agent/common/skills/<name>/SKILL.md`) |

## Pipeline

```
- [ ] 1. Leader triage
- [ ] 2. Designer (if frontend or both)
- [ ] 3. backend-team skill (if backend or both) — backend first when both
- [ ] 4. frontend-team skill (if frontend or both)
- [ ] 5. committer (only if teams approved)
```

### 1. Leader — `leader`

```
次の要望を評価し、実装方針とチーム振り分け（または reject / clarify）を JSON で返せ。

要望:
<task>
```

Required JSON shape:

```json
{
  "status": "proceed|reject|clarify",
  "team": "frontend|backend|both",
  "plan": "...",
  "conditions": "UI seed conditions if frontend/both (optional)",
  "reason": "...",
  "alternative": "...",
  "ambiguities": "...",
  "questions": "..."
}
```

- `status=reject` → stop. Return reason + alternative to the user. No teams.
- `status=clarify` → stop. Return ambiguities + questions to the user. No teams.
- `status=proceed` → continue with `plan`, `team`, optional `conditions`.

Judgment rules live in the leader agent file — do not soften reject/clarify.

### 2. Designer — `designer` (only if `team` is `frontend` or `both`)

```
次のタスクとリーダーの実装方針をデザインシステムに照らして評価し、
brief とデザイン達成条件（または reject / clarify）を JSON で返せ。

タスク:
<task>

リーダーの実装方針:
<plan>

リーダーのUI達成条件:
<conditions>
```

```json
{
  "status": "proceed|reject|clarify",
  "brief": "...",
  "conditions": "...",
  "reason": "...",
  "alternative": "...",
  "ambiguities": "...",
  "questions": "..."
}
```

- reject / clarify → stop and surface to the user (same as leader).
- proceed → keep `brief`. Merge seed conditions:

```
seed_conditions = leader.conditions
  + (designer.conditions ? "【デザイン達成条件】\n" + designer.conditions : "")
```

### 3. `backend-team` skill (if `backend` or `both`)

Invoke **backend-team** with:

- `task` = original task
- `plan` = leader plan

If return `approved != true` → stop. Report failure; **do not** commit; **do not** run frontend unless you intentionally continue after user fix (default: stop).

Save `summary` from the team result.

### 4. `frontend-team` skill (if `frontend` or `both`)

Invoke **frontend-team** with:

- `task`, `plan`, `brief` (may be empty if somehow missing — should not be)
- `seed_conditions` = merged leader/designer conditions (strategist refines these; see frontend-team)

If `approved != true` → stop. No commit.

Overwrite `summary` with frontend summary when present.

### 5. Committer — `committer` (only after all required teams approved)

```
検品承認済みの変更をコミットせよ。

タスク:
<task>

検品サマリ:
<summary>
```

This skill's successful completion **is** explicit permission to commit (dev-cycle
exception). Still: no push, no amend, no history rewrite, no tree discard.
Follow the committer agent file.

## Outputs

**Clarify / reject (early stop):**

```json
{
  "approved": false,
  "needsClarification": true,
  "ambiguities": "...",
  "questions": "..."
}
```
or
```json
{
  "approved": false,
  "rejected": true,
  "rejectedBy": "leader|designer",
  "reason": "...",
  "alternative": "..."
}
```

Show questions/reasons to the user clearly; wait for their reply before re-running.

**Team failure:**

```json
{ "approved": false, "note": "…チームが未承認", "result": { } }
```

**Success:**

```json
{ "approved": true, "team": "backend|frontend|both", "summary": "...", "commit": "..." }
```

## Hard rules

- Never implement in the parent turn — only orchestrate.
- Never call committer if any required team failed or triage stopped.
- Never discard the working tree.
- Prefer invoking child **skills** over re-implementing their pipelines inline.
- On clarify/reject, do not start teams "just in case".
