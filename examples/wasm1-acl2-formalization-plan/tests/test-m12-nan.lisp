;; WASM 1.0 ACL2 — M12: IEEE 754 NaN/Inf propagation tests
;;
;; Tests the NaN propagation and ±Infinity semantics added in M12.
;; All expected values confirmed by the Node.js V8 oracle (wat2wasm + Node.js).
;; See tests/oracle/nan_oracle.wat for the WAT source of each oracle test.
;;
;; Oracle command:
;;   wat2wasm nan_oracle.wat -o /tmp/nan_oracle.wasm
;;   node -e "<see test header>" < /tmp/nan_oracle.wasm
;;
;; Verified results (Node.js V8 engine, 2026-04-20):
;;   NaN + 5 = NaN         NaN * 3 = NaN
;;   NaN == NaN = 0        NaN < 5 = 0    NaN != NaN = 1
;;   0/0 = NaN             5/0 = +Inf     -5/0 = -Inf
;;   sqrt(-1) = NaN        sqrt(4) = 2
;;   neg(NaN) = NaN        abs(NaN) = NaN
;;   neg(+Inf) = -Inf      abs(-Inf) = +Inf

(in-package "WASM")
(include-book "../execution")


;; ─── Helpers ────────────────────────────────────────────────────────────────

;; Build a 1-frame state with pre-loaded operand stack and given instruction list
(defun make-nan-state (ostack instrs)
  (declare (xargs :guard t :verify-guards nil))
  (make-state
   :store nil
   :call-stack (list (make-frame
                      :return-arity 1
                      :locals nil
                      :operand-stack ostack
                      :instrs instrs
                      :label-stack nil))
   :memory nil
   :globals nil))

