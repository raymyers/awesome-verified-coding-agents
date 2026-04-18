# AGENTS.md — WASM 1.0 ACL2 Formalization

## Project
ACL2 formalization of WASM 1.0 operational semantics, extending the Kestrel books.
Repo: `raymyers/awesome-verified-coding-agents` branch `add-wasm1-acl2-formalization-plan-try1`
Subdir: `examples/wasm1-acl2-formalization-plan/`

## Current Status (2026-04-18)
- **Plan documents**: WASM1_PLAN.md (560+ lines, M0-M12) + ACL2_SEMANTICS_REF.md (900+ lines, 17 sections)
- **ACL2 environment**: Verified working — SBCL 2.5.2, ACL2 8.7, Kestrel books certified
- **Proof-of-concept**: Extended Kestrel execution.lisp with i32.sub, certified independently, 4 tests pass
- **Critical gotchas documented**: 17 verified operational findings in ACL2_SEMANTICS_REF.md §17

## Key Files
- `WASM1_PLAN.md` — Milestone plan with task bullets, MVP strategy, testing plan
- `ACL2_SEMANTICS_REF.md` — SpecTec → ACL2 mapping, build commands, patterns, references
- `execution.lisp` — Main semantics (canonical copy, also in src/)
- `proofs/proof-add-spec.lisp` — Add spec + commutativity (2 theorems)
- `proofs/proof-sub-spec.lisp` — Sub spec + self-zero + add-sub-inverse (3 theorems)
- `tests/test-spot-check.lisp` — 20 ground-truth tests
- `tests/test-packed-mem.lisp` — 10 packed memory tests
- `tests/oracle/check-all.sh` — Oracle pipeline (compile WAT → run Node.js)

## ACL2 Build
```bash
sudo apt-get install -y sbcl
git clone --depth 1 https://github.com/acl2/acl2.git /tmp/acl2-full
cd /tmp/acl2-full && make LISP=sbcl
export ACL2=/tmp/acl2-full/saved_acl2
```

## Certify Execution Book
```bash
# Copy our execution.lisp over the skeleton:
cp execution.lisp /tmp/acl2-full/books/kestrel/wasm/execution.lisp
# Certify with cert.pl (NOT bare make):
cd /tmp/acl2-full && books/build/cert.pl --acl2 ./saved_acl2 books/kestrel/wasm/execution
```
**CRITICAL**: Don't use `make -C books/kestrel/wasm` (no Makefile there). Use `cert.pl`.

## Run Tests
```bash
# Spot-check tests
echo '(ld "books/kestrel/wasm/test-spot-check.lisp") (quit)' | $ACL2
# Packed memory tests
echo '(ld "/tmp/test-packed-mem.lisp") (quit)' | $ACL2
# Proofs
echo '(ld "path/to/proof-sub-spec.lisp") (quit)' | $ACL2
# Oracle (needs wabt + node)
cd tests/oracle && bash check-all.sh
```

## State Aggregate (current shape)
```lisp
(defaggregate state
  ((store storep)        ; list of funcinst
   (call-stack ...)      ; list of frames
   (memory byte-listp)   ; flat byte list
   (globals globalinst-listp)))

(defaggregate frame
  ((return-arity natp)
   (locals val-listp)
   (operand-stack operand-stackp)
   (instrs true-listp)   ; relaxed from instr-listp for nested control
   (label-stack true-listp)))
```

## Key Patterns
- Each instruction → `execute-<name>` function
- `execute-instr` does case dispatch on instruction tag (`:i32.add`, `:block`, etc.)
- `step` calls `execute-instr` on first instruction
- `run` loops step N times, handling return-from-function + label completion
- Values: `(:i32.const n)`, `(:i64.const n)`
- Macros: `def-i32-binop`, `def-i32-relop`, `def-i32-unop`, `def-packed-load`, `def-packed-store`

## Proof Technique
```lisp
(defthm name
  (implies (and (unsigned-byte-p 32 a) ...)
           (equal (top-operand (current-operand-stack
                    (run N (make-state ...))))
                  (make-i32-val (bvplus 32 a b))))
  :hints (("Goal" :in-theory (enable run execute-instr execute-i32.const
                                     execute-i32.add ...)  ; must enable all defund fns
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))))))
```
- For subtraction cancellation: `(include-book "kestrel/bv/bvuminus")` + enable `acl2::bvminus`
- Don't put macros (`advance-instrs`, `ffn-symb`) in enable lists

## WASM 1.0 SpecTec Reference
`https://github.com/WebAssembly/spec/tree/main/specification/wasm-1.0`
- `8-reduction.spectec` = operational semantics (reduction rules)
- `1-syntax.spectec` = AST types and instructions
- `3-numerics.spectec` = numeric operation definitions
- `4-runtime.spectec` = runtime state structures

## Oracle Testing (TEST_GUIDELINES.md rule 1)
ALWAYS derive expected values from `wat2wasm` + Node.js FIRST, then encode in ACL2.
Signed results from JS need u32 conversion: `-85` → `4294967211` (0xFFFFFFAB).

## What's Next
- M7a: Floating-point (f32/f64) — IEEE 754 modeling
- M7b: Tables + call_indirect
- M7c: Module instantiation + binary integration
- M9: Type validation
