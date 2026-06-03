// -*- mode: Bluespec; -*-

/// Quint spec for NB-Agent reward composition (L0 project).
/// Models: qa, format, code_execution rewards with weights.
/// Properties: bounds correctness and anti-gaming (more steps can't inflate total).

module nb_agent_reward {

  // ═══════════════════════════════════════════
  // 1. TYPES
  // ═══════════════════════════════════════════

  // A single step's raw inputs
  type StepInput = {
    formatOk: bool,       // has exactly one <think> and one <code> with content
    codeOutputs: int,     // total code cell outputs
    codeErrors: int,      // error outputs
    hasAnswer: bool,      // whether final_answer is non-null
    exactMatch: bool,     // whether answer exactly matches ground truth
    f1Score: int,         // F1 score * 100 (integer percentage, 0-100)
  }

  // Per-step computed rewards (scaled to 0-100 integer range)
  type StepReward = {
    qa: int,
    format: int,
    codeExec: int,
  }

  type State = {
    steps: List[StepInput],
    rewards: List[StepReward],
    numSteps: int,
  }

  // ═══════════════════════════════════════════
  // 2. CONSTANTS
  // ═══════════════════════════════════════════

  // Weights (scaled to sum to 100)
  pure val W_QA = 80
  pure val W_FORMAT = 10
  pure val W_CODE = 10

  // QA sub-weights (sum to 100)
  pure val W_F1 = 0
  pure val W_EM = 90
  pure val W_HAS_ANSWER = 10

  pure val MAX_STEPS = 4

  // ═══════════════════════════════════════════
  // 3. PURE FUNCTIONS
  // ═══════════════════════════════════════════

  // QA reward for a single step (0-100). NOT scaled by num_steps.
  pure def qaReward(step: StepInput): int = {
    val emScore = if (step.exactMatch) 100 else 0
    val hasAnswerScore = if (step.hasAnswer) 100 else 0
    // weighted sum: (W_F1 * f1 + W_EM * em + W_HAS_ANSWER * has) / 100
    (W_F1 * step.f1Score + W_EM * emScore + W_HAS_ANSWER * hasAnswerScore) / 100
  }

  // Format reward for a single step, scaled by 1/numSteps (0 to 100/numSteps).
  pure def formatReward(step: StepInput, numSteps: int): int = {
    val raw = if (step.formatOk) 100 else 0
    raw / numSteps
  }

  // Code execution reward for a single step, scaled by 1/numSteps.
  pure def codeExecReward(step: StepInput, numSteps: int): int = {
    val raw = if (step.codeOutputs > 0)
      ((step.codeOutputs - step.codeErrors) * 100) / step.codeOutputs
    else
      0
    raw / numSteps
  }

  // Combined reward for one step
  pure def combinedStepReward(sr: StepReward): int = {
    (W_QA * sr.qa + W_FORMAT * sr.format + W_CODE * sr.codeExec) / 100
  }

  // Total trajectory reward = sum of combined step rewards
  pure def totalReward(rewards: List[StepReward]): int = {
    rewards.foldl(0, (acc, sr) => acc + combinedStepReward(sr))
  }

  // Compute step reward from input
  pure def computeReward(step: StepInput, numSteps: int): StepReward = {
    {
      qa: qaReward(step),
      format: formatReward(step, numSteps),
      codeExec: codeExecReward(step, numSteps),
    }
  }

  // ═══════════════════════════════════════════
  // 4. STATE VARIABLES
  // ═══════════════════════════════════════════

  var steps: List[StepInput]
  var rewards: List[StepReward]
  var numSteps: int

  val currentState: State = {
    steps: steps,
    rewards: rewards,
    numSteps: numSteps,
  }

  // ═══════════════════════════════════════════
  // 5. INVARIANTS
  // ═══════════════════════════════════════════

  // -- Bounds: every individual sub-reward is in [0, 100]
  val allQaInBounds = rewards.foldl(true, (ok, sr) =>
    ok and sr.qa >= 0 and sr.qa <= 100
  )

  val allFormatInBounds = rewards.foldl(true, (ok, sr) =>
    ok and sr.format >= 0 and sr.format <= 100
  )

  val allCodeExecInBounds = rewards.foldl(true, (ok, sr) =>
    ok and sr.codeExec >= 0 and sr.codeExec <= 100
  )

  // -- Bounds: combined step reward is non-negative
  val allCombinedNonNegative = rewards.foldl(true, (ok, sr) =>
    ok and combinedStepReward(sr) >= 0
  )

  // -- Bounds: total trajectory reward is bounded [0, 100]
  val totalInBounds = totalReward(rewards) >= 0 and totalReward(rewards) <= 100

  // -- Anti-gaming: format trajectory sum <= 100 (scaling prevents inflation)
  val formatTrajSumBounded = rewards.foldl(0, (acc, sr) => acc + sr.format) <= 100

  // -- Anti-gaming: code exec trajectory sum <= 100
  val codeTrajSumBounded = rewards.foldl(0, (acc, sr) => acc + sr.codeExec) <= 100

  // -- Master invariant
  val allInvariants = and {
    allQaInBounds,
    allFormatInBounds,
    allCodeExecInBounds,
    allCombinedNonNegative,
    totalInBounds,
    formatTrajSumBounded,
    codeTrajSumBounded,
  }

  // ═══════════════════════════════════════════
  // 6. ACTIONS
  // ═══════════════════════════════════════════

  action unchanged_all = all {
    steps' = steps,
    rewards' = rewards,
    numSteps' = numSteps,
  }

  // Initialize with a chosen number of steps (1 to MAX_STEPS)
  action init = {
    nondet n = 1.to(MAX_STEPS).oneOf()
    all {
      steps' = List(),
      rewards' = List(),
      numSteps' = n,
    }
  }

  // Add a step with nondeterministic inputs
  action addStep = {
    // Only add if we haven't reached numSteps yet
    nondet fmtOk = Set(true, false).oneOf()
    nondet outputs = 0.to(5).oneOf()
    nondet errors = 0.to(outputs).oneOf()
    nondet hasAns = Set(true, false).oneOf()
    nondet em = Set(true, false).oneOf()
    nondet f1 = 0.to(100).oneOf()
    val input: StepInput = {
      formatOk: fmtOk,
      codeOutputs: outputs,
      codeErrors: errors,
      hasAnswer: hasAns,
      exactMatch: em,
      f1Score: f1,
    }
    val reward = computeReward(input, numSteps)
    if (steps.length() < numSteps) all {
      steps' = steps.append(input),
      rewards' = rewards.append(reward),
      numSteps' = numSteps,
    } else {
      unchanged_all
    }
  }

  action step = addStep

  // ═══════════════════════════════════════════
  // 7. TEMPORAL
  // ═══════════════════════════════════════════

  temporal safety = always(allInvariants)
}
