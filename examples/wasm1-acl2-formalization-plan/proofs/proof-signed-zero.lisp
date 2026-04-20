;; WASM 1.0 ACL2 — IEEE 754 Signed Zero Proofs (M11.2)
;;
;; Formal theorems about signed zero semantics in the WASM 1.0 execution model.
;; All theorems are concrete evaluations (no symbolic hypothesis needed) showing
;; that the formalization correctly implements IEEE 754 signed-zero behavior.
;;
;; Design: :f32.+0 / :f32.-0 are float-specialp atoms distinct from
;; (:f32.const 0).  neg((:f32.const 0)) = :f32.-0  (positive zero negated
;; gives the negative zero atom).  Comparisons treat both as rational 0.

(in-package "ACL2")
(ld "/tmp/acl2-full/books/kestrel/wasm/package.lsp")
(in-package "WASM")
(include-book "kestrel/wasm/execution" :dir :system)

(set-guard-checking :none)

;; ─── State helpers ────────────────────────────────────────────────────────────
(defund sz-state (instrs)
  (declare (xargs :guard t :verify-guards nil))
  (make-state
   :store nil
   :call-stack (list (make-frame
                      :return-arity 1 :locals nil
                      :operand-stack (empty-operand-stack)
                      :instrs instrs
                      :label-stack nil))
   :memory nil :globals nil))

(defund sz-top (n instrs)
  (declare (xargs :guard t :verify-guards nil))
  (top-operand (current-operand-stack (run n (sz-state instrs)))))

(defconst *sz-theory*
  '(sz-state sz-top
    run step execute-instr
    execute-f32.const execute-f32.neg execute-f32.abs execute-f32.copysign
    execute-f32.div execute-f32.eq execute-f32.ne execute-f32.lt
    f32-sign-negativep
    current-frame current-instrs current-operand-stack
    current-label-stack current-locals
    update-current-operand-stack update-current-instrs
    complete-label return-from-function
    make-f32-val f32-valp f32-const-argsp no-argsp
    i32-valp i64-valp f64-valp float-specialp
    push-operand top-operand pop-operand push-vals
    operand-stack-height empty-operand-stack operand-stackp
    localsp framep top-frame push-call-stack pop-call-stack call-stackp
    valp u32p u64p))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §1. NEG SIGNED ZERO

