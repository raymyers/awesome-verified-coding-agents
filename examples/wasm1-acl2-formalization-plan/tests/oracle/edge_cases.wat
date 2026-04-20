;; WASM 1.0 spec conformance edge cases
;; Oracle values captured via wat2wasm + Node.js V8

(module
  ;; i32 division / remainder
  (func (export "i32_div_s") (param i32 i32) (result i32) local.get 0 local.get 1 i32.div_s)
  (func (export "i32_rem_s") (param i32 i32) (result i32) local.get 0 local.get 1 i32.rem_s)
  (func (export "i32_div_u") (param i32 i32) (result i32) local.get 0 local.get 1 i32.div_u)
  (func (export "i32_rem_u") (param i32 i32) (result i32) local.get 0 local.get 1 i32.rem_u)

  ;; i32 shifts
  (func (export "i32_shl")   (param i32 i32) (result i32) local.get 0 local.get 1 i32.shl)
  (func (export "i32_shr_s") (param i32 i32) (result i32) local.get 0 local.get 1 i32.shr_s)
  (func (export "i32_shr_u") (param i32 i32) (result i32) local.get 0 local.get 1 i32.shr_u)

  ;; i32 rotations
  (func (export "i32_rotl") (param i32 i32) (result i32) local.get 0 local.get 1 i32.rotl)
  (func (export "i32_rotr") (param i32 i32) (result i32) local.get 0 local.get 1 i32.rotr)

  ;; i32 bit counting
  (func (export "i32_clz")    (param i32) (result i32) local.get 0 i32.clz)
  (func (export "i32_ctz")    (param i32) (result i32) local.get 0 i32.ctz)
  (func (export "i32_popcnt") (param i32) (result i32) local.get 0 i32.popcnt)

  ;; i32 comparisons
  (func (export "i32_lt_s") (param i32 i32) (result i32) local.get 0 local.get 1 i32.lt_s)
  (func (export "i32_ge_s") (param i32 i32) (result i32) local.get 0 local.get 1 i32.ge_s)

  ;; Conversions
  (func (export "i32_wrap_i64") (param i64) (result i32) local.get 0 i32.wrap_i64)
  (func (export "i64_extend_s") (param i32) (result i64) local.get 0 i64.extend_i32_s)
  (func (export "i64_extend_u") (param i32) (result i64) local.get 0 i64.extend_i32_u)

  ;; i64 division edge cases
  (func (export "i64_div_s") (param i64 i64) (result i64) local.get 0 local.get 1 i64.div_s)
  (func (export "i64_rem_s") (param i64 i64) (result i64) local.get 0 local.get 1 i64.rem_s)

  ;; i64 bit counting
  (func (export "i64_clz")    (param i64) (result i64) local.get 0 i64.clz)
  (func (export "i64_ctz")    (param i64) (result i64) local.get 0 i64.ctz)
  (func (export "i64_popcnt") (param i64) (result i64) local.get 0 i64.popcnt)

  ;; i64 rotations
  (func (export "i64_rotl") (param i64 i64) (result i64) local.get 0 local.get 1 i64.rotl)
  (func (export "i64_rotr") (param i64 i64) (result i64) local.get 0 local.get 1 i64.rotr)
  (func (export "i64_shr_s") (param i64 i64) (result i64) local.get 0 local.get 1 i64.shr_s)
)
