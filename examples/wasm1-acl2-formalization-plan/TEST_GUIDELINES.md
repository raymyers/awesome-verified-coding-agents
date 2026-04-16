# WASM 1.0 ACL2 — Test Guidelines

Rules for writing correct tests. Every rule here exists because we
shipped a bug that could have been caught earlier.

---

## Rule 1: Oracle-First — Never Hand-Compute Expected Values

**Problem**: We hand-calculated `djb2("Hi") = 5864370`. The actual
answer is `5862390`. One arithmetic slip propagated through
two multiplications and we didn't notice until the spot-check.

**Rule**: Every expected value MUST come from an oracle execution,
not mental math.

### Oracle Setup

```bash
sudo apt-get install -y wabt   # provides wat2wasm, wasm-interp
# Node.js is the runtime (already available)
```

### Workflow: WAT First, Then ACL2

1. **Write the program as WAT** (WebAssembly Text Format):

```wat
;; file: tests/oracle/gcd.wat
(module
  (func $gcd (export "gcd") (param $a i32) (param $b i32) (result i32)
    (local $temp i32)
    (block $exit
      (loop $loop
        (br_if $exit (i32.eqz (local.get $b)))
        (local.set $temp (local.get $b))
        (local.set $b (i32.rem_u (local.get $a) (local.get $b)))
        (local.set $a (local.get $temp))
        (br $loop)))
    (local.get $a)))
```

2. **Compile and run with Node.js** to get the oracle value:

```bash
wat2wasm tests/oracle/gcd.wat -o /tmp/gcd.wasm
node -e "
const fs = require('fs');
const wasm = fs.readFileSync('/tmp/gcd.wasm');
WebAssembly.instantiate(wasm).then(({instance}) => {
  console.log('gcd(48,18)='+instance.exports.gcd(48,18));
  console.log('gcd(35,14)='+instance.exports.gcd(35,14));
});"
```

Output:
```
gcd(48,18)=6
gcd(35,14)=7
```

3. **Only then** write the ACL2 test using the oracle values:

```lisp
(assert-event
 (equal (get-result (run 200 (make-gcd-state 48 18)))
        (make-i32-val 6)))   ; ← from oracle, not hand-computed
```

4. **Commit the `.wat` file alongside the `.lisp` test** so the oracle
is reproducible.

### One-Shot Oracle Script

For bulk checking, use `tests/oracle/check-all.sh`:

```bash
#!/bin/bash
# Compile all WAT files, run oracle, print expected values
set -u
for wat in tests/oracle/*.wat; do
  base=$(basename "$wat" .wat)
  wat2wasm "$wat" -o "/tmp/${base}.wasm" || { echo "FAIL: $wat"; exit 1; }
done
node tests/oracle/check-all.mjs
```

---

## Rule 2: Stack Ordering — Arguments Are Reversed

**Problem**: We wrote `(list (make-i32-val 0) (make-i32-val 5))`
intending `ptr=0, len=5`. But our operand stack is top-first, so this
meant `top=0, bottom=5`. After `top-n-operands` reversal during
`execute-call`, locals became `[5, 0]` — ptr=5, len=0. The function
returned immediately. We didn't catch it on GCD because gcd(a,b)=gcd(b,a).

**Rule**: In the operand stack list, the **last argument pushed** is
**first** in the list.

```lisp
;; Calling func(arg0=ptr, arg1=len):
;; WASM pushes arg0 first, then arg1.
;; Stack = (arg1-on-top arg0-on-bottom)
;; top-n-operands pops and reverses → locals = (arg0 arg1) ✓

;; CORRECT — len on top, ptr on bottom:
:operand-stack (list (make-i32-val 5)    ; arg1 = len (top)
                     (make-i32-val 0))   ; arg0 = ptr (bottom)

;; WRONG — this gives ptr=5, len=0:
:operand-stack (list (make-i32-val 0)    ; ← this is TOP, becomes arg1
                     (make-i32-val 5))   ;    this becomes arg0
```

### Verification: Always Test With Non-Commutative Args First

Before adding a new function test, run it once with distinguishable,
non-commutative arguments. Example:

```lisp
;; BAD first test: gcd(12, 8) = 4     ← gcd is commutative, hides reversal
;; GOOD first test: sub(10, 3) = 7    ← sub(3, 10) would give 4294967289
```

---

## Rule 3: Instruction Format — Nested Lists

**Problem**: We wrote `(:block 0 (:loop 0 (:local.get 1) ...))`.
The `instrp` recognizer expects `(:block arity body-list)` where
`body-list` is a **list of instructions**, not a single nested form.

