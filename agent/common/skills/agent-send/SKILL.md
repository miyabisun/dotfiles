---
name: agent-send
description: Send a one-way, terminal message to another interactive agent through agent-talk when no reply is wanted, such as a final answer, notification, handoff result, or FYI. Do not use for incoming "[agent-talk]" prompts or when a response, consultation, review, or follow-up is required; use agent-talk instead. Requires tmux.
---

# Agent Send

Send one terminal message through the existing `agent-talk` transport without
starting another conversational round.

Before sending, read `../agent-talk/SKILL.md` for the authoritative addressing,
delivery, sandbox, and reply-policy rules. This skill only selects the one-way
mode; it does not define a second transport.

## Send

1. Resolve the recipient with `agent-talk who` and the addressing rules in
   agent-talk. Never guess an ambiguous target.
2. Make the first non-empty body line exactly:

   ```text
   reply-policy: no-reply
   ```

3. Follow it with a self-contained final answer, notification, result, or
   handoff. Do not ask a question or request confirmation in a no-reply message.
4. Send the body through `agent-talk send`:

   ```bash
   agent-talk send '%<pane-id>' <<'EOF'
   reply-policy: no-reply

   ## 連絡
   ...
   EOF
   ```

5. Report the `sent ->` or `queued (busy) ->` receipt to the user, then finish.
   Do not wait for, solicit, or send an acknowledgement.

The recipient normally stays silent. Agent-talk permits one terminal veto only
when silence would cause material harm; that exception is not an invitation to
continue the conversation.
