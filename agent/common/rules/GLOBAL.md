# Global Rules

## 言語

- 常に日本語で応答する

## 場面 → スキル

ルールの本体はスキル側にある。下の場面に当たったら、対応するスキルを
起動してから作業する。

| 場面 | スキル |
|---|---|
| git コマンドでの操作 | `git` |
| ファイルの修正 (見込み合計〜20行) | `chore` |
| ファイルの修正 (それ以上)・開発 | `knowledge-read` → `deliver` |
| Herdr 内の他エージェントとの情報共有 (自己判断で可) | `agent-talk` |
| プロンプトに `[agent-talk]` が含まれる (着信) | `agent-talk` |

ファイルの修正は必ずスキルを通す (git 操作と同じ)。規模や場面が合わない
ときは**拒否ではなくスキルを持ち替えて**自律的に進める。

着信の例:
`[agent-talk] knowledge/intake から連絡が届きました。read_message 123 で本文を確認してください。`

## 仕事の進め方

- 頼まれた仕事は自発的に進める。記録に答えがあることを確認で聞き直さない
- 止まるときは黙って止まらない: ブロッカー、完了済みの部分、ユーザーに
  必要な決断を1つ挙げる

## 設計

- Unix 哲学に従う (1つのことをうまくやる・小さなツールを組み合わせる・シンプルに保つ)
- DRY 原則を好む (同じ知識を2箇所に書かない・重複は1つの所有者に集約する)

## ツール

- **コード検索**: コードの動きを理解するときは Grep/Glob/Read より semble
  (`mcp__semble__search` / `mcp__semble__find_related`) を優先する。
- **Web 取得**: まず WebFetch を使う (軽量・要約済みで、ほとんどのサイトで
  速く安い)。失敗したとき (403 / ブロック / 空 / JS 必須) だけ Obscura
  (`~/.local/bin/obscura`, V8 搭載の Rust ヘッドレスブラウザ) に切り替える:
  `obscura fetch <url> --eval "..."`、`obscura serve` (CDP)、または obscura MCP。
  Obscura は AI ブロック・JS 重要ページ向けの「二の矢」であり、既定ではない。
  インストールは `~/projects/miyabisun/dotfiles/bin/install-apps`。
- **ブラウザ E2E テスト**: Obscura の CDP はリクエスト介入 (`page.route`) と
  title 報告が無いので、自動 E2E は **Chromium + Playwright** を使う
  (Obscura はスクレイピングと対話的確認向けで、アサーション駆動の E2E 向けではない)。
