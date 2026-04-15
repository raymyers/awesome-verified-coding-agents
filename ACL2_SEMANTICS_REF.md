# ACL2 Semantics Reference for WASM 1.0 Formalization

> Working notes and references for formalizing WASM 1.0 operational semantics
> in ACL2, extending the Kestrel books (`books/kestrel/wasm/`).

---

## 1. Build & Certification Environment

### ACL2 Installation
```bash
# Prerequisites
sudo apt-get install -y sbcl   # Steel Bank Common Lisp

# Clone & build ACL2
git clone --depth 1 https://github.com/acl2/acl2.git /opt/acl2
cd /opt/acl2 && make LISP=sbcl
export ACL2=/opt/acl2/saved_acl2

# Certify a book (from the books/ directory)
cd /opt/acl2/books
ACL2=$ACL2 make USE_QUICKLISP=0 ACL2_CUSTOMIZATION=NONE kestrel/wasm/execution.cert
```

### Certification Order for Existing Books
```
portcullis.lisp         (package definition, via portcullis.acl2 → package.lsp)
execution.lisp          (core interpreter: ~500 lines, depends on portcullis, bvplus, defaggregate)
proof-support.lisp      (defopeners for run, nth-local, etc.)
add-proof.lisp          (proof that add program computes bvplus 32 x y)
parse-binary.lisp       (~1400 lines, binary format parser, partially complete)
```

### Headless Agent Certification Pattern
```bash
# Certify a single book
cd /opt/acl2/books
ACL2=/opt/acl2/saved_acl2 make USE_QUICKLISP=0 ACL2_CUSTOMIZATION=NONE \
    kestrel/wasm/<bookname>.cert

# Run a test script interactively
echo '
(in-package "ACL2")
(ld "/opt/acl2/books/kestrel/wasm/package.lsp")
(in-package "WASM")
(include-book "kestrel/wasm/execution" :dir :system)
;; ... test code ...
(quit)
' | /opt/acl2/saved_acl2
```

### Test Pattern (assert-event)
```lisp
;; Ground-truth execution test (computes concretely, no proofs needed)
(assert-event
 (let ((result (run 4
                    (make-state :store :fake
                                :call-stack (list (make-frame :return-arity 1
                                                              :locals (list (make-i32-val 3) (make-i32-val 4))
                                                              :operand-stack (empty-operand-stack)
                                                              :instrs '((:local.get 1) (:local.get 0) (:i32.add)))
                                                  (make-frame :return-arity 0
                                                              :locals nil
                                                              :operand-stack (empty-operand-stack)
                                                              :instrs nil))))))
   (and (statep result)
        (equal (top-operand (current-operand-stack result))
               (make-i32-val 7)))))
```

---

## 2. WASM 1.0 SpecTec → ACL2 Mapping

### 2.1 Source Files (SpecTec, 2300 lines total)

| SpecTec File | Lines | ACL2 Target | Notes |
|---|---|---|---|
| `0-aux.spectec` | 42 | N/A (implicit in ACL2) | Ki=1024, min, sum, concat |
| `1-syntax.spectec` | 300 | `types.lisp`, `instructions.lisp` | Full AST: types, ops, instructions, modules |
| `2-syntax-aux.spectec` | 50 | `types.lisp` | size, type projections |
| `3-numerics.spectec` | 243 | `numerics.lisp` | signed/unsigned, all arith/bitwise/compare/convert ops |
| `4-runtime.spectec` | 110 | `execution.lisp` (state model) | store, frame, state, admin instrs |
| `5-runtime-aux.spectec` | 115 | `execution.lisp` (accessors) | State accessors, updaters, grow |
| `6-typing.spectec` | 456 | `typing.lisp` (phase 5) | Validation/type-checking |
| `8-reduction.spectec` | 271 | `execution.lisp` (step/execute-*) | Core operational semantics |
| `9-module.spectec` | 172 | `modules.lisp` | Allocation, instantiation, invocation |
| `A-binary.spectec` | 541 | `parse-binary.lisp` (exists) | Binary format (partially done) |

