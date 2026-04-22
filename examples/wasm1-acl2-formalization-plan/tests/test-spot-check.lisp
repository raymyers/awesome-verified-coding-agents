;; Spot-check: non-trivial programs that exercise multiple features together
;; Instruction format: (:block arity (body-list)), (:loop arity (body-list))
;;                     (:if arity (then-list) (else-list))

(in-package "WASM")
(include-book "../execution")

;; Extract result from state or (:done state) — handles function return
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

;; Helper to get final memory from state or (:done state)
(defun get-memory (r)
  (declare (xargs :guard t :verify-guards nil))
  (if (and (consp r) (eq :done (first r)))
      (state->memory (second r))
    (if (statep r)
        (state->memory r)
      nil)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 1. GCD via Euclidean algorithm
;;    local[0]=a, local[1]=b, local[2]=temp

(defconst *gcd-func*
  (make-funcinst
   :param-count 2 :local-count 1 :return-arity 1
   :body (list
          '(:block 0 ((:loop 0 ((:local.get 1)
                                 (:i32.eqz)
                                 (:br_if 1)
                                 (:local.get 1)
                                 (:local.set 2)
                                 (:local.get 0)
                                 (:local.get 1)
                                 (:i32.rem_u)
                                 (:local.set 1)
                                 (:local.get 2)
                                 (:local.set 0)
                                 (:br 0)))))
          '(:local.get 0))))

;; Stack order: top-first. WASM pushes arg0, then arg1, so stack=(arg1 arg0).
;; top-n-operands reverses: (arg0 arg1) → local[0]=a, local[1]=b
(defun make-gcd-state (a b)
  (declare (xargs :guard (and (natp a) (natp b)) :verify-guards nil))
  (make-state
   :store (list *gcd-func*)
   :call-stack (list (make-frame :return-arity 1 :locals nil
                      :operand-stack (list (make-i32-val b) (make-i32-val a))
                      :instrs (list '(:call 0)) :label-stack nil))
   :memory nil :globals nil))

(assert-event
 (equal (get-result (run 200 (make-gcd-state 48 18)))
        (make-i32-val 6)))
(value-triple (cw "~%PASS: gcd(48, 18) = 6~%"))

(assert-event
 (equal (get-result (run 200 (make-gcd-state 35 14)))
        (make-i32-val 7)))
(value-triple (cw "PASS: gcd(35, 14) = 7~%"))

(assert-event
 (equal (get-result (run 200 (make-gcd-state 1 1)))
        (make-i32-val 1)))
(value-triple (cw "PASS: gcd(1, 1) = 1~%"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 2. Sum of i32 array in memory
;;    Memory has [10, 20, 30, 40, 50] as i32 LE → sum = 150

(defconst *sum-array-func*
  (make-funcinst
   :param-count 2 :local-count 2 :return-arity 1
   :body (list
          '(:block 0 ((:loop 0 ((:local.get 3)
                                 (:local.get 1)
                                 (:i32.ge_u)
                                 (:br_if 1)
                                 (:local.get 0)
                                 (:local.get 3)
                                 (:i32.const 4)
                                 (:i32.mul)
                                 (:i32.add)
                                 (:i32.load 0)
                                 (:local.get 2)
                                 (:i32.add)
                                 (:local.set 2)
                                 (:local.get 3)
                                 (:i32.const 1)
                                 (:i32.add)
                                 (:local.set 3)
                                 (:br 0)))))
          '(:local.get 2))))

(assert-event
 (equal (get-result
          (run 500
               (make-state
                :store (list *sum-array-func*)
                :call-stack (list (make-frame :return-arity 1 :locals nil
                                  :operand-stack (list (make-i32-val 5) (make-i32-val 0))
                                  :instrs (list '(:call 0)) :label-stack nil))
                :memory (list 10 0 0 0  20 0 0 0  30 0 0 0  40 0 0 0  50 0 0 0)
                :globals nil)))
        (make-i32-val 150)))
(value-triple (cw "PASS: sum_array([10,20,30,40,50]) = 150~%"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 3. Memory swap: swap mem[0] and mem[4]

(defconst *swap-func*
  (make-funcinst
   :param-count 2 :local-count 1 :return-arity 0
   :body (list '(:local.get 0) '(:i32.load 0) '(:local.set 2)
               '(:local.get 0) '(:local.get 1) '(:i32.load 0) '(:i32.store 0)
               '(:local.get 1) '(:local.get 2) '(:i32.store 0))))

(defconst *swap-result*
  (run 100 (make-state
            :store (list *swap-func*)
            :call-stack (list (make-frame :return-arity 0 :locals nil
                              :operand-stack (list (make-i32-val 4) (make-i32-val 0))
                              :instrs (list '(:call 0)) :label-stack nil))
            :memory (list 42 0 0 0  99 0 0 0)
            :globals nil)))

(assert-event (equal (nth 0 (get-memory *swap-result*)) 99))
(assert-event (equal (nth 4 (get-memory *swap-result*)) 42))
(value-triple (cw "PASS: swap(mem[0]=42, mem[4]=99) -> mem[0]=99, mem[4]=42~%"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 4. Absolute value via if/else + signed comparison
;;    abs(-5) where -5 = 4294967291

(defun make-abs-state (x)
  (declare (xargs :guard (natp x) :verify-guards nil))
  (make-state
   :store nil
   :call-stack (list (make-frame :return-arity 1
                      :locals (list (make-i32-val x))
                      :operand-stack (empty-operand-stack)
                      :instrs (list '(:local.get 0) '(:i32.const 0) '(:i32.lt_s)
                                    '(:if 1
                                       ((:i32.const 0) (:local.get 0) (:i32.sub))
                                       ((:local.get 0))))
                      :label-stack nil))
   :memory nil :globals nil))

(assert-event
 (equal (get-result (run 20 (make-abs-state 4294967291)))
        (make-i32-val 5)))
(value-triple (cw "PASS: abs(-5) = 5~%"))

(assert-event
 (equal (get-result (run 20 (make-abs-state 7)))
        (make-i32-val 7)))
(value-triple (cw "PASS: abs(7) = 7~%"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 5. djb2 hash: hash = 5381; hash = hash*33 + byte
;;    "Hi" = [72, 105] → 5381*33+72=177645 → 177645*33+105=5862390

(defconst *hash-func*
  (make-funcinst
   :param-count 2 :local-count 2 :return-arity 1
   :body (list '(:i32.const 5381) '(:local.set 2)
          '(:block 0 ((:loop 0 ((:local.get 3) (:local.get 1) (:i32.ge_u) (:br_if 1)
                                 (:local.get 0) (:local.get 3) (:i32.add)
                                 (:i32.load 0) (:i32.const 255) (:i32.and)
                                 (:local.get 2) (:i32.const 33) (:i32.mul) (:i32.add)
                                 (:local.set 2)
                                 (:local.get 3) (:i32.const 1) (:i32.add) (:local.set 3)
                                 (:br 0)))))
          '(:local.get 2))))

(assert-event
 (equal (get-result
          (run 500 (make-state
                    :store (list *hash-func*)
                    :call-stack (list (make-frame :return-arity 1 :locals nil
                                      :operand-stack (list (make-i32-val 2) (make-i32-val 0))
                                      :instrs (list '(:call 0)) :label-stack nil))
                    :memory (list 72 105 0 0  0 0 0 0)
                    :globals nil)))
        (make-i32-val 5862390)))
(value-triple (cw "PASS: djb2_hash('Hi') = 5862390~%"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 6. Collatz sequence length
;;    collatz(6): 6->3->10->5->16->8->4->2->1 = 8 steps
;;    collatz(27) = 111 steps

(defconst *collatz-func*
  (make-funcinst
   :param-count 1 :local-count 1 :return-arity 1
   :body (list
          '(:block 0 ((:loop 0 ((:local.get 0) (:i32.const 1) (:i32.le_u) (:br_if 1)
                                 (:local.get 1) (:i32.const 1) (:i32.add) (:local.set 1)
                                 (:local.get 0) (:i32.const 2) (:i32.rem_u) (:i32.eqz)
                                 (:if 0
                                   ((:local.get 0) (:i32.const 2) (:i32.div_u) (:local.set 0))
                                   ((:local.get 0) (:i32.const 3) (:i32.mul)
                                    (:i32.const 1) (:i32.add) (:local.set 0)))
                                 (:br 0)))))
          '(:local.get 1))))

(defun make-collatz-state (n)
  (declare (xargs :guard (natp n) :verify-guards nil))
  (make-state
   :store (list *collatz-func*)
   :call-stack (list (make-frame :return-arity 1 :locals nil
                      :operand-stack (list (make-i32-val n))
                      :instrs (list '(:call 0)) :label-stack nil))
   :memory nil :globals nil))

(assert-event
 (equal (get-result (run 1000 (make-collatz-state 6)))
        (make-i32-val 8)))
(value-triple (cw "PASS: collatz(6) = 8 steps~%"))

(assert-event
 (equal (get-result (run 10000 (make-collatz-state 27)))
        (make-i32-val 111)))
(value-triple (cw "PASS: collatz(27) = 111 steps~%"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 7. i64 overflow: 0xFFFFFFFF * 0xFFFFFFFF = 0xFFFFFFFE00000001

(assert-event
 (equal (get-result
          (run 5 (make-state
                  :store nil
                  :call-stack (list (make-frame :return-arity 1 :locals nil
                                    :operand-stack (empty-operand-stack)
                                    :instrs (list '(:i64.const 4294967295)
                                                  '(:i64.const 4294967295) '(:i64.mul))
                                    :label-stack nil))
                  :memory nil :globals nil)))
        (make-i64-val 18446744065119617025)))
(value-triple (cw "PASS: i64 0xFFFFFFFF * 0xFFFFFFFF = 0xFFFFFFFE00000001~%"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 8. is_prime(n) by trial division

(defconst *is-prime-func*
  (make-funcinst
   :param-count 1 :local-count 1 :return-arity 1
   :body (list
          '(:local.get 0) '(:i32.const 2) '(:i32.lt_u)
          '(:if 0 ((:i32.const 0) (:return)) ())
          '(:i32.const 2) '(:local.set 1)
          '(:block 0 ((:loop 0 ((:local.get 1) (:local.get 1) (:i32.mul)
                                 (:local.get 0) (:i32.gt_u) (:br_if 1)
                                 (:local.get 0) (:local.get 1) (:i32.rem_u) (:i32.eqz)
                                 (:if 0 ((:i32.const 0) (:return)) ())
                                 (:local.get 1) (:i32.const 1) (:i32.add) (:local.set 1)
                                 (:br 0)))))
          '(:i32.const 1))))

(defun make-prime-state (n)
  (declare (xargs :guard (natp n) :verify-guards nil))
  (make-state
   :store (list *is-prime-func*)
   :call-stack (list (make-frame :return-arity 1 :locals nil
                      :operand-stack (list (make-i32-val n))
                      :instrs (list '(:call 0)) :label-stack nil))
   :memory nil :globals nil))

(assert-event
 (equal (get-result (run 500 (make-prime-state 2)))
        (make-i32-val 1)))
(value-triple (cw "PASS: is_prime(2) = 1~%"))

(assert-event
 (equal (get-result (run 500 (make-prime-state 7)))
        (make-i32-val 1)))
(value-triple (cw "PASS: is_prime(7) = 1~%"))

(assert-event
 (equal (get-result (run 500 (make-prime-state 12)))
        (make-i32-val 0)))
(value-triple (cw "PASS: is_prime(12) = 0~%"))

(assert-event
 (equal (get-result (run 500 (make-prime-state 97)))
        (make-i32-val 1)))
(value-triple (cw "PASS: is_prime(97) = 1~%"))

(assert-event
 (equal (get-result (run 500 (make-prime-state 100)))
        (make-i32-val 0)))
(value-triple (cw "PASS: is_prime(100) = 0~%"))

(assert-event
 (equal (get-result (run 500 (make-prime-state 1)))
        (make-i32-val 0)))
(value-triple (cw "PASS: is_prime(1) = 0~%"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(value-triple (cw "~%=== ALL SPOT CHECKS PASSED ===~%"))
