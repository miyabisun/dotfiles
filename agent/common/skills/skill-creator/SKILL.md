---
name: skill-creator
description: 効果的な skill を作るためのガイド。専門知識・workflow・tool 連携で Claude の能力を拡張する新しい skill を作りたいとき (または既存の skill を更新したいとき) に、この skill を使う。
license: Complete terms in LICENSE.txt
---

# Skill Creator

この skill は、効果的な skill を作るための指針を示す。

## skill について

skill は、専門知識・workflow・tool を提供して Claude の能力を拡張する、
modular で自己完結した package である。特定のドメインやタスク向けの
「オンボーディングガイド」だと考えればよい。skill は汎用の agent を、どの
モデルも完全には持ちえない手続き的知識を備えた専門の agent へ変える。

### skill が提供するもの

1. 専門的な workflow — 特定のドメイン向けの多段の手順
2. tool 連携 — 特定のファイル形式や API を扱うための指示
3. ドメインの専門知識 — 企業固有の知識・schema・業務ロジック
4. bundled resources — 複雑で反復的なタスク向けの scripts・references・assets

## 基本原則

### 簡潔に書く

context window は公共財である。skill は、Claude が必要とする他のすべてと
context window を共有する。共有相手は system prompt・会話履歴・他 skill の
metadata、そして実際の user 要求である。

**既定の前提: Claude はすでに十分に賢い。** Claude がまだ持っていない
context だけを足す。個々の情報を「Claude はこの説明を本当に必要とするか」
「この段落は token コストに見合うか」と問い直す。

冗長な説明よりも簡潔な例を選ぶ。

### 適切な自由度を設定する

具体性の水準を、タスクの壊れやすさとばらつきに合わせる:

**高い自由度 (テキストによる指示)**: 複数のやり方が有効なとき、判断が文脈に
依存するとき、経験則が進め方を導くときに使う。

**中程度の自由度 (擬似コード、または引数を持つ script)**: 望ましいパターンが
存在するとき、ある程度の差異を許容できるとき、設定が振る舞いを変えるときに
使う。

**低い自由度 (引数の少ない特定の script)**: 操作が壊れやすく誤りやすいとき、
一貫性が決定的なとき、特定の順序に従わなければならないときに使う。

Claude が道を進むところを思い浮かべればよい。崖に挟まれた狭い橋には具体的な
手すりが要る (低い自由度)。開けた野原なら多くの経路を許せる (高い自由度)。

### skill の構造

すべての skill は、必須の SKILL.md ファイルと任意の bundled resources から
成る:

```
skill-name/
├── SKILL.md (required)
│   ├── YAML frontmatter metadata (required)
│   │   ├── name: (required)
│   │   ├── description: (required)
│   │   └── compatibility: (optional, rarely needed)
│   └── Markdown instructions (required)
└── Bundled Resources (optional)
    ├── scripts/          - Executable code (Python/Bash/etc.)
    ├── references/       - Documentation intended to be loaded into context as needed
    └── assets/           - Files used in output (templates, icons, fonts, etc.)
```

#### SKILL.md (必須)

すべての SKILL.md は次から成る:

- **フロントマター** (YAML): 必須の `name` と `description` の field に加えて、
  `license`・`metadata`・`compatibility` などの任意の field を持つ。skill が
  いつ発火するかの判定に Claude が読むのは `name` と `description` だけで
  ある。skill が何であり、いつ使うのかを明確に、漏れなく書く。
  `compatibility` field は環境要件 (対象プロダクト、システム package など) を
  書くためのものだが、ほとんどの skill には要らない。
- **本文** (Markdown): skill を使うための指示と手引き。skill が発火した
  **後**にだけ読み込まれる (読み込まれない場合もある)。

#### 同梱リソース (任意)

##### スクリプト (`scripts/`)

決定的な信頼性を要する、あるいは繰り返し書き直されるタスクのための実行可能
コード (Python/Bash など)。

- **含めるとき**: 同じコードを繰り返し書き直しているとき、または決定的な
  信頼性が必要なとき
- **例**: PDF 回転タスク向けの `scripts/rotate_pdf.py`
- **利点**: token 効率がよい・決定的である・context へ読み込まずに実行できる
- **注意**: patch 当てや環境固有の調整のために、Claude が script を読む必要は
  残る

##### 参照資料 (`references/`)

Claude の進め方と思考に情報を与えるため、必要に応じて context へ読み込むこと
を意図した文書・参照資料。

