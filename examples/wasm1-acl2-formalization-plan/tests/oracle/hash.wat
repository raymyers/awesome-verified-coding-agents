(module
  (memory (export "memory") 1)
  (data (i32.const 0) "\48\69")  ;; "Hi" = 72, 105
  (func $djb2 (export "djb2") (param $ptr i32) (param $len i32) (result i32)
    (local $hash i32) (local $i i32)
    (local.set $hash (i32.const 5381))
    (block $exit
      (loop $loop
        (br_if $exit (i32.ge_u (local.get $i) (local.get $len)))
        (local.set $hash
          (i32.add
            (i32.mul (local.get $hash) (i32.const 33))
            (i32.and
              (i32.load (i32.add (local.get $ptr) (local.get $i)))
              (i32.const 255))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $loop)))
    (local.get $hash)))
