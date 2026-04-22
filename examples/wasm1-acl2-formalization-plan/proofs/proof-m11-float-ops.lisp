;; WASM 1.0 ACL2 — M11: New float instruction proofs
;;
;; Theorems + concrete tests for: f32/f64.trunc, f32/f64.nearest,
;; f32/f64.copysign, f32/f64.reinterpret, f32/f64 load/store
;;
;; Oracle: Node.js running compiled WAT (see tests/oracle/float_ops.wat)

(in-package "WASM")
(include-book "../execution")

(local (defconst *m11-theory*
  '(run execute-instr step
    execute-f32.const execute-f64.const
    execute-f32.trunc execute-f64.trunc
    execute-f32.nearest execute-f64.nearest
    execute-f32.copysign execute-f64.copysign
    execute-f32.reinterpret_i32 execute-i32.reinterpret_f32
    execute-f64.reinterpret_i64 execute-i64.reinterpret_f64
    execute-f32.load execute-f64.load
    execute-f32.store execute-f64.store
    execute-i32.const
    current-frame current-instrs current-operand-stack
    current-label-stack current-locals
    update-current-operand-stack update-current-instrs
    complete-label return-from-function
    make-f32-val make-f64-val make-i32-val make-i64-val
    f32-valp f64-valp i32-valp i64-valp
    f32-const-argsp f64-const-argsp i32-const-argsp no-argsp
    push-operand top-operand pop-operand top-n-operands push-vals
    operand-stack-height empty-operand-stack operand-stackp
    localsp framep top-frame push-call-stack pop-call-stack call-stackp
    valp u32p u64p
    update-memory)))

;; Helper: make a 1-frame state with given instructions
(defund mk-state (instrs)
  (declare (xargs :guard t :verify-guards nil))
  (make-state
   :store nil
   :call-stack (list (make-frame
                      :return-arity 1
                      :locals nil
                      :operand-stack (empty-operand-stack)
                      :instrs instrs
                      :label-stack nil))
   :memory nil
   :globals nil))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 1. f32.trunc tests — Oracle: Node f32_trunc

