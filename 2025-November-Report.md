# Verified Coding Agents

"Verified coding agents" is a term I'm coining to describe the pursuit of bringing mathematical certainty—via the field of formal verification—to the valuable but highly chaotic space of AI coding agents. Large language models give these agents impressive capabilities, but also some rather chaotic characteristics. Verification is meant as a counterbalance.

## What is a Coding Agent?

A coding agent is an AI-based tool that takes requests in natural language and performs multi-step software development tasks, using feedback from the environment as it goes. They're often implemented as an LLM chat-loop with tool use, where the tools are suited for coding tasks.

**Tools typically include:**
- **Navigation** - browsing codebases, finding files
- **Editing** - modifying code with various strategies
- **Execution** - running tests, checking builds
- **Knowledge** - documentation, search, context retrieval

## What is Formal Verification?

Formal verification is reasoning about programs with mathematical rigor by proving the implementation matches some specified behavior. Formal specification is a related practice focused on verifying the design rather than the implementation itself.

## What is a Verified Coding Agent?

A verified coding agent combines coding agents with formal verification in one of these ways:

1. **A coding agent that generates verified code**
2. **A coding agent with some verified component**

## Why?

To demonstrate ways of using coding agents with higher assurance, inspiring future work on the risk-bottleneck of practical AI coding. If we can show concrete approaches that work, we can start closing the trust gap.

## Approach 1: Agents Generating Verified Code

### The Straightforward Path

Regardless of what kind of agent we have, if we happen to be using it to generate code in a verifiable language, we could say we have a verified coding agent. Whatever the agent generates, we'll get assurances on the result—to whatever extent we understand the specs, we ought to be able to reason about what the code might do.

You can use ChatGPT or your favorite coding agent to generate code in a provable language such as **Lean**, **ACL2**, **Dafny**, **Rocq** (formerly Coq), or **Isabelle**. These are some of the common ones.

### The Adoption Barrier

Here's the catch: verification-friendly languages tend to be pretty niche within computer science and software engineering as a whole. There are some domains where they've built sturdy bridges to use these arcane tools, but they're far from popular consumption.

If you want to create a verified coding agent in the sense of just generating verified code, you've got the task of convincing your target audience that they want to write in a verifiable language—or at least write code that can interface with one. This either means you're targeting fairly niche users, or you're going to try and build such a bridge yourself.

**Dafny** is an example of an attempt at such a bridge. It compiles down to industrial languages like Python, C#, and Java. That's pretty interesting. There are also a number of attempts well along the way to create verifiable bridges to Rust. There's OCaml, which Rocq and some others will extract to. These allow an architecture of having a verified core in something a little more arcane, and then an interface to it—you're using this extracted prover code with your conventional industrial code around it, calling into the verified core.

### The Interface Problem

I think that if you're targeting a wide audience, none of the existing solutions are quite there—even Dafny. While it may compile to Python, it doesn't compile to Python that's very convenient to interface with. The interfaces aren't well documented. You end up with things like... just to use a simple string or an integer, you're wrapping them in their custom verifiable types. It's not a very friendly experience right now.

### Provable Python: A Bridge Idea

You could build on existing solutions to make them more friendly, or you could take an approach like this: an idea I had recently was **Provable Python**.

Suppose we define a semantics for a very restricted subset of Python and say that our prover is going to be able to speak that. You write in Provable Python, extract it to a prover language to make whatever verifications you want—but this is also plain Python. Someone who knows Python can look at it and understand it. They just may not understand what features they're allowed to use and not use.

To make this maximally simple, it would be **purely functional**—no mutations, no side effects. Therefore we're restricting the architecture such that your verified core communicates entirely via input/output, with primitive types and maybe Pydantic models as the only ways it could interface. Purely functional, no side effects—but otherwise perfectly runnable Python code that you could also perform verification-related tasks on.

I think that would be pretty interesting.

### Specialized Agents for Verified Code

Beyond just prompting standard agents, you could build agents made especially for verified code—agents that understand the idioms of proof assistants, can invoke tactics, and know how to structure proofs. Or agents that externalize reasoning to a prover, delegating verification tasks to specialized systems.

## Approach 2: Agents with Verified Components

There's also making the agent itself verified, regardless of what kind of code it's working on. This may mean you write an agent in a verification-friendly language, or you verify some component.

I think one of the most tractable types of verified coding agents would be a coding agent where some **important piece** of it had been verified.

### Example: StackPack's Cedar Permission System

An example of this in production would be **StackPack**, because its permission model uses Amazon's **Cedar** permission language (an access control language). Cedar has a Rust implementation with high assurance—there's a formally verified spec in Lean, and the verification technique involves differential testing between the executable model and the production version of the code.

### Other Verifiable Components

You can imagine other kinds of components:

**The Planner** - We now have agents with explicit planning tools that keep track of tasks to be done. You could externalize that into a prover to manage more kinds of facts about the relationships between tasks, what hypotheses were being validated, and so forth.

