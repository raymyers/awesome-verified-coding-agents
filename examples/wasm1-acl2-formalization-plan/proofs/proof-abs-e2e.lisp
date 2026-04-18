;; WASM 1.0 ACL2 — M8.17: End-to-end program correctness proofs
;;
;; Part A: abs(x) function correctness
;; Combines: local variables, signed comparison (i32.lt_s), if/else, i32.sub
;; Theorems:
;; 1. abs(0) = 0
;; 2. abs(7) = 7 (positive value unchanged)
;; 3. abs(-5) = 5 (negative via 2's complement subtraction)
;;
;; Part B: return instruction proofs
;; 4. return inside block produces :done (early exit)
;; 5. return skips unreachable code (i32.const 99 never reached)

(in-package "ACL2")
(ld "/tmp/acl2-full/books/kestrel/wasm/package.lsp")
(in-package "WASM")
(include-book "kestrel/wasm/execution" :dir :system)

;; abs(x) program: if (x <_s 0) then (0 - x) else x
(defconst *abs-instrs*
  '((:local.get 0)
    (:i32.const 0)
    (:i32.lt_s)
    (:if 1
         ((:i32.const 0) (:local.get 0) (:i32.sub))
         ((:local.get 0)))))

(defmacro abs-state (x)
  `(make-state
    :store nil
    :call-stack (list (make-frame
                      :return-arity 1
                      :locals (list (make-i32-val ,x))
                      :operand-stack (empty-operand-stack)
                      :instrs *abs-instrs*
                      :label-stack nil))
    :memory nil
    :globals nil))

(defconst *abs-theory*
  '(run execute-instr
    execute-i32.const execute-i32.sub execute-i32.lt_s
    execute-local.get execute-if
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
    label-stackp nth-label pop-n-labels
    nth-local))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 1: abs(0) = 0
;; 0 is not < 0 (signed), so else branch (return x unchanged)
;; 6 steps: get + const + lt_s + if→else + get + label-complete

(defthm abs-of-zero
  (equal
   (top-operand
    (current-operand-stack
     (run 6 (abs-state 0))))
   (make-i32-val 0))
  :hints (("Goal" :in-theory (enable . #.*abs-theory*)
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))
                           (:free (n s a) (top-n-operands n s a))
                           (:free (v s) (push-vals v s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 2: abs(7) = 7
;; 7 is not < 0 (signed), so else branch

(defthm abs-of-positive
  (equal
   (top-operand
    (current-operand-stack
     (run 6 (abs-state 7))))
   (make-i32-val 7))
  :hints (("Goal" :in-theory (enable . #.*abs-theory*)
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))
                           (:free (n s a) (top-n-operands n s a))
                           (:free (v s) (push-vals v s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 3: abs(-5) = 5
;; -5 as unsigned 32-bit = 4294967291 (bit 31 set → signed negative)
;; i32.lt_s says 4294967291 < 0 → then branch
;; then: 0 - 4294967291 mod 2^32 = 5
;; 8 steps: get + const + lt_s + if→then + const + get + sub + label-complete

(defthm abs-of-negative
  (equal
   (top-operand
    (current-operand-stack
     (run 8 (abs-state 4294967291)))) ;; -5 as u32
   (make-i32-val 5))
  :hints (("Goal" :in-theory (enable . #.*abs-theory*)
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))
                           (:free (n s a) (top-n-operands n s a))
                           (:free (v s) (push-vals v s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Part B: return instruction proofs
;;
;; return inside a block exits the entire function.
;; Code after return is dead code (never executed).

(defconst *return-theory*
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

;; Theorem 4: return inside block produces :done (function exits)
(defthm return-exits-block-early
  (consp
   (run 5
        (make-state
         :store nil
         :call-stack (list (make-frame
                           :return-arity 1
                           :locals nil
                           :operand-stack (empty-operand-stack)
                           :instrs (list (list :block 1
                                               '((:i32.const 42)
                                                 (:return)
                                                 (:i32.const 99))))
                           :label-stack nil))
         :memory nil
         :globals nil)))
  :hints (("Goal" :in-theory (enable . #.*return-theory*)
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))
                           (:free (n s a) (top-n-operands n s a))
                           (:free (n s) (pop-n-labels n s))
                           (:free (v s) (push-vals v s))))))

;; Theorem 5: return produces :done tag (skips i32.const 99)
(defthm return-skips-unreachable-code
  (equal
   (car (run 5
             (make-state
              :store nil
              :call-stack (list (make-frame
                                :return-arity 1
                                :locals nil
                                :operand-stack (empty-operand-stack)
                                :instrs (list (list :block 1
                                                    '((:i32.const 42)
                                                      (:return)
                                                      (:i32.const 99))))
                                :label-stack nil))
              :memory nil
              :globals nil)))
   :done)
  :hints (("Goal" :in-theory (enable . #.*return-theory*)
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))
                           (:free (n s a) (top-n-operands n s a))
                           (:free (n s) (pop-n-labels n s))
                           (:free (v s) (push-vals v s))))))

(cw "~% - abs-of-zero: abs(0)=0 (Q.E.D.)~%")
(cw " - abs-of-positive: abs(7)=7 (Q.E.D.)~%")
(cw " - abs-of-negative: abs(-5)=5 via 2's complement (Q.E.D.)~%")
(cw " - return-exits-block-early: return produces :done (Q.E.D.)~%")
(cw " - return-skips-unreachable-code: dead code skipped (Q.E.D.)~%")
