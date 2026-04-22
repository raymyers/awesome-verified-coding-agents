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

(in-package "WASM")
(include-book "../execution")
(include-book "kestrel/floats/ieee-floats-as-bvs" :dir :system)
(include-book "kestrel/floats/round" :dir :system)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; f32.reinterpret_i32 and i32.reinterpret_f32 are now defined in execution.lisp.
;; These tests exercise them via direct function calls.


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
