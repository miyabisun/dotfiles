---
description: バージョンを major bump (X.y.z の X+1、minor・patch は 0 リセット) してタグを打ち、リリース CI を発火させる
allowed-tools: Bash(git *), Bash(cargo *), Bash(gh *), Read, Edit
---

# bump-tag: major

現在のリポジトリのバージョンを **major** bump (`X.y.z` → `(X+1).0.0`) し、コミット・タグ・push まで一気に行う。

以下の手順を厳密に実行すること:

## 1. 事前チェック (失敗したら中止して報告)

- `git status --porcelain` が空であること。未コミット変更があれば **中止** (bump コミットに無関係な変更を混ぜない)
- 現在ブランチがリポジトリのデフォルトブランチ (通常 main) であること。違えば中止
- `git ls-remote --tags origin` で重複タグがないこと (新バージョン計算後に確認)

## 2. 現在バージョンの検出

リポジトリルートで、以下の優先順で現在バージョンを読む:

1. `Cargo.toml` の `[package] version`
2. `package.json` の `.version`
3. どちらも無ければ最新の `v*` git タグ

## 3. 新バージョンの計算 (semver)

- **major bump**: `X.y.z` → `(X+1).0.0` (minor と patch は 0 にリセット)

## 4. バージョンファイルの更新

リポジトリルートに**存在するものすべて**を新バージョンに揃える:

- `Cargo.toml` — 更新したら `cargo check` を実行して `Cargo.lock` 内の自パッケージ版数も追従させ、**Cargo.lock もコミットに含める**
- `package.json` (ルートのみ。サブディレクトリの package.json は触らない)
- `pyproject.toml` / その他マニフェストがあれば同様に

## 5. コミット・タグ・push

```
git add <更新したファイル>
git commit -m "release: vX.Y.Z"
git tag vX.Y.Z
git push origin <ブランチ> && git push origin vX.Y.Z
```

- コミットメッセージは `release: vX.Y.Z` (Conventional Commits、英語)
- **ブランチとタグの両方を push する** (タグだけ push すると main が遅れる)
- グローバル CLAUDE.md の「コミット禁止」ルールについて: このスキルの起動自体がコミット・タグ・push の明示的な指示である

## 6. CI 発火の確認

push 後にタグをトリガーにしたワークフローが起動したことを確認し、実行 URL をユーザーに報告する。`gh` があれば `gh run list --limit 3`、無ければ `curl -sf "https://api.github.com/repos/<owner>/<repo>/actions/runs?per_page=3"` で status を読む。60 秒待っても何も走らない場合はその旨を警告する (タグトリガーのワークフローが無いリポジトリなら「CI なし」と報告するだけでよい)。

## 注意

- プレリリース (`-rc.1` 等) は非対応。必要なら手動で行う
- 途中で失敗したら、作ってしまったタグ・コミットの状態を正直に報告し、リカバリ方法 (例: `git tag -d vX.Y.Z`) を提示する