;; neg(+0) = -0  [rational +0 maps to :f32.-0]
(defthm f32-neg-pos-zero-is-neg-zero
  (equal (sz-top 2 (list '(:f32.const 0) '(:f32.neg)))
         :f32.-0)
  :hints (("Goal" :in-theory (enable . #.*sz-theory*)
                  :expand ((:free (n s) (run n s))))))

;; neg(-0) = +0
(defthm f32-neg-neg-zero-is-pos-zero
  (equal
   (top-operand
    (current-operand-stack
     (run 1 (make-state
             :store nil
             :call-stack (list (make-frame :return-arity 1 :locals nil
                                           :operand-stack (list :f32.-0)
                                           :instrs (list '(:f32.neg))
                                           :label-stack nil))
             :memory nil :globals nil))))
   :f32.+0)
  :hints (("Goal" :in-theory (enable run step execute-instr execute-f32.neg
                                      float-specialp
                                      current-frame current-instrs
                                      current-operand-stack
                                      update-current-operand-stack
                                      update-current-instrs
                                      complete-label return-from-function
                                      f32-valp make-f32-val no-argsp
                                      push-operand top-operand pop-operand
                                      operand-stack-height empty-operand-stack
                                      operand-stackp framep call-stackp
                                      valp i32-valp i64-valp f64-valp)
                  :expand ((:free (n s) (run n s))))))

;; neg(+0) then neg(-0) = +0  (double negation)
(defthm f32-double-neg-zero-restores-pos
  (equal (sz-top 3 (list '(:f32.const 0) '(:f32.neg) '(:f32.neg)))
         :f32.+0)
  :hints (("Goal" :in-theory (enable . #.*sz-theory*)
                  :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §2. ABS SIGNED ZERO

;; abs(-0) = +0
(defthm f32-abs-neg-zero-is-pos-zero
  (equal
   (top-operand
    (current-operand-stack
     (run 1 (make-state
             :store nil
             :call-stack (list (make-frame :return-arity 1 :locals nil
                                           :operand-stack (list :f32.-0)
                                           :instrs (list '(:f32.abs))
                                           :label-stack nil))
             :memory nil :globals nil))))
   :f32.+0)
  :hints (("Goal" :in-theory (enable run step execute-instr execute-f32.abs
                                      float-specialp
                                      current-frame current-instrs
                                      current-operand-stack
                                      update-current-operand-stack
                                      update-current-instrs
                                      complete-label return-from-function
                                      f32-valp make-f32-val no-argsp
                                      push-operand top-operand pop-operand
                                      operand-stack-height empty-operand-stack
                                      operand-stackp framep call-stackp
                                      valp i32-valp i64-valp f64-valp)
                  :expand ((:free (n s) (run n s))))))

;; abs(+0) = +0 (abs of positive zero is positive zero)
(defthm f32-abs-pos-zero-is-pos-zero
  (equal
   (top-operand
    (current-operand-stack
     (run 1 (make-state
             :store nil
             :call-stack (list (make-frame :return-arity 1 :locals nil
                                           :operand-stack (list :f32.+0)
                                           :instrs (list '(:f32.abs))
                                           :label-stack nil))
             :memory nil :globals nil))))
   :f32.+0)
  :hints (("Goal" :in-theory (enable run step execute-instr execute-f32.abs
                                      float-specialp
                                      current-frame current-instrs
                                      current-operand-stack
                                      update-current-operand-stack
                                      update-current-instrs
                                      complete-label return-from-function
                                      f32-valp make-f32-val no-argsp
                                      push-operand top-operand pop-operand
                                      operand-stack-height empty-operand-stack
                                      operand-stackp framep call-stackp
                                      valp i32-valp i64-valp f64-valp)
                  :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §3. EQUALITY: +0 == -0

;; f32.eq(+0, -0) = 1  (IEEE 754: positive and negative zero are equal)
(defthm f32-pos-neg-zero-eq
  (equal (sz-top 4 (list '(:f32.const 0) '(:f32.const 0)
                          '(:f32.neg) '(:f32.eq)))
         (make-i32-val 1))
  :hints (("Goal" :in-theory (enable . #.*sz-theory*)
                  :expand ((:free (n s) (run n s))))))

;; f32.ne(+0, -0) = 0  (they are equal, not different)
(defthm f32-pos-neg-zero-ne
  (equal (sz-top 4 (list '(:f32.const 0) '(:f32.const 0)
                          '(:f32.neg) '(:f32.ne)))
         (make-i32-val 0))
  :hints (("Goal" :in-theory (enable . #.*sz-theory*)
                  :expand ((:free (n s) (run n s))))))

;; f32.lt(+0, -0) = 0  (neither is strictly less)
(defthm f32-pos-neg-zero-lt
  (equal (sz-top 4 (list '(:f32.const 0) '(:f32.const 0)
                          '(:f32.neg) '(:f32.lt)))
         (make-i32-val 0))
  :hints (("Goal" :in-theory (enable . #.*sz-theory*)
                  :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §4. DIVISION BY ±0

;; pos / +0 = +Inf
(defthm f32-div-pos-by-pos-zero
  (equal (sz-top 3 (list '(:f32.const 1) '(:f32.const 0) '(:f32.div)))
         :f32.+inf)
  :hints (("Goal" :in-theory (enable . #.*sz-theory*)
                  :expand ((:free (n s) (run n s))))))

;; pos / -0 = -Inf
(defthm f32-div-pos-by-neg-zero
  (equal (sz-top 4 (list '(:f32.const 1) '(:f32.const 0)
                          '(:f32.neg) '(:f32.div)))
         :f32.-inf)
  :hints (("Goal" :in-theory (enable . #.*sz-theory*)
                  :expand ((:free (n s) (run n s))))))

;; neg / -0 = +Inf  (sign flip for negative numerator)
(defthm f32-div-neg-by-neg-zero
  (equal (sz-top 4 (list '(:f32.const -1) '(:f32.const 0)
                          '(:f32.neg) '(:f32.div)))
         :f32.+inf)
  :hints (("Goal" :in-theory (enable . #.*sz-theory*)
                  :expand ((:free (n s) (run n s))))))
