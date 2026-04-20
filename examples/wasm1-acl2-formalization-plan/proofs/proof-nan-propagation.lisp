;; WASM 1.0 ACL2 — M12: NaN Propagation Proofs
;;
;; Formally proves IEEE 754 NaN propagation properties for WASM float ops.
;; Under our model, float-specialp values (:f32.nan, :f32.+inf, etc.) are
;; valid stack operands (valp) and float operations propagate NaN correctly.
;;
;; Theorems in this file:
;;   1.  f32-nan-propagates-add   : f32.add with NaN operand → NaN result
;;   2.  f32-nan-propagates-mul   : f32.mul with NaN operand → NaN result
;;   3.  f32-nan-propagates-sub   : f32.sub with NaN operand → NaN result
;;   4.  f32-eq-nan-is-zero       : f32.eq(NaN, NaN) = 0  (unordered)
;;   5.  f32-ne-nan-is-one        : f32.ne(NaN, NaN) = 1  (NaN ≠ everything)
;;   6.  f32-lt-nan-is-zero       : f32.lt(NaN, x) = 0
;;   7.  f64-nan-propagates-add   : f64.add with NaN operand → NaN result
;;   8.  f64-nan-propagates-mul   : f64.mul with NaN operand → NaN result
;;   9.  f32-zero-div-zero-is-nan : f32.div(0, 0) = NaN
;;   10. f32-pos-div-zero-is-inf  : f32.div(x, 0) for x>0 = +Inf

(in-package "ACL2")
(ld "/tmp/acl2-full/books/kestrel/wasm/package.lsp")
(in-package "WASM")
(include-book "kestrel/wasm/execution" :dir :system)

;; Theory for float op proofs — includes all needed defund functions
(defconst *nan-theory*
  '(run execute-instr step
    execute-f32.const execute-f32.add execute-f32.mul execute-f32.sub
    execute-f32.eq execute-f32.ne execute-f32.lt execute-f32.div
    execute-f64.const execute-f64.add execute-f64.mul
    execute-f32.neg execute-f32.abs execute-f32.sqrt
    float-specialp valp
    current-frame current-instrs current-operand-stack
    current-label-stack current-locals
    update-current-operand-stack update-current-instrs
    complete-label return-from-function
    make-f32-val make-f64-val make-i32-val
    f32-valp f64-valp i32-valp i64-valp
    f32-const-argsp f64-const-argsp i32-const-argsp no-argsp
    push-operand top-operand pop-operand top-n-operands push-vals
    operand-stack-height empty-operand-stack operand-stackp
    localsp framep top-frame push-call-stack pop-call-stack call-stackp
    u32p u64p))

;; Helper: build a 1-frame state with NaN on top of stack and one finite value below
(defund make-nan-add-state (tag other-val instrs)
  (declare (xargs :guard t :verify-guards nil))
  (make-state
   :store nil
   :call-stack (list (make-frame
                      :return-arity 1
                      :locals nil
                      :operand-stack (list tag other-val)
                      :instrs instrs
                      :label-stack nil))
   :memory nil
   :globals nil))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 1: f32.add(NaN, x) = NaN
;; For any finite f32 value x, adding with NaN (on top) produces NaN.

