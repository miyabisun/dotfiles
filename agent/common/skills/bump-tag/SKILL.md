---
name: bump-tag
description: >-
  semver を bump し、commit・tag・push して release CI を起動する。auto
  (commit から推定)・major・minor・patch・first (明示的な初回 release) を
  サポートする。user が version の bump、release の切り出し、release への
  tag 付け、bump-tag の実行を求めたときに使う。
---

# bump-tag

現在の repository を release する: version を bump → commit → tag → push → CI 確認。

**引数** (任意): `auto` | `major` | `minor` | `patch` | `first`  
既定: `auto`

この skill の起動は、release の commit・tag・push を行う明示的な許可**そのものである**。これは `git` skill のブランチフローが単独では与えない authority である。

user が発行した release task も、より狭い条件でその号令を運べる。
**claim した task が与えるのは同じ手順であって、同じ scope ではない**。
その authority が及ぶのは、task が名指しする repository・branch・操作だけである。
またそれは、user が起動した worker skill が保持している間しか存続しない。
authority は task の終わりとともに終わる — 自分で作り出さない。
**自分の release を授権することになる release task を、自分で作らない。**

## release が起きるとき

**release が通常の delivery や worker loop に相乗りすることはない**。日常の
delivery・レビュー・worker cycle が、この skill を単独で発火させることはない。
release が起きるのはちょうど 2 つの場合だけである。user がこの skill を起動するか、
user が発行した release task が claim されてこの skill を呼ぶかである。

## 1. bump 水準を決める

### 初回 release チェック (全引数共通)

どの水準を決めるより先に、正である **origin** の release tag を確認する。
origin は `git ls-remote --tags origin`、local は `git tag -l 'v*'` で見る:

- **origin に `v*` tag がある** → 既に release 済み。下の引数ごとの節で解決する。
- **origin には無いが local に `v*` tag がある** → push されていない初回 release。
  target は `v0.1.0` のままで §4 は飛ばす。tag を再利用できるかは §2 の再開表の
  local tag 行が決める — 規則は 1 つで、どの引数でも同じである。
- **origin と local のどちらにも `v*` tag が無い**、かつ manifest の version (§3) が
  `0.1.0` → 初回 release。引数が何であれ bump **しない**。明示的な `major` /
  `minor` / `patch` が渡されていたら、初回 release なのでその水準を無視すると
  述べる。初回 release であることを伝え、§2–3 は通常どおり実行し、§4–5 だけを
  飛ばし、tag `v0.1.0` で §6 から続ける。
- **origin と local のどちらにも `v*` tag が無い**が manifest の version が `0.1.0` で
  ない → 引数が何であれ **abort** する。復旧手段: manifest の version を `0.1.0`
  にする。初回 release は常に `v0.1.0` であり、それ以外は bump-tag の保証の外である。

### `auto`

release task が水準を名指ししていたら (`auto` / `major` / `minor` / `patch` /
`first`)、その値をそのまま採る。下の対応する節で解決する。**task が名指しした
水準を `auto` で置き換えない。** `auto` が既定になるのは、user と task のどちらも水準を
名指ししなかったときだけである。

1. baseline の version と既存の tag を検出する (§2–3 を見よ)。初回 release と
   tag の不整合の場合は上のチェックが処理済みで、ここでは origin の tag が存在する。
2. `git log <latest-tag>..HEAD` の subject と関連する diff を調べる。type token
   だけから推定しない。次から選ぶ:

| 水準 | 条件 |
|---|---|
| **minor** | 致命的な破壊的変更のときだけ: 既存の user やデータに移行を強制する、非互換な API・CLI・設定・データ形式 |
| **patch** | それ以外すべて — 新機能・オプション・コマンド・修正・maintenance・テスト・docs・performance・refactor |

`auto` は**どの version でも major を選ばない**。major の bump が起きるのは、
user が明示的に `bump-tag major` を起動したときだけである。破壊があること自体は
決して根拠にならない。0.x → 1.0.0 も同じく、user の明示的な要求でだけ起きる。

commit type は証拠であって authority ではない。`feat` commit であっても patch の
ままである — 機能を足すことは水準を上げない。minor に達するのは、既存の user や
データの破壊が検証されたときだけであり、commit にどんな label が付いていても変わらない。

続ける前に、選んだ水準と 2–3 行の根拠 (commit を引用する) を示す。

**Tie-break**: 迷ったら minor より **patch** を採る。破壊の証拠が弱ければ、
それは patch である。

### `major` / `minor` / `patch`

