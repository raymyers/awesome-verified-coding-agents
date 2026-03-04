# Prompt Summary

This is a retrospective summary of the prompts that produced this PR. Not verbatim — reconstructed after the fact.

---

## Setup

- Create a new branch called `readme-update`.
- Add a GitHub Actions workflow that deletes the `.pr/` directory recursively on PR merge to `main`, so it never lands in the main branch.

## Research and Planning

- Study the existing `README.md`, `2025-November-Report.md`, and the open GitHub issues, then propose a plan for a better README and supporting resources.

The proposed structure was approved with these adjustments:
- Drop speculative items (Provable Python, Agent Verification Protocol) — too early.
- Replace a specific model version reference with "Opus 4+" to reflect the broader sentiment that as of late 2025, SOTA models in agents + MCP have crossed a new threshold of autoformalization usability.
- Don't rank prover languages — instead give distinct advantages for several: Lean, ACL2, Quint.
- CONTRIBUTING should direct: PRs for small changes/new links, issues for new sections, comments on Issue #5 for FAQ questions.

## Implementation

Implement the full plan:

- **README.md** — Rewrite with concept definitions, two-approach taxonomy, prover language comparison table, structured resource sections, and links to FAQ, examples, and CONTRIBUTING.
- **FAQ.md** — Community questions drawn from Issue #5 and the November report, including the "what year is 2026" exchange.
- **CONTRIBUTING.md** — Three contribution paths: PR, issue, FAQ comment.
- **examples/README.md** — Guide to the five kinds of examples welcome (generated verified code, agent code, prompts, tools, harnesses), with reproduction requirements for each including model version.

Refinements:
- Delete the insertion sort code examples; keep only `examples/README.md` as a guide.
- Note in CONTRIBUTING that PRs for examples are welcome and should follow `examples/README.md`.

## More Links

`links-annotated.json` is an extract from the **Nopilot Discord** — a curated, annotated dump of links shared in community discussion channels. From it, generate `MORE_LINKS.md`:

- Include URL and short description; strip author handles, dates, and conversation context entirely.
- Organize into sections with higher relevance at the top:
  - Verified Coding Agents and Support (with subsections: Agents & Tools, Autoformalization & Theorem Proving Research, Static Analysis & Code Intelligence)
  - Agentic Software Craft (Coding Agents, Agent Frameworks & Patterns, MCP & Protocols, Evaluation & Benchmarks)
  - Formal Methods (Proof Assistants & Languages, Applications & Research)
  - Misc AI (Models & Training, Research & Theory)
  - Misc Software Craft (Languages, Paradigms & Tools)
- Include a TOC with anchor links.
- After the initial pass: a truncated extraction had missed entries 110–135 (from `build-a-verified-agent.md` and `formal-methods.md`). Add those — Rosette, Frama-C, KLEE, LLMLift, OptiTrust, Cosette, the fifth Busy Beaver/Coq story, The Little Prover, Cedar, lean4code, MCP security articles, OpenHands CLI, OpenManus, Formal Foundry, ACL2 Docker, and others.
