(in-package "ACL2")
(ld "/tmp/acl2-full/books/kestrel/wasm/package.lsp")
(in-package "WASM")
(include-book "kestrel/wasm/execution" :dir :system)

(defun get-result (r)
  (declare (xargs :guard t :verify-guards nil))
  (if (and (consp r) (eq :done (first r)))
      (let* ((st (second r))
             (cs (state->call-stack st))
             (f (car cs)))
        (top-operand (frame->operand-stack f)))
    (if (statep r) (top-operand (current-operand-stack r)) r)))

(defmacro run-wasm (steps locals instrs)
  `(run ,steps
        (make-state :store nil
                    :call-stack (list (make-frame :return-arity 1
                                                  :locals ,locals
                                                  :operand-stack (empty-operand-stack)
                                                  :instrs ,instrs
                                                  :label-stack nil))
                    :memory nil :globals nil)))

(defmacro check-result (steps locals instrs expected)
  `(assert-event (equal (get-result (run-wasm ,steps ,locals ,instrs)) ,expected)))

;; === i64 arithmetic ===
;; add
(check-result 10 nil '((:i64.const 100) (:i64.const 200) (:i64.add))
              (make-i64-val 300))
;; sub
(check-result 10 nil '((:i64.const 500) (:i64.const 200) (:i64.sub))
              (make-i64-val 300))
;; mul
(check-result 10 nil '((:i64.const 1000000000) (:i64.const 1000000000) (:i64.mul))
              (make-i64-val 1000000000000000000))
;; div_u
(check-result 10 nil '((:i64.const 100) (:i64.const 7) (:i64.div_u))
              (make-i64-val 14))
;; div_u by zero → trap
(assert-event (equal (run-wasm 10 nil '((:i64.const 1) (:i64.const 0) (:i64.div_u)))
                     :trap))
;; rem_u
(check-result 10 nil '((:i64.const 100) (:i64.const 7) (:i64.rem_u))
              (make-i64-val 2))

;; === i64 bitwise ===
;; and
(check-result 10 nil '((:i64.const 255) (:i64.const 15) (:i64.and))
              (make-i64-val 15))
;; or
(check-result 10 nil '((:i64.const 240) (:i64.const 15) (:i64.or))
              (make-i64-val 255))
;; xor
(check-result 10 nil '((:i64.const 255) (:i64.const 255) (:i64.xor))
              (make-i64-val 0))
;; shl
(check-result 10 nil '((:i64.const 1) (:i64.const 32) (:i64.shl))
              (make-i64-val 4294967296))

;; === i64 unary ===
;; clz (leading zeros on 1 = 63)
(check-result 10 nil '((:i64.const 1) (:i64.clz))
              (make-i64-val 63))
;; popcnt
(check-result 10 nil '((:i64.const 255) (:i64.popcnt))
              (make-i64-val 8))

;; === i64 comparison (results are i32!) ===
;; eqz
(check-result 10 nil '((:i64.const 0) (:i64.eqz))
              (make-i32-val 1))
(check-result 10 nil '((:i64.const 42) (:i64.eqz))
              (make-i32-val 0))
;; eq
(check-result 10 nil '((:i64.const 42) (:i64.const 42) (:i64.eq))
              (make-i32-val 1))
;; lt_u
(check-result 10 nil '((:i64.const 1) (:i64.const 2) (:i64.lt_u))
              (make-i32-val 1))

;; === Conversions ===
;; i32.wrap_i64: truncate
(check-result 10 nil '((:i64.const 4294967297) (:i32.wrap_i64))
              (make-i32-val 1))
;; i64.extend_i32_u: zero-extend
(check-result 10 nil '((:i32.const 42) (:i64.extend_i32_u))
              (make-i64-val 42))
;; i64.extend_i32_s: sign-extend negative (0xFFFFFFFF → 0xFFFFFFFFFFFFFFFF)
(check-result 10 nil '((:i32.const 4294967295) (:i64.extend_i32_s))
              (make-i64-val 18446744073709551615))
;; i64.extend_i32_s: sign-extend positive (100 → 100)
(check-result 10 nil '((:i32.const 100) (:i64.extend_i32_s))
              (make-i64-val 100))

;; === i64 memory load/store ===
;; store i64 at addr 0 then load it back
(defun get-result-mem (r)
  (declare (xargs :guard t :verify-guards nil))
  (if (and (consp r) (eq :done (first r)))
      (let* ((st (second r))
             (cs (state->call-stack st))
             (f (car cs)))
        (top-operand (frame->operand-stack f)))
    (if (statep r) (top-operand (current-operand-stack r)) r)))

(assert-event
 (equal (get-result-mem
         (run 20
              (make-state :store nil
                          :call-stack (list (make-frame :return-arity 1 :locals nil
                                                        :operand-stack (empty-operand-stack)
                                                        :instrs '((:i32.const 0)
                                                                   (:i64.const 1234567890123456789)
                                                                   (:i64.store 0)
                                                                   (:i32.const 0)
                                                                   (:i64.load 0))
                                                        :label-stack nil))
                          :globals nil :memory (make-list 16 :initial-element 0))))
        (make-i64-val 1234567890123456789)))

;; === Mixed i32/i64 program: use i64 arithmetic then wrap to i32 ===
(check-result 10 nil
              '((:i64.const 10000000000) (:i64.const 5000000000) (:i64.add) (:i32.wrap_i64))
              (make-i32-val (acl2::bvchop 32 15000000000)))

(cw "~%All M5 tests passed! (i64 ops + conversions + i64 memory)~%")
