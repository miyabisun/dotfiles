# Optional tools and secrets

Run these commands from the dotfiles checkout after [installation](../README.md).
Application downloads and vault access are separate from `bin/install`.
Checkout sync is the exception: `bin/install` wires it on machines that opt in.

## pen CLI updates

From the checkout, install or update pen:

```bash
bash bin/install-apps --run-step install_pen
```

The current version is left in place.
Downloads must pass checksum and version checks before replacing a binary.
An installed legacy pen banner is recognized for a one-time upgrade.
Banner-only v0.1.0/v0.1.1 releases are rejected as new download artifacts.
Failures preserve the existing binary. Fix the release or connection, then retry.
Unrecognized targets are refused.

## Checkout sync

`sync-checkouts` keeps long-lived checkouts on their upstream branch, like a Git watchtower.
A machine opts in by creating `~/.config/sync-checkouts.list`.
Each line is `<dir><TAB><activation>`. A leading `~/` means `$HOME`.
The activation runs with `sh -c` inside `<dir>` after the checkout moves; `-` means none.

```text
~/projects/miyabisun/dotfiles/master	./bin/install
~/projects/household/knowledge/main	-
```

With the list present, `bin/install` links the `sync-checkouts` command into `~/.local/bin`,
links `sync-checkouts.service` and `.timer` into `~/.config/systemd/user`, and enables the timer.
It runs every four minutes. Without the list, nothing is installed.
To pause syncing, move the list away; `bin/install` would re-enable a merely stopped timer.

Each entry is fetched and fast-forwarded only. Modified tracked files, a detached HEAD,
a missing upstream or a diverged branch skip the entry and leave it untouched.
Untracked files do not block a fast-forward. Git refuses one that would overwrite them.
A failed activation is retried on the next run. Results go to the journal:

```bash
journalctl --user -u sync-checkouts.service -n 20
```

## Rust toolchain

Install development Rust with rustup in the user area (`~/.rustup`, `~/.cargo/bin`).
Each repository's `rust-toolchain.toml` selects its pinned version and components inside it.
Elsewhere the default stable toolchain is used.
The shell settings source `~/.cargo/env`, which puts `~/.cargo/bin` before `/usr/bin`.
rustup's cargo then wins over a system `rust` package.
Leave the system package in place; sudo is not needed.

```bash
curl -sSf https://sh.rustup.rs -o /tmp/rustup-init.sh
sh /tmp/rustup-init.sh -y --no-modify-path --profile minimal --default-toolchain stable -c clippy -c rustfmt
rm /tmp/rustup-init.sh
# Install a pinned version per repository first; concurrent auto-install during a build can break it.
(cd <repository> && rustup toolchain install)
cargo --version   # pinned inside the repository, stable elsewhere
```

If a build fails with `can't find crate for std`, run `rustup toolchain uninstall <version>` and install it again.

## Bitwarden commands

Commands in `bin/bw/` use `rbw` and `jq` to manage secrets and keys.
Each command takes a subcommand. Run it without arguments to see usage.

| Command | Bitwarden folder | Subcommands |
|---|---|---|
| `bw-secret` | CLI | `save <name> <value>` / `load` / `list` / `remove <name>` |
| `bw-ssh-key` | SSH Keys | `generate <name>` / `save <name> [filename]` / `load <name> [filename]` / `public <name>` / `private <name>` / `list` / `remove <name>` |
| `bw-ssh-config` | SSH Config | `save [name]` / `load <name>` / `load-all` / `cat <name>` / `list` / `remove <name>` |
| `bw-age` | Age Keys | `create [name]` / `save [name] [file]` / `identity [name]` / `recipient [name]` / `list` / `remove <name>` |
| `bw-env` | Env Files | `save <name> [file]` / `load <name> [file]` / `diff <name> [file]` / `get <name> <var>` / `keys <name>` / `list` / `remove <name>` |

- `bw-secret load` writes secrets to `~/.config/.secrets` as `export KEY="VALUE"` lines.
  `save` and `remove` refresh the file automatically.
- `bw-age create` generates a key with `age-keygen` and stores it in Bitwarden.
  It does not write the key to disk. For a stored key named `personal`, use Bash or Zsh:

  ```bash
  age -d -i <(bw-age identity personal) file.age
  ```

- `bw-env` stores an entire `.env` file as one secure note.
  It does not export variables into the shell.
  `load` restores the file with mode `0600`; `get` prints a variable for scripting.

### Check before restoring an environment file

`bw-env diff <name> [file]` compares the local file with the stored copy.
It is read-only. By default, output contains keys and counts without values.

| Marker | Meaning |
|---|---|
| `-` | Only in Bitwarden |
| `+` | Only in the local file |
| `~` | Present in both, with different values |
| `#` | Summary counts |

Exit status is `0` for a match, `1` for differences, and `2` for an error.
Check the result before `bw-env load` overwrites a local file.
`--values` (`-v`) also prints secret values; use it only where that output is appropriate.

Quoted multiline values and bare PEM blocks are compared as a whole.
Repeated keys use their first occurrence, as in `bw-env get`.
Unparseable assignments such as `KEY = value` produce an error with the line number.
Unquoted wrapped text is treated as separate assignments.
Names resembling base64 fragments are counted but hidden from the default output.
They may contain part of a secret value.
Comparison is byte-for-byte: CRLF and LF endings produce differences.

## TypeSafe credentials

First store your own shell-compatible key file in your configured vault:

```bash
bw-env save typesafe path/to/typesafe.env
```

The file must contain `TYPESAFE_API_KEY=...`.
Then update the shared skills and shell configuration from the checkout:

```bash
git pull --ff-only
bash bin/install
bash bin/install-envs
```

`install-envs` requires a configured, logged-in `rbw` and `jq`.
It unlocks and syncs the vault, then restores `Env Files` / `typesafe`.
The destination is `~/.config/typesafe/env` (directory `0700`, file `0600`).
Retrieval failures leave the existing file intact. Key values are never printed.
Run it again when the key changes; `bin/install` does not retrieve secrets.
New bash/zsh sessions export the key from the local file without calling `rbw`.
For an existing shell or a non-interactive API call, load it explicitly:

```bash
. "$HOME/.config/typesafe/env" && export TYPESAFE_API_KEY
```

The official TypeSafe skill is installed separately on each machine.
If it is absent, use Codex's bundled skill installer:

```bash
python3 "${CODEX_HOME:-$HOME/.codex}/skills/.system/skill-installer/scripts/install-skill-from-github.py" \
  --repo typesafe-ai/skills --path skills/typesafe-ai
```

The skill is available on the next agent turn.
See the [official TypeSafe skill documentation](https://docs.typesafe.ai/agent-skill)
for other agents and updates.

