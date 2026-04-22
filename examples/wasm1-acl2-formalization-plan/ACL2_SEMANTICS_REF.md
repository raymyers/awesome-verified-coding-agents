# ACL2 Semantics Reference for WASM 1.0 Formalization

> Working notes and references for formalizing WASM 1.0 operational semantics
> in ACL2, extending the Kestrel books (`books/kestrel/wasm/`).
>
> **Verified against**: ACL2 8.7 (commit HEAD) + SBCL 2.5.2 on Debian 13.

---

## 1. Build & Certification Environment

### Dev container (recommended)
The repo's `.devcontainer/devcontainer.json` uses `ghcr.io/jimwhite/acl2-jupyter`
which ships ACL2 prebuilt:
```
ACL2=/opt/acl2/bin/acl2              # ACL2 launcher (already on $PATH as acl2)
ACL2_HOME=/home/acl2                 # ACL2 sources
ACL2_SYSTEM_BOOKS=/home/acl2/books   # community books (incl. kestrel/wasm)
```
The `Makefile` in this tree defaults to those paths, so no env setup is needed.

### Standalone install (outside the container)
```bash
sudo apt-get install -y sbcl
git clone --depth 1 https://github.com/acl2/acl2.git $HOME/acl2
cd $HOME/acl2 && make LISP=sbcl
export ACL2=$HOME/acl2/saved_acl2
export CERT=$HOME/acl2/books/build/cert.pl

# Verify
echo '(+ 40 2) (quit)' | $ACL2   # Should print 42
```

### Certifying Books — this tree is a conventional ACL2 book set
This directory ships a `Makefile` and `cert.acl2` files so `cert.pl` certifies
every `.lisp` book with no per-file `.acl2` wrapper. The `WASM` package is
loaded by `(include-book "kestrel/wasm/portcullis" :dir :system)` in each
`cert.acl2`.

```bash
# From examples/wasm1-acl2-formalization-plan/ :
make                       # certify all 45 books (top + 27 proofs + 15 tests + library)
make top                   # just execution + validation + top
make proofs                # just proofs/*.lisp
make tests                 # just tests/*.lisp
make clean                 # remove .cert / .port / .fasl / .out

# Certify a single book directly:
$CERT --acl2 $ACL2 proofs/proof-add-spec

# Check certification log on failure:
cat proofs/proof-add-spec.cert.out
```

### Certification Order for Kestrel Books (upstream, for reference)
```
books/kestrel/wasm/package.lsp → portcullis.acl2 → portcullis.lisp (.cert)
  → execution.lisp (.cert)   — skeleton we extend from
  → parse-binary.lisp (.cert) — 1429-line WASM binary parser
```

### Running a single test or proof book interactively
```bash
# Certifying is the primary way to run (certification embeds every
# assert-event as a theorem, so a failure aborts certification).
# For ad-hoc experimentation you can still ld a book:
echo '(include-book "execution") (quit)' | $ACL2
```

### Test / proof book preamble (VERIFIED — this exact pattern works)
Because `cert.acl2` in every subdir already loads the WASM package, each
book's preamble is just:
```lisp
;; tests/test-*.lisp and proofs/proof-*.lisp :
(in-package "WASM")
(include-book "../execution")
;; (optionally) (include-book "../validation")

;; top-level execution / validation books (in this dir):
(in-package "WASM")
(include-book "execution")
```

Things to keep out of certified books:
- No `(set-guard-checking :none)` at top level — it isn't an embedded event.
- Wrap diagnostic `(cw ...)` in `(value-triple (cw ...))`.
- No read-time eval (`#.`) inside a certified book. Replace
  `(enable . #.*foo*)` with `(union-theories (current-theory :here) *foo*)`.
- Mark shared-name defconsts (`*foo-theory*`, `*test-store*`, ...) `(local ...)`
  so sibling books can share a package without collision.

### assert-event Pattern (VERIFIED)
```lisp
;; assert-event succeeds silently (prints :PASSED) or aborts with error
(assert-event
 (equal (top-operand
          (current-operand-stack
            (run 4
              (make-state :store :fake
                :call-stack (list (make-frame :return-arity 1
                                   :locals (list (make-i32-val 3) (make-i32-val 4))
                                   :operand-stack (empty-operand-stack)
                                   :instrs '((:local.get 0) (:local.get 1) (:i32.add)))
                                  (make-frame :return-arity 0 :locals nil
                                   :operand-stack (empty-operand-stack) :instrs nil))))))
        (make-i32-val 7)))
(value-triple (cw "TEST PASSED: add(3,4)=7~%"))
```

### Single-source WASM package (2026-04-22)
This tree no longer ships its own `package.lsp` / `portcullis.lisp`. The sole
definition of the `WASM` package is the community book
`books/kestrel/wasm/package.lsp`, certified once into `kestrel/wasm/portcullis`.
Every `cert.acl2` in this tree just does:
```lisp
(include-book "kestrel/wasm/portcullis" :dir :system)
```
so `(in-package "WASM")` works inside every book without a local `.acl2` file.

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

**Kestrel Skeleton** (execution.lisp, 545 lines):
```lisp
(defaggregate state   ((store storep) (call-stack call-stackp+consp)))
(defaggregate frame   ((return-arity natp) (locals val-listp)
                       (operand-stack operand-stackp) (instrs instr-listp)))
;; Only i32.add + local.get, store is untyped (anything passes storep)
```

**Our Implementation** (execution.lisp, ~2100 lines):
```lisp
(defaggregate funcinst ((param-count natp) (local-count natp)
                        (return-arity natp) (body true-listp)))
(defaggregate globalinst ((value true-listp) (mutability booleanp)))
(defaggregate frame ((return-arity natp) (locals val-listp)
                     (operand-stack operand-stackp) (instrs true-listp)
                     (label-stack true-listp)))
(defaggregate state ((store storep)       ;; list of funcinst
                     (call-stack ...)     ;; list of frames
                     (memory byte-listp)  ;; flat byte list (pages × 65536)
                     (globals true-listp) ;; list of globalinst
                     (table true-listp))) ;; list of func indices
```

**Key design decisions**:
1. **Label stack in frame** (not admin-instruction nesting): Each frame has a label stack of `(arity continuation-instrs base-operand-height)` triples. `br N` pops N+1 labels.
2. **Instruction lists are `true-listp`** (not `instr-listp`): Relaxed type to support nested block/loop/if instructions without circular recognizer definitions.
3. **Store = list of funcinst**: Simplified from SpecTec's full store; funcinst captures (param-count, local-count, return-arity, body).
4. **Memory = flat byte list**: `(make-list (* pages 65536) :initial-element 0)`. Access via `nth`/`update-nth`.

### 2.3 Value Types

**SpecTec**:
```
valtype = I32 | I64 | F32 | F64
val = CONST valtype val_(valtype)
```