**Correct format**:
```lisp
;; block body is a LIST of instructions (each instruction is a list):
(:block 0 ((:loop 0 ((:local.get 1)
                      (:i32.eqz)
                      (:br_if 1)
                      (:br 0)))))

;; if has two body lists:
(:if 1 ((:i32.const 0) (:return))     ; then-body
       ((:local.get 0)))              ; else-body

;; WRONG — body is a single instruction, not a list:
(:block 0 (:loop 0 (:local.get 1) ...))
```

**Diagnostic**: If you get a guard violation mentioning `(INSTRP INSTR)`,
check that block/loop/if bodies are doubly-nested lists.

---

## Rule 4: Use `get-result` — Handle `:done` Returns

**Problem**: When the last frame returns, `run` produces
`(:done state)` not a bare `state`. Calling `current-operand-stack`
on `(:done ...)` causes a guard violation.

**Rule**: Always use the `get-result` helper:

```lisp
(defun get-result (r)
  (declare (xargs :guard t :verify-guards nil))
  (if (and (consp r) (eq :done (first r)))
      (let* ((st (second r))
             (cs (state->call-stack st))
             (f (car cs)))
        (top-operand (frame->operand-stack f)))
    (if (statep r)
        (top-operand (current-operand-stack r))
      r)))
```

For memory inspection after function calls, use `get-memory`:

```lisp
(defun get-memory (r)
  (declare (xargs :guard t :verify-guards nil))
  (if (and (consp r) (eq :done (first r)))
      (state->memory (second r))
    (if (statep r) (state->memory r) nil)))
```

**When does `:done` happen?** Any `run` where the last instruction
in the last frame completes. This includes all `(:call N)` tests
since the call creates a frame and returning from it is the end.

**When does it NOT happen?** Inline instruction sequences that don't
use function calls — the state stays a normal state.

---

## Rule 5: Test Design — Catch Bugs Early

### Use asymmetric arguments
Pick args where swapping them gives a visibly different answer:

| Function | Good test args | Why |
|----------|---------------|-----|
| sub | (10, 3)→7 | sub(3,10) would be 4294967289 |
| div_u | (10, 3)→3 | div_u(3,10) would be 0 |
| sum_array | ptr=0,len=5 | ptr=5,len=0 returns 0 |
| shl | (1, 4)→16 | shl(4,1) would be 8 |

### Test the zero/identity case AND a non-trivial case
```lisp
;; Not just happy path:
gcd(48, 18) = 6     ; 3 loop iterations
gcd(1, 1) = 1       ; 1 iteration (b becomes 0 immediately)
gcd(17, 0) = 17     ; 0 iterations (b is already 0) — edge case
```

### For loops: verify iteration count, not just final value
If a loop should run 5 times and the result happens to be 0,
you can't tell if the loop ran 5 times or 0 times. Add a counter
or test with inputs where early-exit gives a different answer.

---

## Rule 6: Debugging Failed Tests

When an `assert-event` fails:

### Step 1: Get the actual value
```lisp
(cw "actual: ~x0~%" (get-result (run N state)))
```

### Step 2: Single-step to find where it diverges
```lisp
(cw "step 0: ~x0~%" state)
(cw "step 1: ~x0~%" (step state))
(cw "step 2: ~x0~%" (step (step state)))
```

### Step 3: Check against oracle
Write the equivalent WAT, compile, run with Node.js.

### Step 4: Narrow the divergence
If ACL2 gives X and oracle gives Y, the bug is in ACL2's semantics.
Isolate which instruction produces the wrong result by comparing
intermediate states.

### Common failure modes

| Symptom | Likely cause |
|---------|-------------|
| Function returns 0 / wrong value immediately | Stack arg order reversed (Rule 2) |
| Guard violation on `INSTRP` | Wrong instruction nesting (Rule 3) |
| Guard violation on `STATEP` | Hit `:done` without `get-result` (Rule 4) |
| Loop runs forever (needs huge step count) | `br` target index wrong |
| Loop exits immediately | Condition sense inverted (eqz vs not-eqz) |
| Result off by small amount | Signed vs unsigned confusion (lt_s vs lt_u) |
| Result completely wrong on large numbers | Missing modular wrap (bvplus vs +) |

---

## Rule 7: New Instruction Checklist

When adding a new instruction to `execution.lisp`:

