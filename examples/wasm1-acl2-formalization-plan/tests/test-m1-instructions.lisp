(in-package "ACL2")
(ld "/tmp/acl2-full/books/kestrel/wasm/package.lsp")
(in-package "WASM")
(include-book "kestrel/wasm/execution" :dir :system)

;; Helper: run a single-frame program with given locals
(defmacro run-wasm (steps locals instrs)
  `(run ,steps
        (make-state :store nil
                    :call-stack (list (make-frame :return-arity 1
                                                  :locals ,locals
                                                  :operand-stack (empty-operand-stack)
                                                  :instrs ,instrs
                                                  :label-stack nil)
                                      (make-frame :return-arity 0
                                                  :locals nil
                                                  :operand-stack (empty-operand-stack)
                                                  :instrs nil
                                                  :label-stack nil))
                    :memory nil :globals nil)))

(defun get-result (r)
  (declare (xargs :guard t :verify-guards nil))
  (if (and (consp r) (eq :done (first r)))
      (let* ((st (second r))
             (cs (state->call-stack st))
             (f (car cs)))
        (top-operand (frame->operand-stack f)))
    (if (statep r)
        (top-operand (current-operand-stack r))
      r)))

(defmacro check-result (steps locals instrs expected)
  `(assert-event
    (equal (get-result (run-wasm ,steps ,locals ,instrs))
           ,expected)))

;; Test 1: add(3,4) = 7
(check-result 4 (list (make-i32-val 3) (make-i32-val 4))
              '((:local.get 1) (:local.get 0) (:i32.add))
              (make-i32-val 7))

;; Test 2: sub(10,3) = 7
(check-result 4 (list (make-i32-val 10) (make-i32-val 3))
              '((:local.get 0) (:local.get 1) (:i32.sub))
              (make-i32-val 7))

;; Test 3: mul(6,7) = 42
(check-result 4 (list (make-i32-val 6) (make-i32-val 7))
              '((:local.get 0) (:local.get 1) (:i32.mul))
              (make-i32-val 42))

;; Test 4: div_u(10,3) = 3
(check-result 4 (list (make-i32-val 10) (make-i32-val 3))
              '((:local.get 0) (:local.get 1) (:i32.div_u))
              (make-i32-val 3))

;; Test 5: rem_u(10,3) = 1
(check-result 4 (list (make-i32-val 10) (make-i32-val 3))
              '((:local.get 0) (:local.get 1) (:i32.rem_u))
              (make-i32-val 1))

;; Test 6: and(0xFF, 0x0F) = 0x0F
(check-result 4 (list (make-i32-val 255) (make-i32-val 15))
              '((:local.get 0) (:local.get 1) (:i32.and))
              (make-i32-val 15))

;; Test 7: eqz(0) = 1
(check-result 3 (list (make-i32-val 0))
              '((:local.get 0) (:i32.eqz))
              (make-i32-val 1))

;; Test 8: eqz(5) = 0
(check-result 3 (list (make-i32-val 5))
              '((:local.get 0) (:i32.eqz))
              (make-i32-val 0))

;; Test 9: lt_u(3,5) = 1
(check-result 4 (list (make-i32-val 3) (make-i32-val 5))
              '((:local.get 0) (:local.get 1) (:i32.lt_u))
              (make-i32-val 1))

;; Test 10: i32.const pushes a value
(check-result 2 nil
              '((:i32.const 42))
              (make-i32-val 42))

;; Test 11: nop doesn't change state, then const works
(check-result 3 nil
              '((:nop) (:i32.const 99))
              (make-i32-val 99))

;; Test 12: drop removes top
(check-result 5 nil
              '((:i32.const 42) (:i32.const 99) (:drop))
              (make-i32-val 42))

;; Test 13: select with true condition (nonzero)
(check-result 6 nil
              '((:i32.const 10) (:i32.const 20) (:i32.const 1) (:select))
              (make-i32-val 10))

;; Test 14: select with false condition (zero)
(check-result 6 nil
              '((:i32.const 10) (:i32.const 20) (:i32.const 0) (:select))
              (make-i32-val 20))

;; Test 15: local.set then local.get roundtrip
(check-result 5 (list (make-i32-val 0))
              '((:i32.const 42) (:local.set 0) (:local.get 0))
              (make-i32-val 42))

;; Test 16: local.tee keeps value on stack
(check-result 4 (list (make-i32-val 0))
              '((:i32.const 77) (:local.tee 0))
              (make-i32-val 77))

;; Test 17: shl(1, 4) = 16
(check-result 4 (list (make-i32-val 1) (make-i32-val 4))
              '((:local.get 0) (:local.get 1) (:i32.shl))
              (make-i32-val 16))

;; Test 18: shr_u(256, 4) = 16
(check-result 4 (list (make-i32-val 256) (make-i32-val 4))
              '((:local.get 0) (:local.get 1) (:i32.shr_u))
              (make-i32-val 16))

(cw "~%All M1 tests passed!~%")
