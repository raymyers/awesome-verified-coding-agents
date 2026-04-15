# WASM 1.0 ACL2 Formalization Plan

An agent-generated plan and reference for formalizing the WASM 1.0 operational semantics in ACL2, extending the [Kestrel Institute's WASM books](https://github.com/acl2/acl2/tree/master/books/kestrel/wasm).

## What This Is

A comprehensive formalization plan and semantics reference document, produced by an AI agent that:

1. **Studied the source material**: The [WASM 1.0 SpecTec formal spec](https://github.com/WebAssembly/spec/tree/main/specification/wasm-1.0) (2300 lines across 10 files) and the existing [Kestrel WASM skeleton](https://github.com/acl2/acl2/blob/master/books/kestrel/wasm/execution.lisp) in ACL2
2. **Studied related Kestrel models**: The [EVM formalization](https://github.com/acl2/acl2/tree/master/books/kestrel/ethereum/evm) and [JVM execution model](https://github.com/acl2/acl2/tree/master/books/kestrel/jvm) for architectural patterns
3. **Installed and built ACL2**: Confirmed SBCL + ACL2 8.7+ builds, all existing Kestrel WASM books certify
4. **Validated the approach**: Ran a concrete execution test (`add(3,4)=7`) through ACL2
5. **Produced the plan**: 9 milestones from MVP to full formalization, with testing strategy

## Properties Planned for Verification

- **Instruction correctness**: Each WASM 1.0 instruction's ACL2 semantics matches the SpecTec reduction rules
- **Program proofs**: Symbolic correctness theorems for representative programs (addition, factorial, array sum)
- **Guard verification**: All ACL2 functions have verified guards (type-safe execution)
- **Book certification**: Every `.lisp` file certifies through ACL2's proof checker

## Files

| File | Description |
|---|---|
| [`WASM1_PLAN.md`](WASM1_PLAN.md) | 9-milestone plan with task bullets, MVP strategy, 16 test programs, testing at 4 levels |
| [`ACL2_SEMANTICS_REF.md`](ACL2_SEMANTICS_REF.md) | SpecTec → ACL2 mapping, build commands, numeric operation table, control flow design, reduction rule catalogue |

## Model & Agent

- **Model**: Claude claude-sonnet-4-20250514 (via OpenHands agent)
- **Task prompt**: Study the WASM 1.0 SpecTec and Kestrel WASM skeleton, plan an ACL2 formalization, create milestone plan and semantics reference, install ACL2 and verify the approach
- **Agent actions**: Cloned repos, read all 10 SpecTec files + 7 Kestrel WASM files + EVM/JVM models, built ACL2, certified 3 books, ran execution test

## Prover & Verification Commands

```bash
# Install SBCL
sudo apt-get install -y sbcl

# Clone and build ACL2
git clone --depth 1 https://github.com/acl2/acl2.git /opt/acl2
cd /opt/acl2 && make LISP=sbcl
export ACL2=/opt/acl2/saved_acl2

# Certify existing Kestrel WASM books (confirms build works)
cd /opt/acl2/books
ACL2=$ACL2 make USE_QUICKLISP=0 ACL2_CUSTOMIZATION=NONE kestrel/wasm/execution.cert
ACL2=$ACL2 make USE_QUICKLISP=0 ACL2_CUSTOMIZATION=NONE kestrel/wasm/add-proof.cert
ACL2=$ACL2 make USE_QUICKLISP=0 ACL2_CUSTOMIZATION=NONE kestrel/wasm/parse-binary.cert
```

## Verified Baseline

The agent confirmed these existing results before planning:

- ✅ `execution.lisp` certifies (0.67s) — core interpreter with i32.add, local.get
- ✅ `add-proof.lisp` certifies (0.42s) — symbolic proof: `∀ x y : u32. add(x,y) = bvplus(32,x,y)`
- ✅ `parse-binary.lisp` certifies (7.29s) — partial WASM binary parser
- ✅ Concrete test: `run 4` of `[local.get 1, local.get 0, i32.add]` with locals `(3, 4)` yields `(:i32.const 7)`

## Known Gaps

- This is a **plan**, not a completed formalization — no new ACL2 code is included yet
- Floating-point (f32/f64) IEEE 754 modeling in ACL2 is flagged as high-risk/high-effort
- Some Kestrel BV library functions for rotate/clz/ctz/popcnt may need custom definitions
- The label stack design for blocks/loops is proposed but untested
- The plan assumes the existing skeleton's architecture (explicit call stack) rather than SpecTec's admin-instruction nesting — this is a deliberate design choice for proof ergonomics but diverges from the formal spec's structure
