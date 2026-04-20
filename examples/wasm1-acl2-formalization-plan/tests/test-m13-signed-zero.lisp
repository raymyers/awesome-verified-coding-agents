;; WASM 1.0 ACL2 — M13: IEEE 754 Signed Zero Tests
;;
;; Oracle: tests/oracle/signed_zero_oracle.wat compiled with wat2wasm,
;; executed with Node.js V8 engine (2026-04-20).
;;
;; Signed zero semantics implemented (M11.2):
;;   neg(+0) = -0,  neg(-0) = +0,  abs(-0) = +0
;;   +0 == -0  (comparisons treat both as rational 0)
;;   x / -0 = -∞  (negative denominator flips sign of infinity)
;;   copysign(x, -0) = negative x
;;
;; Representation: :f32.+0  :f32.-0  :f64.+0  :f64.-0  (float-specialp atoms)
;; Regular (:f32.const 0) is positive zero; neg((:f32.const 0)) = :f32.-0.

(in-package "ACL2")
(ld "/tmp/acl2-full/books/kestrel/wasm/package.lsp")
(in-package "WASM")
(include-book "kestrel/wasm/execution" :dir :system)

(set-guard-checking :none)

;; ─── Inline state builder ──────────────────────────────────────────────────
(defun f32-test-state (instrs)
  (declare (xargs :guard t :verify-guards nil))
  (make-state
   :store nil
   :call-stack (list (make-frame
                      :return-arity 1
                      :locals nil
                      :operand-stack (empty-operand-stack)
                      :instrs instrs
                      :label-stack nil))
   :memory nil
   :globals nil))

