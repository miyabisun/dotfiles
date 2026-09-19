# Optional tools and secrets

Run these commands from the dotfiles checkout after [installation](../README.md).
Application downloads and vault access are separate from `bin/install`.

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

