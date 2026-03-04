# Examples

This directory is for concrete, reproducible examples demonstrating verified coding agents in practice. Below is a guide to what kinds of examples are welcome and what to include.

---

## Kinds of Examples

### 1. Generated Verified Code

Code in a prover language produced by an agent or LLM — demonstrating Approach 1 (agents generating verified code).

**What to include:**
- The source file(s) in the prover language (Lean, ACL2, Quint, Dafny, etc.)
- A `README.md` in the example's subdirectory with:
  - What the code does and what properties are proved
  - The model and version used to generate it (e.g. `claude-opus-4-5`, `gpt-4o-2024-11-20`)
  - The prompt or task description given to the agent
  - Prover version and commands to verify (e.g. `lake build`, `acl2 < file.lisp`)
  - Any known gaps (e.g. `sorry` placeholders)

### 2. Agent Code

An implementation of a verified coding agent or a verified agent component — demonstrating Approach 2 (agents with verified components).

**What to include:**
- The agent source code and any verified components
- A `README.md` covering:
  - Architecture overview: what is verified and how
  - Dependencies and install steps
  - How to run the agent and what to expect
  - Any evaluation results (e.g. SWE-bench score, proof success rate)

### 3. Prompts

System prompts, task prompts, or reusable prompt templates that guide agents toward producing verified code.

**What to include:**
- The prompt file(s) (plain text or Markdown)
- A `README.md` covering:
  - What the prompt is for and what prover language it targets
  - Which models it was tested with (name + version)
  - Representative output showing the prompt working well
  - Known failure modes or limitations

### 4. Tools

MCP servers, tool wrappers, or integrations that give agents access to provers or verification feedback.

**What to include:**
- Source code or a link to the external repo
- A `README.md` covering:
  - What the tool does and which prover(s) it wraps
  - Install and configuration steps
  - Which agents or frameworks it has been tested with
  - An example interaction showing the feedback loop in action

### 5. Harnesses

Evaluation setups, test harnesses, or agent configurations used to measure or reproduce results.

**What to include:**
- Scripts and configuration files
- A `README.md` covering:
  - What is being measured and how
  - How to reproduce the run (model, version, environment, seed if applicable)
  - Expected outputs or benchmark numbers

---

## General Guidance

- **Reproducibility first.** The goal is that someone else can follow the steps and get the same result. If exact reproduction isn't possible (e.g. a model version has been retired), note that clearly.
- **Model versions matter.** Agent + prover results can vary significantly between model versions. Always specify (e.g. `claude-opus-4` vs a specific dated snapshot).
- **Partial results are fine.** An example that mostly works, with clearly documented gaps, is more useful than a polished demo that obscures what the agent actually struggled with.

See [CONTRIBUTING.md](../CONTRIBUTING.md) for how to submit an example.
