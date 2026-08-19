---
name: find-skills
description: user が "how do I do X"、"find a skill for X"、"is there a skill that can..." のような質問をしたとき、または能力の拡張に関心を示したときに、agent skill の発見と install を助ける。install 可能な skill として存在しうる機能を user が探しているときに、この skill を使う。
---

# Find Skills

この skill は、open agent skills ecosystem から skill を発見して install するのを助ける。

## この skill を使う場面

user が次に当たるとき、この skill を使う:

- 既存の skill がありそうな一般的な task について「X はどうやるのか」と尋ねる
- 「X の skill を探して」「X の skill はあるか」と言う
- 専門的な能力である X について「X はできるか」と尋ねる
- agent の能力を拡張することに関心を示す
- tool・template・workflow を検索したがる
- 特定の領域 (design・testing・deployment など) で助けが欲しいと述べる

## Skills CLI とは

Skills CLI (`npx skills`) は open agent skills ecosystem の package manager である。skill は modular な package であり、専門的な知識・workflow・tool で agent の能力を拡張する。

**主なコマンド:**

- `npx skills find [query]` - 対話的に、または keyword で skill を検索する
- `npx skills add <package>` - GitHub などの source から skill を install する
- `npx skills check` - skill の更新を確認する
- `npx skills update` - install 済みの skill をすべて更新する

**skill を見るなら:** https://skills.sh/

## user の skill 探しを助ける方法

### 手順 1: 何が必要かを掴む

user が何かの助けを求めてきたら、次を特定する:

1. 領域 (例: React・testing・design・deployment)
2. 具体的な task (例: テストを書く・アニメーションを作る・PR をレビューする)
3. skill が存在しそうなほど一般的な task かどうか

### 手順 2: skill を検索する

関連する query を付けて find コマンドを実行する:

```bash
npx skills find [query]
```

例:

- user が「React app をもっと速くするには?」と尋ねる → `npx skills find react performance`
- user が「PR レビューを手伝ってもらえるか?」と尋ねる → `npx skills find pr review`
- user が「changelog を作りたい」と言う → `npx skills find changelog`

このコマンドは次のような結果を返す:

```
Install with npx skills add <owner/repo@skill>

vercel-labs/agent-skills@vercel-react-best-practices
└ https://skills.sh/vercel-labs/agent-skills/vercel-react-best-practices
```

### 手順 3: 選択肢を user へ提示する

関連する skill が見つかったら、次を添えて user へ提示する:

1. skill 名と、それが何をするか
2. user が実行できる install コマンド
3. skills.sh の詳細ページへのリンク

応答例:

```
I found a skill that might help! The "vercel-react-best-practices" skill provides
React and Next.js performance optimization guidelines from Vercel Engineering.

To install it:
npx skills add vercel-labs/agent-skills@vercel-react-best-practices

Learn more: https://skills.sh/vercel-labs/agent-skills/vercel-react-best-practices
```

### 手順 4: install を申し出る

user が進めたいと言うなら、代わりに skill を install してよい:

```bash
npx skills add <owner/repo@skill> -g -y
```

`-g` flag は global (user-level) に install し、`-y` は確認 prompt を飛ばす。

## よくある skill のカテゴリ

検索するときは、次のよくあるカテゴリを検討する:

| カテゴリ     | query の例                               |
| ------------ | ---------------------------------------- |
| Web 開発     | react, nextjs, typescript, css, tailwind |
| テスト       | testing, jest, playwright, e2e           |
| DevOps       | deploy, docker, kubernetes, ci-cd        |
| ドキュメント | docs, readme, changelog, api-docs        |
| コード品質   | review, lint, refactor, best-practices   |
| デザイン     | ui, ux, design-system, accessibility     |
| 生産性       | workflow, automation, git                |

## 効果的な検索のコツ

1. **具体的な keyword を使う**: 単に「testing」とするより「react testing」のほうがよい
2. **別の語を試す**: 「deploy」で当たらないなら「deployment」や「ci-cd」を試す
3. **人気の source を見る**: skill の多くは `vercel-labs/agent-skills` か `ComposioHQ/awesome-claude-skills` にある

## skill が見つからないとき

関連する skill が存在しないなら、次を行う:

1. 既存の skill が見つからなかったことを伝える
2. 自分の一般的な能力で task を直接手伝うと申し出る
3. `npx skills init` で user 自身の skill を作れると提案する

例:

```
I searched for skills related to "xyz" but didn't find any matches.
I can still help you with this task directly! Would you like me to proceed?

If this is something you do often, you could create your own skill:
npx skills init my-xyz-skill
```
