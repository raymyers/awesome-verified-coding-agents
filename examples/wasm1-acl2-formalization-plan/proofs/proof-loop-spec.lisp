;; WASM 1.0 ACL2 — M8.14: Loop specification proofs
;;
;; Theorems:
;; 1. loop-exits-on-false-condition: br_if with 0 exits loop (symbolic)
;; 2. countdown-loop-2-reaches-zero: 2-iteration countdown terminates at 0
;; 3. sum-loop-3-equals-6: 3-iteration accumulator computes sum(1..3)=6
;;
;; These prove the complete loop lifecycle: enter, re-enter (br_if true),
;; and exit (br_if false with label completion).

(in-package "WASM")
(include-book "../execution")

(local (defconst *loop-theory*
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
    valp i64-valp u32p u64p val-listp
    label-entryp label-entry->arity label-entry->continuation
    label-entry->is-loop push-label pop-label top-label
    label-stackp nth-label pop-n-labels)))

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
  :hints (("Goal" :in-theory (union-theories (current-theory :here) *loop-theory*)
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))
                           (:free (n s a) (top-n-operands n s a))
                           (:free (v s) (push-vals v s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Extended theory for multi-iteration loop proofs

(local (defconst *loop-full-theory*
  '(run execute-instr
    execute-i32.const execute-i32.add execute-i32.sub
    execute-loop execute-local.get execute-local.set execute-local.tee
    current-frame current-instrs current-operand-stack
    current-label-stack current-locals
    update-current-operand-stack update-current-instrs
    update-current-label-stack update-current-locals
    complete-label return-from-function
    make-i32-val i32-valp i32-const-argsp
    local-idx-argsp no-argsp
    push-operand top-operand pop-operand top-n-operands push-vals
    operand-stack-height empty-operand-stack operand-stackp
    localsp framep top-frame push-call-stack pop-call-stack call-stackp
    valp i64-valp u32p u64p val-listp
    label-entryp label-entry->arity label-entry->continuation
    label-entry->is-loop push-label pop-label top-label
    label-stackp nth-label pop-n-labels
    nth-local update-nth-local)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 2: Countdown loop (2 iterations)
;;
;; local[0] starts at 2. Loop body: decrement, br_if 0 if nonzero.
;; After 2 iterations: local[0] = 0, pushed onto stack via local.get.
;;
;; Execution trace (14 steps):
;; 1: loop-enter
;; 2-6: iter 1 (get 0, const 1, sub, tee 0, br_if 0 → true, re-enter)
;; 7-11: iter 2 (get 0, const 1, sub, tee 0, br_if 0 → false, fall through)
;; 12: label-complete
;; 13: local.get 0
;; 14: (result on stack)

(defthm countdown-loop-2-reaches-zero
  (equal
   (top-operand
    (current-operand-stack
     (run 14
          (make-state
           :store nil
           :call-stack (list (make-frame
                             :return-arity 1
                             :locals (list (make-i32-val 2))
                             :operand-stack (empty-operand-stack)
                             :instrs (list (list :loop 0
                                                 '((:local.get 0)
                                                   (:i32.const 1)
                                                   (:i32.sub)
                                                   (:local.tee 0)
                                                   (:br_if 0)))
                                           '(:local.get 0))
                             :label-stack nil))
           :memory nil
           :globals nil))))
   (make-i32-val 0))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) *loop-full-theory*)
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))
                           (:free (n s a) (top-n-operands n s a))
                           (:free (n s) (pop-n-labels n s))
                           (:free (v s) (push-vals v s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 3: Sum accumulator loop (3 iterations)
;;
;; local[0] = counter (3), local[1] = accumulator (0)
;; Loop body: acc += counter; counter -= 1; br_if 0 if counter != 0
;; Result: sum(1..3) = 3 + 2 + 1 = 6
;;
;; 9 instructions per iteration × 3 iterations = 27 body steps
;; + loop-enter(1) + label-complete(1) + local.get(1) + extra(2) = 32 total

(defthm sum-loop-3-equals-6
  (equal
   (top-operand
    (current-operand-stack
     (run 32
          (make-state
           :store nil
           :call-stack (list (make-frame
                             :return-arity 1
                             :locals (list (make-i32-val 3)   ;; counter
                                           (make-i32-val 0))  ;; accumulator
                             :operand-stack (empty-operand-stack)
                             :instrs (list (list :loop 0
                                                 '((:local.get 1)
                                                   (:local.get 0)
                                                   (:i32.add)
                                                   (:local.set 1)
                                                   (:local.get 0)
                                                   (:i32.const 1)
                                                   (:i32.sub)
                                                   (:local.tee 0)
                                                   (:br_if 0)))
                                           '(:local.get 1))
                             :label-stack nil))
           :memory nil
           :globals nil))))
   (make-i32-val 6))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) *loop-full-theory*)
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))
                           (:free (n s a) (top-n-operands n s a))
                           (:free (n s) (pop-n-labels n s))
                           (:free (v s) (push-vals v s))))))

(value-triple (cw "~% - loop-exits-on-false-condition: br_if exit mechanism (Q.E.D.)~%"))
(value-triple (cw " - countdown-loop-2-reaches-zero: 2-iter countdown (Q.E.D.)~%"))
(value-triple (cw " - sum-loop-3-equals-6: 3-iter accumulator sum(1..3)=6 (Q.E.D.)~%"))
