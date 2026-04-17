;; WASM 1.0 ACL2 — M8.14: Loop specification proof
;;
;; Theorem: loop exits when br_if condition is false (0)
;;
;; This proves the fundamental loop exit mechanism:
;; When br_if 0 receives a 0 (false) condition, execution
;; falls through to the end of the loop body, triggering
;; label completion and returning the result value.

(in-package "ACL2")
(ld "/tmp/acl2-full/books/kestrel/wasm/package.lsp")
(in-package "WASM")
(include-book "kestrel/wasm/execution" :dir :system)

(defconst *loop-theory*
  '(run execute-instr execute-i32.const execute-loop
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
    valp i64-valp f32-valp f64-valp u32p u64p val-listp
    label-entryp label-entry->arity label-entry->continuation
    label-entry->is-loop push-label pop-label top-label
    label-stackp nth-label pop-n-labels))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem: Loop exits when br_if condition is false
;;
;; (loop (result i32)
;;   (i32.const v)     ;; push result value
;;   (i32.const 0)     ;; push false condition
;;   (br_if 0)         ;; false → fall through (exit loop)
;; end) → v
;;
;; Execution trace (5 steps):
;; 1. execute-loop: push label (is-loop=t), set instrs to body
;; 2. i32.const v: push v
;; 3. i32.const 0: push 0
;; 4. br_if 0: condition=0, falls through (advance-instrs)
;; 5. complete-label: body exhausted, pop label, keep arity=1 values

(defthm loop-exits-on-false-condition
  (implies
   (unsigned-byte-p 32 v)
   (equal
    (top-operand
     (current-operand-stack
      (run 5
           (make-state
            :store nil
            :call-stack (list (make-frame
                              :return-arity 1
                              :locals nil
                              :operand-stack (empty-operand-stack)
                              :instrs (list (list :loop 1
                                                  (list (list :i32.const v)
                                                        '(:i32.const 0)
                                                        '(:br_if 0))))
                              :label-stack nil))
            :memory nil
            :globals nil))))
    (make-i32-val v)))
  :hints (("Goal" :in-theory (enable . #.*loop-theory*)
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))
                           (:free (n s a) (top-n-operands n s a))
                           (:free (v s) (push-vals v s))))))

(cw "~% - loop-exits-on-false-condition: loop/br_if exit mechanism (Q.E.D.)~%")
