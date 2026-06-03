# NB-Agent Reward Composition — Quint Specification

A [Quint](https://quint-lang.org/) specification modeling the reward composition logic of [NB-Agent](https://github.com/cmriat/l0) (L0 project), checking bounds correctness and anti-gaming properties.

## What This Does

NB-Agent is an RL-trained notebook-based coding agent. Its training uses a multi-signal reward function combining QA accuracy, format compliance, and code execution success. This spec models that reward composition and checks two property classes:

1. **Bounds correctness** — every sub-reward in [0, 1], total trajectory reward in [0, 1]
2. **Anti-gaming** — more steps cannot inflate the total reward above the maximum

### Properties Proved (held under simulation)

| Invariant | Meaning |
|-----------|---------|
| `formatTrajSumBounded` | Format reward trajectory sum <= 1.0 |
| `codeTrajSumBounded` | Code execution reward trajectory sum <= 1.0 |
| `allQaInBounds` | Individual QA step scores in [0, 1] |
| `allCombinedNonNegative` | No negative combined step rewards |

### Bug Found: Unbounded Total Reward

**Violated invariant:** `totalInBounds` (total trajectory reward <= 1.0)

`qa_reward_fn` does not divide per-step scores by the number of steps, unlike `format_reward_fn` and `code_execution_reward_fn`. When `combine_str_reward_fn` sums weighted per-step rewards, the QA component accumulates without bound.

**Counterexample** (3-step trajectory, default weights qa=0.8, format=0.1, code=0.1):

| Step | QA | Format (÷3) | CodeExec (÷3) | Combined |
|------|----|-------------|---------------|----------|
| 1 | 0.10 | 0.00 | 0.33 | 0.11 |
| 2 | 1.00 | 0.33 | 0.11 | 0.84 |
| 3 | 1.00 | 0.33 | 0.22 | 0.85 |
| **Total** | | | | **1.80** |

**Possible fix:** scale QA rewards by `1/num_steps` like the other reward functions, or use only the last step's QA score.

## How It Was Made

This spec was generated using Claude Code guided by the [Quint specification language skill](https://gist.github.com/raymyers/7066fb7ebef80df48d48516f3314d663), a reusable prompt that teaches the agent Quint's type system, module structure, and CLI commands. The workflow was:

1. Cloned [cmriat/l0](https://github.com/cmriat/l0) and read the reward source (`src/l0/verl_adapter/reward/nb_agent_reward.py`)
2. Loaded the Quint skill prompt into the agent's context
3. Wrote the spec modeling integer-scaled reward arithmetic with nondeterministic step inputs
4. Ran `quint typecheck` then `quint run` — violation found in 18ms across 56 traces

## Target Code

[cmriat/l0](https://github.com/cmriat/l0) — `src/l0/verl_adapter/reward/nb_agent_reward.py`

## Files

| File | Description |
|------|-------------|
| `nb_agent_reward.qnt` | Quint spec: types, pure reward functions, state machine, invariants |

## Prerequisites

```bash
npm i @informalsystems/quint -g
```

Tested with Quint v0.32.0.

## How to Verify

```bash
# Type-check
quint typecheck examples/nb_agent_quint_spec/nb_agent_reward.qnt

# Simulate (finds the violation)
quint run examples/nb_agent_quint_spec/nb_agent_reward.qnt \
  --main=nb_agent_reward --invariant=allInvariants \
  --max-steps=10 --max-samples=1000 --backend=typescript

# Reproduce exact counterexample
quint run examples/nb_agent_quint_spec/nb_agent_reward.qnt \
  --main=nb_agent_reward --invariant=allInvariants \
  --seed=0x1270d68a27b6b7 --backend=typescript --verbosity=3
```

Expected output:
```
[violation] Found an issue (18ms at 56 traces/second).
error: Invariant violated
```

## Known Gaps

- Uses integer arithmetic (0-100 scale) to approximate the Python float logic; rounding differences are possible but don't affect the core finding
- Length reward is modeled but disabled (weight=0) matching the default config
- The spec does not model the training pipeline's downstream normalization, if any — the unbounded sum may be intentional if handled elsewhere
