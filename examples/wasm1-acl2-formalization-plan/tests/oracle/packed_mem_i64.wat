(module
  (memory (export "memory") 1)
  (data (i32.const 0) "\ab\cd\ef\12\34\56\78\9a")

  (func $load8_u  (export "i64_load8_u")  (param $addr i32) (result i64) (i64.load8_u  (local.get $addr)))
  (func $load8_s  (export "i64_load8_s")  (param $addr i32) (result i64) (i64.load8_s  (local.get $addr)))
  (func $load16_u (export "i64_load16_u") (param $addr i32) (result i64) (i64.load16_u (local.get $addr)))
  (func $load16_s (export "i64_load16_s") (param $addr i32) (result i64) (i64.load16_s (local.get $addr)))
  (func $load32_u (export "i64_load32_u") (param $addr i32) (result i64) (i64.load32_u (local.get $addr)))
  (func $load32_s (export "i64_load32_s") (param $addr i32) (result i64) (i64.load32_s (local.get $addr)))

  (func $store8_load (export "i64_store8_load") (param $addr i32) (param $val i64) (result i64)
    (i64.store8 (local.get $addr) (local.get $val))
    (i64.load8_u (local.get $addr)))

  (func $store16_load (export "i64_store16_load") (param $addr i32) (param $val i64) (result i64)
    (i64.store16 (local.get $addr) (local.get $val))
    (i64.load16_u (local.get $addr)))

  (func $store32_load (export "i64_store32_load") (param $addr i32) (param $val i64) (result i64)
    (i64.store32 (local.get $addr) (local.get $val))
    (i64.load32_u (local.get $addr)))
)
