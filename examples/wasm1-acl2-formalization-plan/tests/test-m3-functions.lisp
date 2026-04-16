(in-package "ACL2")
(ld "/tmp/acl2-full/books/kestrel/wasm/package.lsp")
(in-package "WASM")
(include-book "kestrel/wasm/execution" :dir :system)

(defconst *test-store*
  (list
   ;; func 0: add(a,b) = a + b
   (make-funcinst :param-count 2 :local-count 0 :return-arity 1
                  :body '((:local.get 0) (:local.get 1) (:i32.add)))
   ;; func 1: double(x) = x + x
   (make-funcinst :param-count 1 :local-count 0 :return-arity 1
                  :body '((:local.get 0) (:local.get 0) (:i32.add)))
   ;; func 2: factorial(n) recursive
   (make-funcinst :param-count 1 :local-count 0 :return-arity 1
                  :body '((:local.get 0)
                          (:i32.eqz)
                          (:if 1
                               ((:i32.const 1))
                               ((:local.get 0)
                                (:local.get 0)
                                (:i32.const 1)
                                (:i32.sub)
                                (:call 2)
                                (:i32.mul)))))
   ;; func 3: fibonacci(n) recursive
   ;; fib(0)=0, fib(1)=1, fib(n)=fib(n-1)+fib(n-2)
   (make-funcinst :param-count 1 :local-count 0 :return-arity 1
                  :body '((:local.get 0)
                          (:i32.const 2)
                          (:i32.lt_u)
                          (:if 1
                               ((:local.get 0))
                               ((:local.get 0)
                                (:i32.const 1)
                                (:i32.sub)
                                (:call 3)
                                (:local.get 0)
                                (:i32.const 2)
                                (:i32.sub)
                                (:call 3)
                                (:i32.add)))))))

(defmacro run-wasm-store (steps store locals instrs)
  `(run ,steps
        (make-state :store ,store
                    :call-stack (list (make-frame :return-arity 1
                                                  :locals ,locals
                                                  :operand-stack (empty-operand-stack)
                                                  :instrs ,instrs
                                                  :label-stack nil))
                    :memory nil :globals nil)))

;; Extract result from state or (:done state)
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

(defmacro check-result-m3 (steps store locals instrs expected)
  `(assert-event
    (equal (get-result (run-wasm-store ,steps ,store ,locals ,instrs))
           ,expected)))

;; Test M3.1: call add(3, 4) = 7
(check-result-m3 20 *test-store* nil
                 '((:i32.const 3) (:i32.const 4) (:call 0))
                 (make-i32-val 7))

;; Test M3.2: call double(21) = 42
(check-result-m3 20 *test-store* nil
                 '((:i32.const 21) (:call 1))
                 (make-i32-val 42))

;; Test M3.3: chain: double(add(2,3)) = 10
(check-result-m3 30 *test-store* nil
                 '((:i32.const 2) (:i32.const 3) (:call 0) (:call 1))
                 (make-i32-val 10))

;; Test M3.4: recursive factorial(5) = 120
(check-result-m3 200 *test-store* nil
                 '((:i32.const 5) (:call 2))
                 (make-i32-val 120))

;; Test M3.5: recursive factorial(0) = 1
(check-result-m3 20 *test-store* nil
                 '((:i32.const 0) (:call 2))
                 (make-i32-val 1))

;; Test M3.6: fibonacci(7) = 13
(check-result-m3 5000 *test-store* nil
                 '((:i32.const 7) (:call 3))
                 (make-i32-val 13))

(cw "~%All M3 tests passed! (recursive factorial+fibonacci via call)~%")
