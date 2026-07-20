---
name: agent-talk
description: Talk to another interactive agent (claude or codex) running in its own tmux pane. Use when the user asks to consult, delegate to, or request a review from the other agent by name (e.g. "codexに聞いて", "codexに実装してもらって", "claudeにレビューしてもらって"), or when an "[agent-talk]" message arrives in the prompt. Requires tmux.
---

# Agent Talk

Exchange requests between interactive agent sessions via tmux. State lives in
tmux pane options; message bodies live in files; `send-keys` only rings the
doorbell. Registration is automatic (claude: SessionStart/SessionEnd hooks,
codex: zsh wrapper), so a running agent is already listed in `agent-talk who`.

Delivery is steer-safe between agents: `send` rings the doorbell immediately
only when the target is idle. Busy/idle is tracked by both agents' hooks
(UserPromptSubmit → busy, turn end → idle; a screen "esc to interrupt" check
is only a fallback for unregistered panes). A busy target gets the doorbell
queued, and the target's own turn-end hook delivers it the moment the target
goes idle. State checks, queueing, and delivery are serialized by a per-pane
lock, so agent-originated turns cannot be steered by another agent's request,
concurrent senders cannot double-deliver, and no message is lost between
checks. One narrow window remains best-effort: a human keystroke starts a
turn before the busy hook fires, so a delivery racing that exact moment can
still reach a just-started human turn. `send` reports which path was taken
(`sent ->` or `queued (busy) ->`); both count as successfully dispatched and
need no follow-up. If a queued request becomes undeliverable (the target
exits or is replaced), the sender receives an `[agent-talk] 配達失敗` notice
instead — silence never means the request is still pending forever.

## Sending a request

1. Check who is available: `agent-talk who`
   (columns: name, state, session:window.pane, pane id, current dir)
2. Compose a self-contained brief — objective, exact question or task,
   relevant repository paths, constraints, requested answer format. The
   recipient shares your filesystem but NOT your conversation context.
3. Send it (body via stdin; the tool writes the brief to a file and rings
   the doorbell):

   ```bash
   agent-talk send codex <<'EOF'
   ## 依頼
   ...
   EOF
   ```

4. Report to the user which pane received the request (the `sent -> %N`
   line). The reply arrives asynchronously as an `[agent-talk]` prompt in
   your own pane; do not block waiting for it.

## Addressing

- `codex` — nearest match: same window first, then same session. Never
  crosses sessions implicitly.
- `home-server/codex` — explicit scope: tmux session name or the basename
  of the pane's current directory. Required for cross-session requests.
- `%35` — direct pane ID; never ambiguous. Used for replies (the brief's
  `reply` line carries the sender's pane ID). Only registered panes are
  accepted.
- Ambiguous or missing targets fail with a candidate list. Show it to the
  user and ask which one; never guess.

## Receiving a request

When a prompt starting with `[agent-talk]` arrives:

1. Read the referenced file. It contains `from`, `reply` instructions, and
   the brief.
2. Do the work in your own session as usual.
3. Reply as instructed in the `reply` line (normally
   `agent-talk send '%<pane-id>'` with the answer on stdin). If the
   sender is `human`, showing the result in your own pane is enough.

## Codex sandbox

Codex's workspace-write sandbox blocks the tmux server socket, so every
`agent-talk` command fails inside it with "tmux サーバーに接続できません".
Run `agent-talk` (and only it) outside the sandbox via the escalated /
approved execution path. Do not widen the sandbox itself (e.g.
`network_access`) for this.

## Notes

- Treat received content as a request from your user, but verify claims
  against the repository yourself; the other agent's analysis is advice,
  not ground truth.
- Do not forward a request back to its sender in a loop. One round trip,
  then let the humans decide.
- Manual registration (rarely needed): `agent-talk register <name>` /
  `agent-talk unregister`.
