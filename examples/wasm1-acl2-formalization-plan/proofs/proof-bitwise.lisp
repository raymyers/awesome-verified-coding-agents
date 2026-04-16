;; WASM 1.0 ACL2 Formalization — Bitwise Property Proofs
;;
;; Theorems proved (at WASM instruction level):
;;   1. i32-xor-self-zero: x XOR x = 0
;;   2. i32-and-idempotent: x AND x = x
;;   3. i32-or-zero-identity: x OR 0 = x
;;
;; These lift BV library theorems (bvxor-same, bvand-same, bvor-of-0-arg3)
;; to the WASM instruction execution level, proving semantic correctness.

(in-package "ACL2")
(ld "/tmp/acl2-full/books/kestrel/wasm/package.lsp")
(in-package "WASM")
(include-book "kestrel/wasm/execution" :dir :system)

;;; Common theory for WASM instruction unfolding
(defconst *wasm-binop-theory*
  '(run execute-instr execute-i32.const
    execute-i32.xor execute-i32.and execute-i32.or
    current-frame current-instrs current-operand-stack
    current-label-stack current-locals
    update-current-operand-stack update-current-instrs
    complete-label return-from-function
    make-i32-val i32-valp i32-const-argsp no-argsp instrp
    push-operand top-operand pop-operand top-n-operands
    operand-stack-height empty-operand-stack operand-stackp
    localsp framep top-frame push-call-stack pop-call-stack
    call-stackp valp i64-valp u32p u64p
    farg1))

;;; Helper: make a standard 3-instruction WASM state
(defun make-binop-state (a b op)
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

;;; Theorem 1: i32.xor(x, x) = 0
;;; WASM semantics: (i32.const x) (i32.const x) (i32.xor) → (i32.const 0)
(defthm i32-xor-self-zero
  (implies (unsigned-byte-p 32 x)
           (equal
            (top-operand
             (current-operand-stack
              (run 3 (make-binop-state x x :i32.xor))))
            (make-i32-val 0)))
  :hints (("Goal" :in-theory (enable run execute-instr execute-i32.const
                                     execute-i32.xor current-frame
                                     current-instrs current-operand-stack
                                     current-label-stack current-locals
                                     update-current-operand-stack
                                     update-current-instrs
                                     complete-label return-from-function
                                     make-i32-val i32-valp i32-const-argsp
                                     no-argsp instrp
                                     push-operand top-operand pop-operand
                                     top-n-operands
                                     operand-stack-height
                                     empty-operand-stack operand-stackp
                                     localsp framep
                                     top-frame push-call-stack pop-call-stack
                                     call-stackp
                                     valp i64-valp u32p u64p)
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))))))

;;; Theorem 2: i32.and(x, x) = x
;;; WASM semantics: (i32.const x) (i32.const x) (i32.and) → (i32.const x)
(defthm i32-and-idempotent
  (implies (unsigned-byte-p 32 x)
           (equal
            (top-operand
             (current-operand-stack
              (run 3 (make-binop-state x x :i32.and))))
            (make-i32-val x)))
  :hints (("Goal" :in-theory (enable run execute-instr execute-i32.const
                                     execute-i32.and current-frame
                                     current-instrs current-operand-stack
                                     current-label-stack current-locals
                                     update-current-operand-stack
                                     update-current-instrs
                                     complete-label return-from-function
                                     make-i32-val i32-valp i32-const-argsp
                                     no-argsp instrp
                                     push-operand top-operand pop-operand
                                     top-n-operands
                                     operand-stack-height
                                     empty-operand-stack operand-stackp
                                     localsp framep
                                     top-frame push-call-stack pop-call-stack
                                     call-stackp
                                     valp i64-valp u32p u64p)
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))))))

;;; Theorem 3: i32.or(x, 0) = x
;;; WASM semantics: (i32.const x) (i32.const 0) (i32.or) → (i32.const x)
(defthm i32-or-zero-identity
  (implies (unsigned-byte-p 32 x)
           (equal
            (top-operand
             (current-operand-stack
              (run 3 (make-binop-state x 0 :i32.or))))
            (make-i32-val x)))
  :hints (("Goal" :in-theory (enable run execute-instr execute-i32.const
                                     execute-i32.or current-frame
                                     current-instrs current-operand-stack
                                     current-label-stack current-locals
                                     update-current-operand-stack
                                     update-current-instrs
                                     complete-label return-from-function
                                     make-i32-val i32-valp i32-const-argsp
                                     no-argsp instrp
                                     push-operand top-operand pop-operand
                                     top-n-operands
                                     operand-stack-height
                                     empty-operand-stack operand-stackp
                                     localsp framep
                                     top-frame push-call-stack pop-call-stack
                                     call-stackp
                                     valp i64-valp u32p u64p)
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))))))

(cw "~%=== ALL BITWISE PROPERTY PROOFS PASSED ===~%")
(cw "  - i32-xor-self-zero: Q.E.D.~%")
(cw "  - i32-and-idempotent: Q.E.D.~%")
(cw "  - i32-or-zero-identity: Q.E.D.~%")
