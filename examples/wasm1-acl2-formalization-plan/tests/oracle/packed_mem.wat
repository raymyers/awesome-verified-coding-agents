(module
  (memory (export "memory") 1)
  ;; At address 0: bytes [0xAB, 0xCD, 0xEF, 0x12, 0x34, 0x56, 0x78, 0x9A]
  (data (i32.const 0) "\ab\cd\ef\12\34\56\78\9a")

  (func $load8_u  (export "load8_u")  (param $addr i32) (result i32) (i32.load8_u  (local.get $addr)))
  (func $load8_s  (export "load8_s")  (param $addr i32) (result i32) (i32.load8_s  (local.get $addr)))
  (func $load16_u (export "load16_u") (param $addr i32) (result i32) (i32.load16_u (local.get $addr)))
  (func $load16_s (export "load16_s") (param $addr i32) (result i32) (i32.load16_s (local.get $addr)))

  (func $store8_load (export "store8_load") (param $addr i32) (param $val i32) (result i32)
    (i32.store8 (local.get $addr) (local.get $val))
    (i32.load8_u (local.get $addr)))

  (func $store16_load (export "store16_load") (param $addr i32) (param $val i32) (result i32)
    (i32.store16 (local.get $addr) (local.get $val))
    (i32.load16_u (local.get $addr)))
)
