# meiseki / meiseki-lint / meiseki-rewrite が共有する部分だけを持つ library。
# 実行ファイルではなく、各 script が自分の実体の隣から source する
# (~/.local/bin の symlink 越しでも readlink -f で repo の bin dir に解決できる)。
#
# source する側は先に meiseki_prog (診断と usage の名乗り) と
# meiseki_usage_note (usage の 2 行目) を置く。
# shellcheck shell=bash
# 定数は source する側が使い、meiseki_prog / meiseki_usage_note は source する側が
# 置く。library 単体では未使用・未代入に見えるだけなので黙らせる。
# shellcheck disable=SC2034,SC2154

meiseki_home="$HOME/.local/share/meiseki"
skill_dir="$meiseki_home/.agents/skills/meiseki"
key_file="$HOME/.cli-proxy-api/client.key"
base_url="http://127.0.0.1:8317"

# 決定論層 (npx / textlint) と、claude が起動する子プロセスにも node を見せる。
# fnm の per-shell path は非対話 shell から見えないため、安定 alias を前置する。
PATH="$HOME/.local/share/fnm/aliases/default/bin:$PATH"

# textlint の起動形 (package・version・config・formatter) はここだけが持つ。
# meiseki-lint はこの配列をそのまま実行し、meiseki-rewrite は同じ配列を
# 1 行へ展開して prompt に埋め込む。claude の --allowedTools 'Bash(npx:*)' は
# 単一コマンドにしか一致しないので、&& / リダイレクト / mktemp を混ぜない。
build_textlint_cmd() { # <config> <target>
    textlint_cmd=(
        npx --min-release-age=7 --yes
        --package textlint@14.8.4
        --package textlint-rule-preset-ja-technical-writing@10.0.2
        --package textlint-rule-preset-ai-writing@1.1.0
        --package textlint-rule-prh@6.1.0
        textlint -c "$1" -f json "$2"
    )
}

usage() {
    echo "usage: $meiseki_prog <file>   |   echo \"text\" | $meiseki_prog" >&2
    echo "  $meiseki_usage_note" >&2
}

# 前提の欠落と使い方の誤りは stderr に 1 行だけ出して exit 2。stdout は常に空に保つ。
die() {
    echo "$meiseki_prog: $1" >&2
    exit 2
}

# 位置引数は 1 個まで。file を取らなければ stdin から読む。
parse_args() {
    file=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 2
                ;;
            -*)
                die "unknown option: $1"
                ;;
            *)
                [[ -z "$file" ]] || die "unexpected argument: $1"
                file="$1"
                shift
                ;;
        esac
    done

    if [[ -n "$file" ]]; then
        [[ -f "$file" && -r "$file" ]] || die "unreadable file: $file"
    elif [[ -t 0 ]]; then
        die "no input: pass a file or pipe text into $meiseki_prog"
    fi
}

# file / stdin のどちらも <dest> へ raw bytes のまま正規化する。
read_input() { # <dest>
    if [[ -n "$file" ]]; then
        cat -- "$file" >"$1"
    else
        cat >"$1"
    fi
    [[ -s "$1" ]] || die 'empty input'
}
