# WASM 1.0 ACL2 Formalization Plan

> Milestone-driven plan for formalizing the WASM 1.0 operational semantics
> in ACL2, extending the Kestrel books (`books/kestrel/wasm/`).
>
> **Goal**: Produce an executable, certifiable ACL2 semantics for WASM 1.0
> that runs inside the Kestrel book infrastructure and can verify simple
> WASM programs end-to-end.
>
> **Source of truth**: [WASM 1.0 SpecTec](https://github.com/WebAssembly/spec/tree/main/specification/wasm-1.0)
> (10 files, 2300 lines of formal spec)
>
> **Existing skeleton**: [Kestrel WASM books](https://github.com/acl2/acl2/tree/master/books/kestrel/wasm)
> (execution.lisp, parse-binary.lisp, add-proof.lisp)

---

## Milestone 0: Environment Bootstrap (Prerequisite)

**Goal**: Headless agent can build ACL2, certify existing books, run tests.

- [ ] Install SBCL (`sudo apt-get install -y sbcl`)
- [ ] Clone ACL2 (`git clone --depth 1 https://github.com/acl2/acl2.git /opt/acl2`)
- [ ] Build ACL2 (`cd /opt/acl2 && make LISP=sbcl`)
- [ ] Set `ACL2=/opt/acl2/saved_acl2`
- [ ] Certify existing books:
  ```bash
  cd /opt/acl2/books
  ACL2=$ACL2 make USE_QUICKLISP=0 ACL2_CUSTOMIZATION=NONE kestrel/wasm/execution.cert
  ACL2=$ACL2 make USE_QUICKLISP=0 ACL2_CUSTOMIZATION=NONE kestrel/wasm/add-proof.cert
  ACL2=$ACL2 make USE_QUICKLISP=0 ACL2_CUSTOMIZATION=NONE kestrel/wasm/parse-binary.cert
  ```
- [ ] Clone WASM spec for reference: `git clone --depth 1 --sparse https://github.com/WebAssembly/spec.git && cd spec && git sparse-checkout set specification/wasm-1.0`
- [ ] Verify test pattern works (assert-event with concrete execution)

**Exit criteria**: All 3 existing `.cert` files build; assert-event test of `run 4` add-program passes.

**Estimated time**: 15 minutes.

---

## Milestone 1: MVP — i32 Arithmetic + Variables + Parametric (Sprint 1)

**Goal**: Execute simple WASM programs using i32 integer arithmetic,
local variables, and parametric instructions. Enough to run programs
like addition, max(a,b), conditional swap, and simple loops.

### 1.1 Extend Value Types
- [ ] Add `i64-valp` recognizer: `(:i64.const <u64>)` with `unsigned-byte-p 64`
- [ ] Update `valp` to include `i64-valp`
- [ ] Add `make-i64-val` constructor
- [ ] Add `val-type` function: extract type tag from a val
- [ ] Prove `valp` forward-chaining and type-preservation theorems

### 1.2 i32 Arithmetic Operations (SpecTec 3-numerics: `$iadd_` .. `$ipopcnt_`)
- [ ] `execute-i32.sub` — `(bvminus 32 x y)`
- [ ] `execute-i32.mul` — `(bvmult 32 x y)`
- [ ] `execute-i32.div_u` — `(bvdiv 32 x y)`, trap if y=0
- [ ] `execute-i32.div_s` — `(sbvdiv 32 x y)`, trap if y=0 or overflow
- [ ] `execute-i32.rem_u` — `(bvmod 32 x y)`, trap if y=0
- [ ] `execute-i32.rem_s` — signed remainder, trap if y=0
- [ ] `execute-i32.and` — `(bvand 32 x y)`
- [ ] `execute-i32.or` — `(bvor 32 x y)`
- [ ] `execute-i32.xor` — `(bvxor 32 x y)`
- [ ] `execute-i32.shl` — `(bvshl 32 x (mod y 32))`
- [ ] `execute-i32.shr_u` — `(bvshr 32 x (mod y 32))`
- [ ] `execute-i32.shr_s` — signed shift right
- [ ] `execute-i32.rotl` — rotate left (may need custom def)
- [ ] `execute-i32.rotr` — rotate right (may need custom def)
- [ ] `execute-i32.clz` — count leading zeros (custom def)
- [ ] `execute-i32.ctz` — count trailing zeros (custom def)
- [ ] `execute-i32.popcnt` — population count (custom def)

### 1.3 i32 Comparison & Test Operations
- [ ] `execute-i32.eqz` — `(bool-to-bit (= x 0))`, push i32 result
- [ ] `execute-i32.eq` — `(bool-to-bit (= x y))`
- [ ] `execute-i32.ne` — `(bool-to-bit (/= x y))`
- [ ] `execute-i32.lt_u` — `(bool-to-bit (< x y))`
- [ ] `execute-i32.lt_s` — `(bool-to-bit (sbvlt 32 x y))`
- [ ] `execute-i32.gt_u`, `gt_s`, `le_u`, `le_s`, `ge_u`, `ge_s`

### 1.4 i32 Constant
- [ ] `execute-i32.const` — push `(make-i32-val n)` onto operand stack

### 1.5 Local Variable Instructions
- [ ] `execute-local.set` — pop value, update locals[x]
  - Add `update-nth-local` function
  - Add `update-current-locals` state updater
- [ ] `execute-local.tee` — duplicate top, then local.set
  (SpecTec: `val (LOCAL.TEE x) ~> val val (LOCAL.SET x)`)

### 1.6 Parametric Instructions
- [ ] `execute-nop` — no-op, advance instrs
- [ ] `execute-unreachable` — return `:trap`
- [ ] `execute-drop` — pop one value from operand stack
- [ ] `execute-select` — pop condition (i32), pop 2 values, push selected one

### 1.7 Update Instruction Recognizer & Dispatch
- [ ] Extend `instrp` to recognize all new instruction forms
- [ ] Extend `execute-instr` case dispatch for all new instructions
- [ ] Prove `statep-of-execute-instr` for all new cases

### 1.8 Tests for Milestone 1
- [ ] Test: `3 + 4 = 7` (existing, verify still works)
- [ ] Test: `10 - 3 = 7`
- [ ] Test: `6 * 7 = 42`
- [ ] Test: `10 / 3 = 3` (unsigned)
- [ ] Test: `10 % 3 = 1`
- [ ] Test: `0xFF & 0x0F = 0x0F`
- [ ] Test: `i32.eqz 0 = 1`, `i32.eqz 5 = 0`
- [ ] Test: `i32.lt_u 3 5 = 1`
- [ ] Test: `select` with true/false conditions
- [ ] Test: `local.set` then `local.get` roundtrip
- [ ] Test: `local.tee` preserves value on stack
- [ ] Test: `drop` removes top element

**Exit criteria**: All tests pass as assert-events. `execution.lisp` certifies.

**Estimated time**: 2-3 hours.

---

## Milestone 2: Control Flow — Blocks, Loops, Branches (Sprint 2)

**Goal**: Execute programs with structured control flow: if/else,
loops, and branch instructions. This enables programs like
factorial, fibonacci, and any bounded loop.

### 2.1 Label Stack Infrastructure
- [ ] Define `label-entry` aggregate: `(arity, continuation, base-height)`
- [ ] Define `label-stackp` recognizer
- [ ] Add `label-stack` field to `frame` aggregate
- [ ] Update all frame constructors/accessors
- [ ] Update `make-frame` calls in existing code (add `:label-stack nil`)
- [ ] Verify existing tests still pass with extended frame

### 2.2 Block Instructions (SpecTec 8-reduction: BLOCK, LOOP, IF)
- [ ] `execute-block` — push label `(arity=|bt|, continuation=rest-instrs, base=ostack-height)`, set instrs to block body
- [ ] `execute-loop` — push label `(arity=0, continuation=(loop bt body)++rest-instrs, base=ostack-height)`, set instrs to loop body
- [ ] `execute-if` — pop i32 condition, dispatch to then-block or else-block (reduce to block)
- [ ] Handle block completion: when instrs exhaust within a label, pop label, restore instrs to continuation, trim operand stack to base+arity values

### 2.3 Branch Instructions
- [ ] `execute-br` — pop N+1 labels (for BR N), trim stack, jump to Nth continuation
  - Special handling: for loops, the continuation re-enters the loop
- [ ] `execute-br_if` — pop i32 condition; if nonzero do BR, else continue
- [ ] `execute-br_table` — pop i32 index, lookup in label vector, BR to result

### 2.4 Return Instruction
- [ ] `execute-return` — like BR that exits all labels + current frame
  - Pop all labels in current frame, return values to caller

### 2.5 Update step/run for Label Awareness
- [ ] Modify `step` to handle label completion (no instrs left but labels remain)
- [ ] Ensure `run` handles the label-popping case
- [ ] Prove termination still holds (or adjust measure)

### 2.6 Update Instruction Recognizer
- [ ] `instrp` recognizes `:block`, `:loop`, `:if`, `:br`, `:br_if`, `:br_table`, `:return`
- [ ] Block/loop/if carry nested instruction lists in their representation

### 2.7 Tests for Milestone 2
- [ ] Test: simple block with no branch (fall through)
- [ ] Test: `block` with `br 0` (early exit)
- [ ] Test: `if/else` true branch
- [ ] Test: `if/else` false branch
- [ ] Test: `loop` with `br_if` (count down to 0)
- [ ] Test: nested blocks with `br 1` (skip outer)
- [ ] Test: `br_table` dispatch
- [ ] Test: **factorial(5) = 120** (loop-based implementation)
  ```wasm
  ;; factorial(n): uses loop with br_if
  (local.get 0)  ;; n
  (i32.const 1)  ;; acc = 1
  (block (loop
    (local.get 0)     ;; n
    (i32.eqz)
    (br_if 1)         ;; if n==0, exit block
    (local.get 0)     ;; n
    (i32.mul)         ;; acc *= n
    (local.get 0)
    (i32.const 1)
    (i32.sub)
    (local.set 0)     ;; n -= 1
    (br 0)))          ;; continue loop
  ```
- [ ] Test: `return` from nested context

**Exit criteria**: Factorial(5)=120 executes correctly. All block/loop/branch tests pass.

**Estimated time**: 3-4 hours.

---

## Milestone 3: Functions — Call, Call Stack, Store (Sprint 3)

**Goal**: Execute multi-function WASM programs with proper function
calls, a real store, and module instances.

### 3.1 Proper Store
- [ ] Define `funcinst` aggregate: `(type, module, code)`
- [ ] Define `globalinst` aggregate: `(type, value)`
- [ ] Define `store` aggregate: `(funcs, globals, tables, mems)`
- [ ] Define `moduleinst` aggregate: `(types, funcs, globals, tables, mems, exports)`
- [ ] Replace `:fake` store usage with proper store

### 3.2 Frame Module Reference
- [ ] Add `module` field to `frame` (reference to `moduleinst`)
- [ ] Update frame accessors for module lookups

### 3.3 Function Call Instructions
- [ ] `execute-call` — look up function by index, set up new frame
  - Resolve funcaddr through moduleinst.funcs
  - Look up funcinst in store.funcs
  - Pop arguments from caller's operand stack
  - Initialize locals = args ++ default values for declared locals
  - Push new frame onto call-stack
- [ ] `execute-call_indirect` — table-based indirect call
  - Read funcaddr from table[0].refs[i]
  - Type-check against expected signature
  - Proceed as direct call (or trap)
- [ ] Update `return-from-function` for proper module-aware frames

### 3.4 Global Variable Instructions
- [ ] `execute-global.get` — read from store.globals[moduleinst.globals[x]].value
- [ ] `execute-global.set` — write to store (only if mutable global)
- [ ] State updater for global mutation

### 3.5 Tests for Milestone 3
- [ ] Test: two-function program (main calls helper)
- [ ] Test: recursive factorial via `call`
- [ ] Test: global variable read/write
- [ ] Test: `call_indirect` with type check
- [ ] Test: `call_indirect` type mismatch → trap

**Exit criteria**: Multi-function programs execute. Store is fully functional.

**Estimated time**: 3-4 hours.

---

## Milestone 4: Memory — Load, Store, Size, Grow (Sprint 4)

**Goal**: Execute WASM programs that use linear memory.

### 4.1 Memory Infrastructure
- [ ] Define `meminst` aggregate: `(type, bytes)`
- [ ] `mem-read-bytes` — read N bytes from memory at offset (bounds-checked)
- [ ] `mem-write-bytes` — write bytes to memory at offset (bounds-checked)
- [ ] Little-endian conversion: `i32-to-le-bytes`, `le-bytes-to-i32`, etc.
- [ ] Add memory to store (initially empty or allocated per module)

### 4.2 Load Instructions
- [ ] `execute-i32.load` — load 4 bytes at `i + offset`, convert to i32
- [ ] `execute-i64.load` — load 8 bytes, convert to i64
- [ ] `execute-i32.load8_s`, `load8_u`, `load16_s`, `load16_u` — packed loads with sign/zero extension
- [ ] `execute-i64.load8_s` .. `load32_u` — all i64 packed loads
- [ ] Bounds checking: trap if `i + offset + size > |mem.bytes|`

### 4.3 Store Instructions
- [ ] `execute-i32.store` — convert to 4 LE bytes, write at `i + offset`
- [ ] `execute-i64.store` — convert to 8 LE bytes, write
- [ ] `execute-i32.store8`, `store16` — packed stores (wrap value)
- [ ] `execute-i64.store8`, `store16`, `store32` — packed stores
- [ ] Bounds checking for writes

### 4.4 Memory Management
- [ ] `execute-memory.size` — push `|mem.bytes| / (64*1024)` as i32
- [ ] `execute-memory.grow` — attempt to grow by N pages
  - Success: extend bytes with zeros, push old page count
  - Failure: push -1 (as unsigned i32)

### 4.5 Tests for Milestone 4
- [ ] Test: store i32, load i32 roundtrip
- [ ] Test: store i32, load8_u (read single byte)
- [ ] Test: memory.size returns correct page count
- [ ] Test: memory.grow then store/load in new region
- [ ] Test: out-of-bounds load → trap
- [ ] Test: out-of-bounds store → trap
- [ ] Test: **sum array** — loop over memory, accumulate i32 values

**Exit criteria**: Memory load/store/grow works. Array sum example executes correctly.

**Estimated time**: 3-4 hours.

---

## Milestone 5: i64 + Conversions (Sprint 5)

**Goal**: Full integer support with 64-bit operations and type conversions.

### 5.1 i64 Operations
- [ ] All i64 arithmetic: add, sub, mul, div_u, div_s, rem_u, rem_s
  (mirror i32 implementations with `64` instead of `32`)
- [ ] All i64 bitwise: and, or, xor, shl, shr_u, shr_s, rotl, rotr, clz, ctz, popcnt
- [ ] All i64 comparisons: eqz, eq, ne, lt_u, lt_s, gt_u, gt_s, le_u, le_s, ge_u, ge_s
- [ ] i64.const

### 5.2 Conversion Operations (SpecTec 3-numerics: `$cvtop__`)
- [ ] `i32.wrap_i64` — `(bvchop 32 x)` (truncate 64→32)
- [ ] `i64.extend_i32_u` — zero-extend 32→64 (identity on unsigned-byte-p 32)
- [ ] `i64.extend_i32_s` — `(bvsx 64 32 x)` sign-extend
- [ ] `i32.trunc_f32_s`, `i32.trunc_f32_u` — (defer if f32 not yet done)
- [ ] `i32.reinterpret_f32`, `i64.reinterpret_f64` — (defer if float not done)
- [ ] `f32.reinterpret_i32`, `f64.reinterpret_i64` — (defer if float not done)

### 5.3 Tests for Milestone 5
- [ ] Test: i64 add, sub, mul
- [ ] Test: i64 div_u with trap on zero
- [ ] Test: i64 bit operations
- [ ] Test: i32.wrap_i64 truncation
- [ ] Test: i64.extend_i32_s sign extension (negative value)
- [ ] Test: mixed i32/i64 program

**Exit criteria**: All i32 and i64 operations work. Conversions between them work.

**Estimated time**: 2-3 hours.

---

## Milestone 6: Floating-Point (Sprint 6)

**Goal**: f32 and f64 support.

### 6.1 IEEE 754 Model in ACL2
- [ ] Define `f32-valp`, `f64-valp` recognizers
- [ ] Model: either rational-based with explicit NaN/Inf/sign tags,
  or bit-level model using kestrel/bv (32-bit / 64-bit representations)
- [ ] Decide on NaN handling strategy (WASM uses canonical NaN propagation)

### 6.2 f32/f64 Operations
- [ ] Arithmetic: fadd, fsub, fmul, fdiv, fmin, fmax, fcopysign
- [ ] Unary: fabs, fneg, fsqrt, fceil, ffloor, ftrunc, fnearest
- [ ] Comparisons: feq, fne, flt, fgt, fle, fge

### 6.3 Remaining Conversions
- [ ] `i32.trunc_f32_s`, `i32.trunc_f32_u`, `i32.trunc_f64_s`, `i32.trunc_f64_u`
- [ ] `i64.trunc_f32_s`, `i64.trunc_f32_u`, `i64.trunc_f64_s`, `i64.trunc_f64_u`
- [ ] `f32.convert_i32_s`, `f32.convert_i32_u`, `f32.convert_i64_s`, `f32.convert_i64_u`
- [ ] `f64.convert_i32_s`, `f64.convert_i32_u`, `f64.convert_i64_s`, `f64.convert_i64_u`
- [ ] `f32.demote_f64`, `f64.promote_f32`
- [ ] Reinterpret operations

### 6.4 Tests
- [ ] Test: basic f32/f64 arithmetic
- [ ] Test: NaN propagation
- [ ] Test: infinity handling
- [ ] Test: truncation traps (out-of-range float to int)

**Exit criteria**: f32/f64 operations pass concrete tests.

**Estimated time**: 4-6 hours (IEEE 754 modeling is complex).

---

## Milestone 7: Module Instantiation & Binary Integration (Sprint 7)

**Goal**: Parse a `.wasm` binary file and instantiate/execute it.

### 7.1 Module Instantiation (SpecTec 9-module.spectec)
- [ ] `allocfunc`, `allocglobal`, `alloctable`, `allocmem`
- [ ] `allocmodule` — full module allocation
- [ ] `instantiate` — evaluate global initializers, init elem/data segments
- [ ] `invoke` — entry point for calling an exported function

### 7.2 Binary Parser Integration
- [ ] Connect `parse-binary.lisp` output to module instantiation
- [ ] Verify parser output matches expected module structure
- [ ] End-to-end: read `.wasm` file → parse → instantiate → invoke → result

### 7.3 Table Operations
- [ ] Elem segment initialization (fill table with function addresses)
- [ ] call_indirect uses table to resolve function addresses

### 7.4 Import/Export
- [ ] Export resolution (find exported function by name)
- [ ] Import stubs (for host functions — model as abstract)

### 7.5 Tests
- [ ] Test: instantiate a minimal module (one function, no imports)
- [ ] Test: parse and execute add.wasm
- [ ] Test: module with memory (data segment initialization)
- [ ] Test: module with globals (global initializer evaluation)
- [ ] Test: exported function invocation

**Exit criteria**: Can parse a `.wasm` binary and execute its start function or an exported function.

**Estimated time**: 4-6 hours.

---

## Milestone 8: Proofs & Verification (Sprint 8)

**Goal**: Prove correctness theorems for representative WASM programs.

### 8.1 Proof Infrastructure
- [ ] Extend `proof-support.lisp` with defopeners for all new functions
- [ ] Add rewrite rules for common patterns (block completion, branch resolution)
- [ ] Lemmas for operand-stack manipulation compositionality

### 8.2 Example Proofs
- [ ] **add-proof.lisp** — verify existing proof still works (regression)
- [ ] **sub-proof** — subtraction computes bvminus
- [ ] **max-proof** — max(a,b) using if/else is correct
- [ ] **factorial-proof** — loop-based factorial computes n!
  (inductive proof over loop iterations)
- [ ] **memory-copy-proof** — copying N bytes produces identical sequences

### 8.3 Symbolic Execution Support
- [ ] Opener rules for new execute-* functions
- [ ] Conditional rewriting through block/loop structures
- [ ] Induction schemes for loop proofs

**Exit criteria**: At least 3 non-trivial proofs certified.

**Estimated time**: 4-8 hours.

---

## Milestone 9: Validation / Type Checking (Sprint 9)

**Goal**: Implement WASM type validation rules.

### 9.1 Typing Context (SpecTec 6-typing.spectec)
- [ ] Define `context` aggregate: types, funcs, globals, tables, mems, locals, labels, return
- [ ] Limits validation
- [ ] Function type, global type, table type, memory type validation

### 9.2 Instruction Typing
- [ ] Type-check each instruction against context
- [ ] Stack typing (type-check operand stack types)
- [ ] Block/loop/if typing (labels in context)
- [ ] Function body typing

### 9.3 Module Validation
- [ ] Validate all function bodies
- [ ] Validate imports/exports
- [ ] Validate memory/table/global constraints

### 9.4 Validation Soundness (stretch goal)
- [ ] Prove: if a module validates, execution never traps due to type errors
  (progress + preservation style theorem)

**Exit criteria**: Type checker accepts valid modules, rejects invalid ones.

**Estimated time**: 6-10 hours.

---

## Testing Strategy

### Level 1: Ground-Truth Execution Tests (assert-event)
Concrete tests that evaluate to a known result. No proof needed —
ACL2 just computes the answer and checks equality.

```lisp
(assert-event (equal (result-of-running program) expected-value))
```

**Coverage**: Every instruction gets at least 2 tests (normal case + edge case/trap).

### Level 2: Symbolic Proofs (defthm)
Universal properties proven by ACL2's theorem prover.

```lisp
(defthm add-correct
  (implies (and (u32p x) (u32p y) ...)
           (equal (result ...) (bvplus 32 x y))))
```

**Coverage**: Key programs get symbolic correctness proofs.

### Level 3: Certification (make .cert)
Every `.lisp` file must certify without errors. This ensures:
- All guards are verified
- All theorems are proven
- No logical inconsistencies

```bash
ACL2=$ACL2 make USE_QUICKLISP=0 ACL2_CUSTOMIZATION=NONE kestrel/wasm/tests.cert
```

### Level 4: Regression (CI)
```bash
# Certify all WASM books in dependency order
for book in types numerics store execution blocks memory modules \
            proof-support tests add-proof factorial-proof; do
  ACL2=$ACL2 make USE_QUICKLISP=0 ACL2_CUSTOMIZATION=NONE \
      kestrel/wasm/$book.cert || exit 1
done
```

### Test Programs (in order of complexity)

| # | Program | Instrs Used | Milestone |
|---|---|---|---|
| 1 | `add(3,4) = 7` | local.get, i32.add | M1 |
| 2 | `sub(10,3) = 7` | local.get, i32.sub | M1 |
| 3 | `mul(6,7) = 42` | local.get, i32.mul | M1 |
| 4 | `div_u(10,3) = 3` | local.get, i32.div_u | M1 |
| 5 | `is_zero(0) = 1` | local.get, i32.eqz | M1 |
| 6 | `max(3,5) = 5` | if/else, i32.gt_u | M2 |
| 7 | `abs(x)` | if/else, i32.sub, i32.lt_s | M2 |
| 8 | `factorial(5) = 120` | loop, br_if, i32.mul, i32.sub | M2 |
| 9 | `fibonacci(10) = 55` | loop, local vars, i32.add | M2 |
| 10 | `gcd(12,8) = 4` | loop, br_if, i32.rem_u | M2 |
| 11 | `call_helper(3,4)` | call, return | M3 |
| 12 | `recursive_fact(5)` | call (recursive) | M3 |
| 13 | `sum_array(mem,n)` | loop, i32.load, memory | M4 |
| 14 | `memcpy(dst,src,n)` | loop, load, store, memory | M4 |
| 15 | `i64_add(big1,big2)` | i64.add | M5 |
| 16 | `parse_and_run(add.wasm)` | binary parse → execute | M7 |

---

## Headless Agent Execution Notes

### Session Setup Script
```bash
#!/bin/bash
# setup-wasm-acl2.sh — Run at start of each agent session
set -x

# 1. Install SBCL if not present
which sbcl || sudo apt-get install -y sbcl

# 2. Build ACL2 if not present
if [ ! -f /opt/acl2/saved_acl2 ]; then
  git clone --depth 1 https://github.com/acl2/acl2.git /opt/acl2
  cd /opt/acl2 && make LISP=sbcl
fi
export ACL2=/opt/acl2/saved_acl2

# 3. Get WASM spec for reference
if [ ! -d /opt/wasm-spec ]; then
  git clone --depth 1 --sparse https://github.com/WebAssembly/spec.git /opt/wasm-spec
  cd /opt/wasm-spec && git sparse-checkout set specification/wasm-1.0
fi

# 4. Verify build
echo '(+ 1 2) (quit)' | $ACL2
```

### Development Workflow
```bash
# Edit a book
vim /opt/acl2/books/kestrel/wasm/execution.lisp

# Certify it
cd /opt/acl2/books
ACL2=$ACL2 make USE_QUICKLISP=0 ACL2_CUSTOMIZATION=NONE kestrel/wasm/execution.cert

# If certification fails, check the log:
cat /opt/acl2/books/kestrel/wasm/execution.cert.out

# Run an interactive test
echo '
(in-package "ACL2")
(ld "/opt/acl2/books/kestrel/wasm/package.lsp")
(in-package "WASM")
(include-book "kestrel/wasm/execution" :dir :system)
;; your test here
(quit)
' | $ACL2
```

### Common Pitfalls
1. **Guard verification failures**: Use `:guard-hints` or add type theorems
2. **Certification timeout**: Break large files into smaller books
3. **Package issues**: Always `(ld "package.lsp")` before `(in-package "WASM")`
4. **Stale .cert files**: Delete `.cert` and `.cert.out` before re-certifying
5. **Include-book paths**: Use `:dir :system` for books under the ACL2 books/ dir
6. **defaggregate field conflicts**: WASM's `state` shadows ACL2's `state` — handled by package exclusion in `package.lsp`

### Certification Dependency Graph
```
package.lsp
  └── portcullis.lisp
       ├── types.lisp
       │    └── numerics.lisp
       ├── store.lisp
       ├── execution.lisp ← types, numerics, store
       │    ├── blocks.lisp
       │    └── memory.lisp
       ├── modules.lisp ← execution, store
       ├── proof-support.lisp ← execution
       │    ├── add-proof.lisp
       │    └── factorial-proof.lisp
       ├── tests.lisp ← execution, blocks, memory
       └── parse-binary.lisp (independent)
```

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Guard verification complexity | High | Medium | Incremental development; prove type theorems early |
| Block/label model mismatch with spec | Medium | High | Prototype with tests before committing to design |
| Floating-point IEEE 754 complexity | High | Medium | Defer to late milestone; integer-only MVP |
| ACL2 build time for large books | Medium | Low | Split into smaller books; parallel certification |
| Parser-executor mismatch | Low | Medium | Test with concrete .wasm files early |
| Termination proofs for recursive execution | Medium | Medium | Use step-count bounded `run` (already done) |
| Existing skeleton API changes breaking proofs | Medium | Medium | Maintain backward compatibility; adapter layer |

---

## Definition of Done

The formalization is **complete** when:
1. ✅ All WASM 1.0 instructions have executable semantics
2. ✅ All books certify (guards verified, theorems proven)
3. ✅ At least 16 test programs execute correctly (assert-event)
4. ✅ At least 3 non-trivial correctness proofs certified (defthm)
5. ✅ A `.wasm` binary can be parsed and executed end-to-end
6. ✅ The code integrates cleanly with existing Kestrel WASM books
