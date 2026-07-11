---
name: backend-team
description: >-
  Run the backend team: test strategy (+ review) → implement → full review →
  fix loop → simplify → regression → security. Use when the user asks for
  backend-team, wants work finished without babysitting /dev↔/rev, or when a
  parent skill delegates backend work.
disable-model-invocation: true
---

# backend-team

Orchestrator only. Do **not** skip phases. Do **not** restart the whole team on
disapproval — only listed fix loops.

## Inputs

| Arg | Required | Meaning |
|---|---|---|
| `task` | yes | User request |
| `plan` | no | Leader implementation plan |

Free text alone → `task`.

## How to run agents

| Runtime | Mechanism |
|---|---|
| Claude Code | `Agent` with `agentType` |
| Cursor | custom agent or `Task(generalPurpose)` + role file |

Roles: `strategist`, `strategy-rev`, `dev`, `rev`, `debugger`, `inspector`, `simplify`, `sec`  
Files: `~/.claude/agents/<role>.md` or `~/.cursor/agents/<role>.md`

## Contracts (JSON)

**Strategy** (`strategist`) — no `approved`:

```json
{
  "contract": "...",
  "mocks": "...",
  "tests": ["path"],
  "conditions": ["automatically verifiable expectation"],
  "notes": "..."
}
```

**Review** (`strategy-rev`, `rev`, `inspector`, `sec`):

```json
{ "approved": true, "issues": ["target — harm — fix"], "summary": "..." }
```

**Fix** (`debugger`): `{ "done": [], "unresolved": [], "summary": "..." }`

## Pipeline

```
- [ ] 1. Strategy (strategist)
- [ ] 2. Strategy review (strategy-rev) — gate; repair max 2
- [ ] 3. Implement (dev) — plan + contract; make strategist tests Green
- [ ] 4. Full review (rev) — only full review; check contract
- [ ] 5. Fix loop if needed (debugger ↔ inspector, max 3)
- [ ] 6. Simplify
- [ ] 7. Regression review (narrow) + fix max 2
- [ ] 8. Security + fix max 2
```

### 1. Strategy — `strategist`

```
タスク:
<task>

リーダーの実装方針（参考）:
<plan>

バックエンド単独で決定的に検証完遂できる契約・モック/フィクスチャ・テストを用意せよ。
プロダクト実装は書くな。approved を付けるな。
```

### 2. Strategy review — `strategy-rev`

```
strategist の成果をレビューし承認可否を JSON で返せ。
トートロジー・実装写経・測れない契約・外部依存が固定されていない境界を落とすこと。

【contract / mocks / tests / conditions】
...
```

If rejected → strategist repairs list-only, re-review. Max **2**. Ceiling → unapproved stop.

### 3. Implement — `dev`

```
タスク:
<task>

リーダーの実装方針（これに従うこと）:
<plan>

テスト戦略の契約（これに従うこと。strategist のテストを Green にすること）:
<contract>
モック方針:
<mocks>
テスト:
<tests>
```

### 4. Full review — `rev`

```
直近の実装をレビューし承認可否を JSON で返せ。
これが唯一のフルレビュー。issues は debugger の作業リスト。全件一括。
strategist の契約との不一致は Critical。

タスク / plan / contract: ...
```

Save `summary` for the final return.

### 5. Fix loop — `debugger` ↔ `inspector`

List-only fixes; inspector no new findings; max **3**. Ceiling → unapproved stop.

Prompts: same as before (修正リスト / 検品).

### 6. Simplify — `simplify`

```
直近の実装を simplify（機能保持のリファクタリング）せよ。
タスク:
<task>
```

### 7. Regression — `rev` (narrow)

```
simplify 直後を退行観点に限定してレビューせよ。
直前はフルレビュー承認済み。新規の製品指摘はしない。

タスク:
<task>
```

Fix loop max **2** if needed.

### 8. Security — `sec`

```
直近の実装をセキュリティ観点でレビューし承認可否を JSON で返せ。
外部入力→URL/SQL/FS/コマンド のシンクを追え。全件一括。

タスク:
<task>
```

Fix loop max **2** if needed.

## Outputs

Success: `{ "approved": true, "summary": "<from rev>" }` — do not commit.  
Failure: `{ "approved": false, "note": "...", "issues": [...] }`

## Hard rules

- No working-tree discard commands.
- No whole-pipeline restart; only listed fix loops.
- No commit/push in this skill.
- Prefer existing project test/build commands; leave the tree green at phase boundaries.