**Our ACL2** (implemented):
```lisp
(defund i32-valp (val) ...)     ;; (:i32.const <u32>), u32p = unsigned-byte-p 32
(defund i64-valp (val) ...)     ;; (:i64.const <u64>), unsigned-byte-p 64
(defund f32-valp (val) ...)     ;; (:f32.const <rational>), rationalp (approximate)
(defund f64-valp (val) ...)     ;; (:f64.const <rational>), rationalp (approximate)
(defund valp (val) (or (i32-valp val) (i64-valp val) (f32-valp val) (f64-valp val)))

;; Constructors
(defund make-i32-val (x) (list :i32.const x))
(defund make-i64-val (x) (list :i64.const x))

;; Type extraction
(defun val-type (v) (car v))    ;; → :i32.const, :i64.const, etc.
```

**Note on floats**: f32/f64 use ACL2 rationals as approximation. Full IEEE 754
conformance (NaN, ±Infinity, signed zero, denormals) requires explicit bitvector
representation — deferred to M11.

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

**DRY macros** (implemented):
```lisp
;; Defines execute-i32.<op> with 2 args from stack, applies bv-fn
(defmacro def-i32-binop (name bv-fn)
  `(defun ,(intern-in-package-of-symbol (concatenate 'string "EXECUTE-I32." (symbol-name name)) 'wasm::foo) (state)
     ...))

;; Similarly: def-i32-relop (comparison ops → i32 0/1)
;; Similarly: def-i32-unop (1 arg from stack)
;; Similarly: def-packed-load, def-packed-store (memory ops with byte width)
```

**Block/loop execution pattern**:
```lisp
;; (:block arity (body-instrs...))
;; Push label, set instrs to body, save continuation
(defun execute-block (arity body-instrs state)
  (b* ((ostack (current-operand-stack state))
       (rest-instrs (rest (current-instrs state)))
       (label (list arity rest-instrs (operand-stack-height ostack)))
       (state (push-label label state))
       (state (update-current-instrs body-instrs state)))
    state))

;; (:loop arity (body-instrs...))
;; Like block but continuation re-enters the loop
(defun execute-loop (arity body-instrs state)
  (b* (... (continuation (cons (list :loop arity body-instrs) rest-instrs))
       (label (list 0 continuation (operand-stack-height ostack))) ...)
    state))
```

**Branch (br N)**:
```lisp
;; Pop N+1 labels, trim operand stack to base + arity values, jump to continuation
(defun execute-br (n state)
  ;; Peel labels one at a time, then jump to continuation of the Nth label
  ...)
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

| Decision | Choice | Rationale | Outcome |
|---|---|---|---|
| State model | Extend skeleton (call-stack + frame) | Compatible with existing proofs | ✅ Works well |
| Label/block model | Label stack in frame | Cleaner for proofs than admin-instrs | ✅ Proven correct |
| Floating-point | Rationals (defer IEEE 754) | Integer-only MVP first | 🔶 Needs NaN/Inf |
| Value representation | `(:i32.const n)` S-exprs | Consistent with existing code | ✅ Clean |
| Instruction representation | Keyword S-exprs + nested blocks | Consistent with parser output | ✅ Clean |
| Store | List of funcinst (defaggregate) | Required for function calls | ✅ Works |
| BV operations | kestrel/bv library | Well-tested, theorem-rich | ✅ Essential |
| Testing | assert-event + defthm + E2E oracle | Multiple levels of assurance | ✅ Robust |
| Package independence | `cert.acl2` → `kestrel/wasm/portcullis` | One authoritative `WASM` package | ✅ Resolved |
| instrp guard | `true-listp` not `instr-listp` | Nested blocks can't use strict recognizer | ✅ Pragmatic |

---

## 11. E2E Validation Pipeline

### Architecture
```
                  wat2wasm         wasm2acl2.js
add.wat ─────────► add.wasm ──────────────────► test-e2e-add.lisp
                                  │                    │
                                  │ Node.js WASM       │ ACL2
                                  │ runtime            │ execution
                                  ▼                    ▼
                              expected: 7          result: 7
                                  │                    │
                                  └──── compare ───────┘
```

### wasm2acl2.js — WASM Binary Parser + ACL2 Translator
- Parses WASM binary sections: Type, Function, Export, Code, Memory
- Maps WASM opcodes to ACL2 S-expression instruction form
- Executes each test case in Node.js WASM runtime for ground-truth expected values
- Generates complete ACL2 `.lisp` file with `assert-event` checks
- Key fixes:
  - **Negative args**: JS `args[i] >>> 0` for i32 unsigned conversion
  - **Memory instructions**: Extract offset from memarg: `(:i32.load offset)` not `(:i32.load)`
  - **Buffer.byteOffset**: Node.js Buffer shares ArrayBuffer; must use `buf.buffer.slice(buf.byteOffset, ...)`

### Test Spec Format (JSON)
```json
{
  "function": "add",
  "tests": [
    {"args": [3, 4], "expected": 7},
    {"args": [0, 0], "expected": 0},
    {"args": [-1, 1], "expected": 0}
  ]
}
```

### Running E2E Tests
```bash
# Prerequisites: wat2wasm (wabt), node.js
# 1. Compile WAT
wat2wasm add.wat -o add.wasm

# 2. Generate ACL2 test (also runs Node.js for expected values)
node wasm2acl2.js add.wasm add.json > test-e2e-add.lisp

# 3. Run in ACL2
echo '(ld "test-e2e-add.lisp") (quit)' | $ACL2 2>&1 | grep "=== ALL"
```

---

## 12. File Organization (actual)

```
examples/wasm1-acl2-formalization-plan/
├── cert.acl2                # (include-book "kestrel/wasm/portcullis" :dir :system)
├── Makefile                 # drives cert.pl over every book
├── top.lisp                 # library bundle (execution + validation)
├── execution.lisp           # Main semantics (3718 lines, 170 instructions)
├── validation.lisp          # Type checker (M9)
├── tests/
│   ├── cert.acl2            # same one-line portcullis include
│   ├── test-m1-instructions.lisp   # i32 arith/cmp/parametric
│   ├── test-m2-control-flow.lisp   # block/loop/if/br
│   ├── test-m3-functions.lisp      # call, funcinst, store
│   ├── test-m4-memory.lisp         # load/store, memory ops
│   ├── test-m5-i64.lisp            # i64 operations
│   ├── test-m5b-globals.lisp       # global.get/set
│   ├── test-m7a-floats.lisp        # f32/f64 operations
│   ├── test-m7b-tables.lisp        # call_indirect, tables
│   ├── test-m9-validation.lisp     # type checking tests
│   ├── test-m12-nan.lisp           # NaN propagation tests
│   ├── test-m13-signed-zero.lisp   # ±0 tests
│   ├── test-m14-inf-arith.lisp     # ±Inf arithmetic tests
│   ├── test-packed-mem.lisp        # packed i32 memory
│   ├── test-packed-mem-i64.lisp    # packed i64 memory
│   ├── test-spot-check.lisp        # 20 cross-cutting tests
│   └── oracle/                     # WAT + Node.js oracle harness
│       ├── cert_pl_exclude         # tells cert.pl to skip this dir
│       ├── check-all.sh
│       └── check-all.mjs
├── proofs/
│   ├── cert.acl2            # same one-line portcullis include
│   ├── proof-add-spec.lisp, proof-sub-spec.lisp, ...   # 27 proof books total
│   └── ... (280 Q.E.D.s)
├── WASM1_PLAN.md
├── ACL2_SEMANTICS_REF.md
├── TEST_GUIDELINES.md
└── README.md
```

