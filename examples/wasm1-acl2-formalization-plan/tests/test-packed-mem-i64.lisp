(in-package "WASM")
(include-book "../execution")

(local (defconst *test-mem*
  (append (list #xAB #xCD #xEF #x12 #x34 #x56 #x78 #x9A)
          (make-list 24 :initial-element 0))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; i64 packed loads — oracle values from wat2wasm + Node.js

;; i64.load8_u(0) = 171
(assert-event
 (equal (top-operand
         (current-operand-stack
          (run 1 (make-state :store nil
                  :call-stack (list (make-frame :return-arity 1 :locals nil
                                    :operand-stack (list (make-i32-val 0))
                                    :instrs (list '(:i64.load8_u 0))
                                    :label-stack nil))
                  :memory *test-mem* :globals nil))))
        (make-i64-val 171)))
(value-triple (cw "PASS: i64.load8_u(0) = 171~%"))

;; i64.load8_s(0) = -85 as i64 → u64: 18446744073709551531
(assert-event
 (equal (top-operand
         (current-operand-stack
          (run 1 (make-state :store nil
                  :call-stack (list (make-frame :return-arity 1 :locals nil
                                    :operand-stack (list (make-i32-val 0))
                                    :instrs (list '(:i64.load8_s 0))
                                    :label-stack nil))
                  :memory *test-mem* :globals nil))))
        (make-i64-val 18446744073709551531)))
(value-triple (cw "PASS: i64.load8_s(0) = 18446744073709551531 (sign-extend 0xAB)~%"))

;; i64.load8_s(3) = 18 (positive byte, no extension)
(assert-event
 (equal (top-operand
         (current-operand-stack
          (run 1 (make-state :store nil
                  :call-stack (list (make-frame :return-arity 1 :locals nil
                                    :operand-stack (list (make-i32-val 3))
                                    :instrs (list '(:i64.load8_s 0))
                                    :label-stack nil))
                  :memory *test-mem* :globals nil))))
        (make-i64-val 18)))
(value-triple (cw "PASS: i64.load8_s(3) = 18~%"))

;; i64.load16_u(0) = 52651
(assert-event
 (equal (top-operand
         (current-operand-stack
          (run 1 (make-state :store nil
                  :call-stack (list (make-frame :return-arity 1 :locals nil
                                    :operand-stack (list (make-i32-val 0))
                                    :instrs (list '(:i64.load16_u 0))
                                    :label-stack nil))
                  :memory *test-mem* :globals nil))))
        (make-i64-val 52651)))
(value-triple (cw "PASS: i64.load16_u(0) = 52651~%"))

;; i64.load16_s(0) = -12885 → u64: 18446744073709538731
(assert-event
 (equal (top-operand
         (current-operand-stack
          (run 1 (make-state :store nil
                  :call-stack (list (make-frame :return-arity 1 :locals nil
                                    :operand-stack (list (make-i32-val 0))
                                    :instrs (list '(:i64.load16_s 0))
                                    :label-stack nil))
                  :memory *test-mem* :globals nil))))
        (make-i64-val 18446744073709538731)))
(value-triple (cw "PASS: i64.load16_s(0) = 18446744073709538731 (sign-extend 0xCDAB)~%"))

;; i64.load32_u(0) = 317705643
(assert-event
 (equal (top-operand
         (current-operand-stack
          (run 1 (make-state :store nil
                  :call-stack (list (make-frame :return-arity 1 :locals nil
                                    :operand-stack (list (make-i32-val 0))
                                    :instrs (list '(:i64.load32_u 0))
                                    :label-stack nil))
                  :memory *test-mem* :globals nil))))
        (make-i64-val 317705643)))
(value-triple (cw "PASS: i64.load32_u(0) = 317705643 (0x12EFCDAB)~%"))

;; i64.load32_s(0) = 317705643 (positive, same as u)
(assert-event
 (equal (top-operand
         (current-operand-stack
          (run 1 (make-state :store nil
                  :call-stack (list (make-frame :return-arity 1 :locals nil
                                    :operand-stack (list (make-i32-val 0))
                                    :instrs (list '(:i64.load32_s 0))
                                    :label-stack nil))
                  :memory *test-mem* :globals nil))))
        (make-i64-val 317705643)))
(value-triple (cw "PASS: i64.load32_s(0) = 317705643 (positive, bit 31=0)~%"))

;; i64.load32_s(4) = -1703389644 → u64: 18446744072006161972
;; Bytes [0x34,0x56,0x78,0x9A] = 0x9A785634, bit 31 set
(assert-event
 (equal (top-operand
         (current-operand-stack
          (run 1 (make-state :store nil
                  :call-stack (list (make-frame :return-arity 1 :locals nil
                                    :operand-stack (list (make-i32-val 4))
                                    :instrs (list '(:i64.load32_s 0))
                                    :label-stack nil))
                  :memory *test-mem* :globals nil))))
        (make-i64-val 18446744072006161972)))
(value-triple (cw "PASS: i64.load32_s(4) = 18446744072006161972 (sign-extend 0x9A785634)~%"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; i64 packed stores — oracle values

;; i64.store8: write 0x1FF, truncate to 0xFF=255
(assert-event
 (equal (top-operand
         (current-operand-stack
          (run 5 (make-state :store nil
                  :call-stack (list (make-frame :return-arity 1 :locals nil
                                    :operand-stack nil
                                    :instrs (list '(:i32.const 16) '(:i64.const 511) '(:i64.store8 0)
                                                  '(:i32.const 16) '(:i64.load8_u 0))
                                    :label-stack nil))
                  :memory (make-list 32 :initial-element 0)
                  :globals nil))))
        (make-i64-val 255)))
(value-triple (cw "PASS: i64.store8(16, 511) + i64.load8_u(16) = 255~%"))

;; i64.store16: write 0xDEADBEEF, truncate to 0xBEEF=48879
(assert-event
 (equal (top-operand
         (current-operand-stack
          (run 5 (make-state :store nil
                  :call-stack (list (make-frame :return-arity 1 :locals nil
                                    :operand-stack nil
                                    :instrs (list '(:i32.const 20) '(:i64.const 3735928559) '(:i64.store16 0)
                                                  '(:i32.const 20) '(:i64.load16_u 0))
                                    :label-stack nil))
                  :memory (make-list 32 :initial-element 0)
                  :globals nil))))
        (make-i64-val 48879)))
(value-triple (cw "PASS: i64.store16(20, 0xDEADBEEF) + i64.load16_u(20) = 48879~%"))

;; i64.store32: write 0x123456789ABCDEF, truncate to 0x89ABCDEF=2309737967
(assert-event
 (equal (top-operand
         (current-operand-stack
          (run 5 (make-state :store nil
                  :call-stack (list (make-frame :return-arity 1 :locals nil
                                    :operand-stack nil
                                    :instrs (list '(:i32.const 24) '(:i64.const 81985529216486895) '(:i64.store32 0)
                                                  '(:i32.const 24) '(:i64.load32_u 0))
                                    :label-stack nil))
                  :memory (make-list 32 :initial-element 0)
                  :globals nil))))
        (make-i64-val 2309737967)))
(value-triple (cw "PASS: i64.store32(24, 0x123456789ABCDEF) + i64.load32_u(24) = 2309737967~%"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Edge cases: out-of-bounds traps (Rule 5)

;; i32.load8_u at last valid byte (addr=31, mem=32 bytes) → should work
(assert-event
 (not (equal :trap
   (run 1 (make-state :store nil
            :call-stack (list (make-frame :return-arity 1 :locals nil
                              :operand-stack (list (make-i32-val 31))
                              :instrs (list '(:i32.load8_u 0))
                              :label-stack nil))
            :memory (make-list 32 :initial-element #x42)
            :globals nil)))))
(value-triple (cw "PASS: i32.load8_u(31) on 32-byte memory → succeeds~%"))

;; i32.load8_u at addr=32 on 32-byte memory → trap (OOB)
(assert-event
 (equal :trap
   (run 1 (make-state :store nil
            :call-stack (list (make-frame :return-arity 1 :locals nil
                              :operand-stack (list (make-i32-val 32))
                              :instrs (list '(:i32.load8_u 0))
                              :label-stack nil))
            :memory (make-list 32 :initial-element 0)
            :globals nil))))
(value-triple (cw "PASS: i32.load8_u(32) on 32-byte memory → trap (OOB)~%"))

;; i32.load16_u at addr=31 on 32-byte memory → trap (needs 2 bytes: 31+2=33 > 32)
(assert-event
 (equal :trap
   (run 1 (make-state :store nil
            :call-stack (list (make-frame :return-arity 1 :locals nil
                              :operand-stack (list (make-i32-val 31))
                              :instrs (list '(:i32.load16_u 0))
                              :label-stack nil))
            :memory (make-list 32 :initial-element 0)
            :globals nil))))
(value-triple (cw "PASS: i32.load16_u(31) on 32-byte memory → trap (OOB, needs 2 bytes)~%"))

;; i32.store8 at addr=32 → trap
(assert-event
 (equal :trap
   (run 3 (make-state :store nil
            :call-stack (list (make-frame :return-arity 1 :locals nil
                              :operand-stack nil
                              :instrs (list '(:i32.const 32) '(:i32.const 0) '(:i32.store8 0))
                              :label-stack nil))
            :memory (make-list 32 :initial-element 0)
            :globals nil))))
(value-triple (cw "PASS: i32.store8(32) on 32-byte memory → trap (OOB)~%"))

(value-triple (cw "~%=== ALL i64 PACKED + EDGE CASE TESTS PASSED (15/15) ===~%"))
