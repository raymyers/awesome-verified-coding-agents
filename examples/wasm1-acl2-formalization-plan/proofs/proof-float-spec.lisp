;; WASM 1.0 ACL2 — M8.9: Floating-point arithmetic specification proofs
;;
;; Theorems: f64.add, f64.mul, f32.add instruction specifications.
;; Under the rational model, float arithmetic is exact and corresponds
;; directly to ACL2's + and * on rationals.

(in-package "WASM")
(include-book "../execution")

(local (defconst *float-theory*
  '(run execute-instr
    execute-f64.const execute-f64.add execute-f64.mul
    execute-f32.const execute-f32.add
    current-frame current-instrs current-operand-stack
    current-label-stack current-locals
    update-current-operand-stack update-current-instrs
    complete-label return-from-function
    make-f64-val make-f32-val
    f64-const-argsp f32-const-argsp
    make-i32-val i32-valp i32-const-argsp no-argsp
    f64-valp f32-valp
    push-operand top-operand pop-operand top-n-operands push-vals
    operand-stack-height empty-operand-stack operand-stackp
    localsp framep top-frame push-call-stack pop-call-stack call-stackp
    valp i64-valp u32p u64p
    step)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 1: f64.add instruction specification
;; For all rationals a, b: (f64.const a) (f64.const b) (f64.add) → (f64 a+b)

(defthm f64-add-spec
  (implies
   (and (rationalp a) (rationalp b))
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
                              :instrs (list (list :f64.const a)
                                            (list :f64.const b)
                                            '(:f64.add))
                              :label-stack nil))
            :memory nil
            :globals nil))))
    (make-f64-val (+ a b))))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) *float-theory*)
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 2: f64.mul instruction specification
;; For all rationals a, b: (f64.const a) (f64.const b) (f64.mul) → (f64 a*b)

(defthm f64-mul-spec
  (implies
   (and (rationalp a) (rationalp b))
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
                              :instrs (list (list :f64.const a)
                                            (list :f64.const b)
                                            '(:f64.mul))
                              :label-stack nil))
            :memory nil
            :globals nil))))
    (make-f64-val (* a b))))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) *float-theory*)
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 3: f32.add instruction specification
;; For all rationals a, b: (f32.const a) (f32.const b) (f32.add) → (f32 a+b)

(defthm f32-add-spec
  (implies
   (and (rationalp a) (rationalp b))
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
                              :instrs (list (list :f32.const a)
                                            (list :f32.const b)
                                            '(:f32.add))
                              :label-stack nil))
            :memory nil
            :globals nil))))
    (make-f32-val (+ a b))))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) *float-theory*)
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))))))

(value-triple (cw "~% - f64-add-spec: f64 addition (Q.E.D.)~%"))
(value-triple (cw " - f64-mul-spec: f64 multiplication (Q.E.D.)~%"))
(value-triple (cw " - f32-add-spec: f32 addition (Q.E.D.)~%"))
