(in-package "WASM")
(include-book "../execution")

;; Helper with label-stack support
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

;; M1 regression: add(3,4)=7
(check-result 10 (list (make-i32-val 3) (make-i32-val 4))
              '((:local.get 1) (:local.get 0) (:i32.add))
              (make-i32-val 7))

;; Test M2.1: simple block, fall through
;; (block 1 (i32.const 42)) -> result 42
(check-result 10 nil
              '((:block 1 ((:i32.const 42))))
              (make-i32-val 42))

;; Test M2.2: block with br 0 (early exit with value)
;; (block 1 (i32.const 99) (br 0) (i32.const 0)) -> 99
(check-result 10 nil
              '((:block 1 ((:i32.const 99) (:br 0) (:i32.const 0))))
              (make-i32-val 99))

;; Test M2.3: if/else true branch
;; if (1) then 10 else 20 -> 10
(check-result 10 nil
              '((:i32.const 1) (:if 1 ((:i32.const 10)) ((:i32.const 20))))
              (make-i32-val 10))

;; Test M2.4: if/else false branch
;; if (0) then 10 else 20 -> 20
(check-result 10 nil
              '((:i32.const 0) (:if 1 ((:i32.const 10)) ((:i32.const 20))))
              (make-i32-val 20))

;; Test M2.5: loop with br_if — count down
;; local 0 = 3, loop: if local0 == 0 exit, else dec, loop again
;; After loop, push local0 (should be 0)
(check-result 50 (list (make-i32-val 3))
              '((:block 0 ((:loop 0 ((:local.get 0)
                                      (:i32.eqz)
                                      (:br_if 1)
                                      (:local.get 0)
                                      (:i32.const 1)
                                      (:i32.sub)
                                      (:local.set 0)
                                      (:br 0)))))
                (:local.get 0))
              (make-i32-val 0))

;; Test M2.6: nested blocks with br 1 (skip outer)
;; (block 1 (block 1 (i32.const 77) (br 1)) (i32.const 0)) -> 77
(check-result 20 nil
              '((:block 1 ((:block 1 ((:i32.const 77) (:br 1)))
                           (:i32.const 0))))
              (make-i32-val 77))

;; Test M2.7: FACTORIAL(5) = 120
;; local 0 = n, local 1 = acc
(check-result 100
              (list (make-i32-val 5) (make-i32-val 1))
              '((:block 0 ((:loop 0 ((:local.get 0)
                                      (:i32.eqz)
                                      (:br_if 1)
                                      (:local.get 1)
                                      (:local.get 0)
                                      (:i32.mul)
                                      (:local.set 1)
                                      (:local.get 0)
                                      (:i32.const 1)
                                      (:i32.sub)
                                      (:local.set 0)
                                      (:br 0)))))
                (:local.get 1))
              (make-i32-val 120))

(value-triple (cw "~%All M2 tests passed! (including factorial(5)=120)~%"))
