---
name: bump-tag
description: >-
  Bump semver, commit, tag, and push to fire release CI. Supports auto
  (infer from commits), major, minor, patch, or first (explicit first
  release). Use when the user asks to bump version, cut a release, tag a
  release, or run bump-tag.
---

# bump-tag

Release the current repository: bump version → commit → tag → push → confirm CI.

**Argument** (optional): `auto` | `major` | `minor` | `patch` | `first`  
Default: `auto`

This skill's invocation **is** explicit permission to commit, tag, and push — overriding the `git` skill's branch flow, which otherwise keeps commits off a shared branch.

A release task the user issued can also carry that order, on narrower terms.
**What a claimed task grants is the same procedure, not the same scope.**
That authority covers only the repository, branch, and operation the task names,
and it lives only while a worker skill the user invoked holds it. The authority
ends when the task does — never manufacture it yourself.
**Never create the release task that would authorize your own release.**

## When a release happens

**Release never rides along with ordinary delivery or a worker loop.** No
routine delivery, review, or worker cycle fires this skill on its own. A
release happens in exactly two cases: the user invokes this skill, or a
release task the user issued is claimed and calls it.

## 1. Resolve bump level

### First-release check (all arguments)

Before resolving any level, check release tags on **origin** — the source of
truth — with `git ls-remote --tags origin`, and locally with `git tag -l 'v*'`:

- **Origin has `v*` tags** → already released. Resolve the argument below.
- **Origin has none, but local `v*` tags exist** → **abort**, whatever the
  argument: inconsistent state (likely an interrupted or unpushed release).
  Inspect and resolve the local tags, then rerun.
- **No `v*` tags on origin or local** and the manifest version (§3) is
  `0.1.0` → first release. Do **not** bump, whatever the argument. If an
  explicit `major` / `minor` / `patch` was given, state that the level is
  ignored because this is the first release. Note the first release, run
  §2–3 as usual, skip only §4–5, then continue at §6 with tag `v0.1.0`.
- **No `v*` tags on origin or local** but the manifest version is not
  `0.1.0` → **abort**, whatever the argument. Recovery: set the manifest
  version to `0.1.0`. First releases are always `v0.1.0`; anything else is
  outside bump-tag's guarantee.

### `auto`

If a release task named the level (`auto` / `major` / `minor` / `patch` /
`first`), take that value as given and resolve it in the matching section
below. **Never substitute `auto` for a level the task named.** `auto` is the
default only when neither the user nor the task named a level.

1. Detect current version and existing tags (see §2–3). First-release and
   inconsistent-tag cases are handled by the check above — origin tags exist here.
2. Inspect subjects and relevant diffs in
   `git log <latest-tag>..HEAD`; do not infer from the type token alone. Choose:

| Level | When |
|---|---|
| **minor** | Only a critical breaking change: an incompatible API, CLI, config, or data format that forces existing users or data to migrate |
| **patch** | Everything else — new features, options, commands, corrections, maintenance, tests, docs, performance, refactors |

`auto` **never chooses major**, at any version. A major bump happens only when
the user explicitly invokes `bump-tag major` — breakage alone is never grounds
for it, and 0.x → 1.0.0 likewise happens only on explicit user request.

Commit types are evidence, not authority. A `feat` commit is still a patch —
adding a capability does not raise the level. Only verified breakage of
existing users or data reaches minor, whatever the commit was labeled.

Show the chosen level and 2–3 lines of rationale (cite commits) before continuing.

**Tie-break**: prefer **patch** over minor when unsure. If the evidence of
breakage is weak, it is a patch.

### `major` / `minor` / `patch`

Use that level directly (still run all checks below).

### `first`

Explicit first release. If origin has any `v*` tag → **abort**: this
repository has already released; use `auto` / `patch` / `minor` / `major`
instead. If origin has none but local `v*` tags exist → abort as inconsistent
state (first-release check above). Otherwise follow the first-release check above.

## 2. Preflight (abort and report on failure)

**Verify before you move a local branch or tag.** The order below is deliberate,
and the guarantee is precise: every check passes before the first command that
moves a local branch or tag. It is not a promise of zero side effects.

- Start by fetching the origin default branch and tags (`git fetch origin --tags`).
  Fetching is a side effect: it
  updates remote-tracking refs and `FETCH_HEAD`, but no local branch or tag,
  so it is safe to run ahead of the checks below
- Resolve the default branch name from remote HEAD
  (`git symbolic-ref refs/remotes/origin/HEAD`) — never assume it is `main`
- `git status --porcelain` must be empty (no unrelated changes in the release commit)
- Current branch must be the default branch (usually `main`) — **abort** otherwise,
  and move no ref until this check passes. A merge with no target named would
  fast-forward whatever branch the caller happened to be on, before the abort fires
- Only then sync the default branch **fast-forward only**, naming the target
  explicitly (`git merge --ff-only origin/<default>`); if local is ahead of or
  diverged from origin, **abort**
- After the sync, `HEAD` must match `origin/<default>` — **abort** otherwise,
  so a tag is never cut on a stale state
- After computing the new version, `git ls-remote --tags origin` must not already have `vX.Y.Z`

## 3. Detect current version

Priority:

1. `Cargo.toml` → `[package] version`
2. `package.json` → `.version`
3. Else latest `v*` git tag

## 4. Compute new version (semver)

| Level | Transform |
|---|---|
| major | `X.y.z` → `(X+1).0.0` |
| minor | `x.Y.z` → `x.(Y+1).0` |
| patch | `x.y.Z` → `x.y.(Z+1)` |

Prereleases (`-rc.1`, etc.) are unsupported — do those manually.

## 5. Update version files

Update **every** root manifest that exists:

- `Cargo.toml` — then run `cargo check` so `Cargo.lock` follows; **include Cargo.lock** in the commit
- `package.json` (root only; do not touch nested package.json)
- `pyproject.toml` / other root manifests if present

## 6. Commit, tag, push

```bash
git add <updated files>
git commit -m "release: vX.Y.Z"
git tag vX.Y.Z
git push origin <branch> && git push origin vX.Y.Z
```

- Message: `release: vX.Y.Z` (Conventional Commits, English)
- Push **both** branch and tag (tag-only push leaves main behind)

First-release path (no `v*` tags on origin or local): §4–5 were skipped, so only `git tag` + dual push here. The version is always `v0.1.0` (first-release check, §1).

## 7. Confirm CI

After push, verify a tag-triggered workflow started and report the run URL.

- Prefer: `gh run list --limit 3`
- Else: `curl -sf "https://api.github.com/repos/<owner>/<repo>/actions/runs?per_page=3"`

If nothing runs within ~60s: warn (or report "no CI" if the repo has no tag-triggered workflow).

## Failure recovery

If something fails mid-flight, report the exact state (local tag/commit created or not) and recovery steps, e.g. `git tag -d vX.Y.Z` / `git reset --soft HEAD~1` (only with user confirmation — never discard unrelated work).
