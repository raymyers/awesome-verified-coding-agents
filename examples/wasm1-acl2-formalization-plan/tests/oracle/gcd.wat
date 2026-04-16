(module
  (func $gcd (export "gcd") (param $a i32) (param $b i32) (result i32)
    (local $temp i32)
    (block $exit
      (loop $loop
        (br_if $exit (i32.eqz (local.get $b)))
        (local.set $temp (local.get $b))
        (local.set $b (i32.rem_u (local.get $a) (local.get $b)))
        (local.set $a (local.get $temp))
        (br $loop)))
    (local.get $a)))
