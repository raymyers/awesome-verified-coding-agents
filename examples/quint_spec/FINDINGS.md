# NB-Agent Reward Composition: Quint Spec Findings

## Target

[cmriat/l0](https://github.com/cmriat/l0) — `src/l0/verl_adapter/reward/nb_agent_reward.py`

## What We Modeled

The NB-Agent reward system combines four reward signals per trajectory step:

| Reward | Weight | Scaled by 1/numSteps? |
|--------|--------|-----------------------|
| QA (F1 + exact match) | 0.8 | No |
| Format (think+code tags) | 0.1 | Yes |
| Code execution (error ratio) | 0.1 | Yes |
| Length | 0.0 (disabled) | Yes |

We wrote a Quint specification (`nb_agent_reward.qnt`) checking two property classes:

1. **Bounds correctness** — all sub-rewards in [0,1], total trajectory reward in [0,1]
2. **Anti-gaming** — more steps should not inflate the total reward above the maximum

## Bug Found: Unbounded Total Reward

**Violated invariant:** `totalInBounds` (total trajectory reward <= 1.0)

The `qa_reward_fn` does not divide per-step scores by the number of steps, unlike `format_reward_fn` and `code_execution_reward_fn`. When `combine_str_reward_fn` sums weighted per-step rewards, the QA component accumulates without bound.

### Counterexample (3-step trajectory)

| Step | QA | Format (÷3) | CodeExec (÷3) | Combined |
|------|----|-------------|---------------|----------|
| 1 | 0.10 | 0.00 | 0.33 | 0.11 |
| 2 | 1.00 | 0.33 | 0.11 | 0.84 |
| 3 | 1.00 | 0.33 | 0.22 | 0.85 |
| **Total** | | | | **1.80** |

### Quint Output

```
[violation] Found an issue (18ms at 56 traces/second).
Use --seed=0x1270d68a27b6b7 --backend=typescript to reproduce.
error: Invariant violated
```

Verbose trace shows:
```
totalReward(...) => 180   (on 0-100 integer scale)
├─ combinedStepReward({ codeExec: 33, format: 0, qa: 10 })   => 11
├─ combinedStepReward({ codeExec: 11, format: 33, qa: 100 }) => 84
└─ combinedStepReward({ codeExec: 22, format: 33, qa: 100 }) => 85
```

### Reproduction

```bash
npm i @informalsystems/quint -g
quint typecheck examples/quint_spec/nb_agent_reward.qnt
quint run examples/quint_spec/nb_agent_reward.qnt \
  --main=nb_agent_reward --invariant=allInvariants \
  --max-steps=10 --max-samples=1000 --backend=typescript
```

### Possible Fix

Either scale QA rewards by `1/num_steps` like the other reward functions, or use only the last step's QA score (since only the final answer matters for evaluation).

## Properties That Held

- `formatTrajSumBounded` — format reward trajectory sum <= 1.0
- `codeTrajSumBounded` — code execution reward trajectory sum <= 1.0
- `allQaInBounds` — individual QA scores in [0, 1]
- `allCombinedNonNegative` — no negative combined rewards
