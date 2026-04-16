(module
  (func $is_prime (export "is_prime") (param $n i32) (result i32)
    (local $i i32)
    (if (i32.lt_u (local.get $n) (i32.const 2))
      (then (return (i32.const 0))))
    (local.set $i (i32.const 2))
    (block $exit
      (loop $loop
        (br_if $exit (i32.gt_u (i32.mul (local.get $i) (local.get $i)) (local.get $n)))
        (if (i32.eqz (i32.rem_u (local.get $n) (local.get $i)))
          (then (return (i32.const 0))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $loop)))
    (i32.const 1)))
