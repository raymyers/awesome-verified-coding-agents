;; WASM 1.0 ACL2 — i32.mul and i32.eqz specification proofs (4 Q.E.D.s)
;;
;; 1. i32-mul-spec: multiplication produces bvmult
;; 2. i32-mul-by-zero: x * 0 = 0
;; 3. i32-eqz-of-zero: eqz(0) = 1
;; 4. i32-eqz-of-nonzero: eqz(x) = 0 when x != 0

(in-package "WASM")
(include-book "../execution")

(local (defconst *wasm-exec-theory*
  '(run execute-instr execute-i32.const
    current-frame current-instrs current-operand-stack
    current-label-stack current-locals
    update-current-operand-stack update-current-instrs
    complete-label return-from-function
    make-i32-val i32-valp i32-const-argsp no-argsp instrp
    push-operand top-operand pop-operand top-n-operands
    operand-stack-height empty-operand-stack operand-stackp
    localsp framep top-frame push-call-stack pop-call-stack
    call-stackp valp i64-valp u32p u64p)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 1: i32.mul specification

(defthm i32-mul-spec
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
                                            '(:i32.mul))
                              :label-stack nil))
            :memory nil
            :globals nil))))
    (make-i32-val (acl2::bvmult 32 a b))))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) (append '(execute-i32.mul) *wasm-exec-theory*))
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 2: x * 0 = 0

(defthm i32-mul-by-zero
  (implies
   (unsigned-byte-p 32 a)
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
                                            '(:i32.const 0)
                                            '(:i32.mul))
                              :label-stack nil))
            :memory nil
            :globals nil))))
    (make-i32-val 0)))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) (append '(execute-i32.mul) *wasm-exec-theory*))
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 3: eqz(0) = 1

(defthm i32-eqz-of-zero
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
                             :instrs (list '(:i32.const 0) '(:i32.eqz))
                             :label-stack nil))
           :memory nil
           :globals nil))))
   (make-i32-val 1))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) (append '(execute-i32.eqz) *wasm-exec-theory*))
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 4: eqz(x) = 0 when x != 0

(defthm i32-eqz-of-nonzero
  (implies
   (and (unsigned-byte-p 32 x)
        (not (= x 0)))
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
                              :instrs (list (list :i32.const x) '(:i32.eqz))
                              :label-stack nil))
            :memory nil
            :globals nil))))
    (make-i32-val 0)))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) (append '(execute-i32.eqz) *wasm-exec-theory*))
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))))))

(value-triple (cw "~%All mul/eqz proofs passed!~%"))
(value-triple (cw "  - i32-mul-spec: multiplication specification (Q.E.D.)~%"))
(value-triple (cw "  - i32-mul-by-zero: x * 0 = 0 (Q.E.D.)~%"))
(value-triple (cw "  - i32-eqz-of-zero: eqz(0) = 1 (Q.E.D.)~%"))
(value-triple (cw "  - i32-eqz-of-nonzero: eqz(x!=0) = 0 (Q.E.D.)~%"))
