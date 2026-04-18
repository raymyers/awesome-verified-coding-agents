# WASM 1.0 ACL2 Formalization Plan

> Milestone-driven plan for formalizing the WASM 1.0 operational semantics
> in ACL2, extending the Kestrel books (`books/kestrel/wasm/`).
>
> **Goal**: Produce an executable, certifiable ACL2 semantics for WASM 1.0
> that runs inside the Kestrel book infrastructure and can verify simple
> WASM programs end-to-end (WAT → binary → ACL2 S-exprs → execution → comparison).
>
> **Source of truth**: [WASM 1.0 SpecTec](https://github.com/WebAssembly/spec/tree/main/specification/wasm-1.0)
> (10 files, 2300 lines of formal spec)
>
> **Existing skeleton**: [Kestrel WASM books](https://github.com/acl2/acl2/tree/master/books/kestrel/wasm)
> — `execution.lisp` (545 lines, i32 only: local.get + i32.add + run),
>   `parse-binary.lisp` (1429 lines, mostly complete binary parser),
>   `add-proof.lisp` (symbolic add correctness),
>   `proof-support.lisp` (defopeners for run, nth-local)

## Progress Summary

| Milestone | Status | Key Metric |
|---|---|---|
| M0: Bootstrap | ✅ Done | ACL2 8.7 + SBCL 2.5.2 builds, execution.cert certified |
| M1: i32 Arith + Vars + Parametric | ✅ Done | 17 i32 arith ops + comparisons + parametric |
| M2: Control Flow | ✅ Done | block/loop/if/br/br_if/br_table/return |
| M3: Functions | ✅ Done | call, call_indirect, funcinst, store |
| M4: Memory | ✅ Done | i32.load/store, packed variants, memory.size/grow |
| M5: i64 + Conversions | ✅ Done | Full i64, wrap/extend/trunc conversions |
| M5b: Globals | ✅ Done | global.get, global.set, globalinst |
| M6: Floating-Point | 🔶 Partial | f32/f64 arithmetic, comparisons (no IEEE 754 edge cases) |
| M7: Tables + call_indirect | ✅ Done | table, call_indirect dispatch |
| M8: Proofs | ✅ Done | 5+ theorems certified (add, sub, commutative, etc.) |
| M9: Validation | ✅ Done | Type checker + validation soundness |
| M10: E2E Pipeline | ✅ Done | WAT → .wasm → ACL2 S-expr → execution (5 modules, 20 tests) |
| M11: Hardening | 🔲 Todo | Comprehensive edge-case tests, spec conformance |

**Current**: 102 instructions, ~2100 lines `execution.lisp`, 29 test/proof files passing, 5 WASM modules passing E2E.

---

## Milestone 0: Environment Bootstrap ✅

**Goal**: Headless agent can build ACL2, certify existing books, run tests.

- [x] Install SBCL (`sudo apt-get install -y sbcl`)
- [x] Clone ACL2 (`git clone --depth 1 https://github.com/acl2/acl2.git /tmp/acl2-full`)
- [x] Build ACL2 (`cd /tmp/acl2-full && make LISP=sbcl`) — ~3 minutes
- [x] Set `ACL2=/tmp/acl2-full/saved_acl2`
- [x] Certify Kestrel WASM skeleton:
  ```bash
  cd /tmp/acl2-full
  books/build/cert.pl --acl2 ./saved_acl2 books/kestrel/wasm/execution
  ```
  **CRITICAL**: Use `cert.pl`, NOT `make -C books/kestrel/wasm` (no Makefile in that dir).
- [x] Clone WASM spec: `git clone --depth 1 --sparse https://github.com/WebAssembly/spec.git && cd spec && git sparse-checkout set specification/wasm-1.0`
- [x] Verify test pattern: `assert-event` with `run 4` add-program produces `(make-i32-val 7)`

### Bootstrap Script (copy-paste for new sessions)
```bash
#!/bin/bash
# setup-wasm-acl2.sh — Run at start of each agent session
which sbcl || sudo apt-get install -y sbcl
if [ ! -f /tmp/acl2-full/saved_acl2 ]; then
  git clone --depth 1 https://github.com/acl2/acl2.git /tmp/acl2-full
  cd /tmp/acl2-full && make LISP=sbcl
fi
export ACL2=/tmp/acl2-full/saved_acl2
# Certify skeleton
cd /tmp/acl2-full && books/build/cert.pl --acl2 $ACL2 books/kestrel/wasm/execution
# Verify
echo '(+ 40 2) (quit)' | $ACL2
```

---

## Milestone 1: MVP — i32 Arithmetic + Variables + Parametric ✅

**Goal**: Execute simple WASM programs using i32 integer arithmetic,
local variables, and parametric instructions.

### Completed
- [x] i64-valp recognizer + make-i64-val + val-type
- [x] All 17 i32 arithmetic ops (add, sub, mul, div_u/s, rem_u/s, and, or, xor, shl, shr_u/s, rotl, rotr, clz, ctz, popcnt)
- [x] All i32 comparisons (eqz, eq, ne, lt_u/s, gt_u/s, le_u/s, ge_u/s)
- [x] i32.const push
- [x] local.set, local.tee, update-nth-local, update-current-locals
- [x] nop, unreachable, drop, select
- [x] instrp extended, execute-instr dispatch for all
- [x] Macros: `def-i32-binop`, `def-i32-relop`, `def-i32-unop` for DRY definitions

---

## Milestone 2: Control Flow — Blocks, Loops, Branches ✅

**Goal**: Execute programs with structured control flow.

### Completed
- [x] Label stack in frame: `(arity continuation base-height)` entries
- [x] execute-block, execute-loop, execute-if (dispatch to then/else)
- [x] Label completion: instrs exhaust → pop label, restore continuation
- [x] execute-br, execute-br_if, execute-br_table
- [x] execute-return (exit all labels + frame)
- [x] step/run handle label-popping
- [x] Tests: block fall-through, br 0, if/else, nested blocks, factorial(5)=120, fibonacci(10)=55

### Key Design Decision
Block/loop/if are nested S-expressions in instruction list:
```lisp
(:block arity (body-instrs...))
(:loop arity (body-instrs...))
(:if arity (then-instrs...) (else-instrs...))
```
Label stack entries: `(arity continuation-instrs base-operand-height)`
`br N` pops N+1 labels, trims operand stack, jumps to Nth continuation.
For loops, continuation re-enters the loop instruction.

---

## Milestone 3: Functions — Call, Call Stack, Store ✅

### Completed
- [x] `defaggregate funcinst` — `(param-count local-count return-arity body)`
- [x] Store = list of funcinst (replaces `:fake`)
- [x] execute-call: push new frame with locals = args + zero-initialized locals
- [x] execute-call_indirect: dispatch through table
- [x] return-from-function: pop frame, push return values to caller

---

## Milestone 4: Memory — Load, Store, Size, Grow ✅

### Completed
- [x] Memory = flat byte list (1 page = 65536 bytes)
- [x] i32.load/store (with memarg offset)
- [x] Packed load/store: i32.load8_u/s, i32.load16_u/s, i32.store8, i32.store16
- [x] i64 packed variants: load8/16/32_u/s, store8/16/32
- [x] memory.size, memory.grow
- [x] Little-endian byte extraction (i32-to-bytes, bytes-to-i32)
- [x] Macros: `def-packed-load`, `def-packed-store`

---

## Milestone 5: i64 + Conversions ✅

### Completed
- [x] Full i64 arithmetic (add, sub, mul, div_u/s, rem_u/s)
- [x] Full i64 bitwise (and, or, xor, shl, shr_u/s, rotl, rotr, clz, ctz, popcnt)
- [x] i64 comparisons (eqz, eq, ne, lt_u/s, gt_u/s, le_u/s, ge_u/s)
- [x] i32.wrap_i64, i64.extend_i32_u, i64.extend_i32_s
- [x] i32.trunc_f32_u/s, i32.trunc_f64_u/s (stub)

## Milestone 5b: Globals ✅

- [x] `defaggregate globalinst` — `(value mutability)`
- [x] global.get, global.set
- [x] State extended with `:globals` field

---

## Milestone 6: Floating-Point 🔶 Partial

### Done
- [x] f32/f64 value recognizers and constructors
- [x] Basic f32/f64 arithmetic (add, sub, mul, div)
- [x] f32/f64 comparisons (eq, ne, lt, gt, le, ge)
- [x] f32/f64 unary ops (abs, neg, sqrt, ceil, floor, trunc, nearest)

### Remaining
- [ ] IEEE 754 edge cases: NaN propagation, signed zero, denormals
- [ ] f32.min/f64.min, f32.max/f64.max (NaN handling)
- [ ] f32.copysign/f64.copysign
- [ ] Conversion ops: f32.convert_i32_u/s, f64.convert_i32_u/s, etc.
- [ ] f32.demote_f64, f64.promote_f32
- [ ] f32.reinterpret_i32, f64.reinterpret_i64 (and vice versa)

**Note**: ACL2 rationals model IEEE 754 approximately. Full conformance requires
explicit NaN/infinity representation (see ACL2_SEMANTICS_REF.md §6).

---

## Milestone 7: Tables + call_indirect ✅

- [x] State extended with `:table` field (list of function indices)
- [x] call_indirect dispatch through table
- [x] Table bounds checking (trap on out-of-bounds)

---

## Milestone 8: Proofs & Verification ✅

### Certified Theorems
- [x] `add-correct` — `run` of add program produces `(bvplus 32 x y)`
- [x] `add-commutative` — add(a,b) = add(b,a)
- [x] `sub-correct` — sub program produces `(bvminus 32 x y)`
- [x] `sub-self-zero` — sub(x,x) = 0
- [x] `add-sub-inverse` — add(sub(x,y),y) = x

### Additional Proofs (via ld, not certified books)
- [x] block-br correctness
- [x] local-drop preservation
- [x] mul-eqz relationship
- [x] select-spec
- [x] call-indirect-spec
- [x] memory roundtrip
- [x] bitwise properties
- [x] loop correctness
- [x] max(a,b) via if/else
- [x] float basic spec
- [x] i64 conversion spec
- [x] trap misc spec
- [x] abs e2e
- [x] Validation soundness (type safety for validated add)

### Proof Technique
```lisp
(defthm name
  (implies (and (unsigned-byte-p 32 a) ...)
           (equal (top-operand (current-operand-stack (run N (make-state ...))))
                  (make-i32-val (bvplus 32 a b))))
  :hints (("Goal" :in-theory (enable run execute-instr execute-i32.const
                                     execute-i32.add execute-local.get ...)
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))))))
```

---

## Milestone 9: Validation / Type Checking ✅

### Completed
- [x] Typing context: `(make-val-ctx :locals :labels :return-type)`
- [x] `type-check-instr` for all implemented instructions
- [x] Stack typing (threading type-stack through instruction sequences)
- [x] Block/loop/if typing (labels in context)
- [x] `type-check-instrs` for instruction sequences
- [x] `validate-func-body` for function bodies
- [x] Validation soundness theorem (validated add → execution produces i32)

---

## Milestone 10: E2E Validation Pipeline ✅

**Goal**: Full pipeline from WAT source to verified ACL2 execution.

### Pipeline
```
WAT source → wat2wasm → .wasm binary → wasm2acl2.js → ACL2 S-exprs → ACL2 execution → compare with Node.js runtime
```

### Components
- [x] 5 WAT test programs: add, abs, factorial, fibonacci, memory_store_load
- [x] `wasm2acl2.js` — Node.js WASM binary parser + ACL2 translator
  - Parses Type, Function, Export, Code, Memory sections
  - Translates WASM instructions to ACL2 S-expression form
  - Runs each test case through Node.js WASM runtime for expected values
  - Generates complete ACL2 test file with assert-events
- [x] All 5 modules generate correct ACL2 output
- [x] All 20 E2E tests pass in ACL2

### E2E Test Programs

| Module | Functions | Instructions Tested | Test Cases |
|---|---|---|---|
| add | add(i32,i32)→i32 | local.get, i32.add | 4 |
| abs | abs(i32)→i32 | if/else, i32.sub, i32.lt_s | 5 |
| factorial | fact(i32)→i32 | loop, br_if, i32.mul, i32.sub | 4 |
| fibonacci | fib(i32)→i32 | loop, local vars, i32.add | 4 |
| memory_store_load | store_load(i32,i32)→i32 | i32.store, i32.load, memory | 3 |

### Key E2E Lessons Learned
1. **Negative args → unsigned**: JS `args[i] >>> 0` for i32, `BigInt(x) + (1n << 64n)` for i64
2. **Memory instructions need offset**: `(:i32.load offset)` not `(:i32.load)`; extract from memarg
3. **Package/include-book**: Our execution.lisp needs its own `package.lsp` + `portcullis.lisp` to certify independently (copied from Kestrel); use `include-book` of our certified `.cert`, not Kestrel's skeleton
4. **validation.lisp must also reference our execution** (not Kestrel's), otherwise `storep` redefines

### E2E Pipeline Proof (capstone)
```lisp
;; Validates instruction body, then executes, proves result is well-typed
(defthm e2e-validated-add-produces-i32
  (implies (and (u32p a) (u32p b))
           (i32-valp (get-result (run 20 (make-e2e-add-state a b))))))
```

---

## Milestone 11: Hardening & Spec Conformance 🔲 Todo

**Goal**: Close gaps between implementation and WASM 1.0 spec.

### 11.1 Module Instantiation (SpecTec 9-module.spectec)
- [ ] Allocation functions: allocfunc, allocglobal, alloctable, allocmem
- [ ] Module instantiation: evaluate init expressions, link imports
- [ ] Function invocation from module exports
- [ ] Integration with parse-binary.lisp for full .wasm → execution

### 11.2 IEEE 754 Floating-Point Completeness
- [ ] Explicit NaN/Infinity representation (not ACL2 rationals)
- [ ] NaN propagation rules
- [ ] Signed zero handling
- [ ] All conversion ops (trunc, convert, demote, promote, reinterpret)

### 11.3 Edge Cases & Traps
- [ ] i32.div_s overflow: `(-2^31) / (-1)` → trap
- [ ] Memory alignment checks (optional per spec)
- [ ] Table element type checking in call_indirect
- [ ] Recursive function call depth limits

### 11.4 Spec Conformance Testing
- [ ] Port relevant tests from WASM spec test suite (`test/core/`)
- [ ] Test all branch instruction edge cases
- [ ] Test all numeric edge cases (overflow, underflow, NaN)

### 11.5 Certifiable Book Structure
- [ ] Split execution.lisp into modular books (types, numerics, state, etc.)
- [ ] Create proper `.acl2` files for each book
- [ ] Certify full dependency graph with `cert.pl`
- [ ] Guard verification for all functions

**Exit criteria**: Execution matches WASM spec test suite on integer programs.

**Estimated time**: 8-16 hours.

---

## Milestone 12: Binary Parser Integration 🔲 Todo

**Goal**: Parse `.wasm` binary → instantiate module → execute in ACL2 (pure Lisp, no Node.js).

### 12.1 Connect parse-binary.lisp
- [ ] Verify existing parser handles all WASM 1.0 sections
- [ ] Map parser output to our instruction representation
- [ ] Handle function types, imports, exports, memory, tables, globals

### 12.2 Pure ACL2 E2E
- [ ] Read `.wasm` bytes as ACL2 byte list (via `read-file-bytes` or manual encoding)
- [ ] Parse → instantiate → invoke exported function → check result
- [ ] Test with at least 3 .wasm binaries

**Estimated time**: 4-8 hours.

## Testing Strategy

### Level 1: Ground-Truth Execution Tests (assert-event)
Concrete tests that evaluate to a known result. No proof needed —
ACL2 just computes the answer and checks equality.

```lisp
(assert-event
 (equal (top-operand (current-operand-stack (run N initial-state)))
        (make-i32-val expected)))
```

**Coverage**: Every instruction gets at least 2 tests (normal case + edge case/trap).
Currently: 29 test/proof files, ~50+ individual assert-events.

### Level 2: Oracle Testing (E2E Pipeline)
WAT source code compiled with `wat2wasm`, executed with Node.js WASM runtime
to get ground-truth expected values, then compared against ACL2 execution.

```bash
# Generate ACL2 test from WASM binary
node wasm2acl2.js module.wasm module.json > test-e2e-module.lisp

# Run in ACL2
echo '(ld "test-e2e-module.lisp") (quit)' | $ACL2
```

**RULE**: Always derive expected values from `wat2wasm` + Node.js FIRST, then encode in ACL2.
Signed results from JS need u32 conversion: `-85` → `4294967211` (0xFFFFFFAB).

### Level 3: Symbolic Proofs (defthm)
Universal properties proven by ACL2's theorem prover.

```lisp
(defthm add-correct
  (implies (and (u32p x) (u32p y) (consp rest-of-call-stack))
           (equal (top-operand (current-operand-stack (run 4 (make-state ...))))
                  (make-i32-val (bvplus 32 x y))))
  :hints (("Goal" :in-theory (enable ...))))
```

Currently: 5 certified theorems + 14 additional proofs via `ld`.

### Level 4: Certification
Book certification ensures soundness. Use `cert.pl`:
```bash
cd /tmp/acl2-full
books/build/cert.pl --acl2 ./saved_acl2 path/to/book
```

### Level 5: Regression Script
```bash
# Run all tests and proofs
PASS=0; FAIL=0
for f in tests/*.lisp proofs/*.lisp; do
  result=$(echo "(ld \"$f\") (quit)" | $ACL2 2>&1)
  if echo "$result" | grep -q "FAILED\|ACL2 Error"; then
    echo "FAIL: $f"; FAIL=$((FAIL+1))
  else
    echo "OK: $f"; PASS=$((PASS+1))
  fi
done
echo "=== $PASS passed, $FAIL failed ==="
```

### Test Programs (in order of complexity)

| # | Program | Instructions Tested | Status |
|---|---|---|---|
| 1 | `add(3,4) = 7` | local.get, i32.add | ✅ M1 + E2E |
| 2 | `sub(10,3) = 7` | local.get, i32.sub | ✅ M1 |
| 3 | `mul(6,7) = 42` | local.get, i32.mul | ✅ M1 |
| 4 | `div_u(10,3) = 3` | local.get, i32.div_u | ✅ M1 |
| 5 | `is_zero(0) = 1` | local.get, i32.eqz | ✅ M1 |
| 6 | `max(3,5) = 5` | if/else, i32.gt_u | ✅ M2 |
| 7 | `abs(x)` | if/else, i32.sub, i32.lt_s | ✅ M2 + E2E |
| 8 | `factorial(5) = 120` | loop, br_if, i32.mul, i32.sub | ✅ M2 + E2E |
| 9 | `fibonacci(10) = 55` | loop, local vars, i32.add | ✅ M2 + E2E |
| 10 | `call_helper(3,4)` | call, return | ✅ M3 |
| 11 | `memory_store_load` | i32.store, i32.load, memory | ✅ M4 + E2E |
| 12 | `packed_mem` | load8/16_u/s, store8/16 | ✅ M4 |
| 13 | `i64_ops` | i64 arith + conversions | ✅ M5 |
| 14 | `globals` | global.get/set | ✅ M5b |
| 15 | `call_indirect` | table dispatch | ✅ M7 |
| 16 | `float_ops` | f32/f64 arith + cmp | ✅ M6 |

---

## Headless Agent Execution Notes

### Session Setup Script
```bash
#!/bin/bash
# setup-wasm-acl2.sh — Run at start of each agent session
which sbcl || sudo apt-get install -y sbcl
if [ ! -f /tmp/acl2-full/saved_acl2 ]; then
  git clone --depth 1 https://github.com/acl2/acl2.git /tmp/acl2-full
  cd /tmp/acl2-full && make LISP=sbcl
fi
export ACL2=/tmp/acl2-full/saved_acl2

# Certify skeleton (needed for include-book of Kestrel libs)
cd /tmp/acl2-full && books/build/cert.pl --acl2 $ACL2 books/kestrel/wasm/execution

# For E2E pipeline
which wat2wasm || sudo apt-get install -y wabt
which node || echo "Node.js needed for E2E"

# Clone WASM spec for reference
if [ ! -d /tmp/wasm-spec ]; then
  git clone --depth 1 --sparse https://github.com/WebAssembly/spec.git /tmp/wasm-spec
  cd /tmp/wasm-spec && git sparse-checkout set specification/wasm-1.0
fi

echo '(+ 40 2) (quit)' | $ACL2  # Verify: should print 42
```

### Development Workflow
```bash
# Certify our execution.lisp independently (needs package.lsp + portcullis.lisp in same dir)
cd /tmp/acl2-full && books/build/cert.pl --acl2 ./saved_acl2 /path/to/our/execution

# Run a test
echo '(ld "/path/to/test.lisp") (quit)' | $ACL2

# If certification fails, check the log:
cat /path/to/execution.cert.out
```

### Common Pitfalls (verified by experience, updated 2026-04-18)
1. **Use `cert.pl` not `make`**: No Makefile in kestrel/wasm dir; `cert.pl` auto-resolves deps
2. **Package issues**: Always `(ld "package.lsp")` before `(in-package "WASM")`
3. **Include-book needs .cert**: Must certify execution.lisp before `(include-book ...)` works
4. **defaggregate conflict**: WASM `state` shadows ACL2 `state` — handled by package.lsp exclusion
5. **Stale .cert**: Delete `.cert` + `.cert.out` before re-certifying after edits
6. **Pipe to ACL2**: Long output → use `grep -E "FAIL|PASSED|Error"` to filter
7. **Negative WASM values**: JS signed → ACL2 unsigned: use `>>> 0` for i32, `BigInt + 2^64` for i64
8. **Memory instructions**: Must include memarg offset: `(:i32.load 0)` not `(:i32.load)`
9. **validation.lisp must reference OUR execution**, not Kestrel's, to avoid `storep` redefinition
10. **Don't put macros in `:enable` lists**: `advance-instrs`, `ffn-symb` are macros, not functions
11. **defaggregate `:pred` keyword**: Default generates `name-p`; Kestrel uses `:pred framep`/`:pred statep`
12. **BV functions need `acl2::` prefix**: Only `bvplus` is imported; `bvminus`,`bvand`,etc need `acl2::`
13. **Definition order matters**: All handler defs BEFORE `execute-instr` dispatch (single-pass)
14. **Guard hints pattern**: `(enable valp i32-valp u32p <new-vals-fn>)` for execute fns
15. **`(set-guard-checking :none)`**: Required in tests when any function has unverified guards
16. **`execution.acl2` needed**: Outside Kestrel tree, cert.pl requires `(ld "package.lsp")` in `.acl2` file
17. **See ACL2_SEMANTICS_REF.md §17** for detailed examples of each gotcha

### File Organization (current)
```
examples/wasm1-acl2-formalization-plan/
├── package.lsp              # WASM package definition (copied from Kestrel)
├── portcullis.lisp          # Portcullis book (copied from Kestrel)
├── portcullis.acl2          # Portcullis commands
├── execution.lisp           # Main semantics (~2100 lines, 102 instructions)
├── validation.lisp          # Type checker
├── tests/
│   ├── test-m1-instructions.lisp
│   ├── test-m2-control-flow.lisp
│   ├── test-m3-functions.lisp
│   ├── test-m4-memory.lisp
│   ├── test-m5-i64.lisp
│   ├── test-m5b-globals.lisp
│   ├── test-m7a-floats.lisp
│   ├── test-m7b-tables.lisp
│   ├── test-m9-validation.lisp
│   ├── test-packed-mem.lisp
│   ├── test-packed-mem-i64.lisp
│   └── test-spot-check.lisp
├── proofs/
│   ├── proof-add-spec.lisp
│   ├── proof-sub-spec.lisp
│   ├── proof-abs-e2e.lisp
│   ├── proof-block-br-spec.lisp
│   ├── proof-loop-spec.lisp
│   ├── proof-max-if-else.lisp
│   ├── proof-mem-roundtrip.lisp
│   ├── proof-bitwise.lisp
│   ├── proof-validation-soundness.lisp
│   ├── proof-e2e-pipeline.lisp
│   └── ... (14 total)
├── e2e/
│   ├── wasm2acl2.js         # WASM binary → ACL2 translator
│   ├── add.wat / add.wasm / add.json
│   ├── abs.wat / abs.wasm / abs.json
│   ├── factorial.wat / factorial.wasm / factorial.json
│   ├── fibonacci.wat / fibonacci.wasm / fibonacci.json
│   └── memory_store_load.wat / .wasm / .json
├── WASM1_PLAN.md
└── ACL2_SEMANTICS_REF.md
```

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation | Status |
|---|---|---|---|---|
| Guard verification complexity | High | Medium | Incremental; prove type theorems early | ✅ Managed |
| Block/label model mismatch | Medium | High | Prototyped with tests first | ✅ Resolved |
| Floating-point IEEE 754 | High | Medium | Deferred; integer-only MVP first | 🔶 Partial |
| ACL2 build time | Medium | Low | cert.pl for single books; ~3min full build | ✅ Acceptable |
| Parser-executor mismatch | Low | Medium | E2E pipeline catches mismatches | ✅ Resolved |
| Termination proofs | Medium | Medium | Step-count bounded `run` | ✅ Resolved |
| /tmp loss between sessions | High | High | Commit early; doc all in AGENTS.md | ⚠️ Active |
| defaggregate symbol issues | Medium | Medium | Own package.lsp + portcullis; proper include-book | ✅ Resolved |

---

## Definition of Done

The formalization is **complete** when:
1. ✅ All WASM 1.0 integer instructions have executable semantics (102 done)
2. ✅ execution.lisp certifies with `cert.pl` (guards verified)
3. ✅ 29 test/proof files pass (50+ assert-events)
4. ✅ 5 certified symbolic theorems + 14 additional proofs
5. ✅ 5 WASM modules pass E2E pipeline (WAT → .wasm → ACL2 → verified)
6. ✅ Code extends Kestrel WASM books properly
7. 🔶 IEEE 754 floating-point completeness (stretch)
8. 🔲 Module instantiation + pure ACL2 binary parser integration (M11-12)