- **含めるとき**: 作業中に Claude が参照する文書のため
- **例**: 財務 schema なら `references/finance.md`。社内 NDA template なら
  `references/mnda.md`。社内ポリシーなら `references/policies.md`。API 仕様
  なら `references/api_docs.md`
- **使いどころ**: データベースの schema・API 文書・ドメイン知識・社内
  ポリシー・詳細な workflow の手引き
- **利点**: SKILL.md を軽く保てる。必要だと Claude が判断したときにだけ
  読み込まれる
- **推奨**: ファイルが大きいとき (>10k words) は、grep の検索パターンを
  SKILL.md に書く
- **重複を避ける**: 情報は SKILL.md か references ファイルのどちらか一方に
  置き、両方には置かない。skill の中核でない限り、詳細な情報は references
  ファイルへ寄せる。こうすると SKILL.md は軽いまま、context window を占有
  せずに情報を見つけられる。SKILL.md には必須の手続き的指示と workflow の
  手引きだけを残し、詳細な参照資料・schema・例は references ファイルへ移す。

##### 素材 (`assets/`)

context へ読み込むためではなく、Claude が生成する出力の中で使うためのファイル。

- **含めるとき**: 最終出力で使うファイルを skill が必要とするとき
- **例**: ブランド資産なら `assets/logo.png`。PowerPoint template なら
  `assets/slides.pptx`。HTML/React の boilerplate なら
  `assets/frontend-template/`。typography なら `assets/font.ttf`
- **使いどころ**: template・画像・icon・boilerplate コード・font、そして
  コピーや改変を受けるサンプル文書
- **利点**: 出力用の資源を文書から切り離せる。context へ読み込まずに Claude
  がファイルを使える

#### skill に入れないもの

skill には、その機能を直接支える必須のファイルだけを入れる。次のような余計な
文書・補助ファイルを**作らない**:

- README.md
- INSTALLATION_GUIDE.md
- QUICK_REFERENCE.md
- CHANGELOG.md
- など

skill が持つ情報は、AI agent が目の前の仕事をこなすために必要なものだけに
する。作成にいたる経緯・セットアップやテストの手順・利用者向け文書といった
補助的な context は入れない。文書ファイルを増やしても、雑然として混乱する
だけである。

### progressive disclosure の設計原則

skill は context を効率よく扱うため、3 段階の読み込みを使う:

1. **Metadata (name + description)** — 常に context にある (約 100 words)
2. **SKILL.md body** — skill が発火したとき (<5k words)
3. **Bundled resources** — Claude が必要とするとき (script は context window
   へ読み込まずに実行できるので無制限)

#### progressive disclosure のパターン

context の膨張を抑えるため、SKILL.md の body は要点だけに絞り、500 行未満に
保つ。この上限に近づいたら、内容を別ファイルへ分割する。分割したファイルは
SKILL.md から必ず参照し、いつ読むのかを明記する。そうしないと、skill の
読み手はそのファイルの存在と使いどころを知らないままになる。

**核となる原則:** skill が複数の派生・framework・選択肢に対応するなら、
SKILL.md には中核の workflow と選び方の指針だけを残す。派生ごとの詳細
(パターン・例・設定) は別の reference ファイルへ移す。

**パターン 1: references を伴う概要ガイド**

```markdown
# PDF Processing

## Quick start

Extract text with pdfplumber:
[code example]

## Advanced features

- **Form filling**: See [FORMS.md](FORMS.md) for complete guide
- **API reference**: See [REFERENCE.md](REFERENCE.md) for all methods
- **Examples**: See [EXAMPLES.md](EXAMPLES.md) for common patterns
```

Claude は必要なときにだけ FORMS.md・REFERENCE.md・EXAMPLES.md を読み込む。

**パターン 2: ドメイン別の構成**

複数のドメインを持つ skill では、無関係な context を読み込まずに済むよう、
内容をドメイン別に整理する:

```
bigquery-skill/
├── SKILL.md (overview and navigation)
└── reference/
    ├── finance.md (revenue, billing metrics)
    ├── sales.md (opportunities, pipeline)
    ├── product.md (API usage, features)
    └── marketing.md (campaigns, attribution)
```

user が売上指標を尋ねたとき、Claude は sales.md だけを読む。

同じく、複数の framework や派生に対応する skill では、派生ごとに整理する:

```
cloud-deploy/
├── SKILL.md (workflow + provider selection)
└── references/
    ├── aws.md (AWS deployment patterns)
    ├── gcp.md (GCP deployment patterns)
    └── azure.md (Azure deployment patterns)
```

