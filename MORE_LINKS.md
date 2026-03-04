# More Links

Additional resources collected from community discussion, organized by topic.
See [README.md](./README.md) for curated highlights and project descriptions.

---

## Table of Contents

- [Verified Coding Agents and Support](#verified-coding-agents-and-support)
  - [Agents and Tools](#agents-and-tools)
  - [Autoformalization and Theorem Proving Research](#autoformalization-and-theorem-proving-research)
  - [Static Analysis and Code Intelligence](#static-analysis-and-code-intelligence)
- [Agentic Software Craft](#agentic-software-craft)
  - [Coding Agents](#coding-agents)
  - [Agent Frameworks and Patterns](#agent-frameworks-and-patterns)
  - [MCP and Agent Protocols](#mcp-and-agent-protocols)
  - [Evaluation and Benchmarks](#evaluation-and-benchmarks)
- [Formal Methods](#formal-methods)
  - [Proof Assistants and Languages](#proof-assistants-and-languages)
  - [Applications and Research](#applications-and-research)
- [Misc AI](#misc-ai)
  - [Models and Training](#models-and-training)
  - [Research and Theory](#research-and-theory)
- [Misc Software Craft](#misc-software-craft)
  - [Languages, Paradigms, and Tools](#languages-paradigms-and-tools)

---

## Verified Coding Agents and Support

### Agents and Tools

- [MCP server giving LLMs feedback from Lean](https://github.com/GasStationManager/LeanTool)
- [Wraps LeanTool for agent-assisted Lean proof development](https://github.com/GasStationManager/ProvablyCorrectVibeCoding)
- [Agentic Lean proof generation](https://github.com/project-numina/numina-lean-agent)
- [LLM-powered tactic suggestions in Lean](https://github.com/cmu-l3/llmlean)
- [AI assistance for Lean development](https://github.com/siddhartha-gadgil/LeanAide)
- [ACL2 in Jupyter notebooks](https://github.com/jimwhite/acl2-jupyter)
- [Higher-level language wrapper around ACL2](https://cogitolang.org/)
- [Zed's Agent Client Protocol (ACP) in a Jupyter kernel](https://github.com/jimwhite/agent-client-kernel)
- [DeepMind CodeMender: AI agent for automated vulnerability repair](https://deepmind.google/discover/blog/introducing-codemender-an-ai-agent-for-code-security/)
- [seL4: formally verified microkernel](https://github.com/seL4/seL4)
- [No-code platform by Adam Chlipala (formal verification researcher) incorporating verified components](https://nectry.com/)
- [Autoformalization experiments and tooling](https://github.com/dataopsnick/autoformalization)
- [Cedar policy language homepage](https://www.cedarpolicy.com/en)
- [acl2-docker: Docker image for ACL2](https://github.com/mister-walter/acl2-docker)
- [lean4code: LeanDojo VS Code editor for Lean](https://github.com/lean-dojo/lean4code)
- [Formal Foundry: formal methods for AI systems](https://formalfoundry.ai/)
- [MS Power Platform CAT Kit: plan validation for agent tool use](https://devblogs.microsoft.com/powerplatform/plan-validation-cat-kit/)
- [Flaw in Gemini CLI allowed code execution via prompt injection](https://arstechnica.com/security/2025/07/flaw-in-gemini-cli-coding-tool-allowed-hackers-to-run-nasty-commands-on-user-devices/)
- [Code execution through email: exploiting Claude via MCP](https://www.pynt.io/blog/llm-security-blogs/code-execution-through-email-how-i-used-claude-mcp-to-hack-itself)

### Autoformalization and Theorem Proving Research

- [TheoremLlama: Transforming General-Purpose LLMs into Lean 4 Experts](https://arxiv.org/abs/2407.03203)
- [LeanDojo: environment and benchmark data for machine learning on Lean proofs](https://leandojo.org/)
- [AlphaProof: DeepMind AI solves IMO problems at silver-medal level](https://deepmind.google/discover/blog/ai-solves-imo-problems-at-silver-medal-level/)
- [Rethinking Verification for LLM Code Generation: From Generation to Testing](https://arxiv.org/abs/2507.06920)
- [Hilbert: formal specification and reasoning framework for LLM-based agents](https://www.arxiv.org/abs/2509.22819)
- [The Fusion of LLMs and Formal Methods for Trustworthy AI Agents: A Roadmap](https://arxiv.org/abs/2412.06512)
- [Getting from Generative AI to Trustworthy AI: What LLMs might learn from Cyc](https://arxiv.org/abs/2308.04445)
- [Lean Zulip: MCP Tools for LLMs and Agentic Mathematics](https://leanprover.zulipchat.com/#narrow/channel/219941-Machine-Learning-for-Theorem-Proving/topic/MCP.20Tools.20for.20LLMs.20and.20Agentic.20Mathematics)
- [LLM Post-Training: A Deep Dive into Reasoning Large Language Models](https://arxiv.org/pdf/2502.21321)
- [RL's Razor: Why Online Reinforcement Learning Forgets Less](https://arxiv.org/abs/2509.04259)
- [LLMLift: verifying LLM-generated code via lifting to proof assistants](https://arxiv.org/abs/2406.03003)
- [Coq used to resolve the fifth Busy Beaver — formal methods landmark](https://www.quantamagazine.org/amateur-mathematicians-find-fifth-busy-beaver-turing-machine-20240702/)
- [The Little Prover: introduction to inductive proofs via J-Bob](https://the-little-prover.github.io/)

### Static Analysis and Code Intelligence

- [LLMSA: Compositional Neuro-Symbolic Approach to Compilation-free Static Analysis](https://arxiv.org/abs/2412.14399)
- [LLMSCAN: tree-sitter-powered syntactic extractor for LLM-based analysis](https://github.com/PurCL/LLMSCAN)
- [LLMDFA: Analyzing Dataflow in Code with Large Language Models](https://github.com/chengpeng-wang/LLMDFA)
- [LLMSAN: LLM-based static analysis for security](https://github.com/chengpeng-wang/LLMSAN)
- [Static analysis to guardrail coding agents without executing code](https://arxiv.org/html/2410.09117v1)
- [Multi-SWE-bench: multilingual software engineering benchmark](https://arxiv.org/abs/2504.02605)
- [Fuzzing Book: extracting dynamic invariants from executions](https://www.fuzzingbook.org/html/DynamicInvariants)
- [KLEE: symbolic execution engine for finding bugs in C programs](https://klee-se.org/)
- [Space and Time Proof of SQL: ZK proof of SQL query execution](https://github.com/spaceandtimelabs/sxt-proof-of-sql)

## Agentic Software Craft

### Coding Agents

- [OpenHands: open-source coding agent platform](https://github.com/All-Hands-AI/OpenHands)
- [OpenHands CLI: AI-powered development in your terminal](https://www.all-hands.dev/blog/the-openhands-cli-ai-powered-development-in-your-terminal)
- [OpenHands: SOTA on SWE-bench with inference-time scaling and critic model](https://www.all-hands.dev/blog/sota-on-swe-bench-verified-with-inference-time-scaling-and-critic-model)
- [OpenHands Index: cross-functional agent evaluation](https://openhands.dev/blog/openhands-index)
- [Aider: AI pair programming in the terminal](https://github.com/Aider-AI/aider)
- [Aider SOTA on SWE-bench and SWE-bench Lite](https://aider.chat/2024/06/02/main-swe-bench.html)
- [Aider LLM leaderboards for coding](https://aider.chat/docs/leaderboards/)
- [SWE-agent: agent-computer interfaces for automated software engineering](https://swe-agent.com/latest/)
- [SWE-agent paper: Agent-Computer Interfaces Enable Automated Software Engineering](https://arxiv.org/abs/2405.15793)
- [mini-SWE-agent: minimal (~100 lines) coding agent with solid benchmark scores](https://github.com/SWE-agent/mini-swe-agent)
- [Agentless: fixed-stage agent matching multi-agent benchmarks at lower cost](https://github.com/OpenAutoCoder/Agentless)
- [OpenAI Codex: CLI coding agent](https://github.com/openai/codex)
- [Goose: open agent from Block, MCP-native](https://block.github.io/goose/)
- [Goose GitHub repo (Rust)](https://github.com/block/goose)
- [Amazon Q Developer CLI — includes Rust components via PyO3](https://github.com/aws/amazon-q-developer-cli)
- [Don't Sleep on Single-Agent Systems — OpenHands blog](https://www.all-hands.dev/blog/dont-sleep-on-single-agent-systems)
- [Konwinski Prize strategy guide: common agent libraries and patterns](https://github.com/raymyers/konwinski-prize-strategy-guide)
- [AutoAgent: fully-automated zero-code LLM agent framework](https://github.com/HKUDS/AutoAgent)
- [Meta Coral: collaborative reasoning via consensus between adversarial agents](https://github.com/facebookresearch/collaborative-reasoner)
- [Context7: MCP context service for coding agents](https://github.com/upstash/context7)
- [The Claude Code workflow you can copy](https://medium.com/@chrisdunlop_37984/the-claude-code-workflow-you-can-copy-6265009df76d?sk=afa02989b227ebedb156c546971ea198)
- [OpenManus: open agent framework from FoundationAgents](https://github.com/FoundationAgents/OpenManus)

### Agent Frameworks and Patterns

- [PydanticAI: structured and validated LLM responses using Pydantic](https://github.com/pydantic/pydantic-ai)
- [Instructor: structured outputs from LLMs](https://python.useinstructor.com/)
- [DSPy: programming framework for LLM pipelines](https://dspy.ai/)
- [DSPy agent tutorials](https://dspy.ai/tutorials/agents/)
- [TextGrad: automatic differentiation via text for LLM optimization](https://textgrad.com/)
- [BeeAI: IBM agent framework (Linux Foundation)](https://github.com/i-am-bee)
- [mcp-agent: compose agents from MCP tools](https://github.com/lastmile-ai/mcp-agent)
- [OctoTools: extensible Stanford agent framework with strong benchmark results](https://github.com/octotools/octotools)
- [Verifiers: TRL GRPO fine-tuner running code in each reasoning step](https://github.com/willccbb/verifiers/tree/dev)
- [rStar2: Microsoft agent with tool-calling and self-play reasoning](https://github.com/microsoft/rStar)
- [Adaptive Graph of Thoughts: test-time reasoning unifying chain, tree, and graph](https://arxiv.org/abs/2502.05078)
- [Interactive Agents to Overcome Ambiguity in Software Engineering](https://arxiv.org/abs/2502.13069)
- [Graph-based repo localization for coding agents](https://arxiv.org/abs/2503.09089)
- [Survey: How Code Empowers LLMs to Serve as Intelligent Agents](https://arxiv.org/abs/2401.00812)
- [Agent0: RL with naturally occurring objective functions](https://arxiv.org/abs/2511.16043)
- [Agent0 GitHub repo](https://github.com/aiming-lab/Agent0)
- [Mozilla: run agents anywhere safely using WASM](https://github.com/mozilla-ai/wasm-agents-blueprint)
- [Volcano: MCP-based agent SDK, browser/WASM-friendly](https://konghq.com/blog/product-releases/volcano)
- [Volcano SDK GitHub repo](https://github.com/Kong/volcano-sdk)
- [Scaling data collection for training SWE agents](https://nebius.com/blog/posts/scaling-data-collection-for-training-swe-agents)
- [Prompt engineering: bootstrapping with prompts](https://chip-hennig.medium.com/prompt-engineering-pulling-yourself-up-by-the-bootstraps-fc15c4a44d68)

### MCP and Agent Protocols

- [MCP specification and architecture](https://spec.modelcontextprotocol.io/specification/2024-11-05/architecture/)
- [Official MCP servers reference implementations](https://github.com/modelcontextprotocol/servers)
- [Awesome MCP Servers: curated list](https://github.com/punkpeye/awesome-mcp-servers)
- [Awesome MCP Clients: curated list](https://github.com/punkpeye/awesome-mcp-clients)
- [JetBrains MCP plugin](https://github.com/JetBrains/mcp-jetbrains/)
- [OpenAI Agents Python SDK: MCP integration](https://openai.github.io/openai-agents-python/mcp/)
- [mcp.run: MCP client and server running in WASM](https://docs.mcp.run/blog/2024/12/18/universal-tools-for-ai/)
- [Google A2A (Agent-to-Agent) protocol: multi-agent coordination on top of MCP](https://google.github.io/A2A/)
- [How Goose uses MCP for agent integrations](https://block.github.io/goose/blog/2025/02/17/agentic-ai-mcp)

### Evaluation and Benchmarks

- [SWE-bench leaderboard](https://www.swebench.com/)
- [SWE-bench Verified: curated subset of actually-solvable instances](https://openai.com/index/introducing-swe-bench-verified/)
- [Konwinski Prize: $1M contest for 90% on SWE-bench](https://www.kaggle.com/competitions/konwinski-prize)
- [Multi-SWE-bench: multilingual software engineering benchmark](https://multi-swe-bench.github.io/)
- [CodeClash: 'goals not tasks' eval from SWE-bench team](https://codeclash.ai/)
- [CodeELO: ELO-based system making humans and agents comparable](https://codeelo-bench.github.io/#leaderboard-table)
- [AgentLab: framework for developing, testing, and benchmarking web agents](https://github.com/ServiceNow/AgentLab)
- [ASTRA: multi-file project-based coding benchmark (HackerRank)](https://www.hackerrank.com/ai/astra-reports)
- [cline-bench: real-world open-source agentic coding benchmark](https://cline.bot/blog/cline-bench-initiative)
- [Galileo agent leaderboard: tool use and token cost](https://huggingface.co/spaces/galileo-ai/agent-leaderboard)
- [SWE-bench analysis: the disturbing reality of AI coding benchmarks](https://arxiv.org/pdf/2410.06992)

## Formal Methods

### Proof Assistants and Languages

- [F* (F-star): general-purpose proof-oriented programming language from MSR/Inria](https://fstar-lang.org/)
- [Reliable Software in the LLM Era — Gabriela Moreira of Quint](https://quint-lang.org/posts/llm_era)
- [ACL2 books in semantic web form — arithmetic](https://jimwhite.github.io/acl2/books/arithmetic-5/lib/basic-ops/numerator-and-denominator.html)
- [ACL2 books in semantic web form — number theory](https://jimwhite.github.io/acl2/books/kestrel/number-theory/defprime.html)
- [Adenine: semantic web programming language](https://www.ifcx.org/wiki/Adenine.html)
- [Adenine GitHub repo](https://github.com/jimwhite/adenine)
- [Rosette: solver-aided programming language built on Racket](https://docs.racket-lang.org/rosette-guide/index.html)
- [Python interactive theorem proving — Philip Zucker](https://www.philipzucker.com/python-itp/)
- [Frama-C: framework for static analysis and verification of C programs](https://frama-c.com/)

### Applications and Research

- [Hardware/Software Co-Verification with ACL2 (2022)](https://arxiv.org/abs/2205.11709)
- [DARPA TRACTOR: LLMs to convert C/C++ to Rust](https://www.darpa.mil/news-events/2024-07-31a)
- [Slack: LLM + AST/DOM logic for Enzyme-to-RTL automated test migration](https://slack.engineering/balancing-old-tricks-with-new-feats-ai-powered-conversion-from-enzyme-to-react-testing-library-at-slack/)
- [Thoughtworks CodeConcise: LLM-powered AST to knowledge graph for legacy code](https://martinfowler.com/articles/legacy-modernization-gen-ai.html)
- [Imagine a Dependently Typed Python — Andor Penzes, Lambda Days 2024](https://youtu.be/3zinei9AAq0?si=4nCcdP9lP4XWCEVQ)
- [Philip Wadler: The Two Cultures of Artificial Intelligence (keynote)](https://youtu.be/OH6vJZ0PDrQ)
- [Future of Coding podcast: Beyond Syntax — visual and structural editors](https://futureofcoding.org/episodes/073)
- [VPRI STEPS: 100x code reduction using scoped DSLs](https://web.archive.org/web/20140108193416/http://www.vpri.org/pdf/tr2011004_steps11.pdf)
- [Exo 2: user-schedulable DSLs for high-performance computing](https://news.mit.edu/2025/high-performance-computing-with-much-less-code-0313)
- [OptiTrust: interactive framework for source-to-source transformations](https://www.chargueraud.org/research/2022/optitrust/optitrust.pdf)
- [KLEE: symbolic execution paper — USENIX OSDI 2008](https://www.usenix.org/legacy/event/osdi08/tech/full_papers/cadar/cadar.pdf)
- [DARPA Translating All C to Rust (TRACTOR) program page](https://www.darpa.mil/research/programs/translating-all-c-to-rust)
- [Compiler verification with ACL2 — formal methods for compilers](https://www.ssw.uni-linz.ac.at/General/Staff/TW/FormCompilerVerificationACL2.pdf)
- [Cosette: automated SQL query equivalence verification](https://cosette.cs.washington.edu/)

## Misc AI

### Models and Training

- [Qwen3-Coder: Alibaba coding LLM](https://qwenlm.github.io/blog/qwen3-coder/)
- [Qwen Code: CLI coding tool](https://github.com/QwenLM/qwen-code)
- [The Illustrated DeepSeek-R1](https://newsletter.languagemodels.co/p/the-illustrated-deepseek-r1)
- [DeepSeek-V3](https://github.com/deepseek-ai/DeepSeek-V3)
- [Simon Willison on DeepSeek-V3](https://simonwillison.net/2024/Dec/26/deepseek-v3/)
- [Unsloth dynamic GGUFs beat proprietary models on Aider Polyglot benchmark](https://docs.unsloth.ai/basics/unsloth-dynamic-ggufs-on-aider-polyglot)
- [Open-source RL libraries for LLMs — Anyscale](https://www.anyscale.com/blog/open-source-rl-libraries-for-llms)
- [WebLLM: LLMs in the browser via WebGPU](https://webllm.mlc.ai/)
- [WebLLM GitHub repo](https://github.com/mlc-ai/web-llm)
- [LM Studio: desktop app for local models](https://lmstudio.ai/)
- [Tiny Recursive Models: small hierarchical reasoning models](https://arxiv.org/abs/2510.04871)
- [TinyRecursiveModels GitHub repo](https://github.com/SamsungSAILMontreal/TinyRecursiveModels)
- [DeepSeek 3FS: high-performance distributed file system for AI training](https://github.com/deepseek-ai/3FS)
- [Oumi: open and reliable frontier AI](https://oumi.ai/)

### Research and Theory

- [Noam Brown: AI reasoning models could have arrived decades ago](https://techcrunch.com/2025/03/19/openai-research-lead-noam-brown-thinks-ai-reasoning-models-couldve-arrived-decades-ago/)
- [MSR: AI and critical thinking survey](https://www.microsoft.com/en-us/research/wp-content/uploads/2025/01/lee_2025_ai_critical_thinking_survey.pdf)
- [ML-powered automated physics/chemistry reasoning](https://link.aps.org/doi/10.1103/xrbw-xr49)
- [THOR: physics reasoning ML system (LANL)](https://github.com/lanl/thor)
- [Google Tunix: RL for explainable reasoning with small LLMs](https://www.kaggle.com/competitions/google-tunix-hackathon)
- [AISuite: Andrew Ng's unified LLM API library](https://github.com/andrewyng/aisuite)

## Misc Software Craft

### Languages, Paradigms, and Tools

- [GLISP: graphical Lisp with direct manipulation](https://glisp.app/)
- [Bauble Studio: interactive visual tool using Lisp](https://bauble.studio/)
- [Electric Clojure: reactive full-stack framework with unified client/server model](https://github.com/hyperfiddle/electric)
- [Awesome Structure Editors: projectional/structural editors list](https://github.com/yairchu/awesome-structure-editors)
- [Wisp: Python-style indentation for Lisp — helps LLMs with parenthesis balancing](https://www.draketo.de/software/wisp)
- [Sourcebot: fast code search, deployable as a single Docker image](https://github.com/sourcebot-dev/sourcebot)
- [AnythingLLM: all-in-one agent building environment with RAG and MCP](https://github.com/Mintplex-Labs/anything-llm)
- [The Sudoku Affair: Jeffries vs Norvig — tests vs algorithms](https://explaining.software/archive/the-sudoku-affair/)
- [Proving tmux is Turing complete](https://willhbr.net/2024/03/15/making-a-compiler-to-prove-tmux-is-turing-complete/)
- [Compiling Java and Clojure to WASM](https://shagunagrawal.me/posts/compiling-clojure-to-wasm-image/)
- [Nix: death by a thousand cuts](https://www.dgt.is/blog/2025-01-10-nix-death-by-a-thousand-cuts/)
- [Hillel Wayne: Why I prefer RST to Markdown](https://buttondown.com/hillelwayne/archive/why-i-prefer-rst-to-markdown/)

