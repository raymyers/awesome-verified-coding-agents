(in-package "WASM")
(include-book "../execution")

(defconst *test-mem-bytes*
  (append (list #xAB #xCD #xEF #x12 #x34 #x56 #x78 #x9A)
          (make-list 24 :initial-element 0)))

(defmacro run-load-1 (addr-val instr mem)
  (list 'top-operand
        (list 'current-operand-stack
              (list 'run 1
                    (list 'make-state
                          :store nil
                          :call-stack (list 'list (list 'make-frame
                                                       :return-arity 1
                                                       :locals nil
                                                       :operand-stack (list 'list (list 'make-i32-val addr-val))
                                                       :instrs (list 'list (list 'quote instr))
                                                       :label-stack nil))
                          :memory mem
                          :globals nil)))))

;; i32.load8_u(0) = 171
(assert-event (equal (run-load-1 0 (:i32.load8_u 0) *test-mem-bytes*)
                     (make-i32-val 171)))
(value-triple (cw "PASS: i32.load8_u(0) = 171~%"))

;; i32.load8_u(1) = 205
(assert-event (equal (run-load-1 1 (:i32.load8_u 0) *test-mem-bytes*)
                     (make-i32-val 205)))
(value-triple (cw "PASS: i32.load8_u(1) = 205~%"))

;; i32.load8_s(0) = 4294967211 (sign-extend 0xAB)
(assert-event (equal (run-load-1 0 (:i32.load8_s 0) *test-mem-bytes*)
                     (make-i32-val 4294967211)))
(value-triple (cw "PASS: i32.load8_s(0) = 4294967211 (0xFFFFFFAB)~%"))

;; i32.load8_s(3) = 18 (positive)
(assert-event (equal (run-load-1 3 (:i32.load8_s 0) *test-mem-bytes*)
                     (make-i32-val 18)))
(value-triple (cw "PASS: i32.load8_s(3) = 18~%"))

;; i32.load16_u(0) = 52651
(assert-event (equal (run-load-1 0 (:i32.load16_u 0) *test-mem-bytes*)
                     (make-i32-val 52651)))
(value-triple (cw "PASS: i32.load16_u(0) = 52651 (0xCDAB)~%"))

;; i32.load16_u(2) = 4847
(assert-event (equal (run-load-1 2 (:i32.load16_u 0) *test-mem-bytes*)
                     (make-i32-val 4847)))
(value-triple (cw "PASS: i32.load16_u(2) = 4847 (0x12EF)~%"))

;; i32.load16_s(0) = 4294954411 (sign-extend 0xCDAB)
(assert-event (equal (run-load-1 0 (:i32.load16_s 0) *test-mem-bytes*)
                     (make-i32-val 4294954411)))
(value-triple (cw "PASS: i32.load16_s(0) = 4294954411 (0xFFFFCDAB)~%"))

;; i32.load16_s(2) = 4847 (positive)
(assert-event (equal (run-load-1 2 (:i32.load16_s 0) *test-mem-bytes*)
                     (make-i32-val 4847)))
(value-triple (cw "PASS: i32.load16_s(2) = 4847~%"))

;; store8 + load8_u roundtrip: write 511 (0x1FF), read back 255 (0xFF)
(assert-event
 (equal
  (top-operand
   (current-operand-stack
    (run 5
         (make-state
          :store nil
          :call-stack (list (make-frame
                            :return-arity 1
                            :locals nil
                            :operand-stack nil
                            :instrs (list '(:i32.const 16) '(:i32.const 511) '(:i32.store8 0)
                                          '(:i32.const 16) '(:i32.load8_u 0))
                            :label-stack nil))
          :memory (make-list 32 :initial-element 0)
          :globals nil))))
  (make-i32-val 255)))
(value-triple (cw "PASS: store8(16, 0x1FF) + load8_u(16) = 255~%"))

;; store16 + load16_u roundtrip: write 0xDEADBEEF, read back 0xBEEF=48879
(assert-event
 (equal
  (top-operand
   (current-operand-stack
    (run 5
         (make-state
          :store nil
          :call-stack (list (make-frame
                            :return-arity 1
                            :locals nil
                            :operand-stack nil
                            :instrs (list '(:i32.const 20) '(:i32.const 3735928559) '(:i32.store16 0)
                                          '(:i32.const 20) '(:i32.load16_u 0))
                            :label-stack nil))
          :memory (make-list 32 :initial-element 0)
          :globals nil))))
  (make-i32-val 48879)))
(value-triple (cw "PASS: store16(20, 0xDEADBEEF) + load16_u(20) = 48879 (0xBEEF)~%"))

(value-triple (cw "~%=== ALL PACKED MEMORY TESTS PASSED (10/10) ===~%"))
