;; WASM 1.0 ACL2 — Commutativity Theorems
;;
;; Symbolic proofs that commutative WASM operations produce identical
;; results regardless of argument order at the operand-stack level.
;;
;; For each op, we prove:
;;   ∀ a,b ∈ uNp.  run(... a b op ...) = run(... b a op ...)
;;
;; This lifts BV-library commutativity (bvplus, bvmult, bvand, bvor, bvxor)
;; to the full WASM execution model, establishing that the formalization
;; respects the algebraic symmetry guaranteed by the WASM 1.0 spec.

(in-package "ACL2")
(ld "/tmp/acl2-full/books/kestrel/wasm/package.lsp")
(in-package "WASM")
(include-book "kestrel/wasm/execution" :dir :system)

(set-guard-checking :none)

;; ─── Re-use helpers from proof-algebraic-properties.lisp ─────────────────────
;;     (duplicated here so this file loads standalone)

(defund cm-binop32 (a b op)
  (declare (xargs :guard t :verify-guards nil))
  (make-state
   :store nil
   :call-stack (list (make-frame
                      :return-arity 1
                      :locals nil
                      :operand-stack (empty-operand-stack)
                      :instrs (list (list :i32.const a)
                                    (list :i32.const b)
                                    (list op))
                      :label-stack nil))
   :memory nil
   :globals nil))

(defund cm-binop64 (a b op)
  (declare (xargs :guard t :verify-guards nil))
  (make-state
   :store nil
   :call-stack (list (make-frame
                      :return-arity 1
                      :locals nil
                      :operand-stack (empty-operand-stack)
                      :instrs (list (list :i64.const a)
                                    (list :i64.const b)
                                    (list op))
                      :label-stack nil))
   :memory nil
   :globals nil))

(defund cm-result32 (n s)
  (declare (xargs :guard t :verify-guards nil))
  (top-operand (current-operand-stack (run n s))))

(defund cm-result64 (n s)
  (declare (xargs :guard t :verify-guards nil))
  (top-operand (current-operand-stack (run n s))))

;; ─── Shared theory constants ──────────────────────────────────────────────────

(defconst *cm32-theory*
  '(cm-binop32 cm-result32
    run step execute-instr
    execute-i32.const execute-i32.add execute-i32.mul
    execute-i32.and execute-i32.or execute-i32.xor
    current-frame current-instrs current-operand-stack
    current-label-stack current-locals
    update-current-operand-stack update-current-instrs
    complete-label return-from-function
    make-i32-val i32-valp i32-const-argsp no-argsp
    i64-valp f32-valp f64-valp
    push-operand top-operand pop-operand top-n-operands push-vals
    operand-stack-height empty-operand-stack operand-stackp
    localsp framep top-frame push-call-stack pop-call-stack call-stackp
    valp u32p u64p))

(defconst *cm64-theory*
  '(cm-binop64 cm-result64
    run step execute-instr
    execute-i64.const execute-i64.add execute-i64.mul
    execute-i64.and execute-i64.or execute-i64.xor
    current-frame current-instrs current-operand-stack
    current-label-stack current-locals
    update-current-operand-stack update-current-instrs
    complete-label return-from-function
    make-i64-val i64-valp i64-const-argsp no-argsp
    i32-valp f32-valp f64-valp
    push-operand top-operand pop-operand top-n-operands push-vals
    operand-stack-height empty-operand-stack operand-stackp
    localsp framep top-frame push-call-stack pop-call-stack call-stackp
    valp u32p u64p))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §1. i32 COMMUTATIVITY

;; i32.add(a, b) = i32.add(b, a)
(defthm i32-add-commutes
  (implies (and (u32p a) (u32p b))
           (equal (cm-result32 3 (cm-binop32 a b :i32.add))
                  (cm-result32 3 (cm-binop32 b a :i32.add))))
  :hints (("Goal" :in-theory (enable . #.*cm32-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i32.mul(a, b) = i32.mul(b, a)
(defthm i32-mul-commutes
  (implies (and (u32p a) (u32p b))
           (equal (cm-result32 3 (cm-binop32 a b :i32.mul))
                  (cm-result32 3 (cm-binop32 b a :i32.mul))))
  :hints (("Goal" :in-theory (enable . #.*cm32-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i32.and(a, b) = i32.and(b, a)
(defthm i32-and-commutes
  (implies (and (u32p a) (u32p b))
           (equal (cm-result32 3 (cm-binop32 a b :i32.and))
                  (cm-result32 3 (cm-binop32 b a :i32.and))))
  :hints (("Goal" :in-theory (enable . #.*cm32-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i32.or(a, b) = i32.or(b, a)
(defthm i32-or-commutes
  (implies (and (u32p a) (u32p b))
           (equal (cm-result32 3 (cm-binop32 a b :i32.or))
                  (cm-result32 3 (cm-binop32 b a :i32.or))))
  :hints (("Goal" :in-theory (enable . #.*cm32-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i32.xor(a, b) = i32.xor(b, a)
(defthm i32-xor-commutes
  (implies (and (u32p a) (u32p b))
           (equal (cm-result32 3 (cm-binop32 a b :i32.xor))
                  (cm-result32 3 (cm-binop32 b a :i32.xor))))
  :hints (("Goal" :in-theory (enable . #.*cm32-theory*)
                  :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §2. i64 COMMUTATIVITY

;; i64.add(a, b) = i64.add(b, a)
(defthm i64-add-commutes
  (implies (and (u64p a) (u64p b))
           (equal (cm-result64 3 (cm-binop64 a b :i64.add))
                  (cm-result64 3 (cm-binop64 b a :i64.add))))
  :hints (("Goal" :in-theory (enable . #.*cm64-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i64.mul(a, b) = i64.mul(b, a)
(defthm i64-mul-commutes
  (implies (and (u64p a) (u64p b))
           (equal (cm-result64 3 (cm-binop64 a b :i64.mul))
                  (cm-result64 3 (cm-binop64 b a :i64.mul))))
  :hints (("Goal" :in-theory (enable . #.*cm64-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i64.and(a, b) = i64.and(b, a)
(defthm i64-and-commutes
  (implies (and (u64p a) (u64p b))
           (equal (cm-result64 3 (cm-binop64 a b :i64.and))
                  (cm-result64 3 (cm-binop64 b a :i64.and))))
  :hints (("Goal" :in-theory (enable . #.*cm64-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i64.or(a, b) = i64.or(b, a)
(defthm i64-or-commutes
  (implies (and (u64p a) (u64p b))
           (equal (cm-result64 3 (cm-binop64 a b :i64.or))
                  (cm-result64 3 (cm-binop64 b a :i64.or))))
  :hints (("Goal" :in-theory (enable . #.*cm64-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i64.xor(a, b) = i64.xor(b, a)
(defthm i64-xor-commutes
  (implies (and (u64p a) (u64p b))
           (equal (cm-result64 3 (cm-binop64 a b :i64.xor))
                  (cm-result64 3 (cm-binop64 b a :i64.xor))))
  :hints (("Goal" :in-theory (enable . #.*cm64-theory*)
                  :expand ((:free (n s) (run n s))))))
