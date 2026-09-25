# SM1 ratio (v0.24.0 single-architect fired vs v0.23.0 three-architect fired baseline)

Command:
```
bash evals/forward/single-architect/sm1-ratio.sh \
  .feature-flow/single-architect-design/evidence/verify-5/forward-new/single-architect/fired \
  .feature-flow/single-architect-design/evidence/verify-3/forward-v023/single-architect/fired
```
Exit: 0

## Full output
```
SM1 cost v0.24.0=$0.4127 (n=2) v0.23.0=$0.4710 (n=2) ratio=0.876 (<= 0.90)
SM1 wall v0.24.0=133.0000s v0.23.0=69.5000s ratio=1.914 (recorded, not gated)
SM1 PASS
```

Baseline used: pass 3's `verify-3/forward-v023/single-architect/fired` (the two v0.23.0 three-architect runs), no new paid run made for this step. Cost ratio 0.876 <= 0.90 gate → PASS. Wall-time ratio (1.914) is recorded only, not gated, per the script's comment (single architect cannot parallelize the way a fan-out of three did).
