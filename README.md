# Awesome Verified Coding Agents

> Resources on AI coding agents using high-assurance techniques such as Formal Verification.

Formal Methods is a family of techniques applying mathematical rigor to software engineering. AI coding agents use Large Language Models with iteration and tool feedback to assist development tasks, unlocking huge productivity gains *when they work*.

By combining these, we aim to enable the widespread creation of software that is highly reliable and maintainable.

## What is a Verified Coding Agent?

### Coding Agent

A coding agent is an AI-based tool that takes requests in natural language and performs multi-step software development tasks, using feedback from the environment as it goes. Typically implemented as an LLM chat-loop with tool use, where tools cover:

- **Navigation** — browsing codebases, finding files
- **Editing** — modifying code
- **Execution** — running tests, checking builds
- **Knowledge** — documentation, search, context retrieval

### Formal Verification

Formal Verification is reasoning about programs with mathematical rigor — proving that an implementation matches a specified behavior, rather than relying only on testing. Formal Specification is a related practice focused on verifying the design rather than the implementation.

### Combining them

A verified coding agent combines these in one of two ways:

1. **A coding agent that generates verified code**
2. **A coding agent with some verified component**

---

## Approach 1: Agents Generating Verified Code

Use a coding agent to produce code in a verifiable language. Whatever the agent generates, the prover checks — providing assurance proportional to how well the specs are understood.

Any standard agent can be pointed at a prover language today. Specialized agents go further: understanding proof idioms, invoking tactics, and structuring proofs automatically. As of late 2025, SOTA models (Opus 4+, etc.) paired with MCP tooling for provers have pushed autoformalization to a new threshold of practical usability.

### Prover Languages

Each has distinct strengths — the right choice depends on your domain and team:

| Language | Strengths |
|---|---|
| [Lean 4](https://lean-lang.org/) | Strong momentum, Mathlib, best LLM tooling as of 2025 |
| [ACL2](https://www.cs.utexas.edu/users/moore/acl2/) | Industrial track record, especially hardware/systems; powerful automation |
| [Quint](https://quint-lang.org/) | Readable TLA+-style specs; particularly good for distributed systems and protocols |
| [Dafny](https://dafny.org/) | Familiar syntax, compiles to mainstream languages; useful for a verified core alongside conventional code |
| [Rocq (Coq)](https://coq.inria.fr/) | Mature ecosystem, widely used in safety-critical systems and academia |
| [Isabelle](https://isabelle.in.tum.de/) | Powerful automation, strong academic adoption |

---

## Approach 2: Agents with Verified Components

Rather than verifying what the agent produces, verify part of the agent itself — or constrain it by construction.

### Permission & Policy Systems

Tool use is a high-leverage point: regardless of what the LLM outputs, verified tool policies provide strong guarantees on what can actually happen in the world.

**In production:** [Stakpak](https://stakpak.dev/) uses a [policy enforcer](https://stakpak.gitbook.io/docs/how-it-works/warden-guardrails) built on [Cedar](https://www.cedarpolicy.com/en). Cedar has a formally [verified reference implementation](https://arxiv.org/abs/2407.01688v1) in Lean 4, differential-tested against the production Rust implementation.

### Restricted Agents by Design

Get assurance not by verifying code, but by construction — limiting the agent's power:

- Only allow syntax-level transformations rather than arbitrary file edits
- Enforce test coverage before permitting changes
- Apply [Test-Commit-Revert (TCR)](https://medium.com/@kentbeck_7670/test-commit-revert-870bbd756864): run tests on every save, revert automatically on failure — enforcing the small steps that work well with agents

### Verified Individual Tools

Each tool an agent uses (file editors, refactoring operations, search) can be independently verified. Formal guarantees can be scoped to wherever they deliver the most value.

---

## Projects & Tools

### Production

| Project | Description |
|---|---|
| [Stakpak](https://stakpak.dev/) | Coding agent with Cedar-based formally verified permission system |

### Frameworks & Tooling

| Project | Description |
|---|---|
| 🌟 [numina-lean-agent](https://github.com/project-numina/numina-lean-agent) | Agentic Lean proof generation |
| 🌟 [quint-llm-kit](https://github.com/informalsystems/quint-llm-kit) | Ready-to-go Docker image for using Claude Code with Quint |
| [LeanCopilot](https://github.com/lean-dojo/LeanCopilot) | LLMs as copilots for theorem proving in Lean |
| [LeanTool](https://github.com/GasStationManager/LeanTool) | MCP server giving LLMs feedback from Lean |
| [Provably Correct Vibecoding](https://github.com/GasStationManager/ProvablyCorrectVibeCoding) | Wraps LeanTool for agent-assisted proof development |
| [LLMLean](https://github.com/cmu-l3/llmlean) | LLM-powered tactic suggestions in Lean |
| [LeanAide](https://github.com/siddhartha-gadgil/LeanAide) | AI assistance for Lean development |
| [ACL2 Jupyter](https://github.com/jimwhite/acl2-jupyter) | ACL2 in Jupyter notebooks |
| [mini-SWE-agent](https://github.com/SWE-agent/mini-swe-agent) | Minimal coding agent (~100 lines); tractable target for verification |
| [ESBMC agent-marketplace](https://github.com/esbmc/agent-marketplace) | Formal verification for Claude Code: bugs, memory safety, and undefined behavior in C, C++, Python, Solidity, Java/Kotlin via ESBMC bounded model checker |

---

## Research

| Paper | Description |
|---|---|
| [The Fusion of LLMs and Formal Methods for Trustworthy AI Agents: A Roadmap](https://arxiv.org/abs/2412.06512) | Yedi Zhang et al |
| [Universalis](https://dl.acm.org/doi/pdf/10.1145/3746223) | AI-first program synthesis framework |
| [Kimina-Prover Preview](https://github.com/MoonshotAI/Kimina-Prover-Preview) | Large formal reasoning models with reinforcement learning |
| [AlphaGeometry](https://deepmind.google/discover/blog/alphageometry-an-olympiad-level-ai-system-for-geometry/) | Olympiad-level AI system for geometry |
| [Intent Formalization Survey — RiSE Group](https://risemsr.github.io/blog/2026-03-05-shuvendu-intent-formalization/) | Survey of intent formalization approaches by MSR's RiSE group; instructive introduction to verification for those newer to the field |

---

## Talks & Reading

| Resource | Description |
|---|---|
| ["Verified Coding Agents" on Craft vs Cruft](https://www.youtube.com/watch?v=7hRgK6G5aok) | July 2025 introduction to the space |
| [ACL2 for Trustworthy Vibe Coding](https://github.com/wiki3-ai/verified-agent/blob/main/slides.ipynb) | Jim White, Bay Area Lisp and Scheme User Group |
| [Reliable Software in the LLM Era](https://quint-lang.org/posts/llm_era) | Gabriela Moreira of Quint |

---

## Examples

See [`examples/`](./examples/) for guidance on what kinds of examples are welcome and how to contribute one.

## More Links

See [MORE_LINKS.md](./MORE_LINKS.md) for an extended collection of resources organized by topic: agent frameworks, benchmarks, MCP and protocols, formal methods applications, models, and software craft.

## FAQ

See [FAQ.md](./FAQ.md) for common questions including background on the space, prover language guidance, and lessons from early experiments.

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md). Suggestions welcome via issues or [pull requests](https://github.com/raymyers/awesome-verified-coding-agents/pulls)!