(defun f32-top (n instrs)
  (declare (xargs :guard t :verify-guards nil))
  (top-operand (current-operand-stack (run n (f32-test-state instrs)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §1. F32 NEG with signed zeros

;; Oracle: neg_pos_zero = -1.0 (copysign(1.0, neg(+0.0)))
;; neg((:f32.const 0)) → :f32.-0; copysign(1.0, :f32.-0) = -1.0
(assert-event
 (equal (f32-top 4 (list '(:f32.const 1) '(:f32.const 0)
                          '(:f32.neg) '(:f32.copysign)))
        (make-f32-val -1)))

;; Oracle: neg_neg_zero = 1.0 (copysign(1.0, neg(neg(+0.0))))
;; neg(neg(+0)) = neg(:f32.-0) = :f32.+0; copysign(1.0, :f32.+0) = 1.0
(assert-event
 (equal (f32-top 5 (list '(:f32.const 1) '(:f32.const 0)
                          '(:f32.neg) '(:f32.neg) '(:f32.copysign)))
        (make-f32-val 1)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §2. F32 ABS with signed zero

;; Oracle: abs_neg_zero = 1.0 (copysign(1.0, abs(-0.0)))
;; abs(:f32.-0) = :f32.+0; copysign(1.0, :f32.+0) = 1.0
(assert-event
 (equal (f32-top 5 (list '(:f32.const 1) '(:f32.const 0)
                          '(:f32.neg) '(:f32.abs) '(:f32.copysign)))
        (make-f32-val 1)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §3. F32 Comparisons with ±0

;; Oracle: pos_neg_zero_eq = 1 (+0 == -0 per IEEE 754)
(assert-event
 (equal (f32-top 4 (list '(:f32.const 0) '(:f32.const 0)
                          '(:f32.neg) '(:f32.eq)))
        (make-i32-val 1)))

;; Oracle: pos_neg_zero_ne = 0 (+0 != -0 is false; they compare equal)
(assert-event
 (equal (f32-top 4 (list '(:f32.const 0) '(:f32.const 0)
                          '(:f32.neg) '(:f32.ne)))
        (make-i32-val 0)))

;; Oracle: pos_neg_zero_lt = 0 (+0 < -0 is false)
(assert-event
 (equal (f32-top 4 (list '(:f32.const 0) '(:f32.const 0)
                          '(:f32.neg) '(:f32.lt)))
        (make-i32-val 0)))

;; -0 < +0 is also false
(assert-event
 (equal (f32-top 4 (list '(:f32.const 0) '(:f32.neg)
                          '(:f32.const 0) '(:f32.lt)))
        (make-i32-val 0)))

;; le: +0 <= -0 is true (they are equal)
(assert-event
 (equal (f32-top 4 (list '(:f32.const 0) '(:f32.const 0)
                          '(:f32.neg) '(:f32.le)))
        (make-i32-val 1)))

;; ge: +0 >= -0 is true
(assert-event
 (equal (f32-top 4 (list '(:f32.const 0) '(:f32.const 0)
                          '(:f32.neg) '(:f32.ge)))
        (make-i32-val 1)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §4. F32.DIV with ±0 denominator

;; Oracle: 1.0 / -0.0 = -Inf
;; push 1.0, push 0.0, neg → :f32.-0, div → :f32.-inf
(assert-event
 (equal (f32-top 4 (list '(:f32.const 1) '(:f32.const 0)
                          '(:f32.neg) '(:f32.div)))
        :f32.-inf))

;; Oracle: -1.0 / -0.0 = +Inf
(assert-event
 (equal (f32-top 4 (list '(:f32.const -1) '(:f32.const 0)
                          '(:f32.neg) '(:f32.div)))
        :f32.+inf))

;; 1.0 / +0.0 = +Inf (positive denominator → positive infinity)
(assert-event
 (equal (f32-top 3 (list '(:f32.const 1) '(:f32.const 0) '(:f32.div)))
        :f32.+inf))

;; -1.0 / +0.0 = -Inf
(assert-event
 (equal (f32-top 3 (list '(:f32.const -1) '(:f32.const 0) '(:f32.div)))
        :f32.-inf))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §5. F32.COPYSIGN with ±0 sign source

;; Oracle: copysign(5.0, -0.0) = -5.0
;; push 5.0, push 0.0, neg → :f32.-0, copysign
(assert-event
 (equal (f32-top 4 (list '(:f32.const 5) '(:f32.const 0)
                          '(:f32.neg) '(:f32.copysign)))
        (make-f32-val -5)))

;; copysign(5.0, +0.0) = 5.0 (no sign change)
(assert-event
 (equal (f32-top 3 (list '(:f32.const 5) '(:f32.const 0) '(:f32.copysign)))
        (make-f32-val 5)))

;; copysign(+Inf, -0.0) = -Inf: pre-populate stack [:f32.-0, :f32.+inf]
;; (top = :f32.-0 = arg2 sign; bottom = :f32.+inf = arg1 magnitude)
(assert-event
 (equal
  (top-operand
   (current-operand-stack
    (run 1 (make-state
            :store nil
            :call-stack (list (make-frame
                               :return-arity 1 :locals nil
                               :operand-stack (list :f32.-0 :f32.+inf)
                               :instrs (list '(:f32.copysign))
                               :label-stack nil))
            :memory nil :globals nil))))
  :f32.-inf))

;; copysign(-Inf, +0.0) = +Inf: pre-populate stack [:f32.+0, :f32.-inf]
(assert-event
 (equal
  (top-operand
   (current-operand-stack
    (run 1 (make-state
            :store nil
            :call-stack (list (make-frame
                               :return-arity 1 :locals nil
                               :operand-stack (list :f32.+0 :f32.-inf)
                               :instrs (list '(:f32.copysign))
                               :label-stack nil))
            :memory nil :globals nil))))
  :f32.+inf))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §6. F32.ADD with ±0 inputs

;; Oracle: +0 + (-0) produces a zero (no NaN, no trap)
;; The result is a rational 0; copysign(1.0, 0) = 1.0 (+0)
(assert-event
 (equal (f32-top 6 (list '(:f32.const 1) '(:f32.const 0) '(:f32.const 0)
                          '(:f32.neg) '(:f32.add) '(:f32.copysign)))
        (make-f32-val 1)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §7. F64 Signed Zero — key cases

(defun f64-test-state (instrs)
  (declare (xargs :guard t :verify-guards nil))
  (make-state
   :store nil
   :call-stack (list (make-frame
                      :return-arity 1
                      :locals nil
                      :operand-stack (empty-operand-stack)
                      :instrs instrs
                      :label-stack nil))
   :memory nil
   :globals nil))

(defun f64-top (n instrs)
  (declare (xargs :guard t :verify-guards nil))
  (top-operand (current-operand-stack (run n (f64-test-state instrs)))))

;; f64.neg(+0.0) → -0.0; copysign(1.0, -0.0) = -1.0
(assert-event
 (equal (f64-top 4 (list '(:f64.const 1) '(:f64.const 0)
                          '(:f64.neg) '(:f64.copysign)))
        (make-f64-val -1)))

;; f64.abs(-0.0) = +0.0 — 5 instructions need 5 steps
(assert-event
 (equal (f64-top 5 (list '(:f64.const 1) '(:f64.const 0)
                          '(:f64.neg) '(:f64.abs) '(:f64.copysign)))
        (make-f64-val 1)))

;; f64.div(1.0, -0.0) = -Inf
(assert-event
 (equal (f64-top 4 (list '(:f64.const 1) '(:f64.const 0)
                          '(:f64.neg) '(:f64.div)))
        :f64.-inf))

;; f64.eq(+0.0, -0.0) = 1
(assert-event
 (equal (f64-top 4 (list '(:f64.const 0) '(:f64.const 0)
                          '(:f64.neg) '(:f64.eq)))
        (make-i32-val 1)))

;; f64.lt(+0.0, -0.0) = 0
(assert-event
 (equal (f64-top 4 (list '(:f64.const 0) '(:f64.const 0)
                          '(:f64.neg) '(:f64.lt)))
        (make-i32-val 0)))
