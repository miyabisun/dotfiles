---
name: config-merge
description: >-
  agent harness の live config (~/.codex/config.toml、~/.claude/settings.json)
  と、~/projects/miyabisun/dotfiles 側の portable な config を突き合わせる。
  設定がローカルで変わったとき、dotfiles が別のマシンから設定を持ち込んだとき、
  または user がマシン固有の状態を失わずに config の merge・同期・promote・
  配布を求めたときに使う。
---

# config-merge

agent harness の設定は、ファイルを闇雲に結合するのではなく意味で同期する。
portable な意図は dotfiles に置き、runtime やマシン固有の状態は live config に
だけ置く。

## ファイル

対象は harness ごとの pair である。**user が名指しした pair だけ**を扱う。

| harness | 稼働 (live) | 共有 (dotfiles) | 形式 |
| --- | --- | --- | --- |
| Codex | `$HOME/.codex/config.toml` | `agent/codex/config.toml` | TOML |
| Claude Code | `$HOME/.claude/settings.json` | `agent/claude/settings.json` | JSON |

dotfiles の root は `$HOME/projects/miyabisun/dotfiles` である。

live が shared file へ解決される symlink なら、移行の blocker として扱う。
self-merge を試みない。legacy symlink はまず `bin/install` が移行しなければ
ならない、と報告する。

## 1. 両側を調べる

1. 両方のファイルが存在し、別々の通常ファイルであることを確認する。
2. 編集する前に両方を parse する。TOML は TOML として、JSON は `jq -e .` で
   読む。どちらかが不正なら、変更せずに止まる。
3. dotfiles の作業ツリー、config diff の全体、直近の config 履歴を調べる
   (`<shared>` は上の表の共有 path):

   ```text
   git -C "$HOME/projects/miyabisun/dotfiles" status --short
   git -C "$HOME/projects/miyabisun/dotfiles" diff -- <shared>
   git -C "$HOME/projects/miyabisun/dotfiles" log -p -5 -- <shared>
   ```

4. dotfiles の無関係な変更と、事前に stage 済みの作業を保持する。
5. live config を編集する前に、一時的な backup を保存する。

## 2. 設定を分類する

user が portability を明示的に求めない限り、次はローカルに留める。
どちらの harness にも共通するのは、**harness 自身が live file へ書き戻す
runtime の状態**である。

- 認証・credential・token・session の状態・履歴
- マシンの path・デバイス固有のコマンド・host 固有の endpoint
- Codex: `projects.*` / `tui.model_availability_nux.*` / `hooks.state.*`
- Claude Code: `model` — このマシンとセッションの状態であって portable な意図
  ではない。ほかに harness が書き込むと確認できた key も同じ扱いにする

secret や host 限定の値を含まないなら、次は portable の候補として扱う:

- Codex: model・personality・approvals・sandbox といった振る舞いの既定値 /
  `features.*` / `agents.*` / 再利用できる `mcp_servers.*` の定義 /
  恒常的な TUI と通知の設定 / 再利用できる hooks と sandbox の設定
- Claude Code: `permissions` / `hooks` / `env` / `outputStyle` / `language` /
  `effortLevel` — いずれも user が意図して選んだ振る舞いである

混在する table や object は field ごとに分類する。**key の順序が動いただけで
値が同じものは差分として扱わない** — harness が書き戻すときに順序を並べ替える
ことがある。静的な authorization header・bearer
token・credential・秘密鍵・secret な環境変数の値は一切 promote しない。環境変数の
名前それ自体は secret に当たらない。

## 3. reconcile する

編集する前に ledger を組み立てる:

- **promote**: live config にだけある portable な設定 -> shared へ追加する
- **import**: shared config にだけある portable な設定 -> live へ追加する
- **local**: マシン・runtime の設定 -> live にだけ残す
- **aligned**: 両側で等価 -> 変更しない
- **conflict**: 両側で portable な値が異なる -> user の意図・config 履歴・
  周辺の変更から解決する

conflict では、より新しい意図的な変更である証拠が明確な値を優先する。証拠が
不十分で、かつ振る舞いが実質的に変わるなら、その key については両ファイルとも
変更しないまま conflict を報告する。安全に reconcile できる独立した項目に
ついては問い合わせない。

comment・順序・書式は保ったまま、正確な編集を加える。数個の値を変えるためだけに
ファイル全体を serialize して置き換えない。**JSON でも同じである** — `jq` の
出力でファイルを丸ごと置き換えると key の順序が変わるので、読むのに使い、
書くのは局所編集で行う。shared config で見つかった local 限定の状態は、
live config に保持したうえで取り除く。

reconcile 後は、portable な設定がすべて両ファイルで一致しているはずである。
local 限定の設定は live file に残り、shared には無いはずである。

## 4. 検証する

1. 両方のファイルを再び parse する (TOML は TOML として、JSON は `jq -e .`)。
2. runtime の check は harness ごとに違う。Codex は
   `codex --strict-config --version` を実行する。Claude Code には
   `--strict-config` に相当するものが無い。`claude doctor` は settings を
   読むが schema validator ではないので、**JSON として妥当なことの確認は
   `jq -e .` が担う**。
3. `git -C "$HOME/projects/miyabisun/dotfiles" diff --check` を実行する。
   shared config diff の全体を確認する。
4. secret や local 限定の table が shared の diff に入っていないことを確認する。
5. live file が symlink ではなく、保持した local の状態を今も含むことを確認する。

commit・pull・push・reset・restore・変更の破棄はしない。これらの操作には、
user の明示的な意図が別途必要である。

## 出力

次を報告する:

```text
promoted: <portable settings moved to dotfiles>
imported: <portable settings moved to live config>
local: <settings retained only on this machine>
conflicts: <unresolved keys or none>
verification: <checks performed>
```
