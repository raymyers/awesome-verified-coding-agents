;; WASM 1.0 ACL2 — call_indirect specification proofs (3 Q.E.D.s)
;;
;; 1. call_indirect-delegates-to-call: valid table entry delegates to execute-call
;; 2. call_indirect-oob-traps: out-of-bounds table index traps
;; 3. call_indirect-nil-entry-traps: uninitialized table entry traps
;;
;; These establish that table dispatch is correct and safe: valid entries
;; resolve to the right function, and invalid entries always trap.

(in-package "WASM")
(include-book "../execution")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 1: call_indirect with valid table entry delegates to execute-call
;;
;; At the function level: given a state where the table index is on the stack,
;; execute-call_indirect produces the same state as execute-call with the
;; resolved func-idx (after popping the index from the stack).

(defthm call_indirect-delegates-to-call
  (implies
   (and (natp tbl-idx)
        (natp func-idx)
        (< tbl-idx (len (state->table st)))
        (equal (nth tbl-idx (state->table st)) func-idx)
        (statep st)
        (<= 1 (operand-stack-height (current-operand-stack st)))
        (i32-valp (top-operand (current-operand-stack st)))
        (equal (farg1 (top-operand (current-operand-stack st))) tbl-idx))
   (equal
    (execute-call_indirect '(0) st)
    (execute-call (list func-idx)
                  (update-current-operand-stack
                   (pop-operand (current-operand-stack st))
                   st))))
  :hints (("Goal" :in-theory (enable execute-call_indirect
                                     current-operand-stack
                                     update-current-operand-stack
                                     push-operand top-operand pop-operand
                                     operand-stack-height
                                     make-i32-val i32-valp
                                     valp i64-valp u32p u64p)
                  :do-not '(generalize))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 2: call_indirect traps on out-of-bounds table index

(defthm call_indirect-oob-traps
  (implies
   (and (natp tbl-idx)
        (<= (len table) tbl-idx))
   (equal
    (run 2
         (make-state
          :store store
          :call-stack (list (make-frame
                            :return-arity 1
                            :locals nil
                            :operand-stack (list (make-i32-val tbl-idx))
                            :instrs (list '(:call_indirect 0))
                            :label-stack nil))
          :memory nil
          :globals nil
          :table table))
    :trap))
  :hints (("Goal" :in-theory (enable run execute-instr
                                     execute-call_indirect
                                     current-frame
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
;; Theorem 3: call_indirect traps on nil (uninitialized) table entry

(defthm call_indirect-nil-entry-traps
  (implies
   (and (natp tbl-idx)
        (< tbl-idx (len table))
        (null (nth tbl-idx table)))
   (equal
    (run 2
         (make-state
          :store store
          :call-stack (list (make-frame
                            :return-arity 1
                            :locals nil
                            :operand-stack (list (make-i32-val tbl-idx))
                            :instrs (list '(:call_indirect 0))
                            :label-stack nil))
          :memory nil
          :globals nil
          :table table))
    :trap))
  :hints (("Goal" :in-theory (enable run execute-instr
                                     execute-call_indirect
                                     current-frame
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

(value-triple (cw "~%All call_indirect proofs passed!~%"))
(value-triple (cw "  - call_indirect-delegates-to-call: table dispatch correctness (Q.E.D.)~%"))
(value-triple (cw "  - call_indirect-oob-traps: out-of-bounds trap (Q.E.D.)~%"))
(value-triple (cw "  - call_indirect-nil-entry-traps: uninitialized entry trap (Q.E.D.)~%"))
