# AGENTS.md — WASM 1.0 ACL2 Formalization

## Project
ACL2 formalization of WASM 1.0 operational semantics, extending the Kestrel books.
Repo: `raymyers/awesome-verified-coding-agents` branch `add-wasm1-acl2-formalization-plan-try1`
Subdir: `examples/wasm1-acl2-formalization-plan/`

## Current Status (2026-04-21)
- **170/170 WASM 1.0 instructions** implemented, certified, tested (3718 lines)
- **27 proof files, 280 Q.E.D.s, 0 failures**
- **15/15 test files pass**, 312 assertions, 0 failures
- **M12**: IEEE 754 NaN/Inf propagation — float-specialp, 20 formal theorems, 28 oracle tests
- **M13**: IEEE 754 Signed Zero — `:f32.±0`/`:f64.±0` atoms; neg/abs/div/copysign/cmp correct; 11 theorems
- **M14**: IEEE 754 Inf Arithmetic — ±Inf in add/sub/mul/div/min/max; sign-product rules; 34 oracle tests
- **Distributivity proofs**: BV mul-over-add/sub (i32+i64), shl-as-mul — 12 Q.E.D.s
- **Critical gotchas + NaN/±0/Inf design**: ACL2_SEMANTICS_REF.md §17-21

## Key Files
- `WASM1_PLAN.md` — Milestone plan with task bullets, MVP strategy, testing plan
- `ACL2_SEMANTICS_REF.md` — SpecTec → ACL2 mapping, build commands, patterns, references
- `execution.lisp` — Main semantics (3718 lines)
- `validation.lisp` — Type checker
- `top.lisp` — Library bundle: `(include-book "top")` → execution + validation
- `cert.acl2` / `proofs/cert.acl2` / `tests/cert.acl2` — per-dir portcullis, all just `(include-book "kestrel/wasm/portcullis" :dir :system)`
- `Makefile` — drives `cert.pl` over all 45 books
- `proofs/proof-spec-edge-cases.lisp` — 35 Q.E.D.s: trap, shift, rotate, clz/ctz, conversion edge cases
- `proofs/proof-algebraic-properties.lisp` — 27 Q.E.D.s: identity, annihilator, reflexivity properties
- `proofs/proof-add-spec.lisp` — Add spec + commutativity (2 theorems)
- `proofs/proof-sub-spec.lisp` — Sub spec + self-zero + add-sub-inverse (3 theorems)
- `tests/test-spot-check.lisp` — 20 ground-truth tests
- `tests/test-packed-mem.lisp` — 10 packed memory tests
- `tests/oracle/check-all.sh` — Oracle pipeline (compile WAT → run Node.js). Directory contains `cert_pl_exclude` so cert.pl skips it.

## Standalone Repo
The formalization now lives at **https://github.com/raymyers/wasm-acl2** (main branch).
The `examples/wasm1-acl2-formalization-plan/` subdir of this repo stays in sync via PR diffs.

## ACL2 Build
```bash
# The provided dev container already has ACL2 installed. Env vars set by
# .devcontainer/devcontainer.json:
#   ACL2=/opt/acl2/bin/acl2                (also on $PATH as `acl2`)
#   ACL2_HOME=/home/acl2
#   ACL2_SYSTEM_BOOKS=/home/acl2/books
# For a fresh machine, build from source:
sudo apt-get install -y sbcl
git clone --depth 1 https://github.com/acl2/acl2.git $HOME/acl2
cd $HOME/acl2 && make LISP=sbcl
export ACL2=$HOME/acl2/saved_acl2
export CERT=$HOME/acl2/books/build/cert.pl
```

## Certify Everything
```bash
cd examples/wasm1-acl2-formalization-plan
make clean && make          # certifies all 45 books (top + 27 proofs + 15 tests + library)
make top                    # just execution + validation + top
make proofs                 # just proofs/*.lisp
make tests                  # just tests/*.lisp
# Single book:
$CERT --acl2 $ACL2 proofs/proof-add-spec
```
**The WASM package comes from the community book `kestrel/wasm/portcullis`, pulled in via each `cert.acl2`. There is no local `package.lsp`.**
All 45 books return `Exit code from ACL2 is 43` on success.

## Propagating Changes → wasm-acl2 Standalone Repo
```bash
# Diff the formalization subdir between two commits:
git diff <base-sha> <head-sha> -- examples/wasm1-acl2-formalization-plan/ > /tmp/patch.patch
# Apply to wasm-acl2 (strip 3 path components: a/examples/wasm1-acl2-formalization-plan/):
cd /path/to/wasm-acl2 && git apply -p3 /tmp/patch.patch
```

## Run Tests
Certification IS the regression — every `assert-event` in a test book is checked during `make`. For one-off interactive debugging you can still `ld`:
```bash
echo '(include-book "tests/test-spot-check") (quit)' | $ACL2
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

## Verified State (2026-04-21)
- **170/170** WASM 1.0 instructions (100%), `execution.lisp` CERTIFIES (3718 lines)
- **15/15** test files pass (312 assertions, 0 failures)
- **27/27** proof files pass (280 Q.E.D.s, 0 failures)
- **All WASM 1.0 instructions covered**: parametric, control, call, locals, globals, i32, i64, memory, f32/f64, conversions, reinterpret
- **M12 complete**: IEEE 754 NaN propagation (float-specialp pattern), 0/0=NaN, x/0=±Inf, sqrt(-x)=NaN
- **M13 complete**: IEEE 754 Signed Zero — neg(+0)=-0, abs(±0)=+0, +0==−0, x/-0=−∞ for x>0
- **M14 complete**: IEEE 754 Inf Arithmetic — ±Inf in add/sub/mul/div/min/max; sign-product rules
- **Distributivity**: BV mul-distributes-over-add/sub (i32+i64) + shl-as-mul laws (12 Q.E.D.s)
- **Missing**: module instantiation, binary parser integration (future work)

## Kestrel IEEE 754 Library (discovered 2026-04-19)
`books/kestrel/floats/ieee-floats-as-bvs` provides exact IEEE 754 encode/decode:
- `(include-book "kestrel/floats/ieee-floats-as-bvs" :dir :system)` — certifies in <1s
- `(include-book "kestrel/floats/round" :dir :system)` — banker's rounding, certifies in 2s
- `decode-bv-float32` / `decode-bv-float64` — BV → float datum
- `encode-bv-float` — float datum → BV  
- Roundtrip theorems proven (non-NaN)
- **Integration proof**: `proof-ieee754-integration.lisp` — 14 PASSED, 3 Q.E.D.

## Key Proof Techniques (discovered 2026-04-20)
- **Symbolic proofs with `run`**: Use `:expand ((:free (n s) (run n s)))` to force unfolding
- **Theory for 170-case dispatch**: Enable specific execute functions + all state accessors
- **BV library for sub(x,x)=0**: Enable `acl2::bvminus acl2::bvplus acl2::bvuminus acl2::bvchop`
- **Rotation identity ash(-32)**: Use `(local (include-book "arithmetic-5/top" :dir :system))`
- **Never put macros in enable**: `farg1` is a macro → cryptic theory evaluation error

## What's Next
- Module instantiation + binary parser integration (connect parse-binary.lisp to execution)
- Guard verification (currently deferred with `:verify-guards nil`)
- Formal Inf arithmetic proofs (theorems about M14 rules; currently only oracle-tested)
- More symbolic proofs: De Morgan, absorption, rotation laws, mixed i32/i64 theorems
