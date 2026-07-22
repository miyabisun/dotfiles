---
name: push
description: >-
  Push the current Git branch's committed history to a remote with explicit
  destination resolution, fast-forward safety checks, and post-push
  verification. Use only when the user explicitly invokes push or explicitly
  asks to run git push. Never commit, tag, force-push, delete refs, or release.
---

# push

Push one current branch safely. Keep this separate from `commit`, which records
local changes, and release workflows such as `bump-tag`, which may push tags.

An explicit `$push` invocation authorizes one ordinary branch push and the
bounded fetches needed to inspect and verify it. It does not authorize commit,
tag, merge, pull, rebase, amend, force-push, ref deletion, deploy, release,
remote configuration changes, or credential changes. The only permitted local
configuration change is setting the current branch's upstream during its first
unambiguous push.

## Inputs

| Arg | Required | Meaning |
|---|---|---|
| `remote` | no | Existing remote name |
| `branch` | no | Destination branch name |

Free text may identify a remote or destination branch, but never treat extra
text as an arbitrary refspec or command-line option.

## 1. Inspect and resolve the destination

Inspect before network or configuration changes:

```text
git status --short --branch
git symbolic-ref --quiet --short HEAD
git remote
git config --get branch.<current>.remote
git config --get branch.<current>.merge
git config --get branch.<current>.pushRemote
git config --get remote.pushDefault
git rev-parse HEAD
```

- Stop outside a Git repository, on detached HEAD, with unmerged entries, or
  while a merge, rebase, cherry-pick, or revert is in progress.
- Do not print remote URLs. They may contain credentials. If Git includes a URL
  in diagnostic output, redact embedded usernames, passwords, and tokens before
  showing it to the user.
- Validate a selected remote against `git remote` and a destination branch with
  `git check-ref-format --branch`. Reject option-like values, delete refspecs,
  wildcards, and arbitrary source refspecs.
- Uncommitted changes are not part of a push. Report them, but do not block an
  otherwise safe push and never stage, commit, stash, restore, or discard them.

Resolve the remote in this order:

1. The user's explicit `remote`.
2. `branch.<current>.pushRemote`.
3. `remote.pushDefault`.
4. The current branch's upstream remote.
5. The only configured remote.
6. `origin` when it exists and no stronger evidence conflicts.

If multiple plausible remotes remain, stop and ask. Never guess from a URL.

Resolve the destination branch independently:

1. Use the user's explicit `branch` when provided.
2. Otherwise, when the selected remote is the upstream remote, use the remote
   branch named by `branch.<current>.merge` (strip `refs/heads/`).
3. Otherwise, use the current local branch name.

This distinction is mandatory: a local `bar` tracking `origin/foo` must push to
`foo`, not silently create `origin/bar`. Display both local and destination
names whenever they differ. Use `--set-upstream` only when the current branch
has no upstream and the destination was resolved unambiguously.

## 2. Inspect the remote state

Fetch only the selected destination branch without tags, then compare its tip
with local `HEAD`. Treat this as an early, understandable divergence check, not
as a concurrency guarantee; the server's non-fast-forward rejection is the
authoritative safety boundary.

- Remote tip is an ancestor of local `HEAD`: list the commits that will push.
- Tips are equal: report `up-to-date` and do not run push.
- Local `HEAD` is an ancestor of the remote tip: stop as `behind`.
- Neither is an ancestor: stop as `diverged`.
- Destination does not exist: treat it as a first push only after distinguishing
  a missing ref from network, authentication, and remote failures.

Before pushing, report the remote name, local branch, destination branch, local
HEAD, commit count and subjects, whether upstream will be set, and any dirty
paths that will remain local. Do not expose credential-bearing URLs.

Do not pull, merge, rebase, retry, or change settings to repair a failed
preflight. Report the exact state and let the user choose a separate action.

## 3. Push exactly one branch

Use an explicit full destination ref and `--porcelain`:

```text
git push --porcelain -- <remote> HEAD:refs/heads/<destination>
```

For an unambiguous first push only:

```text
git push --porcelain --set-upstream -- <remote> HEAD:refs/heads/<destination>
```

Never add `--force`, `--force-with-lease`, `--mirror`, `--tags`,
`--follow-tags`, `--delete`, a deletion refspec, an arbitrary source refspec,
or push options. Do not push any other branch or tag. A user request for one of
those operations requires a different, explicitly scoped workflow; this skill
must not broaden its authority.

Treat the command exit status and per-ref porcelain status as the primary push
result. On a hook rejection, non-fast-forward rejection, network failure, or
authentication failure, report the failure without automatic retry or local
history changes.

## 4. Verify

After a successful porcelain result:

1. Record local `HEAD`.
2. Read `refs/heads/<destination>` with `git ls-remote --heads`.
3. If the remote SHA equals local `HEAD`, verification passes.
4. If it differs, fetch the destination again. If local `HEAD` is an ancestor
   of the new remote tip, report that this push succeeded and the remote
   advanced immediately afterward. Otherwise report a verification mismatch;
   do not claim the push failed and do not retry automatically.
5. Confirm dirty paths remain unstaged and uncommitted unless they changed for
   an independently observed reason.

## Output

```json
{
  "pushed": true,
  "remote": "origin",
  "local_branch": "main",
  "destination_branch": "main",
  "commits": ["<sha> <subject>"],
  "local_changes": ["path remaining uncommitted"],
  "verification": "remote_matches|remote_advanced|up-to-date"
}
```

For an up-to-date no-op, return `pushed: false`, an empty `commits` list, and
`verification: "up-to-date"`. This is a successful synchronization result but
not a claim that a remote ref was updated, so no porcelain push result exists.

On failure, return `pushed: false`, the failed phase and exact safe diagnosis,
whether any ref was updated, and the unchanged local-work state.

## Hard rules

- Push only committed history from the current branch to one branch ref.
- Never force, delete, push tags, or push multiple refs.
- Never create a commit or modify history.
- Never expose credentials or credential-bearing remote URLs.
- Never claim that a remote ref was updated without a successful porcelain
  result and verification.
- Never push when the destination is ambiguous.
