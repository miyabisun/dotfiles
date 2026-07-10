---
description: コミット履歴から適切なバージョン bump (major/minor/patch) を判定し、対応する bump-tag:* スキルを起動する。タグが 1 つも無ければ現行バージョンのまま初回リリースタグを打つ
allowed-tools: Bash(git *), Bash(cargo *), Bash(gh *), Read, Skill
---

# bump-tag (ディスパッチャ)

リリース内容を自分で判断してタグを打つ。実際の bump 作業は `bump-tag:major` / `bump-tag:minor` / `bump-tag:patch` スキルに委譲し、このスキルは「どれを呼ぶか」の判定と初回リリースの特例だけを担当する。

## 1. 状況把握

- 現在バージョン: `Cargo.toml` の `[package] version` → 無ければ `package.json` の `.version`
- 既存タグ: `git tag -l 'v*'` と `git ls-remote --tags origin`

## 2. 分岐

### A. タグが 1 つも無い (初回リリース)

**バージョンは変更しない**。現行バージョンをそのまま初タグにする:

1. 事前チェック: `git status --porcelain` が空 / デフォルトブランチ上にいる (違えば中止)
2. `git tag vX.Y.Z` (現行バージョン) → `git push origin <ブランチ> && git push origin vX.Y.Z`
3. CI 発火を確認し URL を報告する。`gh` があれば `gh run list --limit 3`、無ければ `curl -sf "https://api.github.com/repos/<owner>/<repo>/actions/runs?per_page=3"` で status を読む

この場合 bump-tag:* は呼ばない (bump しないため)。

### B. タグがある (通常リリース)

`git log <最新タグ>..HEAD --oneline` を読み、変更内容から bump 幅を判定する:

| 判定 | 基準 |
|---|---|
| **major** | 破壊的変更がある: `feat!:` / `BREAKING CHANGE` / API 契約・データ形式の非互換変更 |
| **minor** | 新機能がある: `feat:` があるが破壊的変更はない |
| **patch** | `fix:` / `chore:` / `docs:` / `refactor:` のみ (機能追加なし) |

**0.x 時代の特例** (メジャーが 0 の間): semver 慣習に従い、破壊的変更でも major には上げず **minor** に留める (0.x → 1.0.0 への昇格はユーザーの明示判断のみ)。つまり 0.x では: 破壊的 or 新機能 → minor、それ以外 → patch。

判定結果と根拠 (該当コミットの引用) を 2〜3 行でユーザーに示してから、**Skill ツールで対応するスキルを起動する**:

- major → `Skill(skill: "bump-tag:major")`
- minor → `Skill(skill: "bump-tag:minor")`
- patch → `Skill(skill: "bump-tag:patch")`

### 迷ったら

minor / patch の境界で迷う場合は保守的に **patch** を選ぶ。major (1.0.0 以降の破壊的変更) は影響が大きいので、判定根拠に自信が持てない場合はユーザーに確認する。
