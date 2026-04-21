;; WASM 1.0 ACL2 — M14: IEEE 754 Inf Arithmetic Tests
;;
;; Oracle: tests/oracle/inf_arith_oracle.wat compiled with wabt 1.0.36,
;; executed with Node.js V8 engine (2026-04-21).
;;
;; IEEE 754 Inf rules implemented (M14):
;;   +Inf + +Inf = +Inf,  +Inf + -Inf = NaN,  x + ±Inf = ±Inf
;;   +Inf - +Inf = NaN,   +Inf - -Inf = +Inf, x - ±Inf = ∓Inf
;;   ±Inf × 0    = NaN,   ±Inf × ±Inf = ±Inf (sign product)
;;   ±Inf / ±Inf = NaN,   ±Inf / x    = ±Inf, x / ±Inf = ±0
;;   min(-Inf, x) = -Inf, min(x, +Inf) = x
;;   max(+Inf, x) = +Inf, max(x, -Inf) = x
;;
;; Stack representation: :f32.+inf :f32.-inf :f64.+inf :f64.-inf atoms.

(in-package "ACL2")
(ld "/tmp/acl2-full/books/kestrel/wasm/package.lsp")
(in-package "WASM")
(include-book "kestrel/wasm/execution" :dir :system)

(set-guard-checking :none)

;; ─── Helper: run one binary instruction with two pre-loaded special operands ──
;;
;; ia-run2: construct state with operand-stack = (arg2 arg1),
;; execute one instruction, return the top of the resulting operand stack.
;; Stack-ordering: arg2 is on top (popped first → becomes arg2 in binop),
;;                 arg1 is below   (popped second → becomes arg1 in binop).
(defun ia-make-state (arg1 arg2 instr)
  (declare (xargs :guard t :verify-guards nil))
  (make-state
   :store nil
   :call-stack (list (make-frame
                      :return-arity 1
                      :locals nil
                      :operand-stack (list arg2 arg1)
                      :instrs (list instr)
                      :label-stack nil))
   :memory nil
   :globals nil))