その水準をそのまま使う (下のチェックはすべて実行する)。

### `first`

明示的な初回 release。origin に `v*` tag が 1 つでもあれば **abort** する: この
repository は既に release 済みである。代わりに `auto` / `patch` / `minor` /
`major` を使う。そうでなければ上の初回 release チェックに従う — local tag の
場合も含む。どの引数でも使う §2 の同じ規則に委ねるからである。

## 2. Preflight (失敗したら abort して報告する)

**local の branch や tag を動かす前に検証する**。下の順序は意図的であり、
保証は正確である: local の branch や tag を動かす最初のコマンドより前に、
すべてのチェックが通る。副作用がゼロだという約束ではない。

**チェックが守る不変条件。** どのチェックもこの 4 つのどれかへの手段である。
4 つすべてを満たす状態は、どうやってそこに至ったかによらず release して安全である:

- origin の歴史は決して失われない — branch の push は fast-forward でなければならない
- release commit は §5 が更新する version file だけを載せる
- tag は、target version に対して意図した既定ブランチの commit を指す
- branch と tag の両方が push される (tag だけの push は branch を置き去りにする)

チェック:

- まず origin の既定ブランチと tag を fetch する (`git fetch origin --tags`)。
  fetch は副作用である: remote-tracking ref と `FETCH_HEAD` を更新する。
  ただし local の branch や tag は動かさないので、下のチェックより先に実行して安全である
- 既定ブランチ名は remote HEAD から解決する
  (`git symbolic-ref refs/remotes/origin/HEAD`) — `main` だと決め打ちしない
- `git status --porcelain` に並んでよいのは、§5 が更新する version manifest
  **だけ**である。対象は `Cargo.toml`, `Cargo.lock`, `package.json`,
  `pyproject.toml`, … である。staged かどうかは問わない — それは中断された
  release である (下記)。それ以外の path があれば **abort** する: 無関係な作業を
  release commit に相乗りさせない
- path だけでは足りない — `git add` がファイル全体を stage する。並んだ manifest
  ごとに `git diff -- <file>` と `git diff --cached -- <file>` の両方を読む。変更行は
  すべて target へ動く version 行でなければならない。この判定は §4 が target を
  確定してから行う (`Cargo.lock` は自身の package entry も持ちうる)。それ以外の
  変更行があれば、そのファイルを名指しして **abort** する — さもないと、version 行と
  hunk を共有する無関係な編集が相乗りする
- 現在の branch は既定ブランチ (通例 `main`) でなければならない — そうでないなら
  **abort** し、このチェックが通るまで ref を 1 つも動かさない。target を名指ししない
  merge は、abort が発火する前に、呼び出し元がたまたま居た branch を fast-forward
  してしまう
- その後で初めて、`git rev-list --count HEAD..origin/<default>` が 0 でなければ
  local は遅れている。target を明示的に名指しして **fast-forward だけで**同期する
  (`git merge --ff-only origin/<default>`)。失敗したら **abort** する
- 続いて `git merge-base --is-ancestor origin/<default> HEAD` が成り立たなければ
  ならない。これで push は fast-forward になる。**進んでいるのは問題ない** — §6 が
  branch を push するので、未 push の commit はこの release と一緒に出る。分岐して
  いればここで失敗する → **abort** する
- 新しい version を計算したあと、`git ls-remote --tags origin` に `vX.Y.Z` が
  既にあってはならない

### 中断された release の再開

前回の実行が途中で止まっていることがある。target が確定したら (§4、初回 release
経路では §1)、下の各成果物は**その target に一致するときだけ**残す。一致するものを
作り直さない。
中断以降に commit が入っていることがあるので、残っている bump を信じずに**水準を
決め直す** (§1)。target が変わっていれば、それは不一致である。

| 既にあるもの | 一致 → | 不一致 → **abort** し、報告する内容 |
|---|---|---|
| 変更済み/staged の version manifest | version 行だけの変更 (上のチェック) → 続行する。§5 が同じ値を書き直す | どのファイルがどの version を持つか |
| HEAD にある release commit `release: vX.Y.Z` | 下の release commit チェックを通る → 残す。§5 と commit を飛ばす | commit の version と target の対比、または commit が触る余分な path |
| **origin に無い** local の `v*` tag | そのような tag がちょうど 1 つで、名前が `vX.Y.Z` (target) であり、§6 が tag を打つ commit — release commit、初回 release 経路では HEAD 自身 — を指している → 残す。`git tag` を飛ばす | local にしか無い tag が何か、target の tag がどこを指しているか |