---

## 13. WASM 1.0 Instruction Opcode Quick Reference

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

## 14. Other Kestrel ASM Models (patterns to follow)

### Kestrel EVM Model (`books/kestrel/ethereum/evm/`)
- **1779 lines** in `evm.lisp`, 67 definitions
- Uses `std::defaggregate` for `account-state`, `transaction`, `block-header`
- Separate files: `evm.lisp` (core), `evm-rules.lisp` (rewrite rules), `evm-tests.lisp` (tests), `support.lisp`
- Pattern: state is big aggregate, step function dispatches on opcode, run loops step N times

### Kestrel JVM Model (`books/kestrel/jvm/`)
- **87 files**, mature model
- Separate files for: `states.lisp`, `execution.lisp`, `execution2.lisp`, `call-stacks.lisp`, `class-file-parser.lisp`
- `symbolic-execution.lisp` for symbolic evaluation
- Pattern to emulate: split large execution into execution.lisp (core) + blocks.lisp + memory.lisp

### Common Patterns Across Kestrel ASM Models
1. `defaggregate` for state structures (not `defstobj`)
2. `defund` for core operations (enables explicit `enable` in proofs)
3. `defopeners` for recursive functions used in proofs
4. `assert-event` for concrete ground-truth tests
5. `defthm` with `:in-theory (enable ...)` for symbolic proofs
6. Single `WASM` package via `kestrel/wasm/portcullis`, pulled in by a one-line `cert.acl2`

---

## 15. External References

- **WASM 1.0 SpecTec**: `https://github.com/WebAssembly/spec/tree/main/specification/wasm-1.0`
- **WASM 1.0 Spec (HTML)**: `https://www.w3.org/TR/wasm-core-1/`
- **WASM 1.0 Spec Test Suite**: `https://github.com/WebAssembly/spec/tree/main/test/core`
- **Kestrel WASM books**: `https://github.com/acl2/acl2/tree/master/books/kestrel/wasm`
- **Kestrel EVM model**: `https://github.com/acl2/acl2/tree/master/books/kestrel/ethereum/evm`
- **Kestrel JVM model**: `https://github.com/acl2/acl2/tree/master/books/kestrel/jvm`
- **Kestrel BV library**: `https://github.com/acl2/acl2/tree/master/books/kestrel/bv`
- **ACL2 documentation**: `https://www.cs.utexas.edu/users/moore/acl2/manuals/current/manual/`
- **defaggregate**: `https://www.cs.utexas.edu/users/moore/acl2/manuals/current/manual/?topic=STD____DEFAGGREGATE`
- **cert.pl**: `https://www.cs.utexas.edu/users/moore/acl2/manuals/current/manual/?topic=BUILD____CERT.PL`

---

## 16. Troubleshooting Guide

### "Symbol STOREP not found" or redefinition errors
- Cause: Loading both Kestrel's execution AND our execution in same session
- Fix: Use only one. Books here `(include-book "execution")` (our version); the `WASM` package comes from `kestrel/wasm/portcullis` via `cert.acl2`.

