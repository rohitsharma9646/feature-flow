# Evidence: Assumption 1 — headless session saves a file before an unanswerable question

## Probe

Fresh temp dir (`/tmp/tmp.ENaLHecnil`), `git init -q`, then:

```bash
timeout 300 claude -p --model haiku --permission-mode bypassPermissions --output-format json \
  "Write the text 'saved' to the file report.md in the current directory with the Write tool. Then use the AskUserQuestion tool to ask me whether to continue, with options Yes and No. Stop after asking." \
  > run.json 2> run.err
```

## Result

- **Process exit code:** `0` (command completed within the 300s timeout; no hang)
- **`report.md` content:** `saved` (5 bytes, no trailing newline) — file was written as instructed
- **Step 2 verify** (`test -s "$T/report.md" && echo holds`): `holds`
- **`run.err`:** empty
- **`.result` (final message) from `run.json`:**
  > File written. However, the AskUserQuestion tool isn't available to me. I can ask directly instead:
  >
  > **Should I continue?**
  > - Yes
  > - No
- **`stop_reason`:** `end_turn`
- **`subtype`:** `success`
- **`is_error`:** `false`
- **`terminal_reason`:** `completed`
- **`num_turns`:** `2`
- **`permission_denials`:** `[]`
- **duration:** `duration_ms=7747`, `duration_api_ms=7638` (well under the 300s timeout)

Full `run.json` captured during the probe (key fields reproduced above); no other fields are relevant to this assumption.

## Reading against Assumption 1

Assumption 1 ("a headless session saves a file before an unanswerable question") is **confirmed**:

- The file-write step completes and is durably on disk *before* the session ends, regardless of the
  pause mechanism. `report.md` exists and holds `saved` after the run.
- `AskUserQuestion` is **not available in headless (`-p`) mode** — the model states this explicitly and
  falls back to asking the question as plain text in its final `result`, then ends the turn normally
  (`stop_reason: end_turn`, `subtype: success`, exit code `0`). There is no hang and no error; the
  session simply asks in plain text and ends its turn, with the file already written first.

## Implication for the plan

None. Plan Task 6's asserts (`docs/feature-flow/2026-09-24-single-architect-design/plan.md`, Task 6)
only read `architect.md` off disk after the process exits (`[ -f "$A" ]`, `grep` on its content) — they
never inspect `.result` or any pause state. Since the probe confirms the file is written first and the
session then ends cleanly, Task 6 needs no adaptation.
