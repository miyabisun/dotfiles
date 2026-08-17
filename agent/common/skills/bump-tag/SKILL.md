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

This skill's invocation **is** explicit permission to commit, tag, and push the release — an authority the `git` skill's branch flow does not grant on its own.

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
- **Origin has none, but local `v*` tags exist** → an unpushed first release. The
  target stays `v0.1.0` and §4 is skipped; whether the tag is reusable is decided by
  the local-tag row of §2's resume table — one rule, the same for every argument.
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

1. Detect the baseline version and existing tags (see §2–3). First-release and
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
instead. Otherwise follow the first-release check above — local tags included,
since it defers to the same §2 rule every other argument uses.

## 2. Preflight (abort and report on failure)

**Verify before you move a local branch or tag.** The order below is deliberate,
and the guarantee is precise: every check passes before the first command that
moves a local branch or tag. It is not a promise of zero side effects.

**Invariants the checks defend.** Every check is a means to one of these; a state
satisfying all four is safe to release, however it got there:

- Origin's history is never lost — the branch push must fast-forward
- The release commit carries only the version files §5 updates
- The tag points at the intended default-branch commit for the target version
- Both branch and tag are pushed (tag-only push leaves the branch behind)

Checks:

- Start by fetching the origin default branch and tags (`git fetch origin --tags`).
  Fetching is a side effect: it updates remote-tracking refs and `FETCH_HEAD`, but
  no local branch or tag, so it is safe to run ahead of the checks below
- Resolve the default branch name from remote HEAD
  (`git symbolic-ref refs/remotes/origin/HEAD`) — never assume it is `main`
- `git status --porcelain` may list **only** the version manifests §5 updates
  (`Cargo.toml`, `Cargo.lock`, `package.json`, `pyproject.toml`, …), staged or not —
  that is an interrupted release (below). Any other path → **abort**: unrelated work
  must not ride in the release commit
- Paths are not enough — `git add` stages whole files. For each listed manifest read
  both `git diff -- <file>` and `git diff --cached -- <file>`; every changed line must
  be a version line moving to the target — judge this once §4 fixes it (`Cargo.lock`
  may also carry its own package entry). Any other changed line → **abort**, naming
  the file — an unrelated edit sharing a hunk with the version line rides in otherwise
- Current branch must be the default branch (usually `main`) — **abort** otherwise,
  and move no ref until this check passes. A merge with no target named would
  fast-forward whatever branch the caller happened to be on, before the abort fires
- Only then, if `git rev-list --count HEAD..origin/<default>` is non-zero, local is
  behind: sync **fast-forward only**, naming the target explicitly
  (`git merge --ff-only origin/<default>`), and **abort** if that fails
- `git merge-base --is-ancestor origin/<default> HEAD` must then hold, so the push
  fast-forwards. Being **ahead is fine** — §6 pushes the branch, so unpushed commits
  ship with this release. Diverged fails here → **abort**
- After computing the new version, `git ls-remote --tags origin` must not already have `vX.Y.Z`

### Resuming an interrupted release

A previous run may have stopped partway. Once the target is fixed (§4, or §1 on the
first-release path), keep each artifact below **only if it matches that target**;
never rebuild a matching one.
Commits may have landed since the interruption, so **re-resolve the level** (§1)
rather than trusting the leftover bump; a target that changed is a mismatch.

| Already present | Match → | Mismatch → **abort**, reporting |
|---|---|---|
| Modified/staged version manifests | version-only changes (check above) → continue; §5 rewrites the same values | which file carries which version |
| Release commit `release: vX.Y.Z` at HEAD | passes the release-commit check below → keep it; skip §5 and the commit | the commit's version vs the target, or the extra paths it touches |
| Local `v*` tags **absent from origin** | exactly one such tag, named `vX.Y.Z` (the target), pointing at the commit §6 would tag — the release commit, or HEAD itself on the first-release path → keep it; skip `git tag` | which local-only tags exist and where the target tag points |

**Local-only tags.** Only those are traces of an interruption: subtract the tags origin
advertises (`git ls-remote --tags origin 'v*'`, `^{}` stripped) from `git tag -l 'v*'`.
The fetch above copies every past release into local, so `v1.0.0`, `v1.1.0`, … standing
beside the target are expected — the last row never judges them.

**Manifests at target.** Every root manifest §5 updates that exists at HEAD
(`git show HEAD:Cargo.toml`, `HEAD:package.json`, …) must carry the target — not merely
the ones some commit happened to touch. This is the resume paths' shared condition: it
gates reusing a release commit and, on the first-release path, keeping a tag on HEAD.

**Release-commit check.** The message is not evidence. Reuse one only if
`git show --name-only --format= HEAD` lists solely §5's version files *and* the
manifests-at-target check above passes — else **abort**.

Every abort names what mismatched and the safe resume point (`git tag -d vX.Y.Z`,
`git reset --soft HEAD~1`) — never adopt a stale bump silently.

## 3. Detect the baseline version

§1 fixes the level, §3 the baseline, §4 the target — in that order. The baseline
never comes from the working tree, so a previous run's bump cannot shift it:

- **Origin has `v*` tags** (§1) → the highest of them is the baseline:
  `git ls-remote --tags origin 'v*' | sed 's,.*/v,,;s,\^{},,' | sort -V | tail -1`
- **Origin has none** → first release; §1 already fixed the target at `v0.1.0`,
  and §4 is skipped

Read the root manifests too (`Cargo.toml` `[package] version`, else `package.json`
`.version`): §1's first-release check needs that value and §5 rewrites it. It equals
the baseline on the normal path and the **target** on a resume — the latter is the
trace of an interrupted release (§2), not an error, since §4 bumps the baseline
regardless and all three resume stages land on the same target.

## 4. Compute the target version (semver)

Apply the level to the **baseline** of §3 — never to the manifest version:

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
- **Skip whatever §2 already found in place** — a matching release commit or local
  tag is kept as is; `git add` only the version files of §5
- Push **both** branch and tag (tag-only push leaves main behind). The branch push
  carries every unpushed commit and must fast-forward — **never force**

First-release path (no `v*` tags on origin or local): §4–5 were skipped, so only `git tag` + dual push here. The version is always `v0.1.0` (first-release check, §1).

## 7. Confirm CI

After push, verify a tag-triggered workflow started and report the run URL.

- Prefer: `gh run list --limit 3`
- Else: `curl -sf "https://api.github.com/repos/<owner>/<repo>/actions/runs?per_page=3"`

If nothing runs within ~60s: warn (or report "no CI" if the repo has no tag-triggered workflow).

## Failure recovery

If something fails mid-flight, report the exact state (local tag/commit created or not) and recovery steps, e.g. `git tag -d vX.Y.Z` / `git reset --soft HEAD~1` (only with user confirmation — never discard unrelated work).
