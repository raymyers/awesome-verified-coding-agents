;; WASM 1.0 ACL2 Formalization — IEEE 754 Integration Proof
;;
;; Demonstrates that Kestrel's `kestrel/floats/ieee-floats-as-bvs` library
;; integrates with our WASM execution model to provide bit-accurate IEEE 754
;; float encoding/decoding.
;;
;; This enables the 14 remaining WASM 1.0 float instructions:
;;   f32.reinterpret_i32, i32.reinterpret_f32, f64.reinterpret_i64,
;;   i64.reinterpret_f64, f32.copysign, f64.copysign, f32.nearest,
;;   f64.nearest, f32.trunc, f64.trunc, f32.load, f64.load,
;;   f32.store, f64.store

(in-package "ACL2")
(ld "/tmp/acl2-full/books/kestrel/wasm/package.lsp")
(in-package "WASM")
(include-book "kestrel/wasm/execution" :dir :system)
(include-book "kestrel/floats/ieee-floats-as-bvs" :dir :system)
(include-book "kestrel/floats/round" :dir :system)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Implementation: f32.reinterpret_i32
;; WASM spec: reinterpret the i32 bit pattern as an IEEE 754 binary32 float

(defund execute-f32.reinterpret_i32 (st)
  (declare (xargs :guard t :verify-guards nil))
  (let* ((i32-val (top-operand (current-operand-stack st)))
         (bits (acl2::farg1 i32-val))
         (float-datum (acl2::decode-bv-float32 bits))
         (f32-result (list :f32.const float-datum)))
    (update-current-operand-stack
     (cons f32-result (rest (current-operand-stack st)))
     st)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Implementation: i32.reinterpret_f32
;; WASM spec: reinterpret the f32 as an i32 bit pattern

(defund execute-i32.reinterpret_f32 (st)
  (declare (xargs :guard t :verify-guards nil))
  (let* ((f32-val (top-operand (current-operand-stack st)))
         (float-datum (acl2::farg1 f32-val))
         (bits (acl2::encode-bv-float 32 24 float-datum nil))
         (i32-result (make-i32-val bits)))
    (update-current-operand-stack
     (cons i32-result (rest (current-operand-stack st)))
     st)))

(set-guard-checking :none)

;; Helper to make a simple state with operand stack
(defun mk-st (operand-stack)
  (make-state
   :store nil
   :call-stack (list (make-frame
                      :return-arity 1
                      :locals nil
                      :operand-stack operand-stack
                      :instrs nil
                      :label-stack nil))
   :memory nil
   :globals nil
   :table nil))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Tests: f32.reinterpret_i32

;; 1.0f = 0x3F800000
(assert-event
 (let* ((st (mk-st (list (make-i32-val #x3F800000)))))
   (equal (acl2::farg1 (top-operand (current-operand-stack
                                     (execute-f32.reinterpret_i32 st))))
          1)))

;; Roundtrip: 1.0f
(assert-event
 (let* ((st0 (mk-st (list (make-i32-val #x3F800000))))
        (st1 (execute-f32.reinterpret_i32 st0))
        (st2 (execute-i32.reinterpret_f32 st1)))
   (equal (acl2::farg1 (top-operand (current-operand-stack st2)))
          #x3F800000)))

;; Roundtrip: -2.0f = 0xC0000000
(assert-event
 (let* ((st0 (mk-st (list (make-i32-val #xC0000000))))
        (st1 (execute-f32.reinterpret_i32 st0))
        (st2 (execute-i32.reinterpret_f32 st1)))
   (equal (acl2::farg1 (top-operand (current-operand-stack st2)))
          #xC0000000)))

;; Roundtrip: +infinity = 0x7F800000
(assert-event
 (let* ((st0 (mk-st (list (make-i32-val #x7F800000))))
        (st1 (execute-f32.reinterpret_i32 st0))
        (st2 (execute-i32.reinterpret_f32 st1)))
   (equal (acl2::farg1 (top-operand (current-operand-stack st2)))
          #x7F800000)))

;; Pi: 0x40490FDB ≈ 3.14159
(assert-event
 (let* ((st0 (mk-st (list (make-i32-val #x40490FDB)))))
   (rationalp (acl2::farg1 (top-operand (current-operand-stack
                                         (execute-f32.reinterpret_i32 st0)))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Tests: decode-bv-float32 directly

;; 0.5f = 0x3F000000
(assert-event (equal (acl2::decode-bv-float32 #x3F000000) 1/2))

;; -1.0f = 0xBF800000
(assert-event (equal (acl2::decode-bv-float32 #xBF800000) -1))

;; +0.0f = 0x00000000
(assert-event (equal (acl2::decode-bv-float32 0) acl2::*float-positive-zero*))

;; NaN = 0x7FC00000
(assert-event (equal (acl2::decode-bv-float32 #x7FC00000) acl2::*float-nan*))

;; 1.0d (64-bit) = 0x3FF0000000000000
(assert-event (equal (acl2::decode-bv-float64 #x3FF0000000000000) 1))

;; encode 1.0f back to bits
(assert-event (equal (acl2::encode-bv-float 32 24 1 nil) #x3F800000))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Tests: round-to-nearest-integer-ties-to-even (banker's rounding = f32.nearest)

(assert-event (equal (acl2::round-to-nearest-integer-ties-to-even 5/2) 2))  ; 2.5 → 2
(assert-event (equal (acl2::round-to-nearest-integer-ties-to-even 7/2) 4))  ; 3.5 → 4
(assert-event (equal (acl2::round-to-nearest-integer-ties-to-even 3/2) 2))  ; 1.5 → 2

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; THEOREM 1: f32 reinterpret roundtrip preserves bits (non-NaN)
;;
;; For any 32-bit value that doesn't decode to NaN, encoding the decoded
;; float datum back to bits gives the original bit pattern.

(defthm f32-reinterpret-roundtrip
  (implies (and (acl2::bv-float32p bits)
                (not (equal acl2::*float-nan* (acl2::decode-bv-float32 bits))))
           (equal (acl2::encode-bv-float 32 24 (acl2::decode-bv-float32 bits) oracle)
                  bits))
  :hints (("Goal" :in-theory (enable acl2::decode-bv-float32))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; THEOREM 2: f64 reinterpret roundtrip preserves bits (non-NaN)

(defthm f64-reinterpret-roundtrip
  (implies (and (acl2::bv-float64p bits)
                (not (equal acl2::*float-nan* (acl2::decode-bv-float64 bits))))
           (equal (acl2::encode-bv-float 64 53 (acl2::decode-bv-float64 bits) oracle)
                  bits))
  :hints (("Goal" :in-theory (enable acl2::decode-bv-float64))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; THEOREM 3: decoded non-special f32 values are rational
;;
;; This justifies our float representation: normal/subnormal f32 values
;; are ACL2 rationals, which means arithmetic operations (+, *, etc.)
;; on decoded floats use exact rational arithmetic.

(defthm decoded-f32-is-rational
  (implies (and (not (equal acl2::*float-nan* (acl2::decode-bv-float32 bv)))
                (not (equal acl2::*float-positive-infinity* (acl2::decode-bv-float32 bv)))
                (not (equal acl2::*float-negative-infinity* (acl2::decode-bv-float32 bv)))
                (not (equal acl2::*float-positive-zero* (acl2::decode-bv-float32 bv)))
                (not (equal acl2::*float-negative-zero* (acl2::decode-bv-float32 bv))))
           (rationalp (acl2::decode-bv-float32 bv)))
  :hints (("Goal" :in-theory (enable acl2::decode-bv-float32))))
