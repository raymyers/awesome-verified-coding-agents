;; WASM 1.0 ACL2 Formalization — Proof Milestone
;; Theorem: specification of i32.add instruction sequence
;;
;; We prove that executing (i32.const a) (i32.const b) (i32.add)
;; in a well-formed state produces the expected i32 result on the stack.
;;
;; This demonstrates: (1) the ACL2 proof approach works on our model,
;; (2) instruction composition is correct, (3) BV library integration.

(in-package "WASM")
(include-book "../execution")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 1: i32.add specification
;;
;; For any a, b that are valid u32 values, running the 3-instruction sequence
;; (i32.const a) (i32.const b) (i32.add) produces state with (bvplus 32 a b)
;; on top of the operand stack.

;; Helper: the common theory for unfolding WASM execution
(local (defconst *wasm-exec-theory*
  '(run execute-instr execute-i32.const execute-i32.add
    current-frame current-instrs current-operand-stack
    current-label-stack current-locals
    update-current-operand-stack update-current-instrs
    complete-label return-from-function
    make-i32-val i32-valp i32-const-argsp no-argsp instrp
    push-operand top-operand pop-operand top-n-operands
    operand-stack-height empty-operand-stack operand-stackp
    localsp framep top-frame push-call-stack pop-call-stack
    call-stackp valp i64-valp u32p u64p)))

(defthm i32-add-spec
  (implies
   (and (unsigned-byte-p 32 a)
        (unsigned-byte-p 32 b))
   (equal
    (top-operand
     (current-operand-stack
      (run 3
           (make-state
            :store nil
            :call-stack (list (make-frame
                              :return-arity 1
                              :locals nil
                              :operand-stack (empty-operand-stack)
                              :instrs (list (list :i32.const a)
                                            (list :i32.const b)
                                            '(:i32.add))
                              :label-stack nil))
            :memory nil
            :globals nil))))
    (make-i32-val (bvplus 32 a b))))
  :hints (("Goal" :in-theory (enable run execute-instr execute-i32.const
                                     execute-i32.add current-frame
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 2: i32.add commutativity at WASM level
;;
;; Running (i32.const a) (i32.const b) (i32.add) and
;; (i32.const b) (i32.const a) (i32.add) produce the same result.

(defthm i32-add-commutative
  (implies
   (and (unsigned-byte-p 32 a)
        (unsigned-byte-p 32 b))
   (equal
    (top-operand
     (current-operand-stack
      (run 3
           (make-state
            :store nil
            :call-stack (list (make-frame
                              :return-arity 1
                              :locals nil
                              :operand-stack (empty-operand-stack)
                              :instrs (list (list :i32.const a)
                                            (list :i32.const b)
                                            '(:i32.add))
                              :label-stack nil))
            :memory nil
            :globals nil))))
    (top-operand
     (current-operand-stack
      (run 3
           (make-state
            :store nil
            :call-stack (list (make-frame
                              :return-arity 1
                              :locals nil
                              :operand-stack (empty-operand-stack)
                              :instrs (list (list :i32.const b)
                                            (list :i32.const a)
                                            '(:i32.add))
                              :label-stack nil))
            :memory nil
            :globals nil))))))
  :hints (("Goal" :in-theory (enable run execute-instr execute-i32.const
                                     execute-i32.add current-frame
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

(value-triple (cw "~%All proofs passed!~%"))
(value-triple (cw "  - i32-add-spec: instruction sequence specification~%"))
(value-triple (cw "  - i32-add-commutative: WASM-level commutativity~%"))
