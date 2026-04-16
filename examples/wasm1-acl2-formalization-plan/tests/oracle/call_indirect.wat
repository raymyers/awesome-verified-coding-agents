(module
  ;; Type for functions: (i32) -> (i32)
  (type $t0 (func (param i32) (result i32)))

  ;; Table with 2 entries, initialized via elem segment
  (table 2 funcref)
  (elem (i32.const 0) $double $inc)

  ;; func 0: double(x) = x + x
  (func $double (type $t0) (param $x i32) (result i32)
    local.get $x
    local.get $x
    i32.add)

  ;; func 1: inc(x) = x + 1
  (func $inc (type $t0) (param $x i32) (result i32)
    local.get $x
    i32.const 1
    i32.add)

  ;; dispatch(x, idx) = table[idx](x)
  (func (export "dispatch") (param $x i32) (param $idx i32) (result i32)
    local.get $x
    local.get $idx
    call_indirect (type $t0)))
