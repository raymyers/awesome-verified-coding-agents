(module
  ;; NaN propagation: NaN + 5.0 = NaN
  (func (export "nan_add_f32") (result f32)
    f32.const nan
    f32.const 5
    f32.add)
  ;; NaN propagation: NaN * 3.0 = NaN
  (func (export "nan_mul_f32") (result f32)
    f32.const nan
    f32.const 3
    f32.mul)
  ;; NaN comparison: NaN == NaN = 0 (false)
  (func (export "nan_eq_f32") (result i32)
    f32.const nan
    f32.const nan
    f32.eq)
  ;; NaN comparison: NaN < 5.0 = 0 (false)
  (func (export "nan_lt_f32") (result i32)
    f32.const nan
    f32.const 5
    f32.lt)
  ;; NaN ne: NaN != NaN = 0 per WASM spec (not 1!)
  (func (export "nan_ne_f32") (result i32)
    f32.const nan
    f32.const nan
    f32.ne)
  ;; 0/0 = NaN
  (func (export "zero_div_zero_f32") (result f32)
    f32.const 0
    f32.const 0
    f32.div)
  ;; 5/0 = +inf
  (func (export "pos_div_zero_f32") (result f32)
    f32.const 5
    f32.const 0
    f32.div)
  ;; -5/0 = -inf
  (func (export "neg_div_zero_f32") (result f32)
    f32.const -5
    f32.const 0
    f32.div)
  ;; sqrt(-1) = NaN
  (func (export "sqrt_neg_f32") (result f32)
    f32.const -1
    f32.sqrt)
  ;; sqrt(4) = 2
  (func (export "sqrt4_f32") (result f32)
    f32.const 4
    f32.sqrt)
  ;; neg(NaN) = NaN
  (func (export "neg_nan_f32") (result f32)
    f32.const nan
    f32.neg)
  ;; abs(NaN) = NaN
  (func (export "abs_nan_f32") (result f32)
    f32.const nan
    f32.abs)
  ;; neg(+inf) = -inf
  (func (export "neg_inf_f32") (result f32)
    f32.const inf
    f32.neg)
  ;; abs(-inf) = +inf
  (func (export "abs_neg_inf_f32") (result f32)
    f32.const -inf
    f32.abs)
  ;; f64 NaN propagation
  (func (export "nan_add_f64") (result f64)
    f64.const nan
    f64.const 5
    f64.add)
  (func (export "zero_div_zero_f64") (result f64)
    f64.const 0
    f64.const 0
    f64.div)
)