### 2.2 SpecTec State Model → ACL2

**SpecTec** (4-runtime.spectec):
```
state = store; frame
config = state; admininstr*
store = { FUNCS funcinst*, GLOBALS globalinst*, TABLES tableinst*, MEMS meminst* }
frame = { LOCALS val*, MODULE moduleinst }
admininstr = instr | CALL_ADDR funcaddr | LABEL_ n {instr*} admininstr* | FRAME_ n {frame} admininstr* | TRAP
```

**Existing ACL2** (execution.lisp):
```lisp
(defaggregate state   ((store storep) (call-stack call-stackp+consp)))
(defaggregate frame   ((return-arity natp) (locals val-listp) (operand-stack operand-stackp) (instrs instr-listp)))
;; call-stack = list of frames (implicit FRAME_ nesting)
;; No LABEL_ handling yet — blocks/loops unimplemented
```

**Key design decision**: The existing skeleton models execution as a list of
instructions-to-execute per frame with an explicit call stack, rather than
SpecTec's admin-instruction stack with nested LABEL_ and FRAME_ contexts.

**For blocks/loops**: Need to extend the frame or add a label stack. Options:
1. **Add label-stack to frame**: Each frame gets a stack of `(arity . continuation-instrs)` pairs. `br N` pops N labels.
2. **Flatten to admin instructions**: More faithful to spec but harder to prove things about.
3. **Hybrid**: Keep instruction pointer + label stack (recommended — matches existing style).

### 2.3 Value Types

**SpecTec**:
```
valtype = I32 | I64 | F32 | F64
val = CONST valtype val_(valtype)
```

**Existing ACL2** (only i32):
```lisp
(defund i32-valp (val)  ;; (:i32.const <u32>)
(defund valp (val) (or (i32-valp val)))
```

**Extension needed**:
```lisp
;; Add recognizers:
(defund i64-valp (val) ...)     ;; (:i64.const <u64>)
(defund f32-valp (val) ...)     ;; (:f32.const <ieee754-32>)
(defund f64-valp (val) ...)     ;; (:f64.const <ieee754-64>)
(defund valp (val) (or (i32-valp val) (i64-valp val) (f32-valp val) (f64-valp val)))
```

### 2.4 Instruction Categories (1-syntax.spectec)

| Category | SpecTec | Count | ACL2 Representation |
|---|---|---|---|
| Parametric | NOP, UNREACHABLE, DROP, SELECT | 4 | `(:nop)`, `(:drop)`, etc. |
| Block | BLOCK bt instr*, LOOP bt instr*, IF bt instr* ELSE instr* | 3 | `(:block bt instrs)`, `(:loop bt instrs)`, `(:if bt then-instrs else-instrs)` |
| Branch | BR l, BR_IF l, BR_TABLE l* l | 3 | `(:br l)`, `(:br_if l)`, `(:br_table labels default)` |
| Call | CALL x, CALL_INDIRECT x, RETURN | 3 | `(:call x)`, `(:call_indirect x)`, `(:return)` |
| Numeric/const | CONST t c | 1 | `(:i32.const n)`, `(:i64.const n)`, `(:f32.const n)`, `(:f64.const n)` |
| Numeric/unop | i32: CLZ,CTZ,POPCNT; f32/f64: ABS,NEG,SQRT,CEIL,FLOOR,TRUNC,NEAREST | ~10 | `(:i32.clz)`, etc. |
| Numeric/binop | i32: ADD..ROTR (13); f32/f64: ADD..COPYSIGN (7) | ~20 | `(:i32.add)`, etc. |
| Numeric/testop | i32: EQZ; i64: EQZ | 2 | `(:i32.eqz)`, `(:i64.eqz)` |
| Numeric/relop | i32: EQ..GE_U (10); f32/f64: EQ..GE (6) | ~16 | `(:i32.eq)`, etc. |
| Numeric/cvtop | WRAP, EXTEND, TRUNC, CONVERT, DEMOTE, PROMOTE, REINTERPRET | ~7 sigs | `(:i32.wrap_i64)`, etc. |
| Local | LOCAL.GET x, LOCAL.SET x, LOCAL.TEE x | 3 | `(:local.get x)`, `(:local.set x)`, `(:local.tee x)` |
| Global | GLOBAL.GET x, GLOBAL.SET x | 2 | `(:global.get x)`, `(:global.set x)` |
| Memory | LOAD t, STORE t, MEMORY.SIZE, MEMORY.GROW + packed variants | ~25 | `(:i32.load ao)`, etc. |