**local にしか無い tag。** 中断の痕跡はそれだけである。origin が申告する tag を
`git tag -l 'v*'` から引く。origin の申告は `git ls-remote --tags origin 'v*'` で
得て、`^{}` を除く。上の fetch が過去の release をすべて local へ複製する。
target の横に `v1.0.0`, `v1.1.0`, … が並ぶのは想定どおりであり、最後の行は
それらを判定しない。

**manifest が target を持つこと。** §5 が更新する root manifest のうち HEAD に
存在するものは、すべて target を持たなければならない。`git show HEAD:Cargo.toml`,
`HEAD:package.json`, … で確認する。どれかの commit がたまたま触ったものだけでは
足りない。これは再開経路に共通の条件である: release commit の再利用と、初回
release 経路で HEAD の tag を残すことの両方を規定する。

**release commit チェック。** message は証拠ではない。
`git show --name-only --format= HEAD` が §5 の version file だけを並べること。
上の「manifest が target を持つ」チェックが通ること。この 2 つがそろうときだけ再利用し、
欠ければ **abort** する。

どの abort でも、何が不一致だったかと安全な再開点を名指しする
(`git tag -d vX.Y.Z`, `git reset --soft HEAD~1`)。古い bump を黙って採用しない。

## 3. baseline の version を検出する

§1 が水準を、§3 が baseline を、§4 が target を、この順で確定する。baseline は
作業ツリーからは取らないので、前回の実行の bump がこれを動かすことはない:

- **origin に `v*` tag がある** (§1) → その最大のものが baseline である:
  `git ls-remote --tags origin 'v*' | sed 's,.*/v,,;s,\^{},,' | sort -V | tail -1`
- **origin に無い** → 初回 release。§1 が既に target を `v0.1.0` に確定しており、
  §4 は飛ばす

root manifest も読む (`Cargo.toml` の `[package] version`、無ければ
`package.json` の `.version`)。§1 の初回 release チェックがその値を必要とし、
§5 がそれを書き換える。通常の経路ではこの値は baseline に等しく、再開時は
**target** に等しい。後者は中断された release の痕跡 (§2) であってエラーではない。
§4 はいずれにせよ baseline を bump し、3 つの再開段階はすべて同じ target に
着地するからである。

## 4. target version を計算する (semver)

水準は §3 の **baseline** に適用する — manifest の version には適用しない:

| 水準 | 変換 |
|---|---|
| major | `X.y.z` → `(X+1).0.0` |
| minor | `x.Y.z` → `x.(Y+1).0` |
| patch | `x.y.Z` → `x.y.(Z+1)` |

prerelease (`-rc.1` など) はサポートしない — 手作業で行う。

## 5. version file を更新する

存在する root manifest を**すべて**更新する:

- `Cargo.toml` — 続けて `cargo check` を実行して `Cargo.lock` を追従させる。commit に **Cargo.lock を含める**
- `package.json` (root だけ。入れ子の package.json は触らない)
- `pyproject.toml` / その他の root manifest があれば

## 6. commit・tag・push

```bash
git add <updated files>
git commit -m "release: vX.Y.Z"
git tag vX.Y.Z
git push origin <branch> && git push origin vX.Y.Z
```

- message: `release: vX.Y.Z` (Conventional Commits、英語)
- **§2 が既にそろっていると判定したものは飛ばす** — 一致する release commit や
  local tag はそのまま残す。`git add` は §5 の version file だけを対象にする
- branch と tag の**両方**を push する (tag だけの push は main を置き去りにする)。
  branch の push は未 push の commit をすべて運び、fast-forward でなければならない
  — **force しない**

初回 release 経路 (origin と local のどちらにも `v*` tag が無い): §4–5 は飛ばしている。ここでは `git tag` と 2 つの push だけを行う。version は常に `v0.1.0` である (初回 release チェック、§1)。

## 7. CI を確認する

push のあと、tag を契機とする workflow が始まったことを検証し、run の URL を報告する。

- 優先: `gh run list --limit 3`
- それ以外: `curl -sf "https://api.github.com/repos/<owner>/<repo>/actions/runs?per_page=3"`

~60s 以内に何も走らなければ警告する (repo に tag を契機とする workflow が無ければ「no CI」と報告する)。

## 失敗からの復旧

途中で何かが失敗したら、正確な状態 (local の tag/commit を作ったかどうか) と復旧手順を報告する。例: `git tag -d vX.Y.Z` / `git reset --soft HEAD~1` (user の確認があるときだけ実行する — 無関係な作業を捨てない)。