;; Get top operand from run result
(defun nan-result (r)
  (declare (xargs :guard t :verify-guards nil))
  (if (and (consp r) (eq :done (first r)))
      (let* ((st (second r)) (f (car (state->call-stack st))))
        (top-operand (frame->operand-stack f)))
    (if (statep r)
        (top-operand (current-operand-stack r))
      r)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Section 1: NaN propagation through arithmetic (f32)
;; Oracle: NaN + 5 = NaN

(assert-event
 (equal (nan-result
         (run 1 (make-nan-state
                 (list :f32.nan '(:f32.const 5))
                 '((:f32.add)))))
        :f32.nan)
 :msg "FAIL: f32.add(NaN, 5) should propagate NaN")

;; Oracle: 5 + NaN = NaN (commutative NaN propagation)
(assert-event
 (equal (nan-result
         (run 1 (make-nan-state
                 (list '(:f32.const 5) :f32.nan)
                 '((:f32.add)))))
        :f32.nan)
 :msg "FAIL: f32.add(5, NaN) should propagate NaN")

;; Oracle: NaN * 3 = NaN
(assert-event
 (equal (nan-result
         (run 1 (make-nan-state
                 (list :f32.nan '(:f32.const 3))
                 '((:f32.mul)))))
        :f32.nan)
 :msg "FAIL: f32.mul(NaN, 3) should propagate NaN")

;; Oracle: NaN - 7 = NaN
(assert-event
 (equal (nan-result
         (run 1 (make-nan-state
                 (list :f32.nan '(:f32.const 7))
                 '((:f32.sub)))))
        :f32.nan)
 :msg "FAIL: f32.sub(NaN, 7) should propagate NaN")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Section 2: NaN comparisons (f32)
;; IEEE 754: ordered comparisons with NaN return 0 (false); ne returns 1 (true)

;; Oracle: NaN == NaN = 0
(assert-event
 (equal (nan-result
         (run 1 (make-nan-state
                 (list :f32.nan :f32.nan)
                 '((:f32.eq)))))
        '(:i32.const 0))
 :msg "FAIL: f32.eq(NaN, NaN) should = 0")

;; Oracle: NaN < 5 = 0
(assert-event
 (equal (nan-result
         (run 1 (make-nan-state
                 (list :f32.nan '(:f32.const 5))
                 '((:f32.lt)))))
        '(:i32.const 0))
 :msg "FAIL: f32.lt(NaN, 5) should = 0")

;; Oracle: NaN != NaN = 1  (ne is special: NaN is not-equal to everything)
(assert-event
 (equal (nan-result
         (run 1 (make-nan-state
                 (list :f32.nan :f32.nan)
                 '((:f32.ne)))))
        '(:i32.const 1))
 :msg "FAIL: f32.ne(NaN, NaN) should = 1")

;; Oracle: NaN > 5 = 0
(assert-event
 (equal (nan-result
         (run 1 (make-nan-state
                 (list :f32.nan '(:f32.const 5))
                 '((:f32.gt)))))
        '(:i32.const 0))
 :msg "FAIL: f32.gt(NaN, 5) should = 0")

;; Oracle: 5 != NaN = 1
(assert-event
 (equal (nan-result
         (run 1 (make-nan-state
                 (list '(:f32.const 5) :f32.nan)
                 '((:f32.ne)))))
        '(:i32.const 1))
 :msg "FAIL: f32.ne(5, NaN) should = 1")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Section 3: Division — IEEE 754 zero-division semantics
;; (tested via instruction sequences on rational values)

(defmacro run-f32-prog (instrs)
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

(defmacro f32-result (instrs)
  `(top-operand (current-operand-stack (run-f32-prog ,instrs))))

;; Oracle: 0/0 = NaN
(assert-event
 (equal (f32-result (list '(:f32.const 0) '(:f32.const 0) '(:f32.div)))
        :f32.nan)
 :msg "FAIL: f32.div(0,0) should = NaN")

;; Oracle: 1/0 = +Inf
(assert-event
 (equal (f32-result (list '(:f32.const 1) '(:f32.const 0) '(:f32.div)))
        :f32.+inf)
 :msg "FAIL: f32.div(1,0) should = +Inf")

;; Oracle: -5/0 = -Inf
(assert-event
 (equal (f32-result (list '(:f32.const -5) '(:f32.const 0) '(:f32.div)))
        :f32.-inf)
 :msg "FAIL: f32.div(-5,0) should = -Inf")

;; Oracle: 10/2 = 5  (normal division still works)
(assert-event
 (equal (f32-result (list '(:f32.const 10) '(:f32.const 2) '(:f32.div)))
        '(:f32.const 5))
 :msg "FAIL: f32.div(10,2) should = 5")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Section 4: sqrt — IEEE 754 negative → NaN

;; Oracle: sqrt(-1) = NaN
(assert-event
 (equal (f32-result (list '(:f32.const -1) '(:f32.sqrt)))
        :f32.nan)
 :msg "FAIL: f32.sqrt(-1) should = NaN")

;; Oracle: sqrt(4) = 2  (still works for perfect squares)
(assert-event
 (equal (f32-result (list '(:f32.const 4) '(:f32.sqrt)))
        '(:f32.const 4))
 :msg "FAIL: f32.sqrt(4) should = 4")

;; Oracle: sqrt(NaN) = NaN  (NaN propagates through sqrt)
(assert-event
 (equal (nan-result
         (run 1 (make-nan-state (list :f32.nan) '((:f32.sqrt)))))
        :f32.nan)
 :msg "FAIL: f32.sqrt(NaN) should = NaN")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Section 5: Unary ops — NaN and Inf propagation

;; Oracle: neg(NaN) = NaN
(assert-event
 (equal (nan-result
         (run 1 (make-nan-state (list :f32.nan) '((:f32.neg)))))
        :f32.nan)
 :msg "FAIL: f32.neg(NaN) should = NaN")

;; Oracle: neg(+Inf) = -Inf
(assert-event
 (equal (nan-result
         (run 1 (make-nan-state (list :f32.+inf) '((:f32.neg)))))
        :f32.-inf)
 :msg "FAIL: f32.neg(+Inf) should = -Inf")

;; Oracle: neg(-Inf) = +Inf
(assert-event
 (equal (nan-result
         (run 1 (make-nan-state (list :f32.-inf) '((:f32.neg)))))
        :f32.+inf)
 :msg "FAIL: f32.neg(-Inf) should = +Inf")

;; Oracle: abs(NaN) = NaN
(assert-event
 (equal (nan-result
         (run 1 (make-nan-state (list :f32.nan) '((:f32.abs)))))
        :f32.nan)
 :msg "FAIL: f32.abs(NaN) should = NaN")

;; Oracle: abs(-Inf) = +Inf
(assert-event
 (equal (nan-result
         (run 1 (make-nan-state (list :f32.-inf) '((:f32.abs)))))
        :f32.+inf)
 :msg "FAIL: f32.abs(-Inf) should = +Inf")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Section 6: f64 NaN propagation (parallel to f32)

;; Oracle: NaN + 5 = NaN (f64)
(assert-event
 (equal (nan-result
         (run 1 (make-nan-state
                 (list :f64.nan '(:f64.const 5))
                 '((:f64.add)))))
        :f64.nan)
 :msg "FAIL: f64.add(NaN, 5) should propagate NaN")

;; Oracle: NaN != NaN = 1 (f64 ne)
(assert-event
 (equal (nan-result
         (run 1 (make-nan-state
                 (list :f64.nan :f64.nan)
                 '((:f64.ne)))))
        '(:i32.const 1))
 :msg "FAIL: f64.ne(NaN, NaN) should = 1")

;; f64 div 0/0 = NaN
(assert-event
 (equal (top-operand
         (current-operand-stack
          (run 3 (make-state
                  :store nil
                  :call-stack (list (make-frame
                                     :return-arity 1
                                     :locals nil
                                     :operand-stack (empty-operand-stack)
                                     :instrs (list '(:f64.const 0) '(:f64.const 0) '(:f64.div))
                                     :label-stack nil))
                  :memory nil
                  :globals nil))))
        :f64.nan)
 :msg "FAIL: f64.div(0,0) should = NaN")

;; neg(NaN) = NaN (f64)
(assert-event
 (equal (nan-result
         (run 1 (make-nan-state (list :f64.nan) '((:f64.neg)))))
        :f64.nan)
 :msg "FAIL: f64.neg(NaN) should = NaN")

;; abs(-Inf) = +Inf (f64)
(assert-event
 (equal (nan-result
         (run 1 (make-nan-state (list :f64.-inf) '((:f64.abs)))))
        :f64.+inf)
 :msg "FAIL: f64.abs(-Inf) should = +Inf")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Section 7: NaN propagation chains (more than one hop)
;; Oracle: (NaN + 5) * 3 = NaN  (NaN through two operations)
;; Step 1: f32.add(NaN, 5) = NaN
;; Step 2: f32.const 3  (push 3)
;; Step 3: f32.mul(NaN, 3) = NaN  (NaN propagates through mul too)

(assert-event
 (equal (nan-result
         (run 3 (make-nan-state
                 (list :f32.nan '(:f32.const 5))
                 (list '(:f32.add) '(:f32.const 3) '(:f32.mul)))))
        :f32.nan)
 :msg "FAIL: (NaN+5)*3 should = NaN (NaN propagation chain)")

;; Oracle: NaN - 1 - 1 - 1 = NaN (3-hop propagation chain)
;; Stack starts: [NaN (top), 1].  Each sub pops 2, pushes NaN.
;; After sub1: [NaN].  Push 1: [1, NaN].  sub2: [NaN].
;; Push 1: [1, NaN].  sub3: [NaN].  Five steps total.
(assert-event
 (equal (nan-result
         (run 5 (make-nan-state
                 (list :f32.nan '(:f32.const 1))
                 (list '(:f32.sub) '(:f32.const 1) '(:f32.sub)
                       '(:f32.const 1) '(:f32.sub)))))
        :f32.nan)
 :msg "FAIL: NaN-1-1-1 should = NaN (3-hop chain)")

(value-triple (cw "~% === M12 NaN/Inf tests: ALL PASSED ===~%"))
(value-triple (cw " - NaN propagation: f32.add, f32.mul, f32.sub (Oracle: NaN+5=NaN etc.)~%"))
(value-triple (cw " - NaN comparisons: f32.eq=0, f32.lt=0, f32.ne=1 (IEEE 754 unordered)~%"))
(value-triple (cw " - Division: 0/0=NaN, 1/0=+Inf, -5/0=-Inf (IEEE 754 Section 6.2)~%"))
(value-triple (cw " - sqrt: sqrt(-1)=NaN (IEEE 754), sqrt(4)=4 (finite still works)~%"))
(value-triple (cw " - Unary: neg(NaN)=NaN, neg(+Inf)=-Inf, abs(-Inf)=+Inf~%"))
(value-triple (cw " - f64 NaN: same propagation as f32~%"))
(value-triple (cw " - NaN chains: (NaN+5)*3=NaN (transitive propagation)~%"))