### 2.5 Reduction Rules → execute-* Functions

**SpecTec reduction pattern** (8-reduction.spectec):
```
rule Step_pure/binop-val:
  (CONST t c_1) (CONST t c_2) (BINOP t binop)  ~>  (CONST t c)
  -- if c <- $binop_(t, binop, c_1, c_2)
```

**ACL2 pattern** (execute-i32.add as template):
```lisp
(defun execute-i32.add (state)
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
       (arg2 (top-operand ostack))
       (arg1 (top-operand (pop-operand ostack)))
       ((when (not (and (i32-valp arg1) (i32-valp arg2)))) :trap)
       (result (i32.add-vals arg1 arg2))
       (ostack (push-operand result (pop-operand (pop-operand ostack))))
       (state (update-current-operand-stack ostack state))
       (state (update-current-instrs (rest (current-instrs state)) state)))
    state))
```

---

## 3. Key ACL2 Libraries Used

### Kestrel BV (bitvector) library
```lisp
(include-book "kestrel/bv/bvplus" :dir :system)    ; (bvplus 32 x y)
(include-book "kestrel/bv/bvminus" :dir :system)   ; (bvminus 32 x y)
(include-book "kestrel/bv/bvmult" :dir :system)    ; (bvmult 32 x y)
(include-book "kestrel/bv/bvdiv" :dir :system)     ; (bvdiv 32 x y)  — unsigned
(include-book "kestrel/bv/sbvdiv" :dir :system)    ; (sbvdiv 32 x y) — signed
(include-book "kestrel/bv/bvmod" :dir :system)     ; (bvmod 32 x y)
(include-book "kestrel/bv/bvand" :dir :system)     ; (bvand 32 x y)
(include-book "kestrel/bv/bvor" :dir :system)      ; (bvor 32 x y)
(include-book "kestrel/bv/bvxor" :dir :system)     ; (bvxor 32 x y)
(include-book "kestrel/bv/bvnot" :dir :system)     ; (bvnot 32 x)
(include-book "kestrel/bv/bvsx" :dir :system)      ; (bvsx 64 32 x) — sign-extend
(include-book "kestrel/bv/bvshl" :dir :system)     ; (bvshl 32 x amt)
(include-book "kestrel/bv/bvshr" :dir :system)     ; (bvshr 32 x amt)
(include-book "kestrel/bv/sbvlt-def" :dir :system) ; (sbvlt 32 x y) — signed less-than
(include-book "kestrel/bv/bool-to-bit" :dir :system)
```

### Kestrel Utilities
```lisp
(include-book "std/util/defaggregate" :dir :system) ; record types
(include-book "kestrel/utilities/forms" :dir :system)    ; ffn-symb, fargs, farg1
(include-book "kestrel/utilities/defopeners" :dir :system) ; symbolic execution openers
```

### SpecTec Numeric Operations → Kestrel BV

