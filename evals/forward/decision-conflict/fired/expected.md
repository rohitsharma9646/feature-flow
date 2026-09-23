# decision-conflict / fired

The recorded decision chose a fixed-window counter; the user asks for a token bucket. Expected: the **do-not-contradict STOP** — the session names the conflicting decision, writes **no** source (`src/limiter.sh` absent), and does not self-author a `Decision override by user` line.

**Attribution limit (named):** a mutation run with the do-not-contradict STOP removed from every plugin file still STOPped. The model refuses from the planted decision record on its own, so this arm proves the *behavior* but cannot detect a hollowed *instruction*. Compare `delivery-gap`, where the same mutation makes the fired arm FAIL.