### "Certification loop" or "include-book not found"
- Cause: Stale `.cert` or missing community books
- Fix: `make clean && make`. Inside the dev container the defaults (`ACL2=/opt/acl2/bin/acl2`, `CERT=/home/acl2/books/build/cert.pl`) are correct. Outside it, set `ACL2` and `CERT` to your local install and make sure `kestrel/wasm/portcullis.cert` exists (it's built on demand by `cert.pl`).

### "Guard violation in BVPLUS/BVMINUS"
- Cause: Arguments not proven to be `unsigned-byte-p 32`
- Fix: Add `(unsigned-byte-p 32 x)` hypotheses; enable `bvplus-of-bvuminus-when-bvle`

### "The proof attempt has failed" (defthm)
- Cause: Usually needs more functions enabled or missing :expand hints
- Fix: Add `:in-theory (enable fn1 fn2 ...)` and `:expand ((:free (n s) (run n s)))`
- NEVER put macros (advance-instrs, ffn-symb) in enable lists

### "ACL2 crashed" or session hung
- Cause: Infinite loop in ACL2 term rewriting, or memory exhaustion
- Fix: Kill ACL2 process; add `:do-not '(generalize)` to hints; reduce step count in `run`

### E2E test values mismatch
- Cause: Signed/unsigned confusion between JS and ACL2
- Fix: Always convert JS signed → unsigned: `(result >>> 0)` for i32, `BigInt.asUintN(32, result)` for i32

---

## 17. Critical Gotchas — Hard-Won Lessons (VERIFIED 2026-04-18)

These were discovered through actual certification attempts and are essential
for any agent session extending the Kestrel execution.lisp.

### 17.1 defaggregate generates `name-p` not `namep`
```lisp
;; By default, (std::defaggregate frame ...) generates predicate `frame-p`
;; Kestrel uses :pred framep to override this:
(std::defaggregate frame
  ((return-arity natp)
   (locals val-listp)
   (operand-stack operand-stackp)
   (instrs true-listp))
  :pred framep)     ;; ← REQUIRED if using "framep" elsewhere

;; Same for state:
(std::defaggregate state
  ((store storep)
   (call-stack (and (call-stackp call-stack) (consp call-stack))))
  :pred statep)     ;; ← REQUIRED
```

### 17.2 Package imports: bvplus is imported, bvminus is NOT
The Kestrel `WASM` package imports `bvplus` but NOT `bvminus`, `bvxor`,
`bvand`, `bvor`, `bvshl`, `bvshr`, or other BV operations. Use `acl2::` prefix:
```lisp
(make-i32-val (acl2::bvminus 32 (farg1 val1) (farg1 val2)))
(make-i32-val (acl2::bvand 32 (farg1 val1) (farg1 val2)))
```

### 17.3 Definition ordering: dispatch AFTER all handler defs
`execute-instr` must be defined AFTER all `execute-i32.xxx` functions it
dispatches to. ACL2 is strictly single-pass:
```lisp
;; 1. Define all instruction handlers first
(defun execute-i32.add ...)
(defun execute-i32.sub ...)
(defun execute-i32.mul ...)

;; 2. THEN the dispatch table
(defund execute-instr ...)
```

### 17.4 Guard verification: match Kestrel patterns exactly
New instruction handlers MUST match the guard hint pattern:
```lisp
;; i32-vals function — enable i32-valp and u32p
(defund i32.sub-vals (val1 val2)
  (declare (xargs :guard (and (i32-valp val1) (i32-valp val2))
                  :guard-hints (("Goal" :in-theory (enable i32-valp u32p)))))
  ...)

;; execute function — enable valp, i32-valp, u32p
;; If guard fails, add the *-vals function to the enable list:
(defun execute-i32.sub (state)
  (declare (xargs :guard (statep state)
                  :guard-hints (("Goal" :in-theory (enable valp i32-valp u32p i32.sub-vals)))))
  ...)
```
**If guard verification still fails**, use `:verify-guards nil` BUT then
`execute-instr` won't certify (it requires all callees to have verified guards).
In that case, also add `:verify-guards nil` to `execute-instr` and use
`(set-guard-checking :none)` in tests.

### 17.5 (set-guard-checking :none) for interactive runs only
When guards aren't fully verified, interactive `ld` of a book may need
`(set-guard-checking :none)` before evaluating raw `(run ...)` forms.
However, `(set-guard-checking ...)` is NOT an embedded event form and must
NOT appear at the top level of a certified book. In our tree, every
`assert-event` inside a `tests/test-*.lisp` book is checked during
certification without needing `set-guard-checking`.

### 17.6 No local execution.acl2 / package.lsp needed
The directory's `cert.acl2` files pull in `kestrel/wasm/portcullis`, so
`cert.pl` knows the `WASM` package before certifying any book. Do NOT add a
local `package.lsp`, `portcullis.lisp`, or per-book `.acl2` wrapper — they
would redefine the package and cause conflicts.

### 17.7 state defaggregate: inline guard, not shorthand
The call-stack field guard uses inline AND, not a combined predicate:
```lisp
;; WRONG: (call-stack call-stackp+consp)
;; RIGHT:
(call-stack (and (call-stackp call-stack) (consp call-stack)))
```

### 17.8 farg1 vs cadr for value access
Kestrel uses `(farg1 val)` (from `kestrel/utilities/forms`) not `(cadr val)`:
```lisp
;; Access the numeric part of (:i32.const N):
(farg1 val)         ;; Kestrel style — works with guard verification
(cadr val)          ;; Raw — may fail guard proofs
```

---

## §18 Gap Analysis — WASM 1.0 Completeness (verified 2026-04-18)

### 18.1 Coverage summary

| Category | Implemented | WASM 1.0 Total | Coverage |
|---|---|---|---|
| Parametric (nop, unreachable, drop, select) | 4 | 4 | 100% |
| Control (block, loop, if, br, br_if, br_table, return) | 7 | 7 | 100% |
| Call (call, call_indirect) | 2 | 2 | 100% |
| Local variables (get, set, tee) | 3 | 3 | 100% |
| Global variables (get, set) | 2 | 2 | 100% |
| i32 numeric (const, arith, bitwise, cmp, unary) | 28 | 28 | 100% |
| i64 numeric (const, arith, bitwise, cmp, unary) | 28 | 28 | 100% |
| i32 memory (load, store, packed variants) | 7 | 7 | 100% |
| i64 memory (load, store, packed variants) | 9 | 9 | 100% |
| memory.size, memory.grow | 2 | 2 | 100% |
| Integer conversions (wrap, extend) | 3 | 3 | 100% |
| f32 numeric (arith, cmp, unary, copysign, trunc, nearest) | 29 | 29 | 100% |
| f64 numeric (arith, cmp, unary, copysign, trunc, nearest) | 29 | 29 | 100% |
| f32/f64 memory (load, store) | 4 | 4 | 100% |
| f32/f64 const | 2 | 2 | 100% |
| Float conversions (trunc, convert, demote, promote) | 18 | 18 | 100% |
| Float reinterpret | 4 | 4 | 100% |
| **TOTAL** | **170** | **170** | **100%** |

### 18.2 Previously missing 14 instructions — NOW COMPLETE (2026-04-20)

All 14 were implemented and certified with oracle-backed proofs:
```
f32.copysign     f64.copysign      — sign bit manipulation (inline rational)
f32.nearest      f64.nearest       — banker's rounding (inline ties-to-even)
f32.trunc        f64.trunc         — truncate to integer (CL truncate)
f32.reinterpret_i32                — via kestrel/floats/ieee-floats-as-bvs
f64.reinterpret_i64                — via kestrel/floats/ieee-floats-as-bvs
i32.reinterpret_f32                — via kestrel/floats/ieee-floats-as-bvs
i64.reinterpret_f64                — via kestrel/floats/ieee-floats-as-bvs
f32.load         f64.load          — IEEE 754 decode from memory bytes
f32.store        f64.store         — IEEE 754 encode to memory bytes
```

### 18.3 Kestrel IEEE 754 library — the solution (discovered 2026-04-19)

**`books/kestrel/floats/`** contains a certified IEEE 754 formalization by Eric Smith
that provides exactly what we need. All books certify in <4 seconds.

| Book | Lines | Key Functions | Status |
|---|---|---|---|
| `ieee-floats.lisp` | 1467 | `formatp`, `decode`, `encode`, `floating-point-datump`, special values (NaN, ±∞, ±0) | ✅ Certified |
| `ieee-floats-as-bvs.lisp` | 185 | `decode-bv-float32`, `decode-bv-float64`, `encode-bv-float`, roundtrip theorems | ✅ Certified |
| `round.lisp` | 809 | `round-to-nearest-integer-ties-to-even`, `round-rational-ties-to-even` | ✅ Certified |
| `ieee-floats-tests.lisp` | 34 | Exhaustive minifloat (4-bit) tests | ✅ Certified |
| `ieee-floats-validation.lisp` | 219 | Additional validation | ✅ Certified |

**Key proven theorems from the library:**
```lisp
;; Roundtrip: encode(decode(bv)) = bv  (for non-NaN)
(defthm encode-bv-float-of-decode-bv-float-when-not-nan ...)

;; Roundtrip: decode(encode(datum)) = datum
(defthm decode-bv-float-of-encode-bv-float ...)

;; Decoded non-special values are rational
(defthm rationalp-of-decode-bv-float32 ...)
```

**Integration verified (proof-ieee754-integration.lisp): 14 PASSED, 3 Q.E.D.**
- `decode-bv-float32(0x3F800000) = 1` (1.0f)
- `decode-bv-float32(0x3F000000) = 1/2` (0.5f)
- `decode-bv-float32(0xBF800000) = -1` (-1.0f)
- `encode-bv-float(32, 24, 1, nil) = 0x3F800000` (encode 1.0f)
- Roundtrip `i32 → f32 → i32` preserves bits for 1.0f, -2.0f, +∞
- Banker's rounding: `round-to-nearest-integer-ties-to-even(5/2) = 2`

### 18.4 Approach for completing float support using Kestrel library

Each of the 14 missing instructions maps directly to library functions:

| Missing Instruction | Implementation |
|---|---|
| `f32.reinterpret_i32` | `(decode-bv-float32 bits)` — decode i32 bit pattern as float |
| `i32.reinterpret_f32` | `(encode-bv-float 32 24 datum nil)` — encode float as i32 bits |
| `f64.reinterpret_i64` | `(decode-bv-float64 bits)` — decode i64 bit pattern as float |
| `i64.reinterpret_f64` | `(encode-bv-float 64 53 datum nil)` — encode float as i64 bits |
| `f32.copysign` | `(negate-floating-point-datum ...)` + sign extraction |
| `f64.copysign` | Same as f32.copysign with 64-bit format |
| `f32.nearest` | `(round-to-nearest-integer-ties-to-even x)` for the rational value |
| `f64.nearest` | Same as f32.nearest |
| `f32.trunc` | `(int-part x)` then round toward zero |
| `f64.trunc` | Same as f32.trunc |
| `f32.load` | `bytes-to-i32` (existing) → `decode-bv-float32` |
| `f64.load` | `bytes-to-i64` (existing) → `decode-bv-float64` |
| `f32.store` | `encode-bv-float` → `i32-to-bytes` (existing) |
| `f64.store` | `encode-bv-float` → `i64-to-bytes` (existing) |

**The `include-book` is:**
```lisp
(include-book "kestrel/floats/ieee-floats-as-bvs" :dir :system)
(include-book "kestrel/floats/round" :dir :system)
```

### 18.4.1 Other IEEE 754 libraries in ACL2 (for reference)

- **`books/rtl/rel11/`** — Russinoff's RTL library. Comprehensive theory for hardware FPU
  verification (AMD/Intel). Uses RTL package. More mature but harder to integrate with
  our WASM model. Provides `rnd`, `rtz`, `raz` rounding modes.

- **`books/centaur/lispfloat/`** — Centaur's Lisp float wrapper. Uses constrained functions
  backed by Common Lisp floats. Not useful for logical proofs (no definition in logic).

- **`books/kestrel/jvm/float-to-bits.lisp`** — JVM-specific float-to-bits conversion.
  Experimental/draft status. Uses RTL `expo`/`sig` functions.

- **`books/kestrel/x86/floats.lisp`** — x86-specific float rules. Depends on x86isa project.
  Not suitable for standalone WASM use.

### 18.5 SpecTec reduction rules covered

All 57 reduction rules from `8-reduction.spectec` are covered:

| Rule | Status | Notes |
|---|---|---|
| Step/pure, Step/read, Steps/refl, Steps/trans | ✅ | Via `run` step function |
| Eval_expr | ✅ | Via `run` returning final state |
| Step_pure/unreachable | ✅ | Returns `:trap` |
| Step_pure/nop | ✅ | No-op |
| Step_pure/drop | ✅ | Pop operand |
| Step_pure/select-true, select-false | ✅ | Condition-based select |
| Step_read/block, loop | ✅ | Label stack model |
| Step_pure/if-true, if-false | ✅ | Branch to then/else |
| Step_pure/label-vals | ✅ | Label completion |
| Step_pure/br-zero, br-succ | ✅ | Branch with label depth |
| Step_pure/br_if-true, br_if-false | ✅ | Conditional branch |
| Step_pure/br_table-lt, br_table-ge | ✅ | Table branch |
| Step_read/call, call_indirect-call, call_indirect-trap | ✅ | Function calls |
| Step_read/call_addr | ✅ | Frame creation |
| Step_pure/frame-vals | ✅ | Frame completion |
| Step_pure/return-frame, return-label | ✅ | Return from function |
| Step_pure/trap-vals, trap-label, trap-frame | ✅ | Trap propagation |
| Step/ctxt-label, ctxt-frame | ✅ | Context reduction |
| Step_pure/unop-val, unop-trap | ✅ | Unary operations |
| Step_pure/binop-val, binop-trap | ✅ | Binary operations (traps for div/rem by 0) |
| Step_pure/testop | ✅ | Test operations (eqz) |
| Step_pure/relop | ✅ | Relational operations |
| Step_pure/cvtop-val, cvtop-trap | ✅ | Conversion operations |
| Step_read/local.get, Step/local.set, Step_pure/local.tee | ✅ | Local variables |
| Step_read/global.get, Step/global.set | ✅ | Global variables |
| Step_read/load-num-val, load-num-trap | ✅ | Memory load |
| Step_read/load-pack-val, load-pack-trap | ✅ | Packed memory load |
| Step/store-num-val, store-num-trap | ✅ | Memory store |
| Step/store-pack-val, store-pack-trap | ✅ | Packed memory store |
| Step_read/memory.size | ✅ | Memory size |
| Step/memory.grow-succeed, memory.grow-fail | ✅ | Memory growth |

### 18.6 Verification results snapshot (2026-04-20)

```
=== TESTS (13/13 pass, 256 assertions) ===
  ✅ test-m1-instructions:   18 PASSED
  ✅ test-m2-control-flow:    8 PASSED
  ✅ test-m3-functions:       6 PASSED
  ✅ test-m4-memory:          8 PASSED
  ✅ test-m5-i64:            22 PASSED
  ✅ test-m5b-globals:        7 PASSED
  ✅ test-m7a-floats:        35 PASSED  (updated: IEEE 754 div, 3 new NaN/Inf tests)
  ✅ test-m7b-tables:         7 PASSED
  ✅ test-m9-validation:     70 PASSED
  ✅ test-m12-nan:           28 PASSED  (NEW: NaN propagation + Inf semantics)
  ✅ test-packed-mem-i64:    16 PASSED
  ✅ test-packed-mem:        11 PASSED
  ✅ test-spot-check:        19 PASSED

=== PROOFS (20/20 pass, 150 Q.E.D.s) ===
  ✅ proof-abs-e2e:              10 Q.E.D. (end-to-end abs function)
  ✅ proof-add-spec:              2 Q.E.D. (i32.add specification)
  ✅ proof-bitwise:               6 Q.E.D. (and/or/xor/shifts)
  ✅ proof-block-br-spec:         4 Q.E.D. (block + branch)
  ✅ proof-call-indirect-spec:    6 Q.E.D. (indirect calls)
  ✅ proof-float-spec:            6 Q.E.D. (f64/f32 arithmetic specs)
  ✅ proof-global-spec:           4 Q.E.D. (global roundtrip)
  ✅ proof-i64-conv-spec:        10 Q.E.D. (i64 conversions)
  ✅ proof-ieee754-integration:   3 Q.E.D. (Kestrel ieee-floats-as-bvs)
  ✅ proof-local-drop-spec:       6 Q.E.D. (local set/tee/drop)
  ✅ proof-loop-spec:             6 Q.E.D. (loop exit + multi-iteration)
  ✅ proof-m11-float-ops:        14 Q.E.D. (trunc/nearest/copysign/reinterpret)
  ✅ proof-max-if-else:           6 Q.E.D. (if/else max)
  ✅ proof-mem-roundtrip:         9 Q.E.D. (memory store→load)
  ✅ proof-mul-eqz-spec:          8 Q.E.D. (mul + eqz)
  ✅ proof-nan-propagation:      20 Q.E.D. (NEW: 10 NaN theorems)
  ✅ proof-select-spec:           4 Q.E.D. (select instruction)
  ✅ proof-sub-spec:              6 Q.E.D. (sub + algebraic identities)
  ✅ proof-trap-misc-spec:        8 Q.E.D. (trap propagation)
  ✅ proof-validation-soundness: 12 Q.E.D. (type checker correctness)
```

### 18.7 NaN/Inf Propagation Design (M12, 2026-04-20)

**Representation**: NaN and ±Infinity are bare keyword atoms on the operand stack:
- `f32`: `:f32.nan`, `:f32.+inf`, `:f32.-inf`
- `f64`: `:f64.nan`, `:f64.+inf`, `:f64.-inf`

These are NOT `(:f32.const ...)` lists — they're atoms. This keeps `f32-valp` restricted
to rationals (no disruption to existing proofs) while allowing special values in `valp`.

**Key predicate**: `(float-specialp v)` — recognizes all 6 special atoms. `valp` extended
to include `float-specialp` so NaN/Inf values can live on the operand stack.

**Propagation rules** (verified by Node.js oracle):
```
NaN + x = NaN         (all binops)
NaN == NaN = 0        (ordered comparisons: false)
NaN != NaN = 1        (ne: true — NaN is not-equal to everything)
0/0 = NaN             5/0 = +Inf    -5/0 = -Inf
sqrt(-1) = NaN        neg(NaN) = NaN    abs(-Inf) = +Inf
```

**Macro pattern** for NaN-aware binops (in `def-f32-binop`):
```lisp
;; Check NaN BEFORE f32-valp (NaN atoms fail f32-valp)
((when (or (eq arg1 :f32.nan) (eq arg2 :f32.nan)))
 (let* ((ostack (push-operand :f32.nan (pop-operand (pop-operand ostack))))
        (state (update-current-operand-stack ostack state)))
   (advance-instrs state)))
((when (not (and (f32-valp arg1) (f32-valp arg2)))) :trap)
```

**ne macro parameter**: `(def-f32-cmpop execute-f32.ne (...) :nan-result 1)` — uses
`&key (nan-result 0)` to distinguish ne (returns 1 for NaN) from other comparisons.

**Formal theorems** (`proofs/proof-nan-propagation.lisp`):
1. `f32-nan-propagates-add`:   `f32-valp x → f32.add(NaN, x) = NaN`
2. `f32-nan-propagates-mul`:   `f32-valp x → f32.mul(NaN, x) = NaN`
3. `f32-nan-propagates-sub`:   `f32-valp x → f32.sub(NaN, x) = NaN`
4. `f32-eq-nan-is-zero`:       `f32.eq(NaN, NaN) = 0`
5. `f32-ne-nan-is-one`:        `f32.ne(NaN, NaN) = 1`
6. `f32-lt-nan-is-zero`:       `f32-valp x → f32.lt(NaN, x) = 0`
7. `f64-nan-propagates-add`:   `f64-valp x → f64.add(NaN, x) = NaN`
8. `f64-nan-propagates-mul`:   `f64-valp x → f64.mul(NaN, x) = NaN`
9. `f32-zero-div-zero-is-nan`: `f32.div(0, 0) = NaN`
10. `f32-pos-div-zero-is-inf`:  `rationalp x ∧ x>0 → f32.div(x, 0) = +Inf`

### 18.8 Recommendations for Kestrel collaboration

1. **The full WASM 1.0 semantics are complete with NaN propagation.** 170/170 instructions certify, all reduction rules are covered, 150 theorems pass across 20 proof files. NaN propagates correctly through all float operations per IEEE 754.

2. **NaN propagation is implemented.** The `float-specialp` predicate + keyword atoms approach cleanly extends the rational model without breaking existing proofs.

3. **The `execution.lisp` is designed as a drop-in replacement for Kestrel's skeleton.** It uses the same package, defaggregate types, and include-book structure. The upgrade path is: replace `books/kestrel/wasm/execution.lisp` with our version.

4. **Guard verification is deferred** (`:verify-guards nil`). Full guard verification would strengthen the formalization but isn't required for proof use.

5. **Module instantiation is not yet modeled.** The current model takes pre-decoded instruction lists; it doesn't handle the WASM binary module format or the instantiation algorithm (linking, start function, etc.). Kestrel's `parse-binary.lisp` handles the parsing side.

---

## §19 Proof Techniques Catalog (added 2026-04-20)

### 19.1 Concrete oracle tests (Level 1)

Pattern: compute oracle value from V8/Node.js, embed as `defthm`:
```lisp
(defthm i32-div-s-overflow-traps
  (equal (run 3 (mk (list (list :i32.const 2147483648)
                           (list :i32.const 4294967295)
                           '(:i32.div_s))))
         :trap)
  :hints (("Goal" :in-theory (enable . #.*edge-theory*))))
```
Key: ACL2 fully evaluates ground terms. No symbolic reasoning needed.
This is the cheapest type of proof and catches most bugs.

### 19.2 Symbolic universal proofs (Level 3)

Pattern: prove `∀x. property(x)`:
```lisp
(defthm i32-div-s-any-by-zero-traps
  (implies (u32p x)
           (equal (run 3 (mk (list (list :i32.const x) '(:i32.const 0) '(:i32.div_s))))
                  :trap))
  :hints (("Goal" :in-theory (enable . #.*edge-theory*)
                  :expand ((:free (n s) (run n s))))))
```

**Critical lesson**: `execute-instr` has 170+ cases in a `cond`. When `run` needs
to dispatch on a concrete opcode (`:i32.div_s`) but with a symbolic state, the
prover may not open `run` automatically. Solution: **`:expand ((:free (n s) (run n s)))`**
forces `run` to unfold at every call site.

### 19.3 Theory management for large case dispatches

Problem: `execute-instr` is a huge `cond` with 170 arms. Enabling it naively causes
exponential case splitting on symbolic states.

Solution: Use a curated theory constant:
```lisp
(defconst *edge-theory*
  '(mk run step execute-instr
    execute-i32.const execute-i32.div_s ...
    ;; Include ALL accessor/constructor functions
    current-frame current-instrs current-operand-stack ...))
```

**Gotcha**: Never include macros (e.g., `farg1`) in enable lists. ACL2 gives a
cryptic "theory expression could not be evaluated" error. `farg1` is a macro
for `cadr`; it expands automatically without being in the theory.

### 19.4 BV library lemmas for arithmetic properties

Problem: `bvminus(x, x) = 0` doesn't simplify automatically.

Solution: Enable BV internals:
```lisp
:hints (("Goal" :in-theory (enable acl2::bvminus acl2::bvplus
                                    acl2::bvuminus acl2::bvchop
                                    . #.*alg-theory*)))
```

For rotation identity (`rotl(x, 0) = x`), the implementation uses `(logior (ash x 0) (ash x -32))`.
ACL2 doesn't know `ash(x, -32) = 0` for u32 x. Solution:
```lisp
(local (include-book "arithmetic-5/top" :dir :system))
(defthm ash-neg32-of-u32
  (implies (unsigned-byte-p 32 x)
           (equal (ash x -32) 0)))
```

### 19.5 Proof file structure pattern

Every proof book in `proofs/` follows this skeleton:
```lisp
(in-package "WASM")
(include-book "../execution")

;; State constructors (defund mk ...)
;; Theory constant (local (defconst *my-theory* '(...)))
;; Helper lemmas (local include-books, defthms)
;; Main theorems
```
The `WASM` package is loaded by `proofs/cert.acl2` \u2014 no `(ld package.lsp)` or
`(set-guard-checking ...)` is needed (nor permitted at top level of a certified book).

### 19.6 Algebraic instruction properties catalog

Proved symbolic properties (all ∀x,y ∈ u32):

| Category | Property | Theorem name |
|----------|----------|--------------|
| Add | add(x,0)=x, add(0,x)=x | i32-add-right/left-identity |
| Sub | sub(x,0)=x, sub(x,x)=0 | i32-sub-right-identity, i32-sub-self-is-zero |
| Mul | mul(x,1)=x, mul(1,x)=x, mul(x,0)=0 | i32-mul-right/left-identity, i32-mul-zero-annihilates |
| And | and(x,0)=0, and(x,MAX)=x | i32-and-zero-annihilates, i32-and-all-ones-identity |
| Or | or(x,0)=x, or(x,MAX)=MAX | i32-or-identity, i32-or-all-ones-absorbs |
| Xor | xor(x,0)=x, xor(x,x)=0 | i32-xor-identity, i32-xor-self-annihilates |
| Shift | shl(x,0)=x, shr_u(x,0)=x | i32-shl/shr-u-zero-identity |
| Rotate | rotl(x,0)=x | i32-rotl-zero-identity |
| Compare | eq(x,x)=1, ne(x,x)=0 | i32-eq-reflexive, i32-ne-anti-reflexive |
| Compare | le_u(x,x)=1, ge_u(x,x)=1 | i32-le/ge-u-reflexive |
| Compare | lt_u(x,x)=0, gt_u(x,x)=0 | i32-lt/gt-u-irreflexive |
| Compare | le_s(x,x)=1, ge_s(x,x)=1 | i32-le/ge-s-reflexive |

### 19.7 Trap correctness catalog

| Input | Expected | Proved |
|-------|----------|--------|
| div_s(MIN,-1) | trap | ✅ concrete |
| div_s(x,0) ∀x | trap | ✅ symbolic |
| div_u(x,0) ∀x | trap | ✅ symbolic |
| rem_s(x,0) ∀x | trap | ✅ symbolic |
| rem_u(x,0) ∀x | trap | ✅ symbolic |
| rem_s(MIN,-1) | 0 (NOT trap) | ✅ concrete |
| div_s(-7,2) | -3 (truncate toward zero) | ✅ concrete |
| rem_s(-7,2) | -1 (sign follows dividend) | ✅ concrete |

---

## §20. IEEE 754 Signed Zero (M13, 2026-04-20)

### 20.1 Representation

Four new float-specialp atoms extending the existing NaN/Inf atoms:

| Atom | Meaning | IEEE 754 sign bit |
|------|---------|-------------------|
| `:f32.+0` | f32 positive zero | 0 |
| `:f32.-0` | f32 negative zero | 1 |
| `:f64.+0` | f64 positive zero | 0 |
| `:f64.-0` | f64 negative zero | 1 |

Regular `(:f32.const 0)` (rational 0) is **positive zero** in arithmetic context.
`f32.neg((:f32.const 0)) = :f32.-0` (detected via `(= (farg1 arg) 0)` check).

### 20.2 Operations with ±0

| Operation | Input | Result |
|-----------|-------|--------|
| `f32.neg` | `+0` (rational or :f32.+0) | `:f32.-0` |
| `f32.neg` | `:f32.-0` | `:f32.+0` |
| `f32.abs` | `±0` | `:f32.+0` |
| `f32.eq`  | `+0, -0` | `1` (they compare equal) |
| `f32.ne`  | `+0, -0` | `0` |
| `f32.lt`  | `+0, -0` | `0` |
| `f32.div` | `x > 0, +0` | `:f32.+inf` |
| `f32.div` | `x > 0, -0` | `:f32.-inf` |
| `f32.div` | `x < 0, -0` | `:f32.+inf` |
| `f32.copysign` | `x, -0` | negative `|x|` |
| `f32.copysign` | `x, +0` | positive `|x|` |
| `f32.add/sub/mul` | `±0, ±0` | rational `0` (sign lost) |

### 20.3 Implementation Pattern

**Macros** (`def-f32-binop`, `def-f32-cmpop` etc.) extended to accept ±0 as rational 0:
```lisp
;; Accept finite f32-valp or signed zeros (±0 treated as rational 0)
((when (not (and (or (f32-valp arg1) (eq arg1 :f32.+0) (eq arg1 :f32.-0))
                 (or (f32-valp arg2) (eq arg2 :f32.+0) (eq arg2 :f32.-0))))) :trap)
(v1 (if (f32-valp arg1) (farg1 arg1) 0))
(v2 (if (f32-valp arg2) (farg1 arg2) 0))
```

**Sign helpers**: `f32-sign-negativep` / `f64-sign-negativep`:
```lisp
(defun f32-sign-negativep (arg)
  (or (eq arg :f32.-0) (eq arg :f32.-inf)
      (and (f32-valp arg) (< (farg1 arg) 0))))
```

### 20.4 Proof Techniques

All signed-zero theorems are concrete evaluations:
```lisp
(defthm f32-pos-neg-zero-eq
  (equal (sz-top 4 (list '(:f32.const 0) '(:f32.const 0) '(:f32.neg) '(:f32.eq)))
         (make-i32-val 1))
  :hints (("Goal" :in-theory (enable . #.*sz-theory*)
                  :expand ((:free (n s) (run n s))))))
```

For theorems about pre-loaded special atoms, use pre-populated operand stacks:
```lisp
;; Test neg(:f32.-0) = :f32.+0
(run 1 (make-state
        :call-stack (list (make-frame ... :operand-stack (list :f32.-0)
                                         :instrs (list '(:f32.neg)) ...))
        ...))
```

### 20.5 Proof Summary

| File | Theorems | Content |
|------|----------|---------|
| `proof-signed-zero.lisp` | 11 | neg/abs/eq/ne/lt/div signed zero facts |
| `proof-commutativity.lisp` | 10 | i32/i64 add/mul/and/or/xor commutativity |
| `proof-associativity.lisp` | 10 | i32/i64 add/mul/and/or/xor associativity |
| `proof-i64-algebraic.lisp` | 25 | i64 identity/annihilator/cmp/shift laws |

### 20.6 Known Limitation

Arithmetic operations (`add`, `sub`, `mul`) with ±0 inputs produce rational 0, losing
the sign of zero. Per WASM 1.0 spec §3.3.1, operations like `(-0) × (+1)` should
produce `-0`; our model gives `+0`. Only `neg`, `abs`, `copysign`, and `div` handle
signed zero sign propagation correctly. This is documented in `WASM1_PLAN.md §11.2`.


---

## §21 IEEE 754 Inf Arithmetic (M14)

### 21.1 Atoms and Recognition

Six new `float-specialp` atoms added in M14 (same as M12, but now used in arithmetic):
- `:f32.+inf`, `:f32.-inf`  — positive/negative infinity for f32
- `:f64.+inf`, `:f64.-inf`  — positive/negative infinity for f64

Helper predicates (defined before the arithmetic section):
```lisp
(defun f32-infp (v) (or (eq v :f32.+inf) (eq v :f32.-inf)))
(defun f64-infp (v) (or (eq v :f64.+inf) (eq v :f64.-inf)))
(defun f32-zerovalp (v) (or (eq v :f32.+0) (eq v :f32.-0) (and (f32-valp v) (= (farg1 v) 0))))
(defun f32-sign-negativep (arg)  ; defined early (before f32 arithmetic)
  (or (eq arg :f32.-0) (eq arg :f32.-inf) (and (f32-valp arg) (< (farg1 arg) 0))))
```

**CRITICAL**: `f32-sign-negativep` and `f64-sign-negativep` must be defined BEFORE the
f32/f64 arithmetic section (they're used by `f32-inf-mul`, `execute-f32.div`, etc.).
In the original M13 code they were in the copysign section — M14 moved them earlier.

### 21.2 Inf Rules (IEEE 754)

| Expression | Result | Rule |
|-----------|--------|------|
| `+Inf + +Inf` | `+Inf` | Same-sign infinities add |
| `+Inf + -Inf` | `NaN` | Opposite-sign cancel |
| `x + ±Inf`   | `±Inf` | Infinity absorbs finite |
| `+Inf - +Inf` | `NaN`  | Inf minus itself |
| `+Inf - -Inf` | `+Inf` | Inf minus neg-inf |
| `±Inf × 0`   | `NaN`  | Indeterminate form |
| `±Inf × ±Inf`| `±Inf` | Sign = product of signs |
| `±Inf × nonzero` | `±Inf` | Sign = product |
| `±Inf / ±Inf`| `NaN`  | Indeterminate |
| `±Inf / finite`| `±Inf`| Sign preserved/flipped |
| `finite / ±Inf`| `±0` | Shrinks to zero |
| `min(-Inf, x)` | `-Inf` | −Inf is global min |
| `max(+Inf, x)` | `+Inf` | +Inf is global max |

### 21.3 Implementation Pattern

The `def-f32-binop-inf` macro wraps a binary op with NaN-propagation then
Inf-dispatch, then falls through to finite arithmetic:

```lisp
(defmacro def-f32-binop-inf (fn-name finite-expr inf-fn)
  `(defun ,fn-name (state)
     (declare (xargs :guard (statep state) :verify-guards nil))
     (b* ((ostack (current-operand-stack state))
          ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
          (arg2 (top-operand ostack))
          (arg1 (top-operand (pop-operand ostack)))
          ;; 1. NaN propagates
          ((when (or (eq arg1 :f32.nan) (eq arg2 :f32.nan)))
           (let* ((ostack (push-operand :f32.nan ...))) (advance-instrs state)))
          ;; 2. Inf dispatch
          ((when (or (f32-infp arg1) (f32-infp arg2)))
           (let* ((result (,inf-fn arg1 arg2))
                  (ostack (push-operand result ...))) (advance-instrs state)))
          ;; 3. ±0 dispatch
          ((when (or (f32-zerovalp arg1) (f32-zerovalp arg2)))
           ...)
          ;; 4. Finite arithmetic
          ((when (not (and (f32-valp arg1) (f32-valp arg2)))) :trap)
          (v1 (farg1 arg1)) (v2 (farg1 arg2))
          (result (make-f32-val ,finite-expr)) ...)
       (advance-instrs state))))
```

### 21.4 Inf helper functions

```lisp
;; add: +Inf + -Inf = NaN; same-sign add = that Inf; finite + ±Inf = ±Inf
(defun f32-inf-add (a b) ...)

;; sub: rearranges to add(a, flip(b))
(defun f32-flip-inf (v) (if (eq v :f32.+inf) :f32.-inf :f32.+inf))
(defun f32-inf-sub (a b) (f32-inf-add a (f32-flip-inf b)))

;; mul: ±Inf × 0 = NaN; sign = XOR of signs
(defun f32-inf-mul (a b)
  (if (or (f32-zerovalp a) (f32-zerovalp b)) :f32.nan
    (if (not (eq (f32-sign-negativep a) (f32-sign-negativep b))) :f32.-inf :f32.+inf)))

;; min/max: -Inf always wins min; +Inf always wins max
(defun f32-inf-min (a b) (if (eq a :f32.-inf) :f32.-inf (if (eq b :f32.-inf) :f32.-inf a)))
(defun f32-inf-max (a b) (if (eq a :f32.+inf) :f32.+inf (if (eq b :f32.+inf) :f32.+inf a)))
```

### 21.5 Testing Inf Arithmetic

Use pre-populated operand stacks for Inf atom tests (atoms can't be emitted
by `:f32.const`):
```lisp
(defun ia-make-state (arg1 arg2 instr)
  (make-state
   :call-stack (list (make-frame ... :operand-stack (list arg2 arg1)
                                     :instrs (list instr) ...)) ...))

(defun ia-top (arg1 arg2 instr)
  (top-operand (current-operand-stack (step (ia-make-state arg1 arg2 instr)))))

;; Stack ordering: arg2 = top (popped first), arg1 = below
;; ia-top(a, b, op) computes op(a, b)
```

### 21.6 Distributivity + Shift Laws

`proof-distributivity.lisp` proves BV-arithmetic identities:
- `bvmult 32 (bvplus 32 a b) c = bvplus 32 (bvmult 32 a c) (bvmult 32 b c)`
- Same for `bvminus`, same for 64-bit
- `bvshl 32 x k = bvmult 32 x (2^k)` for k ∈ {1,2,3}

Proof strategy: enable `acl2::bvmult`, `acl2::bvplus`, `acl2::bvminus`, `acl2::bvchop`
and let `arithmetic-5` reduce the modular arithmetic. Needs:
```lisp
(local (include-book "kestrel/bv/rules" :dir :system))
(local (include-book "arithmetic-5/top" :dir :system))
```

**Note**: Multi-step WASM execution proofs for distributivity (5–7 steps involving `mul`)
are too slow for ACL2 to discharge automatically. Prove at the BV level instead.