(defun ia-top (arg1 arg2 instr)
  (declare (xargs :guard t :verify-guards nil))
  (top-operand (current-operand-stack
                (step (ia-make-state arg1 arg2 instr)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §1. F32.ADD with ±Inf  (oracle: inf_arith_oracle.wat)

;; add_posinf_finite: +Inf + 5.0 = +Inf
(assert-event
 (equal (ia-top :f32.+inf (make-f32-val 5) '(:f32.add)) :f32.+inf))

;; add_neginf_finite: -Inf + 5.0 = -Inf
(assert-event
 (equal (ia-top :f32.-inf (make-f32-val 5) '(:f32.add)) :f32.-inf))

;; add_posinf_posinf: +Inf + +Inf = +Inf
(assert-event
 (equal (ia-top :f32.+inf :f32.+inf '(:f32.add)) :f32.+inf))

;; add_posinf_neginf: +Inf + -Inf = NaN
(assert-event
 (equal (ia-top :f32.+inf :f32.-inf '(:f32.add)) :f32.nan))

;; add_neginf_neginf: -Inf + -Inf = -Inf
(assert-event
 (equal (ia-top :f32.-inf :f32.-inf '(:f32.add)) :f32.-inf))

;; add_finite_posinf: 3.0 + +Inf = +Inf
(assert-event
 (equal (ia-top (make-f32-val 3) :f32.+inf '(:f32.add)) :f32.+inf))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §2. F32.SUB with ±Inf

;; sub_posinf_finite: +Inf - 5.0 = +Inf
(assert-event
 (equal (ia-top :f32.+inf (make-f32-val 5) '(:f32.sub)) :f32.+inf))

;; sub_finite_posinf: 5.0 - +Inf = -Inf
(assert-event
 (equal (ia-top (make-f32-val 5) :f32.+inf '(:f32.sub)) :f32.-inf))

;; sub_posinf_posinf: +Inf - +Inf = NaN
(assert-event
 (equal (ia-top :f32.+inf :f32.+inf '(:f32.sub)) :f32.nan))

;; sub_posinf_neginf: +Inf - -Inf = +Inf
(assert-event
 (equal (ia-top :f32.+inf :f32.-inf '(:f32.sub)) :f32.+inf))

;; sub_neginf_finite: -Inf - 5.0 = -Inf
(assert-event
 (equal (ia-top :f32.-inf (make-f32-val 5) '(:f32.sub)) :f32.-inf))

;; sub_finite_neginf: 5.0 - -Inf = +Inf
(assert-event
 (equal (ia-top (make-f32-val 5) :f32.-inf '(:f32.sub)) :f32.+inf))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §3. F32.MUL with ±Inf

;; mul_posinf_pos: +Inf × 2.0 = +Inf  (same sign → +Inf)
(assert-event
 (equal (ia-top :f32.+inf (make-f32-val 2) '(:f32.mul)) :f32.+inf))

;; mul_posinf_neg: +Inf × -2.0 = -Inf  (different sign → -Inf)
(assert-event
 (equal (ia-top :f32.+inf (make-f32-val -2) '(:f32.mul)) :f32.-inf))

;; mul_posinf_posinf: +Inf × +Inf = +Inf
(assert-event
 (equal (ia-top :f32.+inf :f32.+inf '(:f32.mul)) :f32.+inf))

;; mul_posinf_neginf: +Inf × -Inf = -Inf
(assert-event
 (equal (ia-top :f32.+inf :f32.-inf '(:f32.mul)) :f32.-inf))

;; mul_posinf_zero: +Inf × 0 = NaN  (∞ × 0 is indeterminate)
(assert-event
 (equal (ia-top :f32.+inf (make-f32-val 0) '(:f32.mul)) :f32.nan))

;; mul_neginf_neg: -Inf × -2.0 = +Inf  (negative × negative → positive)
(assert-event
 (equal (ia-top :f32.-inf (make-f32-val -2) '(:f32.mul)) :f32.+inf))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §4. F32.DIV with ±Inf

;; div_posinf_pos: +Inf / 2.0 = +Inf
(assert-event
 (equal (ia-top :f32.+inf (make-f32-val 2) '(:f32.div)) :f32.+inf))

;; div_neginf_pos: -Inf / 2.0 = -Inf
(assert-event
 (equal (ia-top :f32.-inf (make-f32-val 2) '(:f32.div)) :f32.-inf))

;; div_posinf_neginf: +Inf / -Inf = NaN  (Inf/Inf is indeterminate)
(assert-event
 (equal (ia-top :f32.+inf :f32.-inf '(:f32.div)) :f32.nan))

;; div_pos_posinf: 2.0 / +Inf = +0  (finite / Inf → zero with sign)
(assert-event
 (equal (ia-top (make-f32-val 2) :f32.+inf '(:f32.div)) :f32.+0))

;; div_neg_posinf: -2.0 / +Inf = -0  (negative / positive → negative zero)
(assert-event
 (equal (ia-top (make-f32-val -2) :f32.+inf '(:f32.div)) :f32.-0))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §5. F32.MIN with ±Inf

;; min_finite_posinf: min(5.0, +Inf) = 5.0  (+Inf loses to any finite)
(assert-event
 (equal (ia-top (make-f32-val 5) :f32.+inf '(:f32.min)) (make-f32-val 5)))

;; min_neginf_finite: min(-Inf, 5.0) = -Inf  (-Inf always wins)
(assert-event
 (equal (ia-top :f32.-inf (make-f32-val 5) '(:f32.min)) :f32.-inf))

;; min_posinf_neginf: min(+Inf, -Inf) = -Inf
(assert-event
 (equal (ia-top :f32.+inf :f32.-inf '(:f32.min)) :f32.-inf))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §6. F32.MAX with ±Inf

;; max_finite_neginf: max(5.0, -Inf) = 5.0  (-Inf loses to any finite)
(assert-event
 (equal (ia-top (make-f32-val 5) :f32.-inf '(:f32.max)) (make-f32-val 5)))

;; max_posinf_finite: max(+Inf, 5.0) = +Inf  (+Inf always wins)
(assert-event
 (equal (ia-top :f32.+inf (make-f32-val 5) '(:f32.max)) :f32.+inf))

;; max_posinf_neginf: max(+Inf, -Inf) = +Inf
(assert-event
 (equal (ia-top :f32.+inf :f32.-inf '(:f32.max)) :f32.+inf))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §7. Regression: finite operations still work after Inf-aware refactor

;; 3.0 + 4.0 = 7.0  (add unchanged for finite args)
(assert-event
 (equal (ia-top (make-f32-val 3) (make-f32-val 4) '(:f32.add))
        (make-f32-val 7)))

;; 10.0 - 3.0 = 7.0  (sub unchanged)
(assert-event
 (equal (ia-top (make-f32-val 10) (make-f32-val 3) '(:f32.sub))
        (make-f32-val 7)))

;; 3.0 × 4.0 = 12.0  (mul unchanged)
(assert-event
 (equal (ia-top (make-f32-val 3) (make-f32-val 4) '(:f32.mul))
        (make-f32-val 12)))

;; min(3.0, 4.0) = 3.0  (min unchanged)
(assert-event
 (equal (ia-top (make-f32-val 3) (make-f32-val 4) '(:f32.min))
        (make-f32-val 3)))

;; max(3.0, 4.0) = 4.0  (max unchanged)
(assert-event
 (equal (ia-top (make-f32-val 3) (make-f32-val 4) '(:f32.max))
        (make-f32-val 4)))

(cw "~%*** M14 Inf arithmetic: all assertions passed ***~%")