| SpecTec | ACL2 BV | Notes |
|---|---|---|
| `$iadd_(N, i1, i2)` | `(bvplus N i1 i2)` | |
| `$isub_(N, i1, i2)` | `(bvminus N i1 i2)` | |
| `$imul_(N, i1, i2)` | `(bvmult N i1 i2)` | |
| `$idiv_(N, U, i1, i2)` | `(bvdiv N i1 i2)` | Trap if i2=0 |
| `$idiv_(N, S, i1, i2)` | `(sbvdiv N i1 i2)` | Trap if i2=0 or overflow |
| `$irem_(N, U, i1, i2)` | `(bvmod N i1 i2)` | Trap if i2=0 |
| `$iand_(N, i1, i2)` | `(bvand N i1 i2)` | |
| `$ior_(N, i1, i2)` | `(bvor N i1 i2)` | |
| `$ixor_(N, i1, i2)` | `(bvxor N i1 i2)` | |
| `$inot_(N, i)` | `(bvnot N i)` | |
| `$ishl_(N, i1, i2)` | `(bvshl N i1 (bvmod N i2 N))` | Shift modulo N |
| `$ishr_(N, U, i1, i2)` | `(bvshr N i1 (bvmod N i2 N))` | |
| `$ishr_(N, S, i1, i2)` | Signed shift right | Need to check kestrel/bv library |
| `$irotl_(N, i1, i2)` | `(rotate-left N i1 (mod i2 N))` | May need custom def |
| `$irotr_(N, i1, i2)` | `(rotate-right N i1 (mod i2 N))` | May need custom def |
| `$iclz_(N, i)` | Count leading zeros | May need custom def |
| `$ictz_(N, i)` | Count trailing zeros | May need custom def |
| `$ipopcnt_(N, i)` | Population count | May need custom def |
| `$ieqz_(N, i)` | `(bool-to-bit (= i 0))` | |
| `$ieq_(N, i1, i2)` | `(bool-to-bit (= i1 i2))` | |
| `$ilt_(N, U, i1, i2)` | `(bool-to-bit (< i1 i2))` | |
| `$ilt_(N, S, i1, i2)` | `(bool-to-bit (sbvlt N i1 i2))` | |
| `$wrap__(64, 32, i)` | `(bvchop 32 i)` | |
| `$extend__(32, 64, U, i)` | `i` (already unsigned) | |
| `$extend__(32, 64, S, i)` | `(bvsx 64 32 i)` | |

