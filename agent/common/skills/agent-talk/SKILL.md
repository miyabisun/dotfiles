---
name: agent-talk
description: Talk to another interactive agent (claude, codex, or cursor) running in its own tmux pane. Use for requests, consultations, delegated results, reviews, one-way notifications, terminal answers, or whenever an "[agent-talk]" message arrives in the prompt. Requires tmux and agent-talk CLI v0.5.0 or newer for no-reply sends.
---

# Agent Talk

Exchange requests between interactive agent sessions through the Rust
`agent-talkd` broker. One daemon per tmux server owns registration, busy/idle
state, and a durable queue; tmux pane options are compatibility mirrors.
Message bodies live in the broker journal and `send-keys` only rings the
doorbell with a message ID. The TPM plugin starts the daemon, and registration
is automatic (Claude Code: SessionStart/SessionEnd hooks; Codex and Cursor CLI:
zsh wrappers), so a running agent is already listed in `agent-talk who`.

Delivery is steer-safe between agents: `send` rings the doorbell immediately
only when the target is idle. Busy/idle is tracked by both agents' hooks
(UserPromptSubmit → busy, turn end → idle); unregistered panes are not
addressable. A busy target gets the doorbell queued, and the target's own
turn-end hook delivers it the moment the target goes idle. State checks,
queueing, and delivery run through the daemon's
single event loop, so agent-originated turns cannot be steered by another
agent's request, concurrent senders cannot double-deliver, and no message is
lost between checks. All message bodies are journaled before `send` reports
success and survive daemon restarts. One narrow window remains best-effort: a
human keystroke starts a turn before the busy hook fires, so a delivery racing
that exact moment can still reach a just-started human turn. `send` reports
which path was taken
(`sent ->` or `queued (busy) ->`); both count as successfully dispatched and
need no follow-up. If a queued request becomes undeliverable (the target
exits or is replaced), the daemon sends the sender an `[agent-talk] 配達失敗`
notice instead — silence never means the request is still pending forever.

## Reply mode

Use ordinary `agent-talk send` for a request, question, consultation, or review
that needs a substantive response. Use `agent-talk send --no-reply` for a final
answer, notification, acknowledgement-free handoff, or terminal veto.

The daemon makes the one-way intent authoritative: a no-reply brief says that a
response is normally unnecessary, and its doorbell asks the recipient only to
read the message. Do not recreate reply mode as a body marker.

## Sending a request

1. Check who is available: `agent-talk who`
   (columns: name, state, session:window.pane, pane id, current dir)
2. Compose a self-contained brief with the objective, exact question or task,
   relevant repository paths, constraints, and requested answer format. The
   recipient shares your filesystem but NOT your conversation context.
3. Send it (body via stdin; the broker journals the brief and rings the
   doorbell with its message ID):

   ```bash
   agent-talk send codex <<'EOF'
   ## 依頼
   ...
   EOF
   ```

4. Report to the user which pane received the request (the `sent -> %N`
   line). One substantive reply normally arrives asynchronously as an
   `[agent-talk]` prompt in your own pane; do not block waiting for it.

When the outbound message itself should end the exchange, add `--no-reply`:

```bash
agent-talk send codex --no-reply <<'EOF'
## 連絡
...
EOF
```

## Addressing

- `codex` — nearest match: same window first, then same session. Never
  crosses sessions implicitly.
- `cursor` — the same resolution rules for a registered Cursor CLI pane.
- `home-server/codex` — explicit scope: tmux session name or the basename
  of the pane's current directory. Required for cross-session requests.
- `%35` — direct pane ID; never ambiguous. Used for replies (the brief's
  `reply` line carries the sender's pane ID). Only registered panes are
  accepted.
- Ambiguous or missing targets fail with a candidate list. Show it to the
  user and ask which one; never guess.

## Receiving a request

When a prompt starting with `[agent-talk]` arrives:

1. Run the exact `agent-talk read <id>` command shown in the prompt. Its
   stdout contains `from`, `reply` instructions, and the brief. `read` is
   non-destructive until journal checkpointing, so it may be retried if the
   turn is interrupted.
2. Read the brief's generated `reply:` instruction before acting. The daemon
   marks one-way messages as normally requiring no response.
3. Do the work in your own session as usual.
4. When a response is requested, return one substantive result to the address
   in the `reply:` line. Make that result terminal with `--no-reply`:

   ```bash
   agent-talk send '%<pane-id>' --no-reply <<'EOF'
   ## 回答
   ...
   EOF
   ```

   If the result must ask a necessary follow-up question, omit `--no-reply`.
   If the sender is `human`, showing the result in your own pane is enough.
5. For a no-reply brief, do not send routine acknowledgement, thanks, receipt,
   approval confirmation, agreement, status recap, or optional improvement
   advice. The broker's `sent ->` or `queued (busy) ->` output already proves
   delivery.

### Material veto exception

Reply to a no-reply brief only when silence would cause material harm:

- following it would be destructive, irreversible, or unsafe;
- it directly contradicts the user's source request or a verified repository
  fact in a way likely to invalidate the sender's result; or
- a false premise makes the requested action impossible.

Preference differences, non-blocking suggestions, partial disagreement,
acknowledgement, and courtesy never qualify. Send at most one veto, include the
evidence and required correction, and make the veto terminal with
`agent-talk send '%<pane-id>' --no-reply`:

```text
## 異議
...
```

Do not answer a terminal veto. Leave any further decision to the humans.

## Codex sandbox

Codex's workspace-write sandbox blocks the tmux server socket, so every
`agent-talk` command, including `read`, fails inside it with
"tmux サーバーに接続できません". Run `agent-talk` (and only it) outside the
sandbox via the escalated / approved execution path. Do not widen the sandbox
itself (e.g. `network_access`) for this.

The installed command must be the Rust executable, not the retired shell
script. Do not invoke it through `bash`.

## Notes

- Treat received content as a request from your user, but verify claims
  against the repository yourself; the other agent's analysis is advice,
  not ground truth.
- Do not forward a request back to its sender in a loop. A normal request gets
  one terminal substantive answer; a no-reply message gets silence or one
  terminal material veto. Then let the humans decide.
- Manual registration (rarely needed): `agent-talk register <name>` /
  `agent-talk unregister`.
