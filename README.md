# Awesome Verified Coding Agents

> Resources on AI coding agents using high assurance technniques such as Formal Verification.

Formal Methods is a family of techniques applying mathematical rigor to software engineering. AI coding agents use Large Language Models with iteration and tool feedback to assist with a variety of development tasks, unlocking huge productivity gains *when they work*. By combining these techniques, we hope to enable the widespread creation of software that is highly reliable and maintainable.

## Examples in production

[Stakpak](https://stakpak.dev/) uses a [policy enforcer](https://stakpak.gitbook.io/docs/how-it-works/warden-guardrails) to restrict agent actions, which is built on the Cedar policy language. Cedar is [developed](https://arxiv.org/abs/2407.01688v1) using a formally verified reference implementation in Lean 4. That spec is then fuzz-tested for equivelence with te production Rust implementation.

To our knowledege this is the first use of Formal Verification in a coding agent product. If you are aware of others, please use an issue or PR to submit them.

## Research

* [LeanCopilot](https://github.com/lean-dojo/LeanCopilot): LLMs as Copilots for Theorem Proving in Lean
* [LeanTool](https://github.com/GasStationManager/LeanTool): MCP Server and facades to give LLMs feedback from Lean
* [Universalis](https://dl.acm.org/doi/pdf/10.1145/3746223): An AI-first program synthesis framework
* [Kimina-Prover Preview](https://github.com/MoonshotAI/Kimina-Prover-Preview): Towards Large Formal Reasoning Models with Reinforcement Learning
* [AlphaGeometry](https://deepmind.google/discover/blog/alphageometry-an-olympiad-level-ai-system-for-geometry/): An Olympiad-level AI system for geometry
* [The Fusion of Large Language Models and Formal Methods
for Trustworthy AI Agents: A Roadmap](https://arxiv.org/abs/2412.06512), Yedi Zhang et al

Submit your suggestions as issues or [pull requests](https://github.com/raymyers/awesome-verified-coding-agents/pulls)!
