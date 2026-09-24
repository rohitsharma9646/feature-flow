# Assumption 2 — a dispatched agent can be resumed with its context intact

**Date:** 2026-09-24 · **Harness:** Claude Code (this session) · **Kind:** cli-output (tool transcript)

1. Dispatched a throwaway `general-purpose` agent (model haiku) with the prompt: "Remember this token
   exactly: QX7-LANTERN-4491. Do not use any tools. Reply with only the word ACK." → returned `ACK`.
2. After it completed, resumed the same agent with `SendMessage` (to its agent id): "repeat the exact
   token I gave you earlier … Do not use any tools." The tool reported `Resuming agent …`.
3. The resumed agent returned `QX7-LANTERN-4491` — the token was never restated in the second message.

**Result:** holds. A completed subagent resumes from its transcript via `SendMessage` with its prior
context. Fix rounds 1–2 resume the recorded implementer; the fresh-dispatch-with-report fallback stays
in the contract for harnesses without resume (Codex, or an id that no longer resolves).
