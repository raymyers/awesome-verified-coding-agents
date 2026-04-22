;; WASM 1.0 ACL2 — M8.16: Trap conditions and miscellaneous proofs
;;
;; Theorems:
;; 1. i64.extend_i32_s: sign extension preserves positive values
;; 2. i32.div_u by zero: traps
;; 3. unreachable: always traps
;; 4. nop: is identity (advances instruction pointer only)

(in-package "WASM")
(include-book "../execution")

(local (defconst *misc-theory*
  '(run execute-instr execute-i32.const execute-i64.const
    current-frame current-instrs current-operand-stack
    current-label-stack current-locals
    update-current-operand-stack update-current-instrs
    complete-label return-from-function
    make-i32-val make-i64-val i32-valp i64-valp
    i32-const-argsp i64-const-argsp no-argsp
    push-operand top-operand pop-operand
    operand-stack-height empty-operand-stack operand-stackp
    localsp framep top-frame push-call-stack pop-call-stack call-stackp
    valp u32p u64p)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 1: Sign extension preserves positive values
;; When the i32 value is positive (bit 31 = 0), i64.extend_i32_s
;; produces the same numeric value (zero in the upper 32 bits).

(defthm i64-extend-i32-s-positive
  (implies
   (and (unsigned-byte-p 32 x)
        (< x (expt 2 31)))
   (equal
    (top-operand
     (current-operand-stack
      (run 2
           (make-state
            :store nil
            :call-stack (list (make-frame
                              :return-arity 1
                              :locals nil
                              :operand-stack (empty-operand-stack)
                              :instrs (list (list :i32.const x)
                                            '(:i64.extend_i32_s))
                              :label-stack nil))
            :memory nil
            :globals nil))))
    (make-i64-val x)))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) (append '(execute-i64.extend_i32_s) *misc-theory*))
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 2: Division by zero traps
;; For all u32 a: (i32.const a) (i32.const 0) (i32.div_u) → :trap

(defthm i32-div-by-zero-traps
  (implies
   (unsigned-byte-p 32 a)
   (equal
    (run 3
         (make-state
          :store nil
          :call-stack (list (make-frame
                            :return-arity 1
                            :locals nil
                            :operand-stack (empty-operand-stack)
                            :instrs (list (list :i32.const a)
                                          '(:i32.const 0)
                                          '(:i32.div_u))
                            :label-stack nil))
          :memory nil
          :globals nil))
    :trap))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) (append '(execute-i32.div_u) *misc-theory*))
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 3: unreachable always traps

(defthm unreachable-traps
  (equal
   (run 1
        (make-state
         :store nil
         :call-stack (list (make-frame
                           :return-arity 0
                           :locals nil
                           :operand-stack (empty-operand-stack)
                           :instrs '((:unreachable))
                           :label-stack nil))
         :memory nil
         :globals nil))
   :trap)
  :hints (("Goal" :in-theory (enable run execute-instr
                                     current-frame current-instrs current-operand-stack
                                     current-label-stack
                                     complete-label return-from-function
                                     framep top-frame push-call-stack pop-call-stack call-stackp
                                     localsp no-argsp operand-stackp)
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 4: nop is identity
;; Two nops after a const don't change the result.

(defthm nop-advances-only
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
                              :instrs (list (list :i32.const v)
                                            '(:nop)
                                            '(:nop))
                              :label-stack nil))
            :memory nil
            :globals nil))))
    (make-i32-val v)))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) (append '(execute-nop) *misc-theory*))
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))))))

(value-triple (cw "~% - i64-extend-i32-s-positive: sign-ext preserves positive (Q.E.D.)~%"))
(value-triple (cw " - i32-div-by-zero-traps: div by 0 → :trap (Q.E.D.)~%"))
(value-triple (cw " - unreachable-traps: always traps (Q.E.D.)~%"))
(value-triple (cw " - nop-advances-only: nop is identity (Q.E.D.)~%"))
