---
name: frontend-team
description: >-
  Run the frontend team: test strategy (+ review) → implement → QA measure
  (Chromium evidence) → code review → fix/UI re-verify → simplify → regression
  → security. Use when the user asks for frontend-team or wants UI work finished
  without babysitting /dev↔/rev.
disable-model-invocation: true
---

# frontend-team

Orchestrator only. Specialized agents do the work. Do **not** skip phases.
Do **not** restart the whole team on disapproval — only fix / UI re-verify /
strategy fix loops.

## Inputs

| Arg | Required | Meaning |
|---|---|---|
| `task` | yes | User request |
| `plan` | no | Leader implementation plan |
| `brief` | no | Designer design brief |
| `seed_conditions` | no | Leader/designer UI conditions to refine (not final) |

Free text alone → `task`.  
Final QA `conditions` come from **strategist** after strategy-rev approves.
If `seed_conditions` is provided, strategist must refine them into measurable
conditions (may add failure modes; must not drop measurable seeds without
strategy-rev-visible reason).

## Agents

| Runtime | Mechanism |
|---|---|
| Claude Code | `Agent` + `agentType` |
| Cursor | custom agent or `Task(generalPurpose)` + role file |

Roles: `strategist`, `strategy-rev`, `dev`, `ui-checker`, `rev`, `debugger`, `inspector`, `simplify`, `sec`  
Files: `~/.claude/agents/<role>.md` or `~/.cursor/agents/<role>.md`

## Contracts (JSON)

**Strategy** (`strategist`) — no `approved`:

```json
{
  "contract": "...",
  "mocks": "...",
  "tests": ["path"],
  "conditions": ["measurable bullet"],
  "notes": "..."
}
```

**Review** (`strategy-rev`, `ui-checker`, `rev`, `inspector`, `sec`):

```json
{
  "approved": true,
  "issues": ["target — harm — fix"],
  "summary": "...",
  "evidence": [{ "condition": "...", "measured": "...", "pass": true }]
}
```

`evidence` is **required** from `ui-checker`. Parent may treat missing evidence as failure even if `approved=true`.

**Fix** (`debugger`): `{ "done": [], "unresolved": [], "summary": "..." }`

## Pipeline

```
- [ ] 1. Strategy (strategist)
- [ ] 2. Strategy review (strategy-rev) — gate; fix loop max 2 if rejected
- [ ] 3. Implement (dev) — plan + brief + contract
- [ ] 4. QA full measure (ui-checker) — evidence per condition
- [ ] 5. Full code review (rev)
- [ ] 6. Fix loop on merged QA+rev issues (max 3)
- [ ] 7. UI re-verify failed items (if QA failed) — up to 2 passes
- [ ] 8. Simplify
- [ ] 9. Regression: light QA (E2E) + narrow rev — fix max 2
- [ ] 10. Security (XSS) + fix max 2
```

### 1. Strategy — `strategist`

```
タスク:
<task>

リーダーの実装方針（参考）:
<plan>

デザイナーの design brief（参考）:
<brief>

リーダー/デザイナーの seed_conditions（測れる形に洗練せよ。落とすなら理由を notes に）:
<seed_conditions>

フロント単独で E2E 完遂できる契約・モック・テスト・QA conditions を用意せよ。
プロダクト実装は書くな。approved を付けるな。
```

Save `contract`, `tests`, `conditions`, `mocks`.

### 2. Strategy review — `strategy-rev`

```
strategist の成果をレビューし承認可否を JSON で返せ。
トートロジー・実装写経・測れない条件・フロント単独で回せないモック境界を落とすこと。

【contract】
...
【mocks】
...
【tests】
...
【conditions】
...
```

If not approved → send issues back to `strategist` (list-only repair), then `strategy-rev` again. Max **2** rounds. Still failing → unapproved stop.

### 3. Implement — `dev`

```
タスク:
<task>

リーダーの実装方針（これに従うこと）:
<plan>

デザイナーの design brief（これに従うこと）:
<brief>

テスト戦略の契約（これに従うこと。strategist のテストを Green にすること）:
<contract>
モック方針:
<mocks>
テスト:
<tests>
```

### 4. QA full — `ui-checker`

```
以下のUI達成条件をブラウザで検証せよ。各条件に evidence を必ず付けよ。
テストファイルの新規作成・戦略の変更はするな。

【達成条件】
<conditions from strategist>

【design brief】
<brief>

【タスク概要】
<task>
```

Parent gate: every condition has `evidence`; any `pass:false` or missing → treat as QA failure.

### 5. Full review — `rev`

```
直近の実装をレビューし承認可否を JSON で返せ。唯一のフルレビュー。
issues は debugger の作業リスト。全件一括。
UI見た目は QA 実測済みなので論理・品質・契約整合に集中。
strategist の契約との不一致は Critical。

タスク / plan / contract: ...
```

### 6–7. Fix + UI re-verify

Same as before: merge QA issues + rev issues → debugger↔inspector max 3.  
If QA failed: re-measure **only** failing conditions (max 2 passes, fix max 2 each).

### 8–10. Simplify → regression → sec

- Light QA: existing E2E only（evidence = command + result）
- Narrow rev (no new product findings)
- sec with XSS focus  
Fix loops max 2 each.

## Outputs

Success: `{ "approved": true, "summary": "<from rev>" }` — do not commit.  
Failure: `{ "approved": false, "note": "...", "issues": [...] }`

## Hard rules

- No working-tree discard commands.
- No whole-pipeline restart; only listed fix loops.
- No commit/push in this skill.
- Never trust ui-checker `approved` without complete `evidence`.
- ui-checker: kill only recorded PIDs.
