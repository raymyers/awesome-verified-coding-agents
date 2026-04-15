# AGENTS.md — WASM 1.0 ACL2 Formalization

## Project
ACL2 formalization of WASM 1.0 operational semantics, extending the Kestrel books.

## Key Files
- `WASM1_PLAN.md` — Milestone plan with task bullets, MVP strategy, testing plan
- `ACL2_SEMANTICS_REF.md` — SpecTec → ACL2 mapping, build commands, patterns, references

## ACL2 Build
```bash
sudo apt-get install -y sbcl
git clone --depth 1 https://github.com/acl2/acl2.git /opt/acl2
cd /opt/acl2 && make LISP=sbcl
export ACL2=/opt/acl2/saved_acl2
cd /opt/acl2/books && ACL2=$ACL2 make USE_QUICKLISP=0 ACL2_CUSTOMIZATION=NONE kestrel/wasm/execution.cert
```

## Kestrel WASM Location
`/opt/acl2/books/kestrel/wasm/` — package: WASM, uses defaggregate, b*, kestrel/bv

## Testing Pattern
```lisp
;; Ground-truth: assert-event with concrete run
(assert-event (equal (top-operand (current-operand-stack (run N state))) expected))
;; Symbolic: defthm with implies + hints
(defthm name (implies guards (equal (run ...) expected)) :hints ...)
```

## Key Patterns
- Each instruction → `execute-<name>` function
- `execute-instr` does case dispatch on instruction tag
- `step` calls `execute-instr` on first instruction
- `run` loops step N times, handling return-from-function
- Values: `(:i32.const n)`, instructions: `(:i32.add)` etc.
- State: `(defaggregate state ((store storep) (call-stack call-stackp)))`
- Frame: `(defaggregate frame ((return-arity natp) (locals val-listp) (operand-stack operand-stackp) (instrs instr-listp)))`

## WASM 1.0 SpecTec Reference
`https://github.com/WebAssembly/spec/tree/main/specification/wasm-1.0`
- `8-reduction.spectec` = operational semantics (reduction rules)
- `1-syntax.spectec` = AST types and instructions
- `3-numerics.spectec` = numeric operation definitions
- `4-runtime.spectec` = runtime state structures