### Floating-point
For f32/f64, ACL2 has rational arithmetic but no native IEEE 754. Options:
1. **Model as rationals** with explicit NaN/Inf tags (like SpecTec's fNmag syntax)
2. **Use kestrel/bv** to model the bit-level representation
3. **Defer** (phase 2+) and focus on integer-only programs first

Recommendation: Defer floating-point to Phase 2. The MVP uses only i32 programs.

---

## 4. Control Flow Design

### Labels and Blocks (Critical for MVP)

The SpecTec spec uses admin instructions:
```
LABEL_ n {instr*} admininstr*
```
Where `n` is the arity, `instr*` is the continuation (where BR jumps to), and
`admininstr*` is the body being executed.

**Recommended ACL2 design**: Add a `label-stack` to each frame.

```lisp
(defaggregate label-entry
  ((arity natp)
   (continuation instr-listp)))  ; instrs to execute after BR to this label

(defund label-stackp (x) ...)   ; list of label-entry

;; Extend frame:
(defaggregate frame
  ((return-arity natp)
   (locals val-listp)
   (operand-stack operand-stackp)
   (instrs instr-listp)
   (label-stack label-stackp)))  ; NEW: stack of enclosing labels
```

### Block Execution
```lisp
;; BLOCK bt instrs  →  push label with arity=|bt|, continuation=rest-of-instrs, then execute instrs
;; LOOP bt instrs   →  push label with arity=0, continuation=(LOOP bt instrs) ++ rest-of-instrs
;; When instrs finish, pop label (fall through)
;; BR n             →  pop n+1 labels, jump to n-th continuation
```

### Operand Stack Interaction with Labels
When entering a block, the operand stack height at entry is recorded.
When a BR fires, the stack is trimmed back to entry height + arity values.

**Design**: Store `(base-height natp)` in label-entry to track the operand
stack boundary.

```lisp
(defaggregate label-entry
  ((arity natp)
   (continuation instr-listp)
   (base-height natp)))  ; operand-stack height at label entry
```

---

## 5. Store Model (for Globals, Tables, Memory)

### Proper Store (replacing `:fake`)
```lisp
(defaggregate store
  ((funcs func-inst-listp)
   (globals global-inst-listp)
   (tables table-inst-listp)
   (mems mem-inst-listp)))

(defaggregate func-inst
  ((type functypep)
   (module module-instp)
   (code funcp)))

(defaggregate global-inst
  ((type global-typep)
   (value valp)))

(defaggregate table-inst
  ((type table-typep)
   (refs funcaddr-option-listp)))  ; list of (option funcaddr)

(defaggregate mem-inst
  ((type mem-typep)
   (data byte-listp)))  ; linear memory bytes
```

### Module Instance
```lisp
(defaggregate module-inst
  ((types functype-listp)
   (funcs funcaddr-listp)
   (globals globaladdr-listp)
   (tables tableaddr-listp)
   (mems memaddr-listp)
   (exports export-inst-listp)))
```

### Frame Extension
```lisp
;; SpecTec frame = { LOCALS val*, MODULE moduleinst }
;; Need to add module reference for function calls, globals, etc.
(defaggregate frame
  ((return-arity natp)
   (locals val-listp)
   (module module-instp)          ; NEW
   (operand-stack operand-stackp)
   (instrs instr-listp)
   (label-stack label-stackp)))   ; NEW
```

---

## 6. Memory Model (for load/store instructions)

### Byte-addressable linear memory
- Memory is a flat byte array, initially zero-filled
- Page size = 64 KiB (65536 bytes)
- Maximum 2^16 pages = 4 GiB
- Little-endian byte order

```lisp
;; Read N bytes from memory at offset
(defund mem-read-bytes (mem offset n)
  (declare (xargs :guard (and (byte-listp mem) (natp offset) (natp n))))
  (take n (nthcdr offset mem)))

;; Write bytes to memory at offset
(defund mem-write-bytes (mem offset bytes)
  (declare (xargs :guard (and (byte-listp mem) (natp offset) (byte-listp bytes))))
  ...)  ; splice bytes into mem at offset

;; Convert between iN values and byte sequences (little-endian)
(defund i32-to-bytes (val) ...)  ; u32 → 4 bytes LE
(defund bytes-to-i32 (bytes) ...) ; 4 bytes LE → u32
```

---

## 7. SpecTec Reduction Rules Reference

### All reduction rules from 8-reduction.spectec:

**Pure reductions** (no state read/write):
- `unreachable → TRAP`
- `nop → ε`
- `val DROP → ε`
- `val₁ val₂ (CONST I32 c) SELECT → val₁ (if c≠0) | val₂ (if c=0)`
- `(CONST I32 c) IF bt then ELSE else → BLOCK bt then (if c≠0) | BLOCK bt else (if c=0)`
- `LABEL_ n {instr'*} val* → val*` (label completed)
- `val'* val^n (BR 0) instr* → val^n instr'*` (in LABEL_n{instr'*})
- `val* (BR l+1) instr* → val* (BR l)` (pass through label)
- `(CONST I32 c) BR_IF l → BR l (if c≠0) | ε (if c=0)`
- `(CONST I32 i) BR_TABLE l* l' → BR l*[i] (if i<|l*|) | BR l' (if i≥|l*|)`
- `val LOCAL.TEE x → val val (LOCAL.SET x)`
- `FRAME_ n {f} val^n → val^n` (frame completed)
- `val'* val^n RETURN instr* → val^n` (in frame context)
- `(CONST t c₁) UNOP t unop → (CONST t c) | TRAP`
- `(CONST t c₁) (CONST t c₂) BINOP t binop → (CONST t c) | TRAP`
- `(CONST t c₁) TESTOP t testop → (CONST I32 c)`
- `(CONST t c₁) (CONST t c₂) RELOP t relop → (CONST I32 c)`
- `(CONST t₁ c₁) CVTOP t₂ t₁ cvtop → (CONST t₂ c) | TRAP`
- `val* TRAP instr* → TRAP` (trap propagation)

**Read reductions** (read from state but don't modify):
- `BLOCK t? instr* → LABEL_ n {ε} instr*`
- `LOOP t? instr* → LABEL_ 0 {LOOP t? instr*} instr*`
- `CALL x → CALL_ADDR funcaddr[x]`
- `(CONST I32 i) CALL_INDIRECT x → CALL_ADDR a (or TRAP)`
- `LOCAL.GET x → local[x]`
- `GLOBAL.GET x → global[x].VALUE`
- `(CONST I32 i) LOAD t ao → (CONST t c) | TRAP`
- `MEMORY.SIZE → (CONST I32 n)`

**State-modifying reductions**:
- `val LOCAL.SET x → ε` (updates local)
- `val GLOBAL.SET x → ε` (updates global)
- `(CONST I32 i) (CONST t c) STORE t ao → ε | TRAP` (updates memory)
- `(CONST I32 n) MEMORY.GROW → (CONST I32 old_size) | (CONST I32 -1)` (grows memory)
- `val^k CALL_ADDR a → FRAME_ n {f} (LABEL_ n {ε} instr*)` (creates new frame)

**Context rules**:
- Steps can occur inside LABEL_ and FRAME_ contexts

---

## 8. Binary Parser Opcodes (parse-binary.lisp coverage)

The existing parser already handles opcodes for most WASM 1.0 instructions,
mapping binary opcodes to the S-expression representation:

| Byte Range | Category | Status |
|---|---|---|
| 0x00-0x11 | Control flow | ✅ Parsed |
| 0x20-0x24 | Variable (local/global) | ✅ Parsed |
| 0x28-0x40 | Memory | ✅ Parsed |
| 0x41-0x42 | i32.const, i64.const | ✅ Parsed |
| 0x43-0x44 | f32.const, f64.const | ✅ Parsed |
| 0x45-0xBF | Numeric ops | ✅ Parsed |

The parser is mostly complete; the execution engine is what needs extension.

---

## 9. Proof Patterns (from add-proof.lisp)

### Ground-truth testing
```lisp
;; assert-event for concrete execution tests (no proof, just evaluation)
(assert-event
 (equal (top-operand (current-operand-stack (run N initial-state)))
        expected-value))
```

### Symbolic verification
```lisp
;; defthm for symbolic proofs (universal quantification)
(defthm program-correct
  (implies (and (u32p x) (u32p y) ...)
           (equal (top-operand (current-operand-stack (run N (make-state ...))))
                  (expected-function x y)))
  :hints (("Goal" :in-theory (enable ...))))
```

### Opener lemmas
```lisp
;; defopeners generates conditional rewrite rules that "open" recursive functions
;; when the argument structure is known (syntactic check on the term)
(acl2::defopeners run)
(acl2::defopeners nth-local)
```

---

## 10. Key Decisions Log

| Decision | Choice | Rationale |
|---|---|---|
| State model | Extend existing skeleton (call-stack + frame) | Compatible with existing proofs; pragmatic |
| Label/block model | Label stack in frame with base-height tracking | Avoids admin-instruction nesting; cleaner for proofs |
| Floating-point | Defer to Phase 2 | Integer-only MVP is sufficient |
| Value representation | S-expressions `(:i32.const n)` | Consistent with existing code |
| Instruction representation | Keyword S-expressions `(:i32.add)` | Consistent with parser output |
| Store | Replace `:fake` with proper defaggregate | Required for globals, memory, function calls |
| BV operations | Use kestrel/bv library | Well-tested, theorem-rich library |
| Testing | assert-event for concrete + defthm for symbolic | Both patterns proven in existing code |

---

## 11. File Organization Plan

```
books/kestrel/wasm/
├── package.lsp              # (exists) WASM package definition
├── portcullis.lisp          # (exists) portcullis
├── portcullis.acl2          # (exists) portcullis commands
├── acl2-customization.lsp   # (exists) customization
│
├── types.lisp               # NEW: value types, type recognizers (i32, i64, f32, f64)
├── numerics.lisp            # NEW: all numeric operations (using kestrel/bv)
├── store.lisp               # NEW: store, instances, module-inst
├── execution.lisp           # (exists) EXTEND: state, frame, step, run + all instructions
├── blocks.lisp              # NEW: label stack, block/loop/if/br execution
├── memory.lisp              # NEW: memory load/store operations
├── modules.lisp             # NEW: allocation, instantiation, invocation
│
├── parse-binary.lisp        # (exists) binary parser
│
├── proof-support.lisp       # (exists) EXTEND: more defopeners
├── add-proof.lisp           # (exists) add correctness proof
├── tests.lisp               # NEW: comprehensive assert-event test suite
├── factorial-proof.lisp     # NEW: factorial example proof
```

---

## 12. WASM 1.0 Instruction Opcode Quick Reference

### Control (0x00-0x11)
```
0x00  unreachable    0x01  nop        0x02  block bt    0x03  loop bt
0x04  if bt          0x05  else       0x0B  end         0x0C  br l
0x0D  br_if l        0x0E  br_table   0x0F  return      0x10  call x
0x11  call_indirect x
```

### Variable (0x20-0x24)
```
0x20  local.get x    0x21  local.set x    0x22  local.tee x
0x23  global.get x   0x24  global.set x
```

### Memory (0x28-0x40)
```
0x28  i32.load       0x29  i64.load       0x2A  f32.load    0x2B  f64.load
0x2C  i32.load8_s    0x2D  i32.load8_u    0x2E  i32.load16_s  0x2F  i32.load16_u
0x30  i64.load8_s    0x31  i64.load8_u    0x32  i64.load16_s  0x33  i64.load16_u
0x34  i64.load32_s   0x35  i64.load32_u
0x36  i32.store      0x37  i64.store      0x38  f32.store   0x39  f64.store
0x3A  i32.store8     0x3B  i32.store16    0x3C  i64.store8  0x3D  i64.store16
0x3E  i64.store32    0x3F  memory.size    0x40  memory.grow
```

### Numeric (0x41-0xBF)
```
0x41  i32.const n    0x42  i64.const n    0x43  f32.const z  0x44  f64.const z
0x45  i32.eqz       0x46-0x4F  i32 relops
0x50  i64.eqz       0x51-0x5A  i64 relops
0x5B-0x60  f32 relops    0x61-0x66  f64 relops
0x67-0x78  i32 unops/binops    0x79-0x8A  i64 unops/binops
0x8B-0x98  f32 unops/binops    0x99-0xA6  f64 unops/binops
0xA7-0xBF  conversion ops
```

---

## 13. External References

- **WASM 1.0 SpecTec**: `https://github.com/WebAssembly/spec/tree/main/specification/wasm-1.0`
- **WASM 1.0 Spec (HTML)**: `https://www.w3.org/TR/wasm-core-1/`
- **Kestrel WASM books**: `https://github.com/acl2/acl2/tree/master/books/kestrel/wasm`
- **Kestrel EVM model**: `https://github.com/acl2/acl2/tree/master/books/kestrel/ethereum/evm`
- **Kestrel BV library**: `https://github.com/acl2/acl2/tree/master/books/kestrel/bv`
- **ACL2 documentation**: `https://www.cs.utexas.edu/users/moore/acl2/manuals/current/manual/`
- **defaggregate**: `https://www.cs.utexas.edu/users/moore/acl2/manuals/current/manual/?topic=STD____DEFAGGREGATE`
