# 0001: tmuxinator YAML 向けの runtime 中立エクスポート

## Decision

**Ready with reduced scope** とする。今回の delivery は runtime 中立資産だけを残す。対象は、現在の tmux セッションを fail-closed で検査する script、安全な tmuxinator YAML 候補を作る skill、排他的に project を作成する writer、設定ディレクトリの作成、既存 `mux` の堅牢化、および関連 export test である。

Ruby/RubyGems による tmuxinator の自動導入と Gem の `PATH` 配線は削除する。Rust 互換ツールの実装と将来統合は別 delivery とする。本書は権限の証拠を整理するものであり、本書自体が変更権限を生むものではない。

Python source の formatter gate には、既存の `uvx` から pinned Ruff 0.12.7 を一時利用する。対象2ファイルだけを format/lint し、repository dependency、設定ファイル、system package は追加しない。これは `$deliver` が許可する bounded development tooling として扱う。

## Decision owner

- 目的と runtime 中立の許可効果: user（下記原文）
- Ruby 導入を除外する縮小スコープ: delivery/discuss agent（unknown を user-origin と扱う規則を適用）

## Authority evidence

一次根拠は、この delivery を起動した user request の次の原文である。

> セッション数がやたら増えたので、tmuxinatorを導入したいです。
> やりたいことは、スキルで現在セッションのwindows&paneが何をやっているのか？をチェックして、それを作るYAMLファイルをスキルに吐き出してもらいたいです。
> 折角muxコマンドをzsh使って導入したのに、それを使わないのは勿体ないなと思ってます

#754/#860 で中継された Ruby 回避意向は、この pane から一次記録を直接確認できない。ただし `discuss` の unknown は user-origin として扱う規則に従い、Ruby 導入を禁止する方向の制約として扱う。直接原依頼は、残す runtime 中立スコープを許可している。

## Authorized effects

Allowed:

- 現在の tmux セッションについて、window/pane の構造、cwd、layout、現在のコマンド名を検査する。
- pane ID を先に列挙し、各 metadata field を個別取得して区切りを曖昧にせず、型、形式、control character、明示的な URL/assignment-like metadata を stdout 出力前に検証する。異常時は raw value を出さず一般エラーで停止する。host に見えるローカル path segment は network endpoint と推測しない。
- 安全な再実行コマンドだけを含む YAML 候補を提示し、user の承認後に tmuxinator 設定へ新規作成する。利用可能な tmuxinator があれば `tmuxinator debug` で検証する。
- absolute かつ安全な project filename だけを受け付ける専用 writer で、root から config directory まで全 path component を symlink を辿らず開き、`0600` で排他的に作成し、flush/fsync する。失敗時は作成途中の宛先を cleanup する。
- `~/.config/tmuxinator` を作成し、既存 `mux` が設定ディレクトリの `.yml` / `.yaml` を安全に選択できるようにする。
- runtime 中立の export test、shell 検査、skill 検証を追加する。

Forbidden:

- Ruby/RubyGems/tmuxinator の自動インストールと Gem の `PATH` 配線。
- 既存 YAML の上書き、YAML 作成直後のセッション自動起動、現在以外のセッションの暗黙な取得。
- scrollback、プロセス引数、環境変数、`.env`、secret store の取得や保存。
- 未検証 metadata の部分出力、相対・不正 filename への書込、config directory/destination symlink の追跡、既存または競合生成された宛先の変更。
- Rust 互換ランチャーの新規実装、または tmuxinator 以外への置換。
- 保護された無関係変更 `agent/claude/settings.json`、`agent/common/skills/deliver/SKILL.md`、`agent/common/skills/discuss/**` の変更。

## Supersedes / updates

- 既存の decision/document を supersede しない。本書は user 原文と unknown-as-user-origin 制約を索引化する `agent-origin / decision evidence` である。
- `agent/common/skills/tmuxinator-export/SKILL.md`: `agent-origin / binding instruction`。validated inspection と exclusive writer を workflow の必須手順にする。
- `agent/common/skills/tmuxinator-export/scripts/inspect-session.sh`: `agent-origin / implementation artifact`。全 metadata を stdout 前に fail-closed 検証する。
- `agent/common/skills/tmuxinator-export/scripts/write-project.py`: `agent-origin / implementation artifact`。安全な宛先だけを排他的に作成する。
- `bin/install-apps`、`config/bash/exports.sh`、`test/install-apps.bash`: Ruby/tmuxinator 導入案の途中変更を取り消し、delivery 前の状態を維持する。
- `test/tmuxinator-install-apps.bash`: Ruby/tmuxinator 自動導入 test の途中追加を取り消し、delivery 対象に含めない。

これらは commit に含める変更ではなく、Ruby 導入禁止に合わせて途中案を除外した記録である。新しい効果、対象、公開範囲、権限主体を追加しない。

## Rejected alternatives

- RubyGems で tmuxinator を自動導入する案: Ruby 回避制約と競合するため却下。
- Rust 製の tmuxinator 互換ランチャーを同時に作る案: 互換性、設定形式、ライフサイクルを新たに決める必要があるため却下。将来統合を含め別 delivery とする。
- Python formatter を system install または repository dependency として追加する案: 今回の2 script を検査する目的に対して影響範囲が広いため却下。pinned one-shot tool を採用する。
- pane の実行引数や scrollback から完全な再開コマンドを復元する案: secret や破壊的操作を保存・再実行する危険があるため却下。既知の安全な bare command 以外は空 shell にする。
- 既存 YAML を更新する案: 意図しない設定消失を避けるため却下。既存パスがあれば停止する。