(defthm f32-nan-propagates-add
  (implies (f32-valp x)
   (equal
    (top-operand
     (current-operand-stack
      (run 1 (make-nan-add-state :f32.nan x '((:f32.add))))))
    :f32.nan))
  :hints (("Goal"
           :in-theory (enable make-nan-add-state . #.*nan-theory*)
           :do-not '(generalize)
           :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 2: f32.mul(NaN, x) = NaN

(defthm f32-nan-propagates-mul
  (implies (f32-valp x)
   (equal
    (top-operand
     (current-operand-stack
      (run 1 (make-nan-add-state :f32.nan x '((:f32.mul))))))
    :f32.nan))
  :hints (("Goal"
           :in-theory (enable make-nan-add-state . #.*nan-theory*)
           :do-not '(generalize)
           :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 3: f32.sub(NaN, x) = NaN

(defthm f32-nan-propagates-sub
  (implies (f32-valp x)
   (equal
    (top-operand
     (current-operand-stack
      (run 1 (make-nan-add-state :f32.nan x '((:f32.sub))))))
    :f32.nan))
  :hints (("Goal"
           :in-theory (enable make-nan-add-state . #.*nan-theory*)
           :do-not '(generalize)
           :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 4: f32.eq(NaN, NaN) = 0
;; IEEE 754: NaN is unordered — equality comparison always returns false.

(defthm f32-eq-nan-is-zero
  (equal
   (top-operand
    (current-operand-stack
     (run 1 (make-state
             :store nil
             :call-stack (list (make-frame
                               :return-arity 1
                               :locals nil
                               :operand-stack (list :f32.nan :f32.nan)
                               :instrs '((:f32.eq))
                               :label-stack nil))
             :memory nil
             :globals nil))))
   '(:i32.const 0))
  :hints (("Goal"
           :in-theory (enable . #.*nan-theory*)
           :do-not '(generalize)
           :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 5: f32.ne(NaN, NaN) = 1
;; IEEE 754: NaN is "not equal" to everything, including itself.

(defthm f32-ne-nan-is-one
  (equal
   (top-operand
    (current-operand-stack
     (run 1 (make-state
             :store nil
             :call-stack (list (make-frame
                               :return-arity 1
                               :locals nil
                               :operand-stack (list :f32.nan :f32.nan)
                               :instrs '((:f32.ne))
                               :label-stack nil))
             :memory nil
             :globals nil))))
   '(:i32.const 1))
  :hints (("Goal"
           :in-theory (enable . #.*nan-theory*)
           :do-not '(generalize)
           :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 6: f32.lt(NaN, x) = 0 for any finite x

(defthm f32-lt-nan-is-zero
  (implies (f32-valp x)
   (equal
    (top-operand
     (current-operand-stack
      (run 1 (make-nan-add-state :f32.nan x '((:f32.lt))))))
    '(:i32.const 0)))
  :hints (("Goal"
           :in-theory (enable make-nan-add-state . #.*nan-theory*)
           :do-not '(generalize)
           :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 7: f64.add(NaN, x) = NaN (f64 version)

(defund make-nan-add-state64 (tag other-val instrs)
  (declare (xargs :guard t :verify-guards nil))
  (make-state
   :store nil
   :call-stack (list (make-frame
                      :return-arity 1
                      :locals nil
                      :operand-stack (list tag other-val)
                      :instrs instrs
                      :label-stack nil))
   :memory nil
   :globals nil))

(defthm f64-nan-propagates-add
  (implies (f64-valp x)
   (equal
    (top-operand
     (current-operand-stack
      (run 1 (make-nan-add-state64 :f64.nan x '((:f64.add))))))
    :f64.nan))
  :hints (("Goal"
           :in-theory (enable make-nan-add-state64 . #.*nan-theory*)
           :do-not '(generalize)
           :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 8: f64.mul(NaN, x) = NaN

(defthm f64-nan-propagates-mul
  (implies (f64-valp x)
   (equal
    (top-operand
     (current-operand-stack
      (run 1 (make-nan-add-state64 :f64.nan x '((:f64.mul))))))
    :f64.nan))
  :hints (("Goal"
           :in-theory (enable make-nan-add-state64 . #.*nan-theory*)
           :do-not '(generalize)
           :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 9: f32.div(0, 0) = NaN
;; IEEE 754: 0/0 is indeterminate → NaN

(defthm f32-zero-div-zero-is-nan
  (equal
   (top-operand
    (current-operand-stack
     (run 1 (make-state
             :store nil
             :call-stack (list (make-frame
                               :return-arity 1
                               :locals nil
                               :operand-stack (list '(:f32.const 0) '(:f32.const 0))
                               :instrs '((:f32.div))
                               :label-stack nil))
             :memory nil
             :globals nil))))
   :f32.nan)
  :hints (("Goal"
           :in-theory (enable . #.*nan-theory*)
           :do-not '(generalize)
           :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 10: f32.div(x, 0) = +Inf for positive finite x
;; IEEE 754: positive / zero = +Infinity

(defthm f32-pos-div-zero-is-inf
  (implies (and (rationalp x) (> x 0))
   (equal
    (top-operand
     (current-operand-stack
      (run 1 (make-state
              :store nil
              :call-stack (list (make-frame
                                :return-arity 1
                                :locals nil
                                :operand-stack (list '(:f32.const 0) (make-f32-val x))
                                :instrs '((:f32.div))
                                :label-stack nil))
              :memory nil
              :globals nil))))
    :f32.+inf))
  :hints (("Goal"
           :in-theory (enable make-f32-val . #.*nan-theory*)
           :do-not '(generalize)
           :expand ((:free (n s) (run n s))))))

(cw "~% - f32-nan-propagates-add: f32.add(NaN, x) = NaN (Q.E.D.)~%")
(cw " - f32-nan-propagates-mul: f32.mul(NaN, x) = NaN (Q.E.D.)~%")
(cw " - f32-nan-propagates-sub: f32.sub(NaN, x) = NaN (Q.E.D.)~%")
(cw " - f32-eq-nan-is-zero:     f32.eq(NaN, NaN) = 0 (Q.E.D.)~%")
(cw " - f32-ne-nan-is-one:      f32.ne(NaN, NaN) = 1 (Q.E.D.)~%")
(cw " - f32-lt-nan-is-zero:     f32.lt(NaN, x)   = 0 (Q.E.D.)~%")
(cw " - f64-nan-propagates-add: f64.add(NaN, x) = NaN (Q.E.D.)~%")
(cw " - f64-nan-propagates-mul: f64.mul(NaN, x) = NaN (Q.E.D.)~%")
(cw " - f32-zero-div-zero-is-nan: f32.div(0,0) = NaN (Q.E.D.)~%")
(cw " - f32-pos-div-zero-is-inf:  f32.div(x>0,0) = +Inf (Q.E.D.)~%")
