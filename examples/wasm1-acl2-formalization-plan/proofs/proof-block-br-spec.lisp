;; WASM 1.0 ACL2 — M8.13: Block and branch specification proofs
;;
;; Theorems:
;; 1. Block passes through result value (label push/pop lifecycle)
;; 2. br 0 exits enclosing block keeping arity values
;;
;; These are the first proofs involving the label stack lifecycle
;; (push on block entry, pop on block completion or br).

(in-package "ACL2")
(ld "/tmp/acl2-full/books/kestrel/wasm/package.lsp")
(in-package "WASM")
(include-book "kestrel/wasm/execution" :dir :system)

;; Theory for block/branch proofs: includes label stack operations
(defconst *block-theory*
  '(run execute-instr execute-i32.const execute-block
    current-frame current-instrs current-operand-stack
    current-label-stack current-locals
    update-current-operand-stack update-current-instrs
    update-current-label-stack
    complete-label return-from-function
    make-i32-val i32-valp i32-const-argsp
    local-idx-argsp no-argsp
    push-operand top-operand pop-operand top-n-operands push-vals
    operand-stack-height empty-operand-stack operand-stackp
    localsp framep top-frame push-call-stack pop-call-stack call-stackp
    valp i64-valp u32p u64p val-listp
    label-entryp label-entry->arity label-entry->continuation
    label-entry->is-loop push-label pop-label top-label
    label-stackp nth-label pop-n-labels))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 1: Block passes through result
;; (block (result i32) (i32.const v) end) → v
;; 3 steps: block-enter → i32.const → label-complete

(defthm block-passes-result
  (implies
   (unsigned-byte-p 32 v)
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
                              :instrs (list (list :block 1
                                                  (list (list :i32.const v))))
                              :label-stack nil))
            :memory nil
            :globals nil))))
    (make-i32-val v)))
  :hints (("Goal" :in-theory (enable . #.*block-theory*)
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))
                           (:free (n s a) (top-n-operands n s a))
                           (:free (v s) (push-vals v s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 2: br 0 exits the enclosing block
;; (block (result i32) (i32.const a) (i32.const b) (br 0) end) → b
;; br 0 unwinds to label 0, keeping arity (1) values from stack top.
;; 4 steps: block-enter → const a → const b → br 0
;; (Step 5 would be return-from-function producing :done)

(defthm br-exits-block
  (implies
   (and (unsigned-byte-p 32 a)
        (unsigned-byte-p 32 b))
   (equal
    (top-operand
     (current-operand-stack
      (run 4
           (make-state
            :store nil
            :call-stack (list (make-frame
                              :return-arity 1
                              :locals nil
                              :operand-stack (empty-operand-stack)
                              :instrs (list (list :block 1
                                                  (list (list :i32.const a)
                                                        (list :i32.const b)
                                                        '(:br 0))))
                              :label-stack nil))
            :memory nil
            :globals nil))))
    (make-i32-val b)))
  :hints (("Goal" :in-theory (enable . #.*block-theory*)
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))
                           (:free (n s a) (top-n-operands n s a))
                           (:free (n s) (pop-n-labels n s))
                           (:free (v s) (push-vals v s))))))

(cw "~% - block-passes-result: block label lifecycle (Q.E.D.)~%")
(cw " - br-exits-block: br 0 unwinds to enclosing block (Q.E.D.)~%")
