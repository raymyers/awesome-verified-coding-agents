(module
  (func $collatz (export "collatz") (param $n i32) (result i32)
    (local $count i32)
    (block $exit
      (loop $loop
        (br_if $exit (i32.le_u (local.get $n) (i32.const 1)))
        (local.set $count (i32.add (local.get $count) (i32.const 1)))
        (if (i32.eqz (i32.rem_u (local.get $n) (i32.const 2)))
          (then (local.set $n (i32.div_u (local.get $n) (i32.const 2))))
          (else (local.set $n (i32.add (i32.mul (local.get $n) (i32.const 3)) (i32.const 1)))))
        (br $loop)))
    (local.get $count)))
