---
name: commit
description: >-
  Create concise, atomic local Git commits from the intended working-tree
  changes. Use only when the user explicitly invokes commit or explicitly asks
  to commit current changes. Inspect and scope the diff, preserve unrelated
  work, write a short English Conventional Commit subject, add a body only for
  non-obvious rationale or migration impact, verify the result, and never push.
---

# commit

Create a readable local commit with the highest useful signal and the least
prose. An explicit `$commit` invocation authorizes local commit creation only.
It does not authorize push, merge, deploy, release, amend, rebase, history
rewriting, or discarding working-tree changes.

## Inputs

| Arg | Required | Meaning |
|---|---|---|
| `intent` | no | Task or outcome the commit should represent |
| `paths` | no | Exact files eligible for staging |

When called by `deliver` or `consolidate`, treat their task, verified ledger,
and eligible file list as authoritative. Otherwise infer intent from the diff
and recent conversation; ask only when materially different atomic groupings
remain plausible.

## 1. Inspect before staging

Run read-only Git inspection:

```text
git status --short
git diff
git diff --cached
git log --oneline -10
```

Identify:

- the coherent change authorized by the user;
- pre-staged changes and whether they belong;
- unrelated, generated, ignored, secret-bearing, or suspicious files;
- whether one commit can tell one truthful story.

If `git status` exposes a file that appears to contain private local configuration or secrets
(for example a runtime `.env`, credential file, or private key), stop the commit attempt before
staging it and inspect whether the file is tracked:

- If it is untracked, ask whether its path or an appropriate pattern should be added to
  `.gitignore`. Do not resume the commit until the user decides.
- If it is already tracked, explain that `.gitignore` alone will not untrack it and ask how the
  user wants to handle it.

Treat explicit public templates such as `.env.example`, `.env.sample`, and `.env.template` as
documentation, not private runtime configuration. They are eligible when their full contents
have been inspected and contain no secrets.

Never use `git add .`, `git add -A`, or an equivalent broad staging command
when unrelated changes exist. Stage exact paths or safe hunks. Do not modify
files merely to make staging easier. If authorized and unrelated edits overlap
the same hunk and cannot be isolated confidently, stop and report the conflict.

If the diff contains multiple independent changes, prefer separate atomic
commits only when the user authorized committing all of them and the separation
is unambiguous. Otherwise commit the requested subset and leave the rest alone.

## 2. Write the message

Use English Conventional Commits:

```text
type(scope): imperative summary
```

Message rules:

- Keep the subject at or below 72 characters; aim near 50 when natural.
- Use a concrete imperative verb and describe the outcome, not the activity.
- Choose the narrowest truthful type: `feat`, `fix`, `style`, `refactor`,
  `test`, `docs`, `build`, `ci`, `perf`, `chore`, or repository convention.
- Add a scope only when it improves scanning; do not invent unstable scopes.
- Omit the body by default.
- Add a body only when the diff cannot explain **why**, a non-obvious tradeoff,
  compatibility behavior, migration requirement, or operational consequence.
- When needed, keep the body to one short paragraph or at most three bullets,
  wrapped around 72 characters.
- Use `BREAKING CHANGE:` and issue trailers when semantically required.

### `feat` versus `fix`

Classify from the user's capability and product contract, not from diff size,
novel code, or the fact that behavior visibly changed.

Use `feat` only when the commit intentionally adds a capability, option,
workflow, command, endpoint, or supported use case that users could not use
before. A reliable test is: **can the user now accomplish something that was
not part of the product before?** If not, avoid `feat`.

Use `fix` when restoring or correcting an existing capability or its intended
presentation: bugs, regressions, incorrect edge cases, broken accessibility,
wrong copy, layout defects, unintended colors, and behavior that did not match
the established contract.

Use `style` for intentional presentation-only adjustments that are neither a
new capability nor a defect correction, such as changing an existing color,
spacing, typography, or formatting by design preference. Use `refactor` when
production structure changes without intended observable behavior.

Decision order:

```text
new user capability?                  → feat
existing contract corrected/restored? → fix
presentation-only preference?         → style
no intended observable change?        → refactor
```

When `feat` and `fix` are both plausible, prefer `fix` unless the product's
supported capability surface genuinely expanded. Never use `feat` merely
because files, UI, CSS, or behavior changed.

Never include:

- a file-by-file inventory;
- a prose replay of the diff;
- test logs or generic statements such as “tests added”;
- headings like Summary, Changes, Implementation, or Testing;
- marketing language, self-congratulation, or speculative benefits;
- “generated by AI” or Co-Authored-By trailers unless the user or repository
  policy explicitly requires them.

Examples:

```text
fix(auth): preserve redirect after token refresh
```

```text
style(theme): soften the inactive tab color
```

```text
refactor(parser): centralize token boundary handling

Keep byte offsets in the lexer so diagnostics retain their existing spans.
```

## 3. Commit safely

1. Stage only the selected paths or hunks.
2. Inspect `git diff --cached --check` and the complete staged diff.
3. Confirm the staged diff contains no unrelated work or secrets.
4. Commit without amend.
5. Verify with `git status --short` and `git log -1 --format=fuller --stat`.

Do not claim tests were run unless evidence was provided or observed. This
skill records a change; it does not retroactively make an unverified change
verified.

## Output

```json
{
  "committed": true,
  "commit": "<hash> <subject>",
  "files": ["path"],
  "body": "omitted|included: <reason>",
  "remaining_changes": ["uncommitted path"]
}
```

On failure, do not create a partial or mixed commit. Return `committed=false`,
the exact ambiguity or blocker, and the remaining working-tree state.

## Hard rules

- Preserve unrelated user changes and pre-existing staged work.
- Respect repository ignore rules; never force-add a file to bypass them.
- Judge commit eligibility from the requested scope, repository policy, and file contents, not
  from filename patterns alone.
- Never commit detected credentials, tokens, private keys, or other secrets.
- Never use checkout, restore, destructive reset, clean, or stash.
- Never push, merge, deploy, release, amend, rebase, or rewrite history.