;; Oracle: f32_trunc(3.7)=3
(defthm f32-trunc-positive-frac
  (equal
   (top-operand
    (current-operand-stack
     (run 2 (mk-state (list '(:f32.const 37/10) '(:f32.trunc))))))
   '(:f32.const 3))
  :hints (("Goal" :in-theory (enable mk-state run execute-instr
                               execute-f32.const execute-f32.trunc
                               f32-valp f32-const-argsp no-argsp
                               make-f32-val
                               current-frame current-instrs current-operand-stack
                               update-current-operand-stack update-current-instrs
                               push-operand top-operand pop-operand
                               operand-stack-height empty-operand-stack
                               step return-from-function))))

;; Oracle: f32_trunc(-3.7)=-3
(defthm f32-trunc-negative-frac
  (equal
   (top-operand
    (current-operand-stack
     (run 2 (mk-state (list '(:f32.const -37/10) '(:f32.trunc))))))
   '(:f32.const -3))
  :hints (("Goal" :in-theory (enable mk-state run execute-instr
                               execute-f32.const execute-f32.trunc
                               f32-valp f32-const-argsp no-argsp
                               make-f32-val
                               current-frame current-instrs current-operand-stack
                               update-current-operand-stack update-current-instrs
                               push-operand top-operand pop-operand
                               operand-stack-height empty-operand-stack
                               step return-from-function))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 2. f32.nearest tests — Oracle: Node f32_nearest

;; Oracle: f32_nearest(2.5)=2  (ties to even: 2 is even)
(defthm f32-nearest-ties-to-even-down
  (equal
   (top-operand
    (current-operand-stack
     (run 2 (mk-state (list '(:f32.const 5/2) '(:f32.nearest))))))
   '(:f32.const 2))
  :hints (("Goal" :in-theory (enable mk-state run execute-instr
                               execute-f32.const execute-f32.nearest
                               f32-valp f32-const-argsp no-argsp
                               make-f32-val
                               current-frame current-instrs current-operand-stack
                               update-current-operand-stack update-current-instrs
                               push-operand top-operand pop-operand
                               operand-stack-height empty-operand-stack
                               step return-from-function))))

;; Oracle: f32_nearest(3.5)=4  (ties to even: 4 is even)
(defthm f32-nearest-ties-to-even-up
  (equal
   (top-operand
    (current-operand-stack
     (run 2 (mk-state (list '(:f32.const 7/2) '(:f32.nearest))))))
   '(:f32.const 4))
  :hints (("Goal" :in-theory (enable mk-state run execute-instr
                               execute-f32.const execute-f32.nearest
                               f32-valp f32-const-argsp no-argsp
                               make-f32-val
                               current-frame current-instrs current-operand-stack
                               update-current-operand-stack update-current-instrs
                               push-operand top-operand pop-operand
                               operand-stack-height empty-operand-stack
                               step return-from-function))))

;; Oracle: f32_nearest(0.5)=0  (ties to even: 0 is even)
(defthm f32-nearest-half-to-zero
  (equal
   (top-operand
    (current-operand-stack
     (run 2 (mk-state (list '(:f32.const 1/2) '(:f32.nearest))))))
   '(:f32.const 0))
  :hints (("Goal" :in-theory (enable mk-state run execute-instr
                               execute-f32.const execute-f32.nearest
                               f32-valp f32-const-argsp no-argsp
                               make-f32-val
                               current-frame current-instrs current-operand-stack
                               update-current-operand-stack update-current-instrs
                               push-operand top-operand pop-operand
                               operand-stack-height empty-operand-stack
                               step return-from-function))))

;; Oracle: f32_nearest(4.7)=5  (not a tie, rounds up)
(defthm f32-nearest-round-up
  (equal
   (top-operand
    (current-operand-stack
     (run 2 (mk-state (list '(:f32.const 47/10) '(:f32.nearest))))))
   '(:f32.const 5))
  :hints (("Goal" :in-theory (enable mk-state run execute-instr
                               execute-f32.const execute-f32.nearest
                               f32-valp f32-const-argsp no-argsp
                               make-f32-val
                               current-frame current-instrs current-operand-stack
                               update-current-operand-stack update-current-instrs
                               push-operand top-operand pop-operand
                               operand-stack-height empty-operand-stack
                               step return-from-function))))

;; Oracle: f32_nearest(-2.5)=-2  (ties to even: -2 is even)
(defthm f32-nearest-negative-ties-to-even
  (equal
   (top-operand
    (current-operand-stack
     (run 2 (mk-state (list '(:f32.const -5/2) '(:f32.nearest))))))
   '(:f32.const -2))
  :hints (("Goal" :in-theory (enable mk-state run execute-instr
                               execute-f32.const execute-f32.nearest
                               f32-valp f32-const-argsp no-argsp
                               make-f32-val
                               current-frame current-instrs current-operand-stack
                               update-current-operand-stack update-current-instrs
                               push-operand top-operand pop-operand
                               operand-stack-height empty-operand-stack
                               step return-from-function))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 3. f32.copysign tests — Oracle: Node f32_copysign

;; Oracle: f32_copysign(5,-3)=-5
(defthm f32-copysign-negative-sign
  (equal
   (top-operand
    (current-operand-stack
     (run 3 (mk-state (list '(:f32.const 5) '(:f32.const -3) '(:f32.copysign))))))
   '(:f32.const -5))
  :hints (("Goal" :in-theory (enable mk-state run execute-instr
                               execute-f32.const execute-f32.copysign
                               f32-valp f32-const-argsp no-argsp
                               make-f32-val
                               current-frame current-instrs current-operand-stack
                               update-current-operand-stack update-current-instrs
                               push-operand top-operand pop-operand
                               operand-stack-height empty-operand-stack
                               step return-from-function))))

;; Oracle: f32_copysign(-5,3)=5
(defthm f32-copysign-positive-sign
  (equal
   (top-operand
    (current-operand-stack
     (run 3 (mk-state (list '(:f32.const -5) '(:f32.const 3) '(:f32.copysign))))))
   '(:f32.const 5))
  :hints (("Goal" :in-theory (enable mk-state run execute-instr
                               execute-f32.const execute-f32.copysign
                               f32-valp f32-const-argsp no-argsp
                               make-f32-val
                               current-frame current-instrs current-operand-stack
                               update-current-operand-stack update-current-instrs
                               push-operand top-operand pop-operand
                               operand-stack-height empty-operand-stack
                               step return-from-function))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 4. f64.trunc tests — Oracle: Node f64_trunc

;; Oracle: f64_trunc(3.7)=3
(defthm f64-trunc-positive-frac
  (equal
   (top-operand
    (current-operand-stack
     (run 2 (mk-state (list '(:f64.const 37/10) '(:f64.trunc))))))
   '(:f64.const 3))
  :hints (("Goal" :in-theory (enable mk-state run execute-instr
                               execute-f64.const execute-f64.trunc
                               f64-valp f64-const-argsp no-argsp
                               make-f64-val
                               current-frame current-instrs current-operand-stack
                               update-current-operand-stack update-current-instrs
                               push-operand top-operand pop-operand
                               operand-stack-height empty-operand-stack
                               step return-from-function))))

;; Oracle: f64_trunc(-3.7)=-3
(defthm f64-trunc-negative-frac
  (equal
   (top-operand
    (current-operand-stack
     (run 2 (mk-state (list '(:f64.const -37/10) '(:f64.trunc))))))
   '(:f64.const -3))
  :hints (("Goal" :in-theory (enable mk-state run execute-instr
                               execute-f64.const execute-f64.trunc
                               f64-valp f64-const-argsp no-argsp
                               make-f64-val
                               current-frame current-instrs current-operand-stack
                               update-current-operand-stack update-current-instrs
                               push-operand top-operand pop-operand
                               operand-stack-height empty-operand-stack
                               step return-from-function))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 5. f64.nearest tests

;; Oracle: f64_nearest(2.5)=2
(defthm f64-nearest-ties-to-even-down
  (equal
   (top-operand
    (current-operand-stack
     (run 2 (mk-state (list '(:f64.const 5/2) '(:f64.nearest))))))
   '(:f64.const 2))
  :hints (("Goal" :in-theory (enable mk-state run execute-instr
                               execute-f64.const execute-f64.nearest
                               f64-valp f64-const-argsp no-argsp
                               make-f64-val
                               current-frame current-instrs current-operand-stack
                               update-current-operand-stack update-current-instrs
                               push-operand top-operand pop-operand
                               operand-stack-height empty-operand-stack
                               step return-from-function))))

;; Oracle: f64_nearest(3.5)=4
(defthm f64-nearest-ties-to-even-up
  (equal
   (top-operand
    (current-operand-stack
     (run 2 (mk-state (list '(:f64.const 7/2) '(:f64.nearest))))))
   '(:f64.const 4))
  :hints (("Goal" :in-theory (enable mk-state run execute-instr
                               execute-f64.const execute-f64.nearest
                               f64-valp f64-const-argsp no-argsp
                               make-f64-val
                               current-frame current-instrs current-operand-stack
                               update-current-operand-stack update-current-instrs
                               push-operand top-operand pop-operand
                               operand-stack-height empty-operand-stack
                               step return-from-function))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 6. f64.copysign test

;; Oracle: f64_copysign(5,-3)=-5
(defthm f64-copysign-negative-sign
  (equal
   (top-operand
    (current-operand-stack
     (run 3 (mk-state (list '(:f64.const 5) '(:f64.const -3) '(:f64.copysign))))))
   '(:f64.const -5))
  :hints (("Goal" :in-theory (enable mk-state run execute-instr
                               execute-f64.const execute-f64.copysign
                               f64-valp f64-const-argsp no-argsp
                               make-f64-val
                               current-frame current-instrs current-operand-stack
                               update-current-operand-stack update-current-instrs
                               push-operand top-operand pop-operand
                               operand-stack-height empty-operand-stack
                               step return-from-function))))

;; All tests pass if this file loads without error.
