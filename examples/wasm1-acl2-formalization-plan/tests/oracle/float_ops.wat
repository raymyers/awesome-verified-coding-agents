;; Oracle WAT: f32/f64 float operations
;; Compile: wat2wasm float_ops.wat -o /tmp/float_ops.wasm
;; Run: node -e "..." (see check-all.mjs)
(module
  ;; f64.add
  (func (export "f64_add") (param f64 f64) (result f64)
    local.get 0 local.get 1 f64.add)

  ;; f64.sub
  (func (export "f64_sub") (param f64 f64) (result f64)
    local.get 0 local.get 1 f64.sub)

  ;; f64.mul
  (func (export "f64_mul") (param f64 f64) (result f64)
    local.get 0 local.get 1 f64.mul)

  ;; f64.div
  (func (export "f64_div") (param f64 f64) (result f64)
    local.get 0 local.get 1 f64.div)

  ;; f64.neg
  (func (export "f64_neg") (param f64) (result f64)
    local.get 0 f64.neg)

  ;; f64.abs
  (func (export "f64_abs") (param f64) (result f64)
    local.get 0 f64.abs)

  ;; f64.ceil
  (func (export "f64_ceil") (param f64) (result f64)
    local.get 0 f64.ceil)

  ;; f64.floor
  (func (export "f64_floor") (param f64) (result f64)
    local.get 0 f64.floor)

  ;; f64.eq (returns i32)
  (func (export "f64_eq") (param f64 f64) (result i32)
    local.get 0 local.get 1 f64.eq)

  ;; f64.lt (returns i32)
  (func (export "f64_lt") (param f64 f64) (result i32)
    local.get 0 local.get 1 f64.lt)

  ;; f32.add
  (func (export "f32_add") (param f32 f32) (result f32)
    local.get 0 local.get 1 f32.add)

  ;; f32.mul
  (func (export "f32_mul") (param f32 f32) (result f32)
    local.get 0 local.get 1 f32.mul)

  ;; max via if/else (i32)
  (func (export "i32_max") (param i32 i32) (result i32)
    local.get 0 local.get 1 i32.gt_u
    (if (result i32)
      (then local.get 0)
      (else local.get 1)))

  ;; f64.convert_i32_s
  (func (export "f64_convert_i32_s") (param i32) (result f64)
    local.get 0 f64.convert_i32_s)

  ;; i32.trunc_f64_u
  (func (export "i32_trunc_f64_u") (param f64) (result i32)
    local.get 0 i32.trunc_f64_u)

  ;; --- M11: New float instructions ---

  ;; f32.trunc
  (func (export "f32_trunc") (param f32) (result f32)
    local.get 0 f32.trunc)

  ;; f32.nearest
  (func (export "f32_nearest") (param f32) (result f32)
    local.get 0 f32.nearest)

  ;; f32.copysign
  (func (export "f32_copysign") (param f32 f32) (result f32)
    local.get 0 local.get 1 f32.copysign)

  ;; f64.trunc
  (func (export "f64_trunc") (param f64) (result f64)
    local.get 0 f64.trunc)

  ;; f64.nearest
  (func (export "f64_nearest") (param f64) (result f64)
    local.get 0 f64.nearest)

  ;; f64.copysign
  (func (export "f64_copysign") (param f64 f64) (result f64)
    local.get 0 local.get 1 f64.copysign)

  ;; f32.reinterpret_i32
  (func (export "f32_reinterpret_i32") (param i32) (result f32)
    local.get 0 f32.reinterpret_i32)

  ;; i32.reinterpret_f32
  (func (export "i32_reinterpret_f32") (param f32) (result i32)
    local.get 0 i32.reinterpret_f32)

  ;; reinterpret roundtrip i32→f32→i32
  (func (export "reinterpret_roundtrip") (param i32) (result i32)
    local.get 0 f32.reinterpret_i32 i32.reinterpret_f32)

  ;; f32 load/store (needs memory)
  (memory (export "mem") 1)

  (func (export "f32_store_load") (param f32) (result f32)
    (f32.store (i32.const 0) (local.get 0))
    (f32.load (i32.const 0)))

  (func (export "f64_store_load") (param f64) (result f64)
    (f64.store (i32.const 0) (local.get 0))
    (f64.load (i32.const 0)))
)