**The Condenser** - There are invariants in the condenser, the part that produces the view that goes into the context of an individual prompt based on a whole conversation (which might be bigger than a prompt can handle). There are various heuristics and invariants with which you could say that a certain condensation is valid. You could verify the code attempting to do that.

**The Tools** - Individual tools that the agent uses to make edits, run commands, etc. These could all be verified. It's just a matter of choosing where verification provides the most value—unless you're just doing it to prove verification is possible, you'd probably want some idea of when this assurance actually helps.

### Mini-SWE Agent as a Feasibility Case

If you look at **Mini-SWE Agent**, which is an attempt to be one of the smallest usable agents—and it does get a respectable SWE-bench score with something like 100 lines of Python in addition to the boilerplate LLM calls—if that's all the code you need to get something usable, you definitely can do that with verified components, or even the whole thing verified if it's a simple implementation.

## Restricted Agents by Design

This overlaps with verifying components, but it's more like verifying the design. Restricted agents try to get assurance not by verifying particular agent code, but by construction—reducing the power the agent has to something you can have control over.

**Examples:**
- Don't let it edit files in an open-ended way—only syntax transformations, or only certain files
- Enforce test coverage—don't allow an unbounded number of edits to code not yet covered by tests
- Implement test-driven development not just as a prompt, but as enforced process

### Test-Commit-Revert Agents

One example I've been thinking about: a **test-commit-revert agent**. Test-Commit-Revert (TCR) was a workflow popularized by Kent Beck. When you save your changes, it runs the tests—if they fail, it reverts. You've got to make your changes again. This enforces small steps.

We know that agents work well in small steps and with tests. So perhaps TCR would be a good workflow for them.

We'd probably have to adapt it, because the trivial way to always save your changes is just... don't test them. Vacuous tests let you TCR your way to any change. So it'd have to be TCR along with some kind of coverage enforcement.

If you're really trying to be high assurance, you might also worry the agent could delete your tests or change your configuration so coverage isn't enforced. So again—you could prove it or not, but just by construction, you can say what the agent's allowed to edit. Just don't include the build configuration in what it's allowed to do. If it needs to add a dependency or make some other change to build configuration, that becomes something requiring a higher level of intervention.

## The Tool Use Leverage Point

Very often we've got a Python agent SDK already, such as the new OpenHands software agent SDK. Perhaps we don't need to reinvent the wheel.

**Tool use is a very high-leverage point**, in my opinion. Regardless of how the agent is coded, if it's going to interact with the world, it's going to do so through a tool. Whatever assurances you put in how the tools are used—or what the tools do when called—you can make some pretty strong guarantees.

You could literally have the LLM make any output whatsoever, be trying actively to delete your hard drive even—and if the tools are set up with appropriate assurance, there's really no risk.

Pragmatically, I think taking existing Python agent SDKs, taking out their default tools, and putting either new tools or some go-between to restrict when tools are allowed to be called—those permission and tool angles are very strong for high assurance. Then you think about when we need to interrupt the user and when we don't.

## Agent Verification Protocol: A Bigger Vision

We have protocols emerging: **MCP** (Model Context Protocol) lets agents interface with tools. **ACP** (Agent-Client Protocol) is going to allow agents to interface with multiple editors and user interfaces—Zed and Toad have adopted it. It's vendor-neutral, kind of taking the place of LSP (Language Server Protocol) within editors.

What if we had **Agent Verification Protocol**?

At first you might think: is this just sitting between the agent and MCP? Like a permission checker for what tool you can use and when? Maybe. But imagine it's bigger in scope.

### Spec-Driven Development

Some people believe that by scaling out this library of prompts we give agents to develop functionality—making the prompts, docs, specs, product requirement documents the new source code—that'll work. Let's take the hypothesis that it **won't** work, that it won't scale, because **prompts are not an abstraction**. Suppose prompts aren't a robust enough abstraction to do this kind of work on large products.

Well, it'll need to be code-like. And a **formal spec is maybe the best of all worlds here**.

If we run with that, perhaps agents will need to interact with some verification world that's more than just "what tools am I allowed to use." It's "what things have been verified about the requirements of the codebase?"

### A Library of Formal Specs

The agent might need to interact with a spec library—formal specs across different systems. Maybe you've got some things in TLA+, or a bare-bones reference implementation in Lean Prover (like that Amazon Cedar permissions library). Maybe you've got executable specs in some other format—maybe it's Cucumber, classic BDD. Maybe it's Alloy specs.

How do we give agents proper access to that? To maybe add to it? What if there were something that could talk to and interact with your formal specs, build out your domain—interact with your Lean specs, your TLA+ specs, your cucumber acceptance tests, your formal domain model?

**Is it feasible to have an Agent Verification Protocol that makes this all intelligible to any agent that implements it?**

I don't know. I think we ought to figure that out.
