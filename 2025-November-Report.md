# Verified Coding Agents - November 2025 Report

"Verified coding agents" is the pursuit of bringing elements of mathematical certainty to the valuable but highly chaotic space of AI coding agents. Large Language Models (LLMs) give these agents impressive capabilities, but also unpredictable characteristics. Formal Verification is meant as a counterbalance.

## Why?

To demonstrate ways of using coding agents with high assurance, inspiring future work on the risk-bottleneck of practical AI coding. If we can show concrete approaches that work, we can start closing the trust gap. See also the July video: ["Verified Coding Agents" on Craft vs Cruft](https://www.youtube.com/watch?v=7hRgK6G5aok)

## What is a Coding Agent?

A coding agent is an AI-based tool that takes requests in natural language and performs multi-step software development tasks, using feedback from the environment as it goes. They're often implemented as an LLM chat-loop with tool use, where the tools are suited for coding tasks.

**Tools typically include:**
- **Navigation** - browsing codebases, finding files
- **Editing** - modifying code with various strategies
- **Execution** - running tests, checking builds
- **Knowledge** - documentation, search, context retrieval

## What is Formal Verification?

Formal verification is reasoning about programs with mathematical rigor by proving the implementation matches some specified behavior. Formal Specification is a related practice focused on verifying the design rather than the implementation itself.

## What is a Verified Coding Agent?

A verified coding agent combines coding agents with formal verification in one of these ways:

1. **A coding agent that generates verified code**
2. **A coding agent with some verified component**

## Approach 1: Agents Generating Verified Code

### The Straightforward Path

Regardless of what kind of agent we have, if we happen to be using it to generate code in a verifiable language, we could say we have a verified coding agent. Whatever the agent generates, we'll get assurances on the result—to whatever extent we understand the specs, we ought to be able to reason about what the code might do.

You can use ChatGPT or your favorite coding agent to generate code in a provable language such as **Lean**, **ACL2**, **Dafny**, **Rocq** , or **Isabelle**.

There is low-hanging fruit in improving the user experience of these provers and how they integrate AI-suggestions. For instance:

* [LeanCopilot](https://github.com/lean-dojo/LeanCopilot)
* [Making ACL2 work in Jupyter notebooks](https://github.com/jimwhite/acl2-jupyter)
* See [awesome-verified-coding-agents](https://github.com/raymyers/awesome-verified-coding-agents) for more.

However there is a more fundamental barrier to adoption even beyond usability.

### The Adoption Barrier

Here's the catch: this needs to play well with existing code. Verification-friendly languages are a small niche within computer science and software engineering as a whole. There are some domains with special needs where they've built usable bridges to use these tools, but they're far from popular consumption.

Therefore, if you want to create a verified coding agent in the sense of just generating verified code, you've got the task of convincing your target audience that they want code in a verifiable language in the first place. This either means you're targeting fairly niche users, or you're going to try and interface with mainstream code by building a bridge yourself.

Dafny is an attempt at such a bridge. It compiles down to industrial languages like Python, C#, and Java. There are also attempts to create verifiable bridges to Rust. There's OCaml, which Rocq and others will extract to. These allow the architecture of a **verified core** written in something more arcane, you're using this extracted prover code with your conventional industrial code around it.

### The Interface Problem

I think that if you're targeting a wide audience, none of the existing solutions are quite there, even Dafny. While it may compile to Python, it doesn't compile to code that's convenient to work with. The project setup isn't well documented, and the types are weird. You end up these wrapper objects just to use a simple string or an integer. It's not a friendly experience right now.

### Provable Python: A Bridge Idea

You could build on existing solutions to make them more friendly, or you could take an approach like a verifiable subsets. An idea I had recently was **Provable Python**.

Suppose we define a semantics for a very restricted subset of Python and our prover is going to be able to speak that. You write in Provable Python, extract it to a prover language to make whatever verifications you want, but it also reads as plain Python. Someone who knows Python can look at it and understand it, they just may not understand what features they're allowed to use and not use.

To make this simple to verify, it would be **purely functional**: no mutations, no side effects. Therefore we're restricting the architecture such that your verified core communicates entirely via input/output, with primitive types and maybe Pydantic models as the only ways it could interface. Purely functional, no side effects, but otherwise perfectly runnable Python code the you could do proofs on.

I think that would be pretty interesting.

### Specialized Agents for Verified Code

Beyond just prompting standard agents, you could build agents made especially for verified development that understand the idioms of proof assistants, can invoke tactics, and know how to structure proofs. Or agents that externalize reasoning to a prover, delegating verification tasks to specialized systems.

## Approach 2: Agents with Verified Components

There's also making the agent itself verified, regardless of what kind of code it's working on. This may mean you write an agent in a verification-friendly language, or you verify some component.

I think one of the most tractable types of verified coding agents would be a coding agent where some **important piece** of it had been verified.

### Example: StakPak's Cedar Permission System

An example of this in production would be [StakPak](https://stakpak.dev/), because its permission model "Warden" uses Amazon's **[Cedar](https://www.cedarpolicy.com/en)** policy language. Cedar has a Rust implementation and a formally verified spec in Lean. They use differential testing between that verified reference implementation and the production version of the code.

### Other Verifiable Components

You can imagine other kinds of components:

**The Planner** - We now have agents with explicit planning tools that keep track of tasks to be done. We could externalize that into a prover to manage more kinds of facts about the relationships between tasks, what hypotheses were being validated, and so forth.

**The Condenser** - There are invariants in the condenser, the part that produces the view that goes into the context of an individual prompt based on a whole conversation (which might be bigger than a prompt can handle). There are various heuristics and invariants with which you could say that a certain condensation is valid. You could formally verify those algorithms.

**The Tools** - Individual tools that the agent uses to make edits, run commands, etc. These could all be verified. It's just a matter of choosing where verification provides the most value. Unless you're just doing it to prove verification is possible, you'd probably want some idea of what assurance is most valuable.

### Mini-SWE-agent as a Feasibility Case

**[mini-SWE-agent](https://github.com/SWE-agent/mini-swe-agent)**, aims to be one of the smallest useful coding agents, and it get's a respectable SWE-bench score with something like 100 lines of Python in addition to the boilerplate LLM calls. If that's all the code you need to get something usable, you definitely can do that with verified components, or even the whole thing verified if it's a simple implementation.

## Restricted Agents by Design

This overlaps with verifying components, but it's more like verifying the design. Restricted agents try to get assurance not by verifying particular agent code, but by construction: reducing the power the agent has to something you can have control over.

**Examples:**
- Don't let it edit files in an open-ended way, only use syntax transformations or certain files
- Enforce test coverage, don't allow arbitrary edits to code not yet covered by tests
- Implement test-driven development not just as a prompt, but as enforced process - see also TCR

### Test-Commit-Revert Agents

[Test-Commit-Revert](https://medium.com/@kentbeck_7670/test-commit-revert-870bbd756864) (TCR) is a workflow suggested by Kent Beck and others around 2018. When you save your changes, it runs the tests. If they fail, it reverts. You've got to make your changes again. `test && commit || revert` This enforces small steps.

We know that agents work well in small steps and with tests. So perhaps TCR could help them.

We'd probably have to adapt it, because the trivial way to always save your changes is just... don't test them. Vacuous tests let you TCR your way to any change. So it'd have to be TCR along with some kind of coverage enforcement.

It's also likely the agent will get stuck if it couldn't break a large transistion down, into small test-passing steps. Do we make that an user intervention point or find a technical solution? 

If you're looking for high assurance, you might also worry the agent could delete your tests or change your configuration so coverage isn't enforced. As before, you could enforce it by construction, you can say what the agent's allowed to edit. Just don't include the build configuration in what it's allowed to change. If it needs to add a dependency or make some other change to build configuration, it must break the flow and ask for user authorization.

## The Tool Use Leverage Point

Very often we've got a Python agent SDK already, such as the new OpenHands software agent SDK. Perhaps we don't need to reinvent the wheel by writing a new agent.

Tool use is a point of high-leverage. Regardless of how the agent is coded, if it's going to interact with the world, it's going to do so through a tool. This means you can provide strong guarantees by restricting how the tools can be used, or what the tools do when called.

You could literally have the LLM make any output whatsoever, actively try to delete your hard drive even, and if the tools are set up with appropriate assurance, there's no risk.

I think it's a very pragmatic approach to take existing Python agent SDKs, remove their default tools, and put in either new tools or some go-between to restrict when tools are allowed to be called. Then you think about when we need to interrupt the user and when we don't.

## Agent Verification Protocol: A Bigger Vision

We have protocols emerging: **MCP** (Model Context Protocol) lets agents interface with tools. **[ACP](https://github.com/agentclientprotocol/agent-client-protocol)** (Agent-Client Protocol) is going to allow agents to interface with multiple editors and user interfaces, Zed and Toad have adopted it. It's vendor-neutral, taking a similar role as LSP (Language Server Protocol) within editors.

What if we had **Agent Verification Protocol**?

At first you might think: is this just sitting between the agent and MCP? Like a permission checker for what tool you can use and when? Maybe. But it could have a bigger scope.

### Is Spec-Driven Development enough?

Some people believe that by scaling out the collection of prompts we give agents to develop functionality, we can just consider the docs, specs, and product requirements as "the new source code". Let's take the hypothesis that it **won't** work, that it won't scale, because **prompts are not an abstraction**. Suppose prompts aren't robust enough be the complete answer on large products.

If prose isn't enough, then our specs will need to be code-like. **Formal specs** may be the best of all worlds here. Perhaps agents will need to interact with some verification world that's more than just "what tools am I allowed to use." It's "what things have been verified about the requirements of the codebase?"

Another approach is [Behavior-Driven Development](https://behave.readthedocs.io/en/latest/philosophy/) (BDD), which defines a middleground of informal specs that run as tests on example data.

### A Library of Formal Specs

The agent might need to interact with a spec library, formal specs across different systems. Maybe you've got some things in TLA+, or a reference implementation in Lean Prover (like that Cedar policy engine). Maybe you've got executable specs in some other format, maybe it's Gherkin, classic BDD.

How do we give agents proper access to that, to navigate add to it? What if there were something that could talk to and interact with your formal specs, build out your domain—interact with your Lean specs, your TLA+ specs, your cucumber acceptance tests, your formal domain model?

Is it feasible to create this Agent Verification Protocol that makes this all intelligible to any agent that speaks it?

I don't know. I think we ought to figure that out.
