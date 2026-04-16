(module
  (memory (export "memory") 1)
  ;; [10, 20, 30, 40, 50] as i32 LE at offsets 0,4,8,12,16
  (data (i32.const 0) "\0a\00\00\00\14\00\00\00\1e\00\00\00\28\00\00\00\32\00\00\00")
  (func $sum_array (export "sum_array") (param $ptr i32) (param $len i32) (result i32)
    (local $sum i32) (local $i i32)
    (block $exit
      (loop $loop
        (br_if $exit (i32.ge_u (local.get $i) (local.get $len)))
        (local.set $sum
          (i32.add (local.get $sum)
                   (i32.load (i32.add (local.get $ptr)
                                      (i32.mul (local.get $i) (i32.const 4))))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $loop)))
    (local.get $sum)))
