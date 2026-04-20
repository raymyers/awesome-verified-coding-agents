(module
  ;; copysign(1.0, neg(+0.0)) = -1.0 → neg(+0) has negative sign
  (func $neg_pos_zero (export "neg_pos_zero") (result f32)
    f32.const 1.0
    f32.const 0.0
    f32.neg
    f32.copysign)
  ;; copysign(1.0, neg(neg(+0.0))) = +1.0 → double-neg restores positive sign
  (func $neg_neg_zero (export "neg_neg_zero") (result f32)
    f32.const 1.0
    f32.const 0.0
    f32.neg
    f32.neg
    f32.copysign)
  ;; abs(-0.0): sign bit cleared → positive zero detected via copysign
  (func $abs_neg_zero (export "abs_neg_zero") (result f32)
    f32.const 1.0
    f32.const 0.0
    f32.neg
    f32.abs
    f32.copysign)
  ;; +0.0 == -0.0 → 1 (ordered equality)
  (func $pos_neg_zero_eq (export "pos_neg_zero_eq") (result i32)
    f32.const 0.0
    f32.const 0.0
    f32.neg
    f32.eq)
  ;; +0.0 != -0.0 → 0 (they are equal)
  (func $pos_neg_zero_ne (export "pos_neg_zero_ne") (result i32)
    f32.const 0.0
    f32.const 0.0
    f32.neg
    f32.ne)
  ;; +0.0 < -0.0 → 0 (they compare equal)
  (func $pos_neg_zero_lt (export "pos_neg_zero_lt") (result i32)
    f32.const 0.0
    f32.const 0.0
    f32.neg
    f32.lt)
  ;; 1.0 / -0.0 = -Inf, check: lt result and -Inf → 0, eq → 1
  (func $div_by_neg_zero_sign (export "div_by_neg_zero_sign") (result i32)
    f32.const 1.0
    f32.const 0.0
    f32.neg
    f32.div       ;; should be -Inf
    f32.neg       ;; negate: -Inf → +Inf
    f32.const 1.0
    f32.const 0.0
    f32.div       ;; 1.0/0 = +Inf
    f32.eq)       ;; (+Inf == +Inf) → 1
  ;; copysign(x, -0.0) = -|x|: test with x=5.0
  (func $copysign_with_neg_zero (export "copysign_with_neg_zero") (result f32)
    f32.const 5.0
    f32.const 0.0
    f32.neg
    f32.copysign)  ;; -5.0
  ;; add(+0, -0) = +0 per WASM spec (round-to-nearest)
  (func $add_zeros (export "add_zeros") (result f32)
    f32.const 1.0
    f32.const 0.0
    f32.const 0.0
    f32.neg
    f32.add       ;; +0 + -0 = +0
    f32.copysign) ;; copysign(1.0, +0) = 1.0
)
