---
name: bump-tag
description: >-
  Bump semver, commit, tag, and push to fire release CI. Supports auto
  (infer from commits), major, minor, or patch. Use when the user asks to
  bump version, cut a release, tag a release, or run bump-tag.
disable-model-invocation: true
---

# bump-tag

Release the current repository: bump version → commit → tag → push → confirm CI.

**Argument** (optional): `auto` | `major` | `minor` | `patch`  
Default: `auto`

This skill's invocation **is** explicit permission to commit, tag, and push — overriding the usual "never commit unless asked" rule.

## 1. Resolve bump level

### `auto`

1. Detect current version and existing tags (see §2–3).
2. **No `v*` tags at all (first release)** → do **not** bump. Tag the current version as-is, then jump to §6 (skip §4–5 version edits).
3. **Tags exist** → read `git log <latest-tag>..HEAD --oneline` and choose:

| Level | When |
|---|---|
| **major** | Breaking: `feat!:` / `BREAKING CHANGE` / incompatible API or data format |
| **minor** | New features: `feat:` without breaking changes |
| **patch** | Only `fix:` / `chore:` / `docs:` / `refactor:` (no new features) |

**0.x rule**: while major is `0`, never bump to major for breakages — use **minor** instead (0.x → 1.0.0 only on explicit user request). So in 0.x: breaking or feat → minor, else → patch.

Show the chosen level and 2–3 lines of rationale (cite commits) before continuing.

**Tie-break**: prefer **patch** over minor when unsure. For major (after 1.0.0), ask the user if the evidence is weak.

### `major` / `minor` / `patch`

Use that level directly (still run all checks below).

## 2. Preflight (abort and report on failure)

- `git status --porcelain` must be empty (no unrelated changes in the release commit)
- Current branch must be the default branch (usually `main`)
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

First-release path (no prior tags): skip §4–5; only `git tag` + dual push of current version.

## 7. Confirm CI

After push, verify a tag-triggered workflow started and report the run URL.

- Prefer: `gh run list --limit 3`
- Else: `curl -sf "https://api.github.com/repos/<owner>/<repo>/actions/runs?per_page=3"`

If nothing runs within ~60s: warn (or report "no CI" if the repo has no tag-triggered workflow).

## Failure recovery

If something fails mid-flight, report the exact state (local tag/commit created or not) and recovery steps, e.g. `git tag -d vX.Y.Z` / `git reset --soft HEAD~1` (only with user confirmation — never discard unrelated work).