## Non-goals

- 実行中プロセスの状態、履歴、引数、接続先の完全復元。
- Ruby/RubyGems/tmuxinator の自動導入、Gem `PATH` 配線、tmuxinator 自体の再実装、既存 YAML の移行。
- Rust 互換ツールの実装、およびそのツールと skill/`mux` の統合。
- YAML の自動適用、session の自動停止・削除・再起動。

## Premises

- tmuxinator YAML が要求された session 再構成面であり、生成・選択機能は runtime の導入方法から分離できる。この前提により runtime 中立資産だけを残し、崩れれば境界設計を再開する。
- `pane_current_command` だけでは安全な引数を復元できない。この制約により bare command の allowlist と空 shell を採用し、破れば secret 漏えいまたは危険な再実行が起こり得る。
- tmux metadata と filesystem は検査・承認中にも攻撃または競合し得る。この制約により、全件検証後の一括出力と専用の排他的 writer を必須にし、破れば sensitive value の部分漏えい、symlink 越しの書込、または既存ファイル破壊が起こり得る。
- 既存の `mux` は project 名から外部 runtime を呼ぶ狭い境界である。この前提により、runtime の導入や将来の Rust 統合を独立課題にできる。
- Ruby 回避意向の一次記録はこの pane で確認できないが、unknown-as-user-origin 規則が適用される。この前提により Ruby 配線を削除し、反証となる直接指示があれば runtime 選択を再開する。

## Reopen triggers

次の場合に限り再開する。

- 権限範囲外の変更が必要になった。
- 上記 Premises が偽と判明した、または上位 instruction と新しい競合が生じた。
- mandatory verification を満たせない。
- 未受容の重大リスク（secret 保存、破壊的コマンド再実行、既存 YAML 上書き等）が見つかった。

期限内に反証がなければ、default action は runtime 中立資産だけを維持する。権限不足は default で越えない。

## Verification

Mandatory:

- `bash test/tmuxinator-export.bash`: PASS が必須。
- 同 test は明示 URL、field 内の tab/改行、ANSI/control character、不正 layout、pane ID 不一致、既存宛先、destination symlink、config-directory symlink の拒否、raw value 非漏えい、作成 mode `0600` を regression 検証する。通常の host-like local path は受理する。
- 残存する関連 shell の `bash -n` / `zsh -n` と `shellcheck`、Python source の副作用なし compile: PASS が必須。
- `quick_validate.py` と `package_skill.py` による skill 検証・package: PASS。
- 実 tmux 内で current session の inspection: PASS。
- 独立 semantic review: PASS が必須。#860 は旧決定の A を FAIL とし、本縮小案を推奨した。
- 新 snapshot に対する security full rerun: mandatory。initial union は #864 counterpart approve と local security snapshot reject に分かれたため、強化後の同一 snapshot に対する両 receipt で delivery gate を閉じる。

Ruby/tmuxinator の install-apps test と実 sudo install は削除対象に対応するため非該当。

既知リスクへの対応は次のとおり。

- metadata 漏えい・誤解釈: pane ID 列挙後の field 単位取得、stdout 前の全件 validation と control/明示 URL/assignment-like metadata 拒否（prevention）、一般エラーかつ raw rejected value 非出力、および negative regression（detection）。host に見える通常のローカル directory 名は拒否しない。
- filesystem race・symlink・上書き: safe absolute filename、実 config directory、no-follow 相当、exclusive create、`0600`（prevention）、既存/競合/symlink の明示拒否 test（detection）、write failure cleanup と既存宛先不変（recovery）。
- 危険コマンド再実行: bare command allowlist と空 shell（prevention）、書込前候補提示と利用可能時の `tmuxinator debug`（detection）、自動起動しないこと（recovery 可能性の維持）。

## Readiness

| Gate | 判定 | 根拠 |
|---|---|---|
| A. Authority closure | PASS | 直接原依頼が runtime 中立の inspection/YAML/`mux` 効果を許可する。unknown-as-user-origin の Ruby 回避制約には Ruby 配線の削除で適合し、Rust 実装は行わない。 |
| B. Conflict closure | PASS | binding instruction の変更は不要。競合する Ruby 導入 artifact は exact-conformance の削除対象に限定した。 |
| C. Product closure | PASS | runtime 中立資産だけを採用し、Ruby 導入、Rust 実装、完全なコマンド復元、上書き、自動起動を非目標または却下案に固定した。 |
| D. Risk closure | PASS | metadata の全件事前検証、raw value 非漏えい、排他的 no-follow 相当 writer、`0600`、fsync、failure cleanup に prevention/detection/recovery が対応する。runtime 選択リスクは別 delivery に隔離した。 |
| E. Verification closure | PASS | malformed/sensitive metadata と filesystem race/symlink/permission の negative test、syntax/lint/compile、skill package、実 tmux inspection、semantic/security review を mandatory に対応付けた。install 検証は非該当。 |
| F. Independent executability | PASS | validated inspection と exclusive writer を必須手順として固定し、変更対象、禁止事項、検証、権限範囲を本書と repository から復元できる。blocking question はない。 |

旧決定に対する独立 discuss review #860 の A=FAIL は、Ruby 配線を削除対象にして解消した。本縮小内容の semantic review と新 snapshot の security full rerun の PASS を delivery 完了条件とし、A〜F は縮小スコープで Implementation Ready。