- [ ] Add to `instrp` recognizer with correct arg pattern
- [ ] Add `execute-X` function
- [ ] Add case to `execute-instr` dispatch
- [ ] Write WAT oracle test (`tests/oracle/X.wat`)
- [ ] Run oracle to get expected values
- [ ] Write ACL2 test using oracle values
- [ ] Test at least: normal case, edge case (0, max, overflow)
- [ ] For binary ops: test with non-commutative args
- [ ] Verify all existing tests still pass (regression)
- [ ] Certify `execution.lisp`

---

## Rule 8: Step Budget

Each instruction takes 1 step. Control flow overhead:

| Operation | Approximate steps |
|-----------|------------------|
| Single instruction (add, const, etc.) | 1 |
| Function call setup | 2 (call + frame push) |
| Function return | 2 (label completion + frame pop) |
| Block enter + exit | 2 |
| Loop iteration (body of N instrs) | N + 2 (loop entry + br) |
| If/else (one branch of N instrs) | N + 3 (condition + if + block completion) |

**Rule of thumb**: `steps = 20 + (instrs_per_iteration × iterations × 2)`.
Always add a safety margin. If a test needs `run 500` and you use `run 50`,
it will silently return a mid-execution state that looks like a wrong answer.

**Diagnostic**: If the result looks like a partially-computed value
(e.g., sum of first 3 elements instead of 5), increase the step count.

---

## File Organization

```
tests/
├── test-m1-i32-ops.lisp        # M1 instruction tests
├── test-m2-control-flow.lisp   # M2 block/loop/branch tests
├── test-m3-functions.lisp      # M3 call tests
├── test-m4-memory.lisp         # M4 load/store tests
├── test-m5-i64.lisp            # M5 i64 + conversions
├── test-m6-globals.lisp        # M6 global variable tests
├── test-spot-check.lisp        # Integration tests (multi-feature)
└── oracle/
    ├── gcd.wat                 # WAT source for oracle comparison
    ├── hash.wat
    ├── collatz.wat
    ├── is_prime.wat
    ├── check-all.sh            # Compile + run all oracle tests
    └── check-all.mjs           # Node.js oracle runner
```

---

## Verified Oracle Values (Reference)

Values confirmed by `wat2wasm` + Node.js V8 engine:

| Test | Input | Oracle result | ACL2 matches |
|------|-------|--------------|-------------|
| gcd | (48, 18) | 6 | ✅ |
| gcd | (35, 14) | 7 | ✅ |
| gcd | (1, 1) | 1 | ✅ |
| sum_array | [10,20,30,40,50] | 150 | ✅ |
| swap | mem[0]=42,mem[4]=99 | mem[0]=99,mem[4]=42 | ✅ |
| abs | -5 (=4294967291) | 5 | ✅ |
| abs | 7 | 7 | ✅ |
| djb2 | "Hi" (ptr=0,len=2) | 5862390 | ✅ |
| collatz | 6 | 8 | ✅ |
| collatz | 27 | 111 | ✅ |
| i64 mul | 0xFFFFFFFF × 0xFFFFFFFF | 18446744065119617025 | ✅ |
| is_prime | 1 | 0 | ✅ |
| is_prime | 2 | 1 | ✅ |
| is_prime | 7 | 1 | ✅ |
| is_prime | 12 | 0 | ✅ |
| is_prime | 97 | 1 | ✅ |
| is_prime | 100 | 0 | ✅ |
| i32.load8_u | addr=0, mem=[0xAB,...] | 171 | ✅ |
| i32.load8_s | addr=0, mem=[0xAB,...] | -85 (u32: 4294967211) | ✅ |
| i32.load16_u | addr=0 | 52651 (0xCDAB) | ✅ |
| i32.load16_s | addr=0 | -12885 (u32: 4294954411) | ✅ |
| i32.store8 | addr=16, val=0x1FF | read-back: 255 | ✅ |
| i32.store16 | addr=20, val=0xDEADBEEF | read-back: 48879 | ✅ |
| i64.load8_u | addr=0 | 171 | ✅ |
| i64.load8_s | addr=0 | -85 (u64: 18446744073709551531) | ✅ |
| i64.load16_s | addr=0 | -12885 (u64: 18446744073709538731) | ✅ |
| i64.load32_u | addr=0 | 317705643 | ✅ |
| i64.load32_s | addr=4 | -1703389644 (u64: 18446744072006161972) | ✅ |
| i64.store8 | addr=16, val=0x1FF | read-back: 255 | ✅ |
| i64.store16 | addr=20, val=0xDEADBEEF | read-back: 48879 | ✅ |
| i64.store32 | addr=24, val=0x123456789ABCDEF | read-back: 2309737967 | ✅ |
