;; WASM 1.0 ACL2 — Milestone 7a: f32/f64 floating-point tests
;; Tests: const, arithmetic, comparison, unary, conversion, promotion/demotion

(in-package "ACL2")
(ld "/tmp/acl2-full/books/kestrel/wasm/package.lsp")
(in-package "WASM")
(include-book "kestrel/wasm/execution" :dir :system)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Helpers

(defmacro run-float-prog (instrs)
  `(run (len ,instrs)
        (make-state
         :store nil
         :call-stack (list (make-frame
                           :return-arity 1
                           :locals nil
                           :operand-stack (empty-operand-stack)
                           :instrs ,instrs
                           :label-stack nil))
         :memory nil
         :globals nil)))

(defmacro result-of (instrs)
  `(top-operand (current-operand-stack (run-float-prog ,instrs))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; f32.const: push a float value
(assert-event
 (equal (result-of (list '(:f32.const 3/2)))
        '(:f32.const 3/2)))

;; f64.const: push a double value
(assert-event
 (equal (result-of (list '(:f64.const 7/4)))
        '(:f64.const 7/4)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; f32 arithmetic

;; f32.add: 1.5 + 2.5 = 4.0
(assert-event
 (equal (result-of (list '(:f32.const 3/2) '(:f32.const 5/2) '(:f32.add)))
        '(:f32.const 4)))

;; f32.sub: 10.0 - 3.0 = 7.0
(assert-event
 (equal (result-of (list '(:f32.const 10) '(:f32.const 3) '(:f32.sub)))
        '(:f32.const 7)))

;; f32.mul: 3.0 * 4.0 = 12.0
(assert-event
 (equal (result-of (list '(:f32.const 3) '(:f32.const 4) '(:f32.mul)))
        '(:f32.const 12)))

;; f32.div: 10.0 / 4.0 = 5/2
(assert-event
 (equal (result-of (list '(:f32.const 10) '(:f32.const 4) '(:f32.div)))
        '(:f32.const 5/2)))

;; f32.div by zero: IEEE 754 — pos/0 = +Inf (Oracle: Node.js f32 1/0 = +Inf)
(assert-event
 (equal (result-of (list '(:f32.const 1) '(:f32.const 0) '(:f32.div)))
        :f32.+inf))

;; f32.div 0/0: IEEE 754 — 0/0 = NaN (Oracle: Node.js)
(assert-event
 (equal (result-of (list '(:f32.const 0) '(:f32.const 0) '(:f32.div)))
        :f32.nan))

;; f32.div neg/0: IEEE 754 — -5/0 = -Inf (Oracle: Node.js)
(assert-event
 (equal (result-of (list '(:f32.const -5) '(:f32.const 0) '(:f32.div)))
        :f32.-inf))

;; f32.min: min(3, 5) = 3
(assert-event
 (equal (result-of (list '(:f32.const 3) '(:f32.const 5) '(:f32.min)))
        '(:f32.const 3)))

;; f32.max: max(3, 5) = 5
(assert-event
 (equal (result-of (list '(:f32.const 3) '(:f32.const 5) '(:f32.max)))
        '(:f32.const 5)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; f32 unary

;; f32.neg: neg(5) = -5
(assert-event
 (equal (result-of (list '(:f32.const 5) '(:f32.neg)))
        '(:f32.const -5)))

;; f32.neg: neg(-3) = 3
(assert-event
 (equal (result-of (list '(:f32.const -3) '(:f32.neg)))
        '(:f32.const 3)))

;; f32.abs: abs(-7) = 7
(assert-event
 (equal (result-of (list '(:f32.const -7) '(:f32.abs)))
        '(:f32.const 7)))

;; f32.ceil: ceil(3/2) = 2
(assert-event
 (equal (result-of (list '(:f32.const 3/2) '(:f32.ceil)))
        '(:f32.const 2)))

;; f32.floor: floor(7/2) = 3
(assert-event
 (equal (result-of (list '(:f32.const 7/2) '(:f32.floor)))
        '(:f32.const 3)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; f32 comparisons (return i32)

;; f32.eq: 3 == 3 → 1
(assert-event
 (equal (result-of (list '(:f32.const 3) '(:f32.const 3) '(:f32.eq)))
        '(:i32.const 1)))

;; f32.eq: 3 == 4 → 0
(assert-event
 (equal (result-of (list '(:f32.const 3) '(:f32.const 4) '(:f32.eq)))
        '(:i32.const 0)))

;; f32.lt: 2 < 5 → 1
(assert-event
 (equal (result-of (list '(:f32.const 2) '(:f32.const 5) '(:f32.lt)))
        '(:i32.const 1)))

;; f32.ge: 5 >= 5 → 1
(assert-event
 (equal (result-of (list '(:f32.const 5) '(:f32.const 5) '(:f32.ge)))
        '(:i32.const 1)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; f64 arithmetic

;; f64.add: 1.5 + 2.5 = 4.0
(assert-event
 (equal (result-of (list '(:f64.const 3/2) '(:f64.const 5/2) '(:f64.add)))
        '(:f64.const 4)))

;; f64.mul: 7 * 6 = 42
(assert-event
 (equal (result-of (list '(:f64.const 7) '(:f64.const 6) '(:f64.mul)))
        '(:f64.const 42)))

;; f64.div: 22 / 7 = 22/7
(assert-event
 (equal (result-of (list '(:f64.const 22) '(:f64.const 7) '(:f64.div)))
        '(:f64.const 22/7)))

;; f64.neg: neg(42) = -42
(assert-event
 (equal (result-of (list '(:f64.const 42) '(:f64.neg)))
        '(:f64.const -42)))

;; f64.abs: abs(-100) = 100
(assert-event
 (equal (result-of (list '(:f64.const -100) '(:f64.abs)))
        '(:f64.const 100)))

;; f64.lt: 3.14 < 3.15 → 1 (using rationals 157/50, 63/20)
(assert-event
 (equal (result-of (list '(:f64.const 157/50) '(:f64.const 63/20) '(:f64.lt)))
        '(:i32.const 1)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Conversions: int → float

;; f64.convert_i32_u: 42 → 42.0
(assert-event
 (equal (result-of (list '(:i32.const 42) '(:f64.convert_i32_u)))
        '(:f64.const 42)))

;; f32.convert_i32_u: 100 → 100.0
(assert-event
 (equal (result-of (list '(:i32.const 100) '(:f32.convert_i32_u)))
        '(:f32.const 100)))

;; f64.convert_i32_s: signed conversion of 0xFFFFFFFF = -1 as signed i32
(assert-event
 (equal (result-of (list '(:i32.const 4294967295) '(:f64.convert_i32_s)))
        '(:f64.const -1)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Conversions: float → int (truncation)

;; i32.trunc_f64_u: 3.7 → 3
(assert-event
 (equal (result-of (list '(:f64.const 37/10) '(:i32.trunc_f64_u)))
        '(:i32.const 3)))

;; i32.trunc_f64_s: -2.9 → -2 (truncate toward zero)
(assert-event
 (equal (result-of (list '(:f64.const -29/10) '(:i32.trunc_f64_s)))
        ;; -2 as u32 = 4294967294
        '(:i32.const 4294967294)))

;; i32.trunc_f64_u: negative traps
(assert-event
 (equal (run-float-prog (list '(:f64.const -1) '(:i32.trunc_f64_u)))
        :trap))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Promotion / demotion

;; f64.promote_f32: f32 → f64 (identity on rationals)
(assert-event
 (equal (result-of (list '(:f32.const 3/2) '(:f64.promote_f32)))
        '(:f64.const 3/2)))

;; f32.demote_f64: f64 → f32 (identity on rationals)
(assert-event
 (equal (result-of (list '(:f64.const 7/4) '(:f32.demote_f64)))
        '(:f32.const 7/4)))

(cw "~%All M7a float tests passed! (28 tests)~%")