user が AWS を選んだとき、Claude は aws.md だけを読む。

**パターン 3: 条件付きの詳細**

基本の内容を示し、応用の内容へはリンクを張る:

```markdown
# DOCX Processing

## Creating documents

Use docx-js for new documents. See [DOCX-JS.md](DOCX-JS.md).

## Editing documents

For simple edits, modify the XML directly.

**For tracked changes**: See [REDLINING.md](REDLINING.md)
**For OOXML details**: See [OOXML.md](OOXML.md)
```

user がそれらの機能を必要とするときにだけ、Claude は REDLINING.md や
OOXML.md を読む。

**重要な指針:**

- **深い入れ子の参照を避ける** — references は SKILL.md から 1 階層の深さに
  保つ。すべての reference ファイルは SKILL.md から直接リンクする。
- **長い reference ファイルを構造化する** — 100 行を超えるファイルは先頭に
  目次を置く。preview したときに Claude が全体の scope を見渡せるようにする。

## skill の作成手順

skill の作成は次の手順から成る:

1. 具体例で skill を理解する
2. 再利用できる skill の中身を計画する (scripts・references・assets)
3. skill を初期化する (init_skill.py を実行する)
4. skill を編集する (リソースを実装し、SKILL.md を書く)
5. skill を package 化する (package_skill.py を実行する)
6. 実際の利用に基づいて反復する

これらの手順は順に踏む。当てはまらない明確な理由があるときだけ飛ばす。

### 手順 1: 具体例で skill を理解する

この手順を飛ばすのは、skill の利用パターンをすでに明確に把握しているときだけ
である。既存の skill を扱うときにも、この手順には価値が残る。

効果的な skill を作るには、その skill がどう使われるかの具体例を明確に把握
する。把握の元は、user が直接示した例でもよいし、こちらが生成して user の
feedback で検証した例でもよい。

たとえば image-editor skill を作るときは、次のような問いが効く:

- 「image-editor skill はどの機能に対応するか。編集、回転、ほかにもあるか」
- 「この skill がどう使われるか、例をいくつか挙げてもらえるか」
- 「user が『この画像の赤目を消して』『この画像を回転して』のように頼む場面が
  思い浮かぶ。ほかにこの skill が使われる場面はあるか」
- 「この skill を発火させるとき、user は何と言うか」

user を圧倒しないよう、1 通のメッセージで多くを問いすぎない。まず最も重要な
問いから始め、必要に応じて追って尋ねる。

skill が対応する機能をはっきりつかめたら、この手順を終える。

### 手順 2: 再利用できる skill の中身を計画する

具体例を効果的な skill へ変えるには、例ごとに次を分析する:

1. その例をゼロから実行する方法を考える
2. これらの workflow を繰り返し実行するとき、どの scripts・references・
   assets が役立つかを見極める

例: 「この PDF を回転させて」のような依頼を扱う `pdf-editor` skill を作る
とき、分析は次を示す:

1. PDF の回転は、毎回同じコードを書き直すことになる
2. `scripts/rotate_pdf.py` を skill に置いておくと役立つ

例: 「todo アプリを作って」「歩数を追う dashboard を作って」のような依頼が
ある。これを扱う `frontend-webapp-builder` skill を設計するとき、分析は次を
示す:

1. frontend webapp を書くには、毎回同じ HTML/React の boilerplate が要る
2. boilerplate の HTML/React project ファイルを収めた
   `assets/hello-world/` template を skill に置いておくと役立つ

例: 「今日ログインした user は何人か」のような依頼を扱う `big-query` skill
を作るとき、分析は次を示す:

1. BigQuery への問い合わせは、毎回テーブルの schema と関係を調べ直すことに
   なる
2. テーブルの schema を記した `references/schema.md` を skill に置いておくと
   役立つ

skill の中身を定めるには、具体例ごとに分析し、同梱する再利用可能なリソースの
一覧を作る。対象は scripts・references・assets である。

### 手順 3: skill を初期化する

ここからは、実際に skill を作る段階である。

この手順を飛ばすのは、開発中の skill がすでに存在し、反復や package 化が必要
なときだけである。その場合は次の手順へ進む。

ゼロから新しい skill を作るときは、必ず `init_skill.py` script を実行する。
この script は、skill に必要なものをすべて含む template の skill ディレクトリ
を生成する。作成の手順はこれで効率よく、確実になる。

使い方:

```bash
scripts/init_skill.py <skill-name> --path <output-directory>
```

この script は次を行う:

- 指定した path に skill ディレクトリを作る
- 適切な frontmatter と TODO placeholder を持つ SKILL.md template を生成する
- 例となるリソースディレクトリ `scripts/`・`references/`・`assets/` を作る
- 各ディレクトリに、書き換えや削除をしてよい例ファイルを置く

初期化のあとは、生成された SKILL.md と例ファイルを必要に応じて書き換えるか
削除する。

### 手順 4: skill を編集する

(新しく生成した、あるいは既存の) skill を編集するときは、その skill が別の
Claude インスタンスのために作られていることを忘れない。Claude にとって有益
で、かつ自明でない情報を入れる。どの手続き的知識・ドメイン固有の詳細・再利用
可能な asset があれば、別の Claude インスタンスがこれらのタスクをより効果的に
こなせるかを考える。

#### 実証された設計パターンを学ぶ

skill の必要に応じて、次の手引きを参照する:

- **多段の処理**: 逐次的な workflow と条件分岐は references/workflows.md を
  見る
- **特定の出力形式や品質基準**: template と例のパターンは
  references/output-patterns.md を見る

これらのファイルには、効果的な skill 設計の定石がまとまっている。

#### 再利用できる skill の中身から始める

実装は、上で洗い出した再利用可能なリソース、つまり `scripts/`・`references/`・
`assets/` のファイルから始める。この手順には user の入力が要る場合もある。
たとえば `brand-guidelines` skill を実装するときを考える。`assets/` に置く
ブランド資産や template、`references/` に置く文書を user から受け取ることに
なる。

追加した script は、実際に走らせてテストする。バグがないこと、出力が期待
どおりであることを確かめるためである。似た script が多いときは、代表的な
ものだけをテストすればよい。完了までの時間と釣り合いを取りつつ、すべてが
動くという確信を得る。

skill に不要な例ファイル・例ディレクトリは削除する。初期化 script は構造を
示すため `scripts/`・`references/`・`assets/` に例ファイルを作るが、ほとんど
の skill はそのすべてを必要としない。

#### SKILL.md を更新する

**記述の指針:** 常に命令形・不定形を使う。

##### フロントマター

`name` と `description` を持つ YAML frontmatter を書く:

- `name`: skill の名前
- `description`: skill の主たる発火機構であり、いつ skill を使うのかを Claude
  が理解する助けになる。
  - skill が何をするかと、いつ使うのかの具体的な発火条件・文脈の両方を書く。
  - 「いつ使うか」の情報はすべてここに書く — body には書かない。body は発火
    した後にしか読み込まれないので、body の "When to Use This Skill" 節は
    Claude の役に立たない。
  - `docx` skill の description の例: "Comprehensive document creation, editing, and analysis with support for tracked changes, comments, formatting preservation, and text extraction. Use when Claude needs to work with professional documents (.docx files) for: (1) Creating new documents, (2) Modifying or editing content, (3) Working with tracked changes, (4) Adding comments, or any other document tasks"

YAML frontmatter に他の field を入れない。

##### 本文

skill と、その bundled resources を使うための指示を書く。

### 手順 5: skill を package 化する

skill の開発が終わったら、user に渡す配布可能な .skill ファイルへ package 化
する。package 化の処理は、まず skill がすべての要件を満たすかを自動で検証
する:

```bash
scripts/package_skill.py <path/to/skill-folder>
```

出力ディレクトリの指定は任意である:

```bash
scripts/package_skill.py <path/to/skill-folder> ./dist
```

package 化の script は次を行う:

1. skill を自動で**検証**し、次を確認する:

   - YAML frontmatter の形式と必須 field
   - skill の命名規約とディレクトリ構造
   - description の網羅性と品質
   - ファイルの構成とリソース参照

2. 検証を通過したら skill を **package** 化する。skill の名前を冠した .skill
   ファイル (例: `my-skill.skill`) を作り、すべてのファイルを含めて配布用の
   ディレクトリ構造を保つ。.skill ファイルは、拡張子を .skill にした zip
   ファイルである。

検証に失敗すると、script はエラーを報告し、package を作らずに終了する。検証
エラーを直してから、package 化のコマンドをもう一度実行する。

### 手順 6: 反復する

skill を試したあと、user が改善を求めることがある。多くは skill を使った直後、
その働きぶりの記憶が新しいうちに起きる。

**反復の workflow:**

1. 実際のタスクで skill を使う
2. つまずきや非効率に気づく
3. SKILL.md や bundled resources をどう更新するかを見極める
4. 変更を実装し、もう一度試す
