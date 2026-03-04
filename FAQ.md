# Frequently Asked Questions

## What is a verified coding agent?

A verified coding agent is an AI coding agent that incorporates formal verification in one of two ways:

1. It generates verified code — code proven correct against a formal specification
2. The agent code itself is verified, or has a verified component such as a verified permission system or individual tools

See the [README](./README.md) for a full breakdown of both approaches.

## What is Formal Verification?

Formal Verification is reasoning about programs with mathematical rigor — proving that an implementation matches a specified behavior, rather than relying only on testing. Unlike tests, which check specific inputs, a formal proof covers all possible inputs within the stated assumptions.

Formal Specification is a related practice focused on verifying the design rather than the implementation itself.

## Which approach is more practical today?

Both have working examples. Approach 2 (verified components) is more immediately deployable in existing systems — [Stakpak's Cedar-based permission system](https://stakpak.dev/) is in production today.

Approach 1 (generating verified code) is advancing rapidly. As of late 2025, SOTA models (Opus 4+, etc.) paired with MCP tooling for provers have crossed a new threshold of practical usability for autoformalization, making this increasingly viable for real projects.

## Which prover language should I use?

There's no single answer — it depends on your domain and team:

- **Lean 4**: Strong momentum, the Mathlib library, and the most LLM tooling as of 2025. A strong default for new projects, especially mathematics-adjacent work.
- **ACL2**: Industrial track record, particularly for hardware and systems verification. Lisp-based with powerful automation; well-suited for teams already in that ecosystem.
- **Quint**: Readable TLA+-style specs with good tooling. Particularly well-suited for distributed systems and protocol design.
- **Dafny**: Familiar imperative syntax; compiles to mainstream languages like Python and C#. Useful when you want a verified core alongside conventional code.
- **Rocq (Coq)**: Mature ecosystem, widely used in safety-critical systems and academic research.

## What have early experiments taught us?

- Standard coding agents can already produce working Lean and ACL2 code for well-understood problems.
- The feedback loop between the LLM and the prover — via MCP or similar tooling — is key to getting proofs to go through
- Small, well-scoped problems work much better than large ones; agents benefit from tight iteration cycles
- Tactic selection remains the hardest part for agents; domain-specific tooling (LeanCopilot, LLMLean) meaningfully helps

## What is the adoption barrier for verified code?

Verification-friendly languages remain a niche. Even when agents can generate correct proofs, the surrounding ecosystem — tooling, project setup, interoperability with mainstream languages — creates friction. Approaches like Dafny's compilation to Python/C# or verified Rust bridges help close the gap, but none are fully frictionless yet.

## If 2024 was the year of Formal Methods, what is 2026?

A few views from the community:

- **Jim**: 2026 is the year of Theorem Driven Development
- **Ray**: 2026 is the year [Software Should Work](https://softwareshould.work/)

## Have more questions?

Add them to [Issue #5](https://github.com/raymyers/awesome-verified-coding-agents/issues/5) — that's where we're collecting questions and answers from the community. Feel free to answer your own question too.
