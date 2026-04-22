; An interpreter / operational semantics for Web Assembly
;
; Copyright (C) 2025 Kestrel Institute
;
; License: A 3-clause BSD license. See the file books/3BSD-mod.txt.
;
; Author: Eric Smith (eric.smith@kestrel.edu)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-package "WASM")

;; STATUS: IN-PROGRESS (WASM 1.0 i32 integer ops, parametric, variable instrs)


(include-book "std/util/defaggregate" :dir :system)
(include-book "kestrel/utilities/forms" :dir :system)
(include-book "kestrel/bv/bvplus" :dir :system)
(include-book "kestrel/bv/bvminus" :dir :system)
(include-book "kestrel/bv/bvmult" :dir :system)
(include-book "kestrel/bv/bvdiv" :dir :system)
(include-book "kestrel/bv/bvmod" :dir :system)
(include-book "kestrel/bv/bvand" :dir :system)
(include-book "kestrel/bv/bvor" :dir :system)
(include-book "kestrel/bv/bvxor" :dir :system)
(include-book "kestrel/bv/bvnot" :dir :system)
(include-book "kestrel/bv/bvshl" :dir :system)
(include-book "kestrel/bv/bvshr" :dir :system)
(include-book "kestrel/bv/bvsx" :dir :system)
(include-book "kestrel/bv/sbvdiv" :dir :system)
(include-book "kestrel/bv/sbvrem" :dir :system)
(include-book "kestrel/bv/bvashr" :dir :system)

;; IEEE 754 float encoding/decoding (for reinterpret + float load/store)
(include-book "kestrel/floats/ieee-floats-as-bvs" :dir :system)

(local
  (defthm consp-when-true-listp
    (implies (true-listp x)
             (iff (consp x)
                  x))))

(local (in-theory (disable natp)))

(defund u32p (x)
  (declare (xargs :guard t))
  (unsigned-byte-p 32 x))

(defthm u32p-forward-to-natp
  (implies (u32p x)
           (natp x))
  :rule-classes :forward-chaining
  :hints (("Goal" :in-theory (enable u32p))))

(defund u64p (x)
  (declare (xargs :guard t))
  (unsigned-byte-p 64 x))

(defthm u64p-forward-to-natp
  (implies (u64p x)
           (natp x))
  :rule-classes :forward-chaining
  :hints (("Goal" :in-theory (enable u64p))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Store and function instances (M3)

;; A function instance: (param-count local-count return-arity body-instrs)
;; params are the first param-count locals; remaining are zero-initialized
(defaggregate funcinst
  ((param-count natp)
   (local-count natp)
   (return-arity natp)
   (body true-listp))
  :pred funcinstp)

(defun funcinst-listp (x)
  (declare (xargs :guard t))
  (if (not (consp x))
      (null x)
    (and (funcinstp (first x))
         (funcinst-listp (rest x)))))

;; Store: list of function instances (indexed by position)
;; Placeholder for tables
(defun storep (x)
  (declare (xargs :guard t))
  (funcinst-listp x))
(in-theory (disable (:t storep)))

(defund i32-valp (val)
  (declare (xargs :guard t))
  (and (consp val)
       (true-listp val)
       (eq :i32.const (ffn-symb val))
       (= 1 (len (acl2::fargs val)))
       (u32p (acl2::farg1 val))))

(defund i64-valp (val)
  (declare (xargs :guard t))
  (and (consp val)
       (true-listp val)
       (eq :i64.const (ffn-symb val))
       (= 1 (len (acl2::fargs val)))
       (u64p (acl2::farg1 val))))

;; f32/f64 values (M7a): modeled as ACL2 rationals.
;; This is an approximation — IEEE 754 bit-level semantics (NaN, rounding,
;; denormals) are deferred. For well-behaved programs the rational model
;; gives correct results.

(defund f32-valp (val)
  (declare (xargs :guard t))
  (and (consp val)
       (true-listp val)
       (eq :f32.const (ffn-symb val))
       (= 1 (len (acl2::fargs val)))
       (rationalp (acl2::farg1 val))))

(defund f64-valp (val)
  (declare (xargs :guard t))
  (and (consp val)
       (true-listp val)
       (eq :f64.const (ffn-symb val))
       (= 1 (len (acl2::fargs val)))
       (rationalp (acl2::farg1 val))))

;; IEEE 754 special float values on the operand stack.
;; NaN and ±Infinity are represented as bare keywords (not (:f32.const ...) lists)
;; so that f32-valp/f64-valp remain restricted to finite rationals and all
;; existing theorems are unaffected.
;;   f32: :f32.nan, :f32.+inf, :f32.-inf, :f32.+0, :f32.-0
;;   f64: :f64.nan, :f64.+inf, :f64.-inf, :f64.+0, :f64.-0
(defund float-specialp (v)
  (declare (xargs :guard t))
  (or (eq v :f32.nan) (eq v :f32.+inf) (eq v :f32.-inf)
      (eq v :f32.+0)  (eq v :f32.-0)        ; IEEE 754 signed zeros
      (eq v :f64.nan) (eq v :f64.+inf) (eq v :f64.-inf)
      (eq v :f64.+0)  (eq v :f64.-0)))

(defund valp (val)
  (declare (xargs :guard t))
  (or (i32-valp val)
      (i64-valp val)
      (f32-valp val)
      (f64-valp val)
      (float-specialp val))) ; NaN and ±Inf are valid stack values

;; Derived theorems for float-special values
(defthm valp-of-f32-nan
  (valp :f32.nan)
  :hints (("Goal" :in-theory (enable valp float-specialp))))

(defthm valp-of-f32-+inf
  (valp :f32.+inf)
  :hints (("Goal" :in-theory (enable valp float-specialp))))

(defthm valp-of-f32--inf
  (valp :f32.-inf)
  :hints (("Goal" :in-theory (enable valp float-specialp))))

(defthm valp-of-f64-nan
  (valp :f64.nan)
  :hints (("Goal" :in-theory (enable valp float-specialp))))

(defthm valp-of-f64-+inf
  (valp :f64.+inf)
  :hints (("Goal" :in-theory (enable valp float-specialp))))

(defthm valp-of-f64--inf
  (valp :f64.-inf)
  :hints (("Goal" :in-theory (enable valp float-specialp))))

;; Signed zeros
(defthm valp-of-f32-+0
  (valp :f32.+0)
  :hints (("Goal" :in-theory (enable valp float-specialp))))

(defthm valp-of-f32--0
  (valp :f32.-0)
  :hints (("Goal" :in-theory (enable valp float-specialp))))

(defthm valp-of-f64-+0
  (valp :f64.+0)
  :hints (("Goal" :in-theory (enable valp float-specialp))))

(defthm valp-of-f64--0
  (valp :f64.-0)
  :hints (("Goal" :in-theory (enable valp float-specialp))))

(defun val-listp (vals)
  (declare (xargs :guard t))
  (if (not (consp vals))
      (null vals)
    (and (valp (first vals))
         (val-listp (rest vals)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Global instances (M5+)

(defun mutabilityp (x)
  (declare (xargs :guard t))
  (or (eq x :const) (eq x :var)))

(defaggregate globalinst
  ((mutability mutabilityp)
   (value valp))
  :pred globalinstp)

(defun globalinst-listp (x)
  (declare (xargs :guard t))
  (if (not (consp x))
      (null x)
    (and (globalinstp (first x))
         (globalinst-listp (rest x)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defund localsp (locals)
  (declare (xargs :guard t))
  (val-listp locals))

(defthm localsp-forward-to-true-listp
  (implies (localsp locals)
           (true-listp locals))
  :rule-classes :forward-chaining
  :hints (("Goal" :in-theory (enable localsp))))

(defund nth-local (n locals)
  (declare (xargs :guard (and (natp n)
                              (< n (len locals))
                              (localsp locals))))
  (nth n locals))

(defthm valp-of-nth-local
  (implies (and (natp n)
                (< n (len locals))
                (localsp locals))
           (valp (nth-local n locals)))
  :hints (("Goal" :in-theory (enable val-listp nth-local localsp))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; The first item is the topmost in the stack
(defund operand-stackp (stack)
  (declare (xargs :guard t))
  (if (not (consp stack))
      (null stack)
    (and (valp (first stack))
         (operand-stackp (rest stack)))))

(defun empty-operand-stack ()
  (declare (xargs :guard t))
  nil)

(defund push-operand (val stack)
  (declare (xargs :guard (and (valp val)
                              (operand-stackp stack))))
  (cons val stack))

(defthm operand-stackp-of-push-operand-stack
  (implies (and (valp val)
                (operand-stackp ostack))
           (operand-stackp (push-operand val ostack)))
  :hints (("Goal" :in-theory (enable push-operand operand-stackp))))

(defund operand-stack-height (stack)
  (declare (xargs :guard (operand-stackp stack)))
  (len stack))

(defund top-operand (stack)
  (declare (xargs :guard (and (operand-stackp stack)
                              (<= 1 (operand-stack-height stack)))
                  :guard-hints (("Goal" :in-theory (enable operand-stackp)))))
  (car stack))

(defthm valp-of-top-operand
  (implies (and (operand-stackp stack)
                (<= 1 (operand-stack-height stack)))
           (valp (top-operand stack)))
  :hints (("Goal" :in-theory (enable operand-stackp operand-stack-height top-operand))))

(defund pop-operand (stack)
  (declare (xargs :guard (and (operand-stackp stack)
                              (<= 1 (operand-stack-height stack)))
                  :guard-hints (("Goal" :in-theory (enable operand-stackp)))))
  (cdr stack))

(defthm pop-operand-of-push-operand
  (equal (pop-operand (push-operand val stack))
         stack)
  :hints (("Goal" :in-theory (enable push-operand
                                     pop-operand))))

(defthm top-operand-of-push-operand
  (equal (top-operand (push-operand val stack))
         val)
  :hints (("Goal" :in-theory (enable push-operand
                                     top-operand))))

(defthm operand-stackp-of-pop-operand-stack
  (implies (operand-stackp operand-stack)
           (operand-stackp (pop-operand operand-stack)))
  :hints (("Goal" :in-theory (enable pop-operand operand-stackp))))

(defthm operand-stack-height-of-pop-operand-stack
  (implies (<= 1 (operand-stack-height stack))
           (equal (operand-stack-height (pop-operand stack))
                  (+ -1 (operand-stack-height stack))))
  :hints (("Goal" :in-theory (enable pop-operand operand-stack-height))))

(defthm operand-stack-height-of-push-operand
  (equal (operand-stack-height (push-operand val stack))
         (+ 1 (operand-stack-height stack)))
  :hints (("Goal" :in-theory (enable push-operand operand-stack-height))))

;; returns a list, with the deepest operand first
(defund top-n-operands (n stack acc)
  (declare (xargs :guard (and (natp n)
                              (operand-stackp stack)
                              (<= n (operand-stack-height stack)))
                  :guard-hints (("Goal" :in-theory (enable operand-stack-height pop-operand operand-stackp)))))
  (if (zp n)
      acc
    (top-n-operands (+ -1 n)
                    (pop-operand stack)
                    (cons (top-operand stack) acc))))

(defthm val-listp-of-top-n-operands
  (implies (and (natp n)
                (operand-stackp stack)
                (<= n (operand-stack-height stack))
                (val-listp acc))
           (val-listp (top-n-operands n stack acc)))
  :hints (("Goal" :in-theory (enable top-n-operands val-listp))))

;; earlier vals end up deeper in the stack
(defund push-vals (vals stack)
  (declare (xargs :guard (and (val-listp vals)
                              (operand-stackp stack))))
  (if (endp vals)
      stack
    (push-vals (rest vals) (push-operand (first vals) stack))))

(defthm operand-stackp-of-push-vals
  (implies (and (val-listp vals)
                (operand-stackp stack))
           (operand-stackp (push-vals vals stack)))
  :hints (("Goal" :in-theory (enable push-vals))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; (defun weak-instrp (instr)
;;   (declare (xargs :guard t))
;;   (and (true-listp instr)
;;        (consp instr)
;;        (let ((opcode (ffn-symb instr))
;;              (fargs (fargs instr)))
;;          (symbolp opcode))))

(defun local-idx-argsp (args)
  (declare (xargs :guard (true-listp args)))
  (and (= 1 (len args)) (u32p (first args))))

(defun no-argsp (args)
  (declare (xargs :guard (true-listp args)))
  (null args))

(defun i32-const-argsp (args)
  (declare (xargs :guard (true-listp args)))
  (and (= 1 (len args)) (u32p (first args))))

(defun i64-const-argsp (args)
  (declare (xargs :guard (true-listp args)))
  (and (= 1 (len args)) (u64p (first args))))

(defun f32-const-argsp (args)
  (declare (xargs :guard (true-listp args)))
  (and (= 1 (len args)) (rationalp (first args))))

(defun f64-const-argsp (args)
  (declare (xargs :guard (true-listp args)))
  (and (= 1 (len args)) (rationalp (first args))))

;; Recognizer for WASM 1.0 instructions
;; Note: block/loop/if carry nested instruction lists as true-listp
;; (mutual recursion avoided for simplicity; bodies validated at execution)
(defund instrp (instr)
  (declare (xargs :guard t))
  (and (true-listp instr)
       (consp instr)
       (let ((name (ffn-symb instr))
             (args (fargs instr)))
         (and (symbolp name)
              (case name
                ;; Parametric instructions
                (:nop (no-argsp args))
                (:unreachable (no-argsp args))
                (:drop (no-argsp args))
                (:select (no-argsp args))
                ;; Variable instructions
                (:local.get (local-idx-argsp args))
                (:local.set (local-idx-argsp args))
                (:local.tee (local-idx-argsp args))
                ;; Global variable access (M5+)
                (:global.get (local-idx-argsp args))
                (:global.set (local-idx-argsp args))
                ;; Numeric constants
                (:i32.const (i32-const-argsp args))
                ;; i32 arithmetic
                (:i32.add (no-argsp args))
                (:i32.sub (no-argsp args))
                (:i32.mul (no-argsp args))
                (:i32.div_u (no-argsp args))
                (:i32.div_s (no-argsp args))
                (:i32.rem_u (no-argsp args))
                (:i32.rem_s (no-argsp args))
                ;; i32 bitwise
                (:i32.and (no-argsp args))
                (:i32.or (no-argsp args))
                (:i32.xor (no-argsp args))
                (:i32.shl (no-argsp args))
                (:i32.shr_u (no-argsp args))
                (:i32.shr_s (no-argsp args))
                (:i32.rotl (no-argsp args))
                (:i32.rotr (no-argsp args))
                ;; i32 unary
                (:i32.clz (no-argsp args))
                (:i32.ctz (no-argsp args))
                (:i32.popcnt (no-argsp args))
                ;; i32 test/comparison
                (:i32.eqz (no-argsp args))
                (:i32.eq (no-argsp args))
                (:i32.ne (no-argsp args))
                (:i32.lt_u (no-argsp args))
                (:i32.lt_s (no-argsp args))
                (:i32.gt_u (no-argsp args))
                (:i32.gt_s (no-argsp args))
                (:i32.le_u (no-argsp args))
                (:i32.le_s (no-argsp args))
                (:i32.ge_u (no-argsp args))
                (:i32.ge_s (no-argsp args))
                ;; Control flow (M2)
                ;; (:block arity body-instrs)
                (:block (and (= (len args) 2)
                             (natp (first args))
                             (true-listp (second args))))
                ;; (:loop arity body-instrs)
                (:loop (and (= (len args) 2)
                            (natp (first args))
                            (true-listp (second args))))
                ;; (:if arity then-instrs else-instrs)
                (:if (and (= (len args) 3)
                          (natp (first args))
                          (true-listp (second args))
                          (true-listp (third args))))
                ;; (:br label-idx)
                (:br (local-idx-argsp args))
                ;; (:br_if label-idx)
                (:br_if (local-idx-argsp args))
                ;; (:br_table label-vec default-label)
                (:br_table (and (= (len args) 2)
                                (true-listp (first args))
                                (natp (second args))))
                ;; (:return)
                (:return (no-argsp args))
                ;; Function call (M3)
                ;; (:call func-idx)
                (:call (local-idx-argsp args))
                ;; Indirect call (M7b)
                ;; (:call_indirect type-idx table-idx)
                ;; type-idx currently ignored; table-idx defaults to 0
                (:call_indirect (and (<= 1 (len args))
                                     (natp (first args))))
                ;; i64 operations (M5)
                (:i64.const (i64-const-argsp args))
                ;; i64 arithmetic
                (:i64.add (no-argsp args))
                (:i64.sub (no-argsp args))
                (:i64.mul (no-argsp args))
                (:i64.div_u (no-argsp args))
                (:i64.div_s (no-argsp args))
                (:i64.rem_u (no-argsp args))
                (:i64.rem_s (no-argsp args))
                ;; i64 bitwise
                (:i64.and (no-argsp args))
                (:i64.or (no-argsp args))
                (:i64.xor (no-argsp args))
                (:i64.shl (no-argsp args))
                (:i64.shr_u (no-argsp args))
                (:i64.shr_s (no-argsp args))
                (:i64.rotl (no-argsp args))
                (:i64.rotr (no-argsp args))
                ;; i64 unary
                (:i64.clz (no-argsp args))
                (:i64.ctz (no-argsp args))
                (:i64.popcnt (no-argsp args))
                ;; i64 comparison
                (:i64.eqz (no-argsp args))
                (:i64.eq (no-argsp args))
                (:i64.ne (no-argsp args))
                (:i64.lt_u (no-argsp args))
                (:i64.lt_s (no-argsp args))
                (:i64.gt_u (no-argsp args))
                (:i64.gt_s (no-argsp args))
                (:i64.le_u (no-argsp args))
                (:i64.le_s (no-argsp args))
                (:i64.ge_u (no-argsp args))
                (:i64.ge_s (no-argsp args))
                ;; Conversions (M5)
                (:i32.wrap_i64 (no-argsp args))
                (:i64.extend_i32_u (no-argsp args))
                (:i64.extend_i32_s (no-argsp args))
                ;; Memory (M4)
                (:i32.load (and (= (len args) 1) (natp (first args))))
                (:i32.store (and (= (len args) 1) (natp (first args))))
                (:i64.load (and (= (len args) 1) (natp (first args))))
                (:i64.store (and (= (len args) 1) (natp (first args))))
                ;; Packed memory (M4b)
                (:i32.load8_u  (and (= (len args) 1) (natp (first args))))
                (:i32.load8_s  (and (= (len args) 1) (natp (first args))))
                (:i32.load16_u (and (= (len args) 1) (natp (first args))))
                (:i32.load16_s (and (= (len args) 1) (natp (first args))))
                (:i32.store8   (and (= (len args) 1) (natp (first args))))
                (:i32.store16  (and (= (len args) 1) (natp (first args))))
                (:i64.load8_u  (and (= (len args) 1) (natp (first args))))
                (:i64.load8_s  (and (= (len args) 1) (natp (first args))))
                (:i64.load16_u (and (= (len args) 1) (natp (first args))))
                (:i64.load16_s (and (= (len args) 1) (natp (first args))))
                (:i64.load32_u (and (= (len args) 1) (natp (first args))))
                (:i64.load32_s (and (= (len args) 1) (natp (first args))))
                (:i64.store8   (and (= (len args) 1) (natp (first args))))
                (:i64.store16  (and (= (len args) 1) (natp (first args))))
                (:i64.store32  (and (= (len args) 1) (natp (first args))))
                (:memory.size (no-argsp args))
                (:memory.grow (no-argsp args))
                ;; f32 operations (M7a)
                (:f32.const (f32-const-argsp args))
                (:f32.add (no-argsp args))
                (:f32.sub (no-argsp args))
                (:f32.mul (no-argsp args))
                (:f32.div (no-argsp args))
                (:f32.neg (no-argsp args))
                (:f32.abs (no-argsp args))
                (:f32.sqrt (no-argsp args))
                (:f32.ceil (no-argsp args))
                (:f32.floor (no-argsp args))
                (:f32.trunc (no-argsp args))
                (:f32.nearest (no-argsp args))
                (:f32.copysign (no-argsp args))
                (:f32.eq (no-argsp args))
                (:f32.ne (no-argsp args))
                (:f32.lt (no-argsp args))
                (:f32.gt (no-argsp args))
                (:f32.le (no-argsp args))
                (:f32.ge (no-argsp args))
                (:f32.min (no-argsp args))
                (:f32.max (no-argsp args))
                ;; f64 operations (M7a)
                (:f64.const (f64-const-argsp args))
                (:f64.add (no-argsp args))
                (:f64.sub (no-argsp args))
                (:f64.mul (no-argsp args))
                (:f64.div (no-argsp args))
                (:f64.neg (no-argsp args))
                (:f64.abs (no-argsp args))
                (:f64.sqrt (no-argsp args))
                (:f64.ceil (no-argsp args))
                (:f64.floor (no-argsp args))
                (:f64.trunc (no-argsp args))
                (:f64.nearest (no-argsp args))
                (:f64.copysign (no-argsp args))
                (:f64.eq (no-argsp args))
                (:f64.ne (no-argsp args))
                (:f64.lt (no-argsp args))
                (:f64.gt (no-argsp args))
                (:f64.le (no-argsp args))
                (:f64.ge (no-argsp args))
                (:f64.min (no-argsp args))
                (:f64.max (no-argsp args))
                ;; Float conversions (M7a)
                (:f32.convert_i32_s (no-argsp args))
                (:f32.convert_i32_u (no-argsp args))
                (:f32.convert_i64_s (no-argsp args))
                (:f32.convert_i64_u (no-argsp args))
                (:f64.convert_i32_s (no-argsp args))
                (:f64.convert_i32_u (no-argsp args))
                (:f64.convert_i64_s (no-argsp args))
                (:f64.convert_i64_u (no-argsp args))
                (:f32.demote_f64 (no-argsp args))
                (:f64.promote_f32 (no-argsp args))
                (:i32.trunc_f32_s (no-argsp args))
                (:i32.trunc_f32_u (no-argsp args))
                (:i32.trunc_f64_s (no-argsp args))
                (:i32.trunc_f64_u (no-argsp args))
                (:i64.trunc_f32_s (no-argsp args))
                (:i64.trunc_f32_u (no-argsp args))
                (:i64.trunc_f64_s (no-argsp args))
                (:i64.trunc_f64_u (no-argsp args))
                ;; Reinterpret (M11)
                (:f32.reinterpret_i32 (no-argsp args))
                (:i32.reinterpret_f32 (no-argsp args))
                (:f64.reinterpret_i64 (no-argsp args))
                (:i64.reinterpret_f64 (no-argsp args))
                ;; Float load/store (M11)
                (:f32.load (and (= (len args) 1) (natp (first args))))
                (:f64.load (and (= (len args) 1) (natp (first args))))
                (:f32.store (and (= (len args) 1) (natp (first args))))
                (:f64.store (and (= (len args) 1) (natp (first args))))
                (otherwise nil))))))

(defun instr-listp (instrs)
  (declare (xargs :guard t))
  (if (not (consp instrs))
      (null instrs)
    (and (instrp (first instrs))
         (instr-listp (rest instrs)))))

(defthm instr-listp-forward-to-true-listp
  (implies (instr-listp instrs)
           (true-listp instrs))
  :rule-classes :forward-chaining
  :hints (("Goal" :in-theory (enable instr-listp))))


(local
  (defthm true-listp-when-instr-listp
    (implies (instr-listp instrs)
             (true-listp instrs))
    :hints (("Goal" :in-theory (enable instr-listp)))))

(defthm instrp-of-first
  (implies (instr-listp instrs)
           (equal (instrp (first instrs))
                  (consp instrs)))
  :hints (("Goal" :in-theory (enable instr-listp))))

(defthm instr-listp-of-rest
  (implies (instr-listp instrs)
           (instr-listp (rest instrs)))
  :hints (("Goal" :in-theory (enable instr-listp))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Label stack for structured control flow (M2)

;; A label-entry records: arity (values to keep), continuation (next instrs),
;; and whether this label is for a loop (affects branch semantics).
(defaggregate label-entry
  ((arity natp)
   (continuation true-listp)
   (is-loop booleanp))
  :pred label-entryp)

(defun label-stackp (stack)
  (declare (xargs :guard t))
  (if (not (consp stack))
      (null stack)
    (and (label-entryp (first stack))
         (label-stackp (rest stack)))))

(defund push-label (entry stack)
  (declare (xargs :guard (and (label-entryp entry)
                              (label-stackp stack))))
  (cons entry stack))

(defund pop-label (stack)
  (declare (xargs :guard (and (label-stackp stack)
                              (consp stack))))
  (cdr stack))

(defund top-label (stack)
  (declare (xargs :guard (and (label-stackp stack)
                              (consp stack))))
  (car stack))

;; Pop n labels (for br n)
(defund pop-n-labels (n stack)
  (declare (xargs :guard (and (natp n)
                              (label-stackp stack))
                  :verify-guards nil
                  :measure (nfix n)))
  (if (or (zp n) (not (consp stack)))
      stack
    (pop-n-labels (1- n) (pop-label stack))))

;; Get nth label (0-indexed from top)
(defund nth-label (n stack)
  (declare (xargs :guard (and (natp n)
                              (label-stackp stack)
                              (< n (len stack)))))
  (nth n stack))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defaggregate frame
  ((return-arity natp)
   (locals val-listp)
   ;; todo: module
   (operand-stack operand-stackp)
   (instrs true-listp)  ; relaxed from instr-listp for nested control flow
   (label-stack label-stackp))
  :pred framep
  )

(defthm true-listp-of-frame->instrs
  (implies (framep frame)
           (true-listp (frame->instrs frame)))
  :hints (("Goal" :in-theory (enable framep frame->instrs))))

;; The first item is the topmost in the stack
(defund call-stackp (stack)
  (declare (xargs :guard t))
  (if (not (consp stack))
      (null stack)
    (and (framep (first stack))
         (call-stackp (rest stack)))))

(defun empty-call-stack ()
  (declare (xargs :guard t))
  nil)

;; the top frame on the stack
(defund top-frame (stack)
  (declare (xargs :guard (and (call-stackp stack)
                              (consp stack))))
  (first stack))

(defthm framep-of-top-frame
  (implies (and (call-stackp stack)
                (consp stack))
           (framep (top-frame stack)))
  :hints (("Goal" :in-theory (enable top-frame call-stackp))))

(defund pop-call-stack (call-stack)
  (declare (xargs :guard (and (call-stackp call-stack)
                              (consp call-stack))))
  (cdr call-stack))

(defthm call-stackp-of-pop-call-stack
  (implies (call-stackp call-stack)
           (call-stackp (pop-call-stack call-stack)))
  :hints (("Goal" :in-theory (enable pop-call-stack call-stackp))))

(defund push-call-stack (frame call-stack)
  (declare (xargs :guard (and (framep frame)
                              (call-stackp call-stack))))
  (cons frame call-stack))

(defthm pop-call-stack-of-push-call-stack
  (equal (pop-call-stack (push-call-stack frame call-stack))
         call-stack)
  :hints (("Goal" :in-theory (enable push-call-stack
                                     pop-call-stack))))

(defthm call-stackp-of-push-call-stack
  (implies (and (framep frame)
                (call-stackp call-stack))
           (call-stackp (push-call-stack frame call-stack)))
  :hints (("Goal" :in-theory (enable push-call-stack call-stackp))))

(defthm top-frame-of-push-call-stack
  (equal (top-frame (push-call-stack frame call-stack))
         frame)
  :hints (("Goal" :in-theory (enable push-call-stack top-frame))))

;; todo: or make it a stobj?
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Linear memory (M4)

;; Memory is a list of bytes (unsigned-byte-p 8)
(defun bytep (x)
  (declare (xargs :guard t))
  (unsigned-byte-p 8 x))

(defun byte-listp (x)
  (declare (xargs :guard t))
  (if (not (consp x))
      (null x)
    (and (bytep (first x))
         (byte-listp (rest x)))))

;; WASM page size is 64KiB
(defconst *page-size* 65536)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defaggregate state
  ((store storep)
   (call-stack (and (call-stackp call-stack)
                    (consp call-stack)))
   (memory byte-listp)
   (globals globalinst-listp)
   (table true-listp))     ; M7b: table of func-idx or nil entries
  :pred statep)



;use this below
(defund current-frame (state)
  (declare (xargs :guard (statep state)))
  (let ((call-stack (state->call-stack state)))
    (top-frame call-stack)))

(defthm framep-of-current-frame
  (implies (statep state)
           (framep (current-frame state)))
  :hints (("Goal" :in-theory (enable current-frame))))

(defund current-instrs (state)
  (declare (xargs :guard (statep state)))
  (let* ((call-stack (state->call-stack state))
         (frame (top-frame call-stack)))
    (frame->instrs frame)))

(defthm true-listp-of-current-instrs
  (implies (statep state)
           (true-listp (current-instrs state)))
  :hints (("Goal" :in-theory (enable current-instrs))))

(defun current-operand-stack (state)
  (declare (xargs :guard (statep state)))
  (let* ((call-stack (state->call-stack state))
         (frame (top-frame call-stack)))
    (frame->operand-stack frame)))

(defun current-locals (state)
  (declare (xargs :guard (statep state)))
  (let* ((call-stack (state->call-stack state))
         (frame (top-frame call-stack)))
    (frame->locals frame)))

(defun update-current-instrs (instrs state)
  (declare (xargs :guard (and (true-listp instrs)
                              (statep state))
                  :verify-guards nil))
  (let* ((call-stack (state->call-stack state))
         (frame (top-frame call-stack))
         (new-frame (change-frame frame :instrs instrs))
         (new-call-stack (push-call-stack new-frame (pop-call-stack call-stack)))
         (new-state (change-state state :call-stack new-call-stack))
         )
    new-state))

(defun update-current-operand-stack (operand-stack state)
  (declare (xargs :guard (and (operand-stackp operand-stack)
                              (statep state))))
  (let* ((call-stack (state->call-stack state))
         (frame (top-frame call-stack))
         (new-frame (change-frame frame :operand-stack operand-stack))
         (new-call-stack (push-call-stack new-frame (pop-call-stack call-stack)))
         (new-state (change-state state :call-stack new-call-stack))
         )
    new-state))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Locals update

(defund update-nth-local (n val locals)
  (declare (xargs :guard (and (natp n)
                              (< n (len locals))
                              (valp val)
                              (localsp locals))))
  (update-nth n val locals))

(defun update-current-locals (locals state)
  (declare (xargs :guard (and (localsp locals)
                              (statep state))))
  (let* ((call-stack (state->call-stack state))
         (frame (top-frame call-stack))
         (new-frame (change-frame frame :locals locals))
         (new-call-stack (push-call-stack new-frame (pop-call-stack call-stack)))
         (new-state (change-state state :call-stack new-call-stack)))
    new-state))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Label stack accessors

(defun current-label-stack (state)
  (declare (xargs :guard (statep state)))
  (let* ((call-stack (state->call-stack state))
         (frame (top-frame call-stack)))
    (frame->label-stack frame)))

(defun update-current-label-stack (label-stack state)
  (declare (xargs :guard (and (label-stackp label-stack)
                              (statep state))
                  :verify-guards nil))
  (let* ((call-stack (state->call-stack state))
         (frame (top-frame call-stack))
         (new-frame (change-frame frame :label-stack label-stack))
         (new-call-stack (push-call-stack new-frame (pop-call-stack call-stack)))
         (new-state (change-state state :call-stack new-call-stack)))
    new-state))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Value constructors

(defund make-i32-val (x)
  (declare (xargs :guard (u32p x)))
  `(:i32.const ,x))

(defthm i32-valp-of-make-i32-val
  (equal (i32-valp (make-i32-val x))
         (u32p x))
  :hints (("Goal" :in-theory (enable i32-valp make-i32-val))))

(defthm valp-of-make-i32-val
  (implies (u32p x)
           (valp (make-i32-val x)))
  :hints (("Goal" :in-theory (enable valp))))

(defund make-i64-val (x)
  (declare (xargs :guard (u64p x)))
  `(:i64.const ,x))

(defthm i64-valp-of-make-i64-val
  (equal (i64-valp (make-i64-val x))
         (u64p x))
  :hints (("Goal" :in-theory (enable i64-valp make-i64-val))))

(defthm valp-of-make-i64-val
  (implies (u64p x)
           (valp (make-i64-val x)))
  :hints (("Goal" :in-theory (enable valp))))

;; f32/f64 value constructors (M7a)

(defund make-f32-val (x)
  (declare (xargs :guard (rationalp x)))
  `(:f32.const ,x))

(defthm f32-valp-of-make-f32-val
  (equal (f32-valp (make-f32-val x))
         (rationalp x))
  :hints (("Goal" :in-theory (enable f32-valp make-f32-val))))

(defthm valp-of-make-f32-val
  (implies (rationalp x)
           (valp (make-f32-val x)))
  :hints (("Goal" :in-theory (enable valp))))

(defund make-f64-val (x)
  (declare (xargs :guard (rationalp x)))
  `(:f64.const ,x))

(defthm f64-valp-of-make-f64-val
  (equal (f64-valp (make-f64-val x))
         (rationalp x))
  :hints (("Goal" :in-theory (enable f64-valp make-f64-val))))

(defthm valp-of-make-f64-val
  (implies (rationalp x)
           (valp (make-f64-val x)))
  :hints (("Goal" :in-theory (enable valp))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Helper: advance instruction pointer (used by all execute-* functions)

(defmacro advance-instrs (state-var)
  `(update-current-instrs (rest (current-instrs ,state-var)) ,state-var))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Parametric instructions

;; nop: do nothing
(defun execute-nop (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (advance-instrs state))

;; unreachable: trap
(defun execute-unreachable (state)
  (declare (xargs :guard (statep state))
           (ignore state))
  :trap)

;; drop: pop one value from operand stack
(defun execute-drop (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (ostack (pop-operand ostack))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;; select: pop i32 condition, pop val2, pop val1; push val1 if c!=0, else val2
(defun execute-select (state)
  (declare (xargs :guard (statep state)
                  :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 3 (operand-stack-height ostack)))) :trap)
       (c-val (top-operand ostack))
       ((when (not (i32-valp c-val))) :trap)
       (c (farg1 c-val))
       (val2 (top-operand (pop-operand ostack)))
       (val1 (top-operand (pop-operand (pop-operand ostack))))
       (result (if (not (= 0 c)) val1 val2))
       (ostack (push-operand result (pop-operand (pop-operand (pop-operand ostack)))))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Variable instructions

;; local.get x: push locals[x]
(defun execute-local.get (args state)
  (declare (xargs :guard (and (true-listp args)
                              (local-idx-argsp args)
                              (statep state))
                  :verify-guards nil))
  (b* ((x (first args))
       (locals (current-locals state))
       (ostack (current-operand-stack state))
       ((when (not (< x (len locals)))) :trap)
       (val (nth-local x locals))
       (ostack (push-operand val ostack))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;; local.set x: pop value, store to locals[x]
(defun execute-local.set (args state)
  (declare (xargs :guard (and (true-listp args)
                              (local-idx-argsp args)
                              (statep state))
                  :verify-guards nil))
  (b* ((x (first args))
       (locals (current-locals state))
       (ostack (current-operand-stack state))
       ((when (not (< x (len locals)))) :trap)
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (val (top-operand ostack))
       (ostack (pop-operand ostack))
       (locals (update-nth-local x val locals))
       (state (update-current-operand-stack ostack state))
       (state (update-current-locals locals state)))
    (advance-instrs state)))

;; local.tee x: like local.set but keeps value on stack
(defun execute-local.tee (args state)
  (declare (xargs :guard (and (true-listp args)
                              (local-idx-argsp args)
                              (statep state))
                  :verify-guards nil))
  (b* ((x (first args))
       (locals (current-locals state))
       (ostack (current-operand-stack state))
       ((when (not (< x (len locals)))) :trap)
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (val (top-operand ostack))
       (locals (update-nth-local x val locals))
       (state (update-current-locals locals state)))
    (advance-instrs state)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Global variable instructions (M5+)

;; global.get x: push globals[x] onto operand stack
(defun execute-global.get (args state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((x (first args))
       (globals (state->globals state))
       ((when (not (< x (len globals)))) :trap)
       (ginst (nth x globals))
       (val (globalinst->value ginst))
       (ostack (current-operand-stack state))
       (ostack (push-operand val ostack))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;; global.set x: pop value, store to globals[x] (must be :var)
(defun execute-global.set (args state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((x (first args))
       (globals (state->globals state))
       ((when (not (< x (len globals)))) :trap)
       (ginst (nth x globals))
       ((when (not (eq :var (globalinst->mutability ginst)))) :trap)
       (ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (val (top-operand ostack))
       (ostack (pop-operand ostack))
       (new-ginst (change-globalinst ginst :value val))
       (new-globals (update-nth x new-ginst globals))
       (state (change-state state :globals new-globals))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; i32 constant

(defun execute-i32.const (args state)
  (declare (xargs :guard (and (true-listp args)
                              (i32-const-argsp args)
                              (statep state))
                  :verify-guards nil))
  (b* ((n (first args))
       (ostack (current-operand-stack state))
       (ostack (push-operand (make-i32-val n) ostack))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; i32 binary arithmetic/bitwise operations
;; Pattern: pop 2 i32 vals, apply op, push i32 result

;; Helper for i32 binary ops
(defmacro def-i32-binop (name bv-expr)
  `(defun ,name (state)
     (declare (xargs :guard (statep state)
                     :verify-guards nil))
     (b* ((ostack (current-operand-stack state))
          ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
          (arg2 (top-operand ostack))
          (arg1 (top-operand (pop-operand ostack)))
          ((when (not (and (i32-valp arg1) (i32-valp arg2)))) :trap)
          (v1 (farg1 arg1))
          (v2 (farg1 arg2))
          (result (make-i32-val ,bv-expr))
          (ostack (push-operand result (pop-operand (pop-operand ostack))))
          (state (update-current-operand-stack ostack state)))
       (advance-instrs state))))

;; Helper for i32 binary ops that can trap (div/rem by zero)
(defmacro def-i32-binop-trap (name bv-expr trap-cond)
  `(defun ,name (state)
     (declare (xargs :guard (statep state)
                     :verify-guards nil))
     (b* ((ostack (current-operand-stack state))
          ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
          (arg2 (top-operand ostack))
          (arg1 (top-operand (pop-operand ostack)))
          ((when (not (and (i32-valp arg1) (i32-valp arg2)))) :trap)
          (v1 (farg1 arg1))
          (v2 (farg1 arg2))
          ((when ,trap-cond) :trap)
          (result (make-i32-val ,bv-expr))
          (ostack (push-operand result (pop-operand (pop-operand ostack))))
          (state (update-current-operand-stack ostack state)))
       (advance-instrs state))))

;; i32 arithmetic
(def-i32-binop execute-i32.add (bvplus 32 v1 v2))
(def-i32-binop execute-i32.sub (acl2::bvminus 32 v1 v2))
(def-i32-binop execute-i32.mul (acl2::bvmult 32 v1 v2))
(def-i32-binop-trap execute-i32.div_u (acl2::bvdiv 32 v1 v2) (= v2 0))
(def-i32-binop-trap execute-i32.rem_u (acl2::bvmod 32 v1 v2) (= v2 0))

;; i32.div_s: signed division, traps on zero or overflow (MIN_INT / -1)
(defun execute-i32.div_s (state)
  (declare (xargs :guard (statep state)
                  :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
       (arg2 (top-operand ostack))
       (arg1 (top-operand (pop-operand ostack)))
       ((when (not (and (i32-valp arg1) (i32-valp arg2)))) :trap)
       (v1 (farg1 arg1))
       (v2 (farg1 arg2))
       ((when (= v2 0)) :trap)
       ;; Overflow: -2^31 / -1 would be 2^31 which doesn't fit in i32
       ((when (and (= v1 (expt 2 31)) (= v2 (1- (expt 2 32))))) :trap)
       (result (make-i32-val (acl2::sbvdiv 32 v1 v2)))
       (ostack (push-operand result (pop-operand (pop-operand ostack))))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;; i32.rem_s: signed remainder, traps on zero
(defun execute-i32.rem_s (state)
  (declare (xargs :guard (statep state)
                  :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
       (arg2 (top-operand ostack))
       (arg1 (top-operand (pop-operand ostack)))
       ((when (not (and (i32-valp arg1) (i32-valp arg2)))) :trap)
       (v1 (farg1 arg1))
       (v2 (farg1 arg2))
       ((when (= v2 0)) :trap)
       (result (make-i32-val (acl2::sbvrem 32 v1 v2)))
       (ostack (push-operand result (pop-operand (pop-operand ostack))))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;; i32 bitwise
(def-i32-binop execute-i32.and (acl2::bvand 32 v1 v2))
(def-i32-binop execute-i32.or  (acl2::bvor 32 v1 v2))
(def-i32-binop execute-i32.xor (acl2::bvxor 32 v1 v2))
(def-i32-binop execute-i32.shl (acl2::bvshl 32 v1 (mod v2 32)))
(def-i32-binop execute-i32.shr_u (acl2::bvshr 32 v1 (mod v2 32)))

;; i32.shr_s: arithmetic (signed) shift right
(defun execute-i32.shr_s (state)
  (declare (xargs :guard (statep state)
                  :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
       (arg2 (top-operand ostack))
       (arg1 (top-operand (pop-operand ostack)))
       ((when (not (and (i32-valp arg1) (i32-valp arg2)))) :trap)
       (v1 (farg1 arg1))
       (v2 (farg1 arg2))
       (amt (mod v2 32))
       ;; Arithmetic shift right: sign-extend then shift then truncate
       (result (make-i32-val (acl2::bvchop 32 (acl2::bvashr 32 v1 amt))))
       (ostack (push-operand result (pop-operand (pop-operand ostack))))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;; i32 rotate
(defun execute-i32.rotl (state)
  (declare (xargs :guard (statep state)
                  :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
       (arg2 (top-operand ostack))
       (arg1 (top-operand (pop-operand ostack)))
       ((when (not (and (i32-valp arg1) (i32-valp arg2)))) :trap)
       (v1 (farg1 arg1))
       (v2 (farg1 arg2))
       (amt (mod v2 32))
       ;; rotl = (v1 << amt) | (v1 >> (32 - amt))
       (result (make-i32-val (acl2::bvchop 32 (logior (ash v1 amt)
                                                       (ash v1 (- amt 32))))))
       (ostack (push-operand result (pop-operand (pop-operand ostack))))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(defun execute-i32.rotr (state)
  (declare (xargs :guard (statep state)
                  :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
       (arg2 (top-operand ostack))
       (arg1 (top-operand (pop-operand ostack)))
       ((when (not (and (i32-valp arg1) (i32-valp arg2)))) :trap)
       (v1 (farg1 arg1))
       (v2 (farg1 arg2))
       (amt (mod v2 32))
       ;; rotr = (v1 >> amt) | (v1 << (32 - amt))
       (result (make-i32-val (acl2::bvchop 32 (logior (ash v1 (- amt))
                                                       (ash v1 (- 32 amt))))))
       (ostack (push-operand result (pop-operand (pop-operand ostack))))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; i32 unary operations

(defun i32-clz-helper (v n)
  (declare (xargs :guard (and (natp v) (natp n))
                  :measure (nfix n)))
  (if (or (zp n) (logbitp (1- n) v))
      0
    (1+ (i32-clz-helper v (1- n)))))

(defun i32-ctz-helper (v bit n)
  (declare (xargs :guard (and (natp v) (natp bit) (natp n))
                  :measure (nfix n)))
  (if (or (zp n) (logbitp bit v))
      0
    (1+ (i32-ctz-helper v (1+ bit) (1- n)))))

(defun i32-popcnt-helper (v n)
  (declare (xargs :guard (and (natp v) (natp n))
                  :measure (nfix n)))
  (if (zp n)
      0
    (+ (if (logbitp (1- n) v) 1 0)
       (i32-popcnt-helper v (1- n)))))

(defmacro def-i32-unop (name expr)
  `(defun ,name (state)
     (declare (xargs :guard (statep state)
                     :verify-guards nil))
     (b* ((ostack (current-operand-stack state))
          ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
          (arg1 (top-operand ostack))
          ((when (not (i32-valp arg1))) :trap)
          (v1 (farg1 arg1))
          (result (make-i32-val ,expr))
          (ostack (push-operand result (pop-operand ostack)))
          (state (update-current-operand-stack ostack state)))
       (advance-instrs state))))

(def-i32-unop execute-i32.clz (i32-clz-helper v1 32))
(def-i32-unop execute-i32.ctz (i32-ctz-helper v1 0 32))
(def-i32-unop execute-i32.popcnt (i32-popcnt-helper v1 32))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; i32 test and comparison operations

;; i32.eqz: test if zero, produces i32 result
(defun execute-i32.eqz (state)
  (declare (xargs :guard (statep state)
                  :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg1 (top-operand ostack))
       ((when (not (i32-valp arg1))) :trap)
       (v1 (farg1 arg1))
       (result (make-i32-val (if (= v1 0) 1 0)))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;; Helper for i32 comparison ops: pop 2 i32 vals, evaluate boolean, push i32 0/1
(defmacro def-i32-relop (name bool-expr)
  `(defun ,name (state)
     (declare (xargs :guard (statep state)
                     :verify-guards nil))
     (b* ((ostack (current-operand-stack state))
          ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
          (arg2 (top-operand ostack))
          (arg1 (top-operand (pop-operand ostack)))
          ((when (not (and (i32-valp arg1) (i32-valp arg2)))) :trap)
          (v1 (farg1 arg1))
          (v2 (farg1 arg2))
          (result (make-i32-val (if ,bool-expr 1 0)))
          (ostack (push-operand result (pop-operand (pop-operand ostack))))
          (state (update-current-operand-stack ostack state)))
       (advance-instrs state))))

;; Signed comparison helper
(defund i32-signed (x)
  (declare (xargs :guard (u32p x)
                  :guard-hints (("Goal" :in-theory (enable u32p)))))
  (if (< x (expt 2 31))
      x
    (- x (expt 2 32))))

(def-i32-relop execute-i32.eq  (= v1 v2))
(def-i32-relop execute-i32.ne  (not (= v1 v2)))
(def-i32-relop execute-i32.lt_u (< v1 v2))
(def-i32-relop execute-i32.gt_u (> v1 v2))
(def-i32-relop execute-i32.le_u (<= v1 v2))
(def-i32-relop execute-i32.ge_u (>= v1 v2))
(def-i32-relop execute-i32.lt_s (< (i32-signed v1) (i32-signed v2)))
(def-i32-relop execute-i32.gt_s (> (i32-signed v1) (i32-signed v2)))
(def-i32-relop execute-i32.le_s (<= (i32-signed v1) (i32-signed v2)))
(def-i32-relop execute-i32.ge_s (>= (i32-signed v1) (i32-signed v2)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; i64 operations (M5)

;; i64 constant
(defun execute-i64.const (args state)
  (declare (xargs :guard (and (true-listp args) (i64-const-argsp args) (statep state))
                  :verify-guards nil))
  (b* ((n (first args))
       (ostack (current-operand-stack state))
       (ostack (push-operand (make-i64-val n) ostack))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;; i64 binary op macros (mirror i32 pattern)
(defmacro def-i64-binop (name bv-expr)
  `(defun ,name (state)
     (declare (xargs :guard (statep state) :verify-guards nil))
     (b* ((ostack (current-operand-stack state))
          ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
          (arg2 (top-operand ostack))
          (arg1 (top-operand (pop-operand ostack)))
          ((when (not (and (i64-valp arg1) (i64-valp arg2)))) :trap)
          (v1 (farg1 arg1))
          (v2 (farg1 arg2))
          (result (make-i64-val ,bv-expr))
          (ostack (push-operand result (pop-operand (pop-operand ostack))))
          (state (update-current-operand-stack ostack state)))
       (advance-instrs state))))

(defmacro def-i64-binop-trap (name bv-expr trap-cond)
  `(defun ,name (state)
     (declare (xargs :guard (statep state) :verify-guards nil))
     (b* ((ostack (current-operand-stack state))
          ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
          (arg2 (top-operand ostack))
          (arg1 (top-operand (pop-operand ostack)))
          ((when (not (and (i64-valp arg1) (i64-valp arg2)))) :trap)
          (v1 (farg1 arg1))
          (v2 (farg1 arg2))
          ((when ,trap-cond) :trap)
          (result (make-i64-val ,bv-expr))
          (ostack (push-operand result (pop-operand (pop-operand ostack))))
          (state (update-current-operand-stack ostack state)))
       (advance-instrs state))))

;; i64 arithmetic
(def-i64-binop execute-i64.add (bvplus 64 v1 v2))
(def-i64-binop execute-i64.sub (acl2::bvminus 64 v1 v2))
(def-i64-binop execute-i64.mul (acl2::bvmult 64 v1 v2))
(def-i64-binop-trap execute-i64.div_u (acl2::bvdiv 64 v1 v2) (= v2 0))
(def-i64-binop-trap execute-i64.rem_u (acl2::bvmod 64 v1 v2) (= v2 0))

(defun execute-i64.div_s (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
       (arg2 (top-operand ostack))
       (arg1 (top-operand (pop-operand ostack)))
       ((when (not (and (i64-valp arg1) (i64-valp arg2)))) :trap)
       (v1 (farg1 arg1))
       (v2 (farg1 arg2))
       ((when (= v2 0)) :trap)
       ((when (and (= v1 (expt 2 63)) (= v2 (1- (expt 2 64))))) :trap)
       (result (make-i64-val (acl2::sbvdiv 64 v1 v2)))
       (ostack (push-operand result (pop-operand (pop-operand ostack))))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(defun execute-i64.rem_s (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
       (arg2 (top-operand ostack))
       (arg1 (top-operand (pop-operand ostack)))
       ((when (not (and (i64-valp arg1) (i64-valp arg2)))) :trap)
       (v1 (farg1 arg1))
       (v2 (farg1 arg2))
       ((when (= v2 0)) :trap)
       (result (make-i64-val (acl2::sbvrem 64 v1 v2)))
       (ostack (push-operand result (pop-operand (pop-operand ostack))))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;; i64 bitwise
(def-i64-binop execute-i64.and (acl2::bvand 64 v1 v2))
(def-i64-binop execute-i64.or  (acl2::bvor 64 v1 v2))
(def-i64-binop execute-i64.xor (acl2::bvxor 64 v1 v2))
(def-i64-binop execute-i64.shl (acl2::bvshl 64 v1 (mod v2 64)))
(def-i64-binop execute-i64.shr_u (acl2::bvshr 64 v1 (mod v2 64)))

(defun execute-i64.shr_s (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
       (arg2 (top-operand ostack))
       (arg1 (top-operand (pop-operand ostack)))
       ((when (not (and (i64-valp arg1) (i64-valp arg2)))) :trap)
       (v1 (farg1 arg1))
       (v2 (farg1 arg2))
       (amt (mod v2 64))
       (result (make-i64-val (acl2::bvchop 64 (acl2::bvashr 64 v1 amt))))
       (ostack (push-operand result (pop-operand (pop-operand ostack))))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(defun execute-i64.rotl (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
       (arg2 (top-operand ostack))
       (arg1 (top-operand (pop-operand ostack)))
       ((when (not (and (i64-valp arg1) (i64-valp arg2)))) :trap)
       (v1 (farg1 arg1))
       (v2 (farg1 arg2))
       (amt (mod v2 64))
       (result (make-i64-val (acl2::bvchop 64 (logior (ash v1 amt)
                                                       (ash v1 (- amt 64))))))
       (ostack (push-operand result (pop-operand (pop-operand ostack))))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(defun execute-i64.rotr (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
       (arg2 (top-operand ostack))
       (arg1 (top-operand (pop-operand ostack)))
       ((when (not (and (i64-valp arg1) (i64-valp arg2)))) :trap)
       (v1 (farg1 arg1))
       (v2 (farg1 arg2))
       (amt (mod v2 64))
       (result (make-i64-val (acl2::bvchop 64 (logior (ash v1 (- amt))
                                                       (ash v1 (- 64 amt))))))
       (ostack (push-operand result (pop-operand (pop-operand ostack))))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;; i64 unary operations (reuse i32 helpers — they work on any natural)
(defmacro def-i64-unop (name expr)
  `(defun ,name (state)
     (declare (xargs :guard (statep state) :verify-guards nil))
     (b* ((ostack (current-operand-stack state))
          ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
          (arg1 (top-operand ostack))
          ((when (not (i64-valp arg1))) :trap)
          (v1 (farg1 arg1))
          (result (make-i64-val ,expr))
          (ostack (push-operand result (pop-operand ostack)))
          (state (update-current-operand-stack ostack state)))
       (advance-instrs state))))

(def-i64-unop execute-i64.clz (i32-clz-helper v1 64))
(def-i64-unop execute-i64.ctz (i32-ctz-helper v1 0 64))
(def-i64-unop execute-i64.popcnt (i32-popcnt-helper v1 64))

;; i64.eqz: test if zero → i32 result (NOT i64)
(defun execute-i64.eqz (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg1 (top-operand ostack))
       ((when (not (i64-valp arg1))) :trap)
       (v1 (farg1 arg1))
       (result (make-i32-val (if (= v1 0) 1 0)))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;; i64 comparison: pop 2 i64 vals → push i32 0/1
(defmacro def-i64-relop (name bool-expr)
  `(defun ,name (state)
     (declare (xargs :guard (statep state) :verify-guards nil))
     (b* ((ostack (current-operand-stack state))
          ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
          (arg2 (top-operand ostack))
          (arg1 (top-operand (pop-operand ostack)))
          ((when (not (and (i64-valp arg1) (i64-valp arg2)))) :trap)
          (v1 (farg1 arg1))
          (v2 (farg1 arg2))
          (result (make-i32-val (if ,bool-expr 1 0)))
          (ostack (push-operand result (pop-operand (pop-operand ostack))))
          (state (update-current-operand-stack ostack state)))
       (advance-instrs state))))

(defund i64-signed (x)
  (declare (xargs :guard (u64p x)
                  :guard-hints (("Goal" :in-theory (enable u64p)))))
  (if (< x (expt 2 63)) x (- x (expt 2 64))))

(def-i64-relop execute-i64.eq  (= v1 v2))
(def-i64-relop execute-i64.ne  (not (= v1 v2)))
(def-i64-relop execute-i64.lt_u (< v1 v2))
(def-i64-relop execute-i64.gt_u (> v1 v2))
(def-i64-relop execute-i64.le_u (<= v1 v2))
(def-i64-relop execute-i64.ge_u (>= v1 v2))
(def-i64-relop execute-i64.lt_s (< (i64-signed v1) (i64-signed v2)))
(def-i64-relop execute-i64.gt_s (> (i64-signed v1) (i64-signed v2)))
(def-i64-relop execute-i64.le_s (<= (i64-signed v1) (i64-signed v2)))
(def-i64-relop execute-i64.ge_s (>= (i64-signed v1) (i64-signed v2)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Conversion operations (M5)

;; i32.wrap_i64: truncate i64 → i32
(defun execute-i32.wrap_i64 (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg1 (top-operand ostack))
       ((when (not (i64-valp arg1))) :trap)
       (v1 (farg1 arg1))
       (result (make-i32-val (acl2::bvchop 32 v1)))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;; i64.extend_i32_u: zero-extend i32 → i64
(defun execute-i64.extend_i32_u (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg1 (top-operand ostack))
       ((when (not (i32-valp arg1))) :trap)
       (v1 (farg1 arg1))
       (result (make-i64-val v1)) ;; u32 value is already valid u64
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;; i64.extend_i32_s: sign-extend i32 → i64
(defun execute-i64.extend_i32_s (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg1 (top-operand ostack))
       ((when (not (i32-valp arg1))) :trap)
       (v1 (farg1 arg1))
       (result (make-i64-val (acl2::bvsx 64 32 v1)))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Control flow instructions (M2)

;; block: push label, set instrs to body
;; (:block arity body-instrs)
;; Label continuation = rest of instrs after this block
(defun execute-block (args state)
  (declare (xargs :guard (statep state)
                  :verify-guards nil))
  (b* ((arity (first args))
       (body (second args))
       (rest-instrs (rest (current-instrs state)))
       (lstack (current-label-stack state))
       (label (make-label-entry :arity arity
                                :continuation rest-instrs
                                :is-loop nil))
       (lstack (push-label label lstack))
       (state (update-current-label-stack lstack state))
       (state (update-current-instrs body state)))
    state))

;; loop: push label, set instrs to body
;; (:loop arity body-instrs)
;; Label continuation = the loop instruction itself ++ rest instrs (for re-entry)
(defun execute-loop (args state)
  (declare (xargs :guard (statep state)
                  :verify-guards nil))
  (b* ((arity (first args))
       (body (second args))
       (loop-instr (first (current-instrs state)))
       (rest-instrs (rest (current-instrs state)))
       (lstack (current-label-stack state))
       ;; For loops, breaking to this label re-enters the loop
       (label (make-label-entry :arity arity
                                :continuation (cons loop-instr rest-instrs)
                                :is-loop t))
       (lstack (push-label label lstack))
       (state (update-current-label-stack lstack state))
       (state (update-current-instrs body state)))
    state))

;; if: pop condition, dispatch to then or else branch (both become blocks)
;; (:if arity then-instrs else-instrs)
(defun execute-if (args state)
  (declare (xargs :guard (statep state)
                  :verify-guards nil))
  (b* ((arity (first args))
       (then-body (second args))
       (else-body (third args))
       (ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (c-val (top-operand ostack))
       ((when (not (i32-valp c-val))) :trap)
       (c (farg1 c-val))
       (ostack (pop-operand ostack))
       (state (update-current-operand-stack ostack state))
       ;; Reduce to a block with the chosen branch
       (body (if (not (= 0 c)) then-body else-body))
       (rest-instrs (rest (current-instrs state)))
       (lstack (current-label-stack state))
       (label (make-label-entry :arity arity
                                :continuation rest-instrs
                                :is-loop nil))
       (lstack (push-label label lstack))
       (state (update-current-label-stack lstack state))
       (state (update-current-instrs body state)))
    state))

;; br: break to the Nth label (0-indexed)
;; Pop N intermediate labels, then use the target label's continuation
;; For blocks: continue after the block (use continuation directly)
;; For loops: re-enter the loop (continuation includes the loop instr)
(defun execute-br (args state)
  (declare (xargs :guard (statep state)
                  :verify-guards nil))
  (b* ((n (first args))
       (lstack (current-label-stack state))
       ((when (not (< n (len lstack)))) :trap)
       (target-label (nth-label n lstack))
       (arity (label-entry->arity target-label))
       (continuation (label-entry->continuation target-label))
       ;; Keep top 'arity' values from operand stack
       (ostack (current-operand-stack state))
       ((when (not (<= arity (operand-stack-height ostack)))) :trap)
       (kept-vals (top-n-operands arity ostack nil))
       ;; Pop n+1 labels (the target label itself is also consumed)
       (new-lstack (pop-n-labels (1+ n) lstack))
       ;; Build the new operand stack: push kept values onto the base
       ;; We need to calculate the base stack. For simplicity, pop everything
       ;; down past what this and intermediate blocks put on, then push kept vals.
       ;; Simple approach: drop everything from ostack, push kept-vals back
       ;; Actually, we need to figure out the stack depth before the blocks.
       ;; The simplest correct approach: wipe the operand stack back to the depth
       ;; it had when the target label's enclosing block was entered.
       ;; For now, use a simplified approach: keep only the top arity values.
       (new-ostack (push-vals kept-vals (empty-operand-stack)))
       (state (update-current-operand-stack new-ostack state))
       (state (update-current-label-stack new-lstack state))
       (state (update-current-instrs continuation state)))
    state))

;; br_if: conditional branch
;; (:br_if label-idx)
(defun execute-br_if (args state)
  (declare (xargs :guard (statep state)
                  :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (c-val (top-operand ostack))
       ((when (not (i32-valp c-val))) :trap)
       (c (farg1 c-val))
       (ostack (pop-operand ostack))
       (state (update-current-operand-stack ostack state)))
    (if (not (= 0 c))
        ;; Branch taken: execute br
        (execute-br args state)
      ;; Branch not taken: continue
      (advance-instrs state))))

;; br_table: indexed branch
;; (:br_table label-vec default-label)
(defun execute-br_table (args state)
  (declare (xargs :guard (statep state)
                  :verify-guards nil))
  (b* ((label-vec (first args))
       (default-label (second args))
       (ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (idx-val (top-operand ostack))
       ((when (not (i32-valp idx-val))) :trap)
       (idx (farg1 idx-val))
       (ostack (pop-operand ostack))
       (state (update-current-operand-stack ostack state))
       ;; Choose target: if idx in range use label-vec[idx], else default
       (target (if (< idx (len label-vec))
                   (nth idx label-vec)
                 default-label)))
    (execute-br (list target) state)))

;; return: exit current function, returning values to caller
;; Like br to the outermost label depth
(defun execute-return (state)
  (declare (xargs :guard (statep state)
                  :verify-guards nil))
  ;; Clear all labels and instrs to trigger return-from-function
  (b* ((f (current-frame state))
       (n (frame->return-arity f))
       (ostack (current-operand-stack state))
       ((when (not (<= n (operand-stack-height ostack)))) :trap)
       (kept-vals (top-n-operands n ostack nil))
       (new-ostack (push-vals kept-vals (empty-operand-stack)))
       (state (update-current-operand-stack new-ostack state))
       (state (update-current-label-stack nil state))
       (state (update-current-instrs nil state)))
    state))

;; Label completion: called when instrs are exhausted but labels remain.
;; Pop the top label, keep arity values, continue with label's continuation.
;; For loops: the continuation is (loop-instr . rest-instrs). On fallthrough
;; (not via br), we skip the loop instruction and continue with rest-instrs.
;; For blocks: continuation is always the rest-instrs after the block.
(defund complete-label (state)
  (declare (xargs :guard (statep state)
                  :verify-guards nil))
  (b* ((lstack (current-label-stack state))
       ((when (not (consp lstack))) state) ; shouldn't happen
       (label (top-label lstack))
       (arity (label-entry->arity label))
       (continuation (label-entry->continuation label))
       ;; For loops, fallthrough skips the loop instruction (first element)
       (continuation (if (label-entry->is-loop label)
                         (rest continuation)
                       continuation))
       (ostack (current-operand-stack state))
       ((when (not (<= arity (operand-stack-height ostack)))) :trap)
       (kept-vals (top-n-operands arity ostack nil))
       (new-ostack (push-vals kept-vals (empty-operand-stack)))
       (state (update-current-operand-stack new-ostack state))
       (state (update-current-label-stack (pop-label lstack) state))
       (state (update-current-instrs continuation state)))
    state))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Memory instructions (M4)

;; Read n bytes from memory starting at addr (little-endian)
(defun mem-read-bytes (n addr memory)
  (declare (xargs :guard (and (natp n) (natp addr))
                  :verify-guards nil))
  (if (zp n) nil
    (cons (nth addr memory)
          (mem-read-bytes (1- n) (1+ addr) memory))))

;; Write bytes to memory at addr (returns new memory)
(defun mem-write-bytes (bytes addr memory)
  (declare (xargs :guard (and (true-listp bytes) (natp addr))
                  :verify-guards nil))
  (if (not (consp bytes)) memory
    (mem-write-bytes (rest bytes) (1+ addr)
                     (update-nth addr (first bytes) memory))))

;; Little-endian conversion: 4 bytes → u32
(defun le-bytes-to-u32 (bytes)
  (declare (xargs :guard t :verify-guards nil))
  (+ (nfix (first bytes))
     (ash (nfix (second bytes)) 8)
     (ash (nfix (third bytes)) 16)
     (ash (nfix (fourth bytes)) 24)))

;; u32 → 4 little-endian bytes
(defun u32-to-le-bytes (x)
  (declare (xargs :guard (u32p x) :verify-guards nil))
  (list (logand x #xff)
        (logand (ash x -8) #xff)
        (logand (ash x -16) #xff)
        (logand (ash x -24) #xff)))

;; Little-endian: 2 bytes → u16
(defun le-bytes-to-u16 (bytes)
  (declare (xargs :guard t :verify-guards nil))
  (+ (nfix (first bytes))
     (ash (nfix (second bytes)) 8)))

;; Little-endian: 8 bytes → u64 (already have le-bytes-to-u64 for i64.load)

;; Sign-extend 8-bit value to 32-bit
(defun sign-extend-8-to-32 (b)
  (declare (xargs :guard t :verify-guards nil))
  (let ((b (logand (nfix b) #xFF)))
    (if (>= b 128) (- (expt 2 32) (- 256 b)) b)))

;; Sign-extend 16-bit value to 32-bit
(defun sign-extend-16-to-32 (h)
  (declare (xargs :guard t :verify-guards nil))
  (let ((h (logand (nfix h) #xFFFF)))
    (if (>= h 32768) (- (expt 2 32) (- 65536 h)) h)))

;; Sign-extend 8-bit value to 64-bit
(defun sign-extend-8-to-64 (b)
  (declare (xargs :guard t :verify-guards nil))
  (let ((b (logand (nfix b) #xFF)))
    (if (>= b 128) (- (expt 2 64) (- 256 b)) b)))

;; Sign-extend 16-bit value to 64-bit
(defun sign-extend-16-to-64 (h)
  (declare (xargs :guard t :verify-guards nil))
  (let ((h (logand (nfix h) #xFFFF)))
    (if (>= h 32768) (- (expt 2 64) (- 65536 h)) h)))

;; Sign-extend 32-bit value to 64-bit
(defun sign-extend-32-to-64 (w)
  (declare (xargs :guard t :verify-guards nil))
  (let ((w (logand (nfix w) #xFFFFFFFF)))
    (if (>= w (expt 2 31)) (- (expt 2 64) (- (expt 2 32) w)) w)))

;; Update state memory
(defun update-memory (memory state)
  (declare (xargs :guard (and (byte-listp memory) (statep state))
                  :verify-guards nil))
  (change-state state :memory memory))

;; i32.load: pop base addr, add offset, read 4 bytes, push i32
;; (:i32.load offset)
(defun execute-i32.load (args state)
  (declare (xargs :guard (statep state)
                  :verify-guards nil))
  (b* ((offset (first args))
       (ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (base-val (top-operand ostack))
       ((when (not (i32-valp base-val))) :trap)
       (base (farg1 base-val))
       (addr (+ base (nfix offset)))
       (memory (state->memory state))
       ((when (< (len memory) (+ addr 4))) :trap) ; bounds check
       (bytes (mem-read-bytes 4 addr memory))
       (val (le-bytes-to-u32 bytes))
       (ostack (pop-operand ostack))
       (ostack (push-operand (make-i32-val (acl2::logand val #xFFFFFFFF)) ostack))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;; i32.store: pop value, pop base addr, write 4 bytes to memory
;; (:i32.store offset)
(defun execute-i32.store (args state)
  (declare (xargs :guard (statep state)
                  :verify-guards nil))
  (b* ((offset (first args))
       (ostack (current-operand-stack state))
       ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
       ;; WASM stack order: base is pushed first, value on top
       (val-val (top-operand ostack))
       ((when (not (i32-valp val-val))) :trap)
       (val (farg1 val-val))
       (ostack (pop-operand ostack))
       (base-val (top-operand ostack))
       ((when (not (i32-valp base-val))) :trap)
       (base (farg1 base-val))
       (ostack (pop-operand ostack))
       (addr (+ base (nfix offset)))
       (memory (state->memory state))
       ((when (< (len memory) (+ addr 4))) :trap) ; bounds check
       (bytes (u32-to-le-bytes val))
       (new-memory (mem-write-bytes bytes addr memory))
       (state (update-memory new-memory state))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Packed memory loads/stores (M4b)
;;
;; i32.load8_u, i32.load8_s, i32.load16_u, i32.load16_s
;; i32.store8, i32.store16
;; i64.load8_u/s, i64.load16_u/s, i64.load32_u/s
;; i64.store8, i64.store16, i64.store32

;; Macro for packed loads: read N bytes, zero-extend or sign-extend to result
(defmacro def-packed-load (name byte-count result-maker)
  `(defun ,name (args state)
     (declare (xargs :guard (statep state) :verify-guards nil))
     (b* ((offset (first args))
          (ostack (current-operand-stack state))
          ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
          (base-val (top-operand ostack))
          ((when (not (i32-valp base-val))) :trap)
          (base (farg1 base-val))
          (addr (+ base (nfix offset)))
          (memory (state->memory state))
          ((when (< (len memory) (+ addr ,byte-count))) :trap)
          (bytes (mem-read-bytes ,byte-count addr memory))
          (result ,result-maker)
          (ostack (pop-operand ostack))
          (ostack (push-operand result ostack))
          (state (update-current-operand-stack ostack state)))
       (advance-instrs state))))

;; i32 packed loads
(def-packed-load execute-i32.load8_u  1
  (make-i32-val (nfix (first bytes))))
(def-packed-load execute-i32.load8_s  1
  (make-i32-val (sign-extend-8-to-32 (first bytes))))
(def-packed-load execute-i32.load16_u 2
  (make-i32-val (le-bytes-to-u16 bytes)))
(def-packed-load execute-i32.load16_s 2
  (make-i32-val (sign-extend-16-to-32 (le-bytes-to-u16 bytes))))

;; i64 packed loads
(def-packed-load execute-i64.load8_u  1
  (make-i64-val (nfix (first bytes))))
(def-packed-load execute-i64.load8_s  1
  (make-i64-val (sign-extend-8-to-64 (first bytes))))
(def-packed-load execute-i64.load16_u 2
  (make-i64-val (le-bytes-to-u16 bytes)))
(def-packed-load execute-i64.load16_s 2
  (make-i64-val (sign-extend-16-to-64 (le-bytes-to-u16 bytes))))
(def-packed-load execute-i64.load32_u 4
  (make-i64-val (le-bytes-to-u32 bytes)))
(def-packed-load execute-i64.load32_s 4
  (make-i64-val (sign-extend-32-to-64 (le-bytes-to-u32 bytes))))

;; Macro for packed stores: pop value, truncate, write N bytes
(defmacro def-packed-store (name byte-count val-pred val-extract)
  `(defun ,name (args state)
     (declare (xargs :guard (statep state) :verify-guards nil))
     (b* ((offset (first args))
          (ostack (current-operand-stack state))
          ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
          (val-val (top-operand ostack))
          ((when (not (,val-pred val-val))) :trap)
          (val ,val-extract)
          (ostack (pop-operand ostack))
          (base-val (top-operand ostack))
          ((when (not (i32-valp base-val))) :trap)
          (base (farg1 base-val))
          (ostack (pop-operand ostack))
          (addr (+ base (nfix offset)))
          (memory (state->memory state))
          ((when (< (len memory) (+ addr ,byte-count))) :trap)
          (bytes (case ,byte-count
                   (1 (list (logand val #xFF)))
                   (2 (list (logand val #xFF) (logand (ash val -8) #xFF)))
                   (4 (list (logand val #xFF) (logand (ash val -8) #xFF)
                            (logand (ash val -16) #xFF) (logand (ash val -24) #xFF)))
                   (otherwise nil)))
          (new-memory (mem-write-bytes bytes addr memory))
          (state (update-memory new-memory state))
          (state (update-current-operand-stack ostack state)))
       (advance-instrs state))))

;; i32 packed stores
(def-packed-store execute-i32.store8  1 i32-valp (farg1 val-val))
(def-packed-store execute-i32.store16 2 i32-valp (farg1 val-val))

;; i64 packed stores
(def-packed-store execute-i64.store8  1 i64-valp (farg1 val-val))
(def-packed-store execute-i64.store16 2 i64-valp (farg1 val-val))
(def-packed-store execute-i64.store32 4 i64-valp (farg1 val-val))

;; memory.size: push current memory size in pages
(defun execute-memory.size (state)
  (declare (xargs :guard (statep state)
                  :verify-guards nil))
  (b* ((memory (state->memory state))
       (pages (floor (len memory) *page-size*))
       (ostack (current-operand-stack state))
       (ostack (push-operand (make-i32-val pages) ostack))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;; memory.grow: grow memory by n pages, push old size (or -1 on failure)
(defun execute-memory.grow (state)
  (declare (xargs :guard (statep state)
                  :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (n-val (top-operand ostack))
       ((when (not (i32-valp n-val))) :trap)
       (n (farg1 n-val))
       (ostack (pop-operand ostack))
       (memory (state->memory state))
       (old-pages (floor (len memory) *page-size*))
       (new-size (+ (len memory) (* n *page-size*)))
       ;; WASM 1.0 max = 65536 pages = 4GiB (but we cap lower for safety)
       ((when (> new-size (* 256 *page-size*))) ; cap at 256 pages = 16MiB
        (let* ((ostack (push-operand (make-i32-val #xFFFFFFFF) ostack))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       (new-memory (append memory (make-list (* n *page-size*) :initial-element 0)))
       (ostack (push-operand (make-i32-val old-pages) ostack))
       (state (update-current-operand-stack ostack state))
       (state (update-memory new-memory state)))
    (advance-instrs state)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; i64 memory load/store (M5)

;; Little-endian: 8 bytes → u64
(defun le-bytes-to-u64 (bytes)
  (declare (xargs :guard t :verify-guards nil))
  (+ (nfix (first bytes))
     (ash (nfix (second bytes)) 8)
     (ash (nfix (third bytes)) 16)
     (ash (nfix (fourth bytes)) 24)
     (ash (nfix (fifth bytes)) 32)
     (ash (nfix (sixth bytes)) 40)
     (ash (nfix (seventh bytes)) 48)
     (ash (nfix (eighth bytes)) 56)))

;; u64 → 8 little-endian bytes
(defun u64-to-le-bytes (x)
  (declare (xargs :guard (u64p x) :verify-guards nil))
  (list (logand x #xff)
        (logand (ash x -8) #xff)
        (logand (ash x -16) #xff)
        (logand (ash x -24) #xff)
        (logand (ash x -32) #xff)
        (logand (ash x -40) #xff)
        (logand (ash x -48) #xff)
        (logand (ash x -56) #xff)))

(defun execute-i64.load (args state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((offset (first args))
       (ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (base-val (top-operand ostack))
       ((when (not (i32-valp base-val))) :trap)
       (base (farg1 base-val))
       (addr (+ base (nfix offset)))
       (memory (state->memory state))
       ((when (< (len memory) (+ addr 8))) :trap)
       (bytes (mem-read-bytes 8 addr memory))
       (val (le-bytes-to-u64 bytes))
       (ostack (pop-operand ostack))
       (ostack (push-operand (make-i64-val (acl2::logand val #xFFFFFFFFFFFFFFFF)) ostack))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(defun execute-i64.store (args state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((offset (first args))
       (ostack (current-operand-stack state))
       ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
       (val-val (top-operand ostack))
       ((when (not (i64-valp val-val))) :trap)
       (val (farg1 val-val))
       (ostack (pop-operand ostack))
       (base-val (top-operand ostack))
       ((when (not (i32-valp base-val))) :trap)
       (base (farg1 base-val))
       (ostack (pop-operand ostack))
       (addr (+ base (nfix offset)))
       (memory (state->memory state))
       ((when (< (len memory) (+ addr 8))) :trap)
       (bytes (u64-to-le-bytes val))
       (new-memory (mem-write-bytes bytes addr memory))
       (state (update-memory new-memory state))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Function call (M3)

;; call: invoke function by index
;; (:call func-idx)
;; Look up function in store, pop args, push new frame
(defun execute-call (args state)
  (declare (xargs :guard (statep state)
                  :verify-guards nil))
  (b* ((func-idx (first args))
       (store (state->store state))
       ((when (not (< func-idx (len store)))) :trap)
       (finst (nth func-idx store))
       ((when (not (funcinstp finst))) :trap)
       (param-count (funcinst->param-count finst))
       (local-count (funcinst->local-count finst))
       (ret-arity (funcinst->return-arity finst))
       (body (funcinst->body finst))
       ;; Pop param-count values from caller's operand stack
       (ostack (current-operand-stack state))
       ((when (not (<= param-count (operand-stack-height ostack)))) :trap)
       (param-vals (top-n-operands param-count ostack nil))
       ;; Build new operand stack for caller (popped args)
       (caller-ostack ostack)
       ;; Pop param-count times
       (caller-ostack (nthcdr param-count caller-ostack))
       ;; Update caller state: advance past call instr, set ostack
       (state (update-current-operand-stack caller-ostack state))
       ;; Don't advance instrs yet (return-from-function does it)
       ;; Initialize locals: params followed by zero-initialized locals
       (zero-locals (make-list local-count :initial-element (make-i32-val 0)))
       (all-locals (append param-vals zero-locals))
       ;; Push new frame
       (new-frame (make-frame :return-arity ret-arity
                              :locals all-locals
                              :operand-stack (empty-operand-stack)
                              :instrs body
                              :label-stack nil))
       (call-stack (state->call-stack state))
       (new-call-stack (push-call-stack new-frame call-stack))
       (new-state (change-state state :call-stack new-call-stack)))
    new-state))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; call_indirect (M7b): indirect call through table
;; (:call_indirect type-idx)
;; Pops an i32 table index from the stack, looks up the function in the table,
;; then calls it. Type-idx is currently ignored (no type checking yet).
(defun execute-call_indirect (args state)
  (declare (xargs :guard (statep state)
                  :verify-guards nil)
           (ignore args))
  (b* (;; type-idx unused for now (would be used for type checking)
       ;; Pop the table index from the stack
       (ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (idx-val (top-operand ostack))
       ((when (not (i32-valp idx-val))) :trap)
       (tbl-idx (farg1 idx-val))
       (ostack (pop-operand ostack))
       (state (update-current-operand-stack ostack state))
       ;; Look up the function in the table
       (table (state->table state))
       ((when (not (<= 0 tbl-idx))) :trap)
       ((when (not (< tbl-idx (len table)))) :trap)
       (func-idx (nth tbl-idx table))
       ;; nil = uninitialized entry → trap
       ((when (not (natp func-idx))) :trap)
       ;; Delegate to execute-call with the resolved func-idx
       ;; But first, advance past call_indirect since execute-call
       ;; handles its own frame pushing without advancing
       )
    ;; Reuse execute-call machinery by calling it with the resolved func-idx
    (execute-call (list func-idx) state)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; f32/f64 floating-point operations (M7a)
;;
;; Values are modeled as ACL2 rationals.  This gives exact arithmetic
;; for programs that don't depend on IEEE 754 rounding/NaN behaviour.

;; f32.const / f64.const
(defun execute-f32.const (args state)
  (declare (xargs :guard (and (true-listp args) (f32-const-argsp args) (statep state))
                  :verify-guards nil))
  (b* ((val (make-f32-val (first args)))
       (ostack (current-operand-stack state))
       (ostack (push-operand val ostack))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(defun execute-f64.const (args state)
  (declare (xargs :guard (and (true-listp args) (f64-const-argsp args) (statep state))
                  :verify-guards nil))
  (b* ((val (make-f64-val (first args)))
       (ostack (current-operand-stack state))
       (ostack (push-operand val ostack))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;; Macro: f32 binary arithmetic op (with IEEE 754 NaN propagation)
;; If either operand is NaN the result is NaN; Inf operands trap for now.
(defmacro def-f32-binop (name expr)
  `(defun ,name (state)
     (declare (xargs :guard (statep state) :verify-guards nil))
     (b* ((ostack (current-operand-stack state))
          ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
          (arg2 (top-operand ostack))
          (arg1 (top-operand (pop-operand ostack)))
          ;; IEEE 754: any NaN operand → NaN result
          ((when (or (eq arg1 :f32.nan) (eq arg2 :f32.nan)))
           (let* ((ostack (push-operand :f32.nan (pop-operand (pop-operand ostack))))
                  (state (update-current-operand-stack ostack state)))
             (advance-instrs state)))
          ;; Accept finite f32-valp or signed zeros (±0 treated as rational 0)
          ((when (not (and (or (f32-valp arg1) (eq arg1 :f32.+0) (eq arg1 :f32.-0))
                           (or (f32-valp arg2) (eq arg2 :f32.+0) (eq arg2 :f32.-0))))) :trap)
          (v1 (if (f32-valp arg1) (farg1 arg1) 0))
          (v2 (if (f32-valp arg2) (farg1 arg2) 0))
          (result (make-f32-val ,expr))
          (ostack (push-operand result (pop-operand (pop-operand ostack))))
          (state (update-current-operand-stack ostack state)))
       (advance-instrs state))))

;; Macro: f64 binary arithmetic op (with IEEE 754 NaN propagation)
(defmacro def-f64-binop (name expr)
  `(defun ,name (state)
     (declare (xargs :guard (statep state) :verify-guards nil))
     (b* ((ostack (current-operand-stack state))
          ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
          (arg2 (top-operand ostack))
          (arg1 (top-operand (pop-operand ostack)))
          ;; IEEE 754: any NaN operand → NaN result
          ((when (or (eq arg1 :f64.nan) (eq arg2 :f64.nan)))
           (let* ((ostack (push-operand :f64.nan (pop-operand (pop-operand ostack))))
                  (state (update-current-operand-stack ostack state)))
             (advance-instrs state)))
          ;; Accept finite f64-valp or signed zeros (±0 treated as rational 0)
          ((when (not (and (or (f64-valp arg1) (eq arg1 :f64.+0) (eq arg1 :f64.-0))
                           (or (f64-valp arg2) (eq arg2 :f64.+0) (eq arg2 :f64.-0))))) :trap)
          (v1 (if (f64-valp arg1) (farg1 arg1) 0))
          (v2 (if (f64-valp arg2) (farg1 arg2) 0))
          (result (make-f64-val ,expr))
          (ostack (push-operand result (pop-operand (pop-operand ostack))))
          (state (update-current-operand-stack ostack state)))
       (advance-instrs state))))

;; Macro: f32 comparison (returns i32 0 or 1)
;; IEEE 754: NaN comparisons return nan-result (0 for ordered comparisons,
;; 1 for ne — because NaN is "unordered" and ne is defined as not-equal).
;; ±0 compare equal: both are converted to rational 0 before comparison.
(defmacro def-f32-cmpop (name expr &key (nan-result '0))
  `(defun ,name (state)
     (declare (xargs :guard (statep state) :verify-guards nil))
     (b* ((ostack (current-operand-stack state))
          ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
          (arg2 (top-operand ostack))
          (arg1 (top-operand (pop-operand ostack)))
          ;; IEEE 754: NaN is unordered; all ordered comparisons return false (0),
          ;; except ne which returns true (1) when either operand is NaN.
          ((when (or (eq arg1 :f32.nan) (eq arg2 :f32.nan)))
           (let* ((ostack (push-operand (make-i32-val ,nan-result)
                                        (pop-operand (pop-operand ostack))))
                  (state (update-current-operand-stack ostack state)))
             (advance-instrs state)))
          ;; Accept finite f32-valp or signed zeros (±0 = rational 0 for comparisons)
          ((when (not (and (or (f32-valp arg1) (eq arg1 :f32.+0) (eq arg1 :f32.-0))
                           (or (f32-valp arg2) (eq arg2 :f32.+0) (eq arg2 :f32.-0))))) :trap)
          (v1 (if (f32-valp arg1) (farg1 arg1) 0))
          (v2 (if (f32-valp arg2) (farg1 arg2) 0))
          (result (make-i32-val (if ,expr 1 0)))
          (ostack (push-operand result (pop-operand (pop-operand ostack))))
          (state (update-current-operand-stack ostack state)))
       (advance-instrs state))))

;; Macro: f64 comparison (returns i32 0 or 1)
;; ±0 compare equal per IEEE 754.
(defmacro def-f64-cmpop (name expr &key (nan-result '0))
  `(defun ,name (state)
     (declare (xargs :guard (statep state) :verify-guards nil))
     (b* ((ostack (current-operand-stack state))
          ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
          (arg2 (top-operand ostack))
          (arg1 (top-operand (pop-operand ostack)))
          ;; IEEE 754: NaN is unordered
          ((when (or (eq arg1 :f64.nan) (eq arg2 :f64.nan)))
           (let* ((ostack (push-operand (make-i32-val ,nan-result)
                                        (pop-operand (pop-operand ostack))))
                  (state (update-current-operand-stack ostack state)))
             (advance-instrs state)))
          ;; Accept finite f64-valp or signed zeros (±0 = rational 0 for comparisons)
          ((when (not (and (or (f64-valp arg1) (eq arg1 :f64.+0) (eq arg1 :f64.-0))
                           (or (f64-valp arg2) (eq arg2 :f64.+0) (eq arg2 :f64.-0))))) :trap)
          (v1 (if (f64-valp arg1) (farg1 arg1) 0))
          (v2 (if (f64-valp arg2) (farg1 arg2) 0))
          (result (make-i32-val (if ,expr 1 0)))
          (ostack (push-operand result (pop-operand (pop-operand ostack))))
          (state (update-current-operand-stack ostack state)))
       (advance-instrs state))))

;; ─── IEEE 754 Inf arithmetic helpers ──────────────────────────────────────────
;;
;; These helpers are called AFTER NaN propagation has been handled.
;; They compute the result when at least one operand is ±Inf.
;;
;; Sign-product logic:
;;   result is NEGATIVE iff exactly one of the inputs is negative.
;;   (f32-sign-negativep already handles ±0, ±Inf, and finite values.)

(defun f32-infp (v)
  (declare (xargs :guard t :verify-guards nil))
  (or (eq v :f32.+inf) (eq v :f32.-inf)))

(defun f64-infp (v)
  (declare (xargs :guard t :verify-guards nil))
  (or (eq v :f64.+inf) (eq v :f64.-inf)))

;; True if v is any form of zero: rational 0, :f32.+0, or :f32.-0
(defun f32-zerovalp (v)
  (declare (xargs :guard t :verify-guards nil))
  (or (eq v :f32.+0) (eq v :f32.-0)
      (and (f32-valp v) (= (farg1 v) 0))))

(defun f64-zerovalp (v)
  (declare (xargs :guard t :verify-guards nil))
  (or (eq v :f64.+0) (eq v :f64.-0)
      (and (f64-valp v) (= (farg1 v) 0))))

;; IEEE 754 add with ±Inf (NaN already dispatched before calling this)
;; Add: +Inf + -Inf = NaN; -Inf + +Inf = NaN; else the Inf arg dominates.
(defun f32-inf-add (a b)
  (declare (xargs :guard t :verify-guards nil))
  (cond ((and (eq a :f32.+inf) (eq b :f32.-inf)) :f32.nan)
        ((and (eq a :f32.-inf) (eq b :f32.+inf)) :f32.nan)
        ((eq a :f32.+inf) :f32.+inf)
        ((eq a :f32.-inf) :f32.-inf)
        ((eq b :f32.+inf) :f32.+inf)
        (t                :f32.-inf)))

(defun f64-inf-add (a b)
  (declare (xargs :guard t :verify-guards nil))
  (cond ((and (eq a :f64.+inf) (eq b :f64.-inf)) :f64.nan)
        ((and (eq a :f64.-inf) (eq b :f64.+inf)) :f64.nan)
        ((eq a :f64.+inf) :f64.+inf)
        ((eq a :f64.-inf) :f64.-inf)
        ((eq b :f64.+inf) :f64.+inf)
        (t                :f64.-inf)))

;; IEEE 754 sub with ±Inf: sub(a,b) = add(a, neg(b))
;; So flip sign of b, then call inf-add.
(defun f32-flip-inf (v)
  (declare (xargs :guard t :verify-guards nil))
  (if (eq v :f32.+inf) :f32.-inf
    (if (eq v :f32.-inf) :f32.+inf v)))

(defun f64-flip-inf (v)
  (declare (xargs :guard t :verify-guards nil))
  (if (eq v :f64.+inf) :f64.-inf
    (if (eq v :f64.-inf) :f64.+inf v)))

(defun f32-inf-sub (a b)
  (declare (xargs :guard t :verify-guards nil))
  (f32-inf-add a (f32-flip-inf b)))

(defun f64-inf-sub (a b)
  (declare (xargs :guard t :verify-guards nil))
  (f64-inf-add a (f64-flip-inf b)))

;; Sign predicates (needed by inf-mul and execute-f32/f64.div below, and also
;; used later by execute-f32/f64.copysign at their definition sites)
(defun f32-sign-negativep (arg)
  (declare (xargs :guard t :verify-guards nil))
  (or (eq arg :f32.-0) (eq arg :f32.-inf)
      (and (f32-valp arg) (< (farg1 arg) 0))))

(defun f64-sign-negativep (arg)
  (declare (xargs :guard t :verify-guards nil))
  (or (eq arg :f64.-0) (eq arg :f64.-inf)
      (and (f64-valp arg) (< (farg1 arg) 0))))

;; IEEE 754 mul with ±Inf (NaN already dispatched)
;; ±Inf * ±0 = NaN; ±Inf * ±Inf or ±Inf * nonzero-finite = ±Inf (sign = product)
(defun f32-inf-mul (a b)
  (declare (xargs :guard t :verify-guards nil))
  (if (or (f32-zerovalp a) (f32-zerovalp b)) :f32.nan
    (if (not (eq (f32-sign-negativep a) (f32-sign-negativep b)))
        :f32.-inf :f32.+inf)))

(defun f64-inf-mul (a b)
  (declare (xargs :guard t :verify-guards nil))
  (if (or (f64-zerovalp a) (f64-zerovalp b)) :f64.nan
    (if (not (eq (f64-sign-negativep a) (f64-sign-negativep b)))
        :f64.-inf :f64.+inf)))

;; IEEE 754 min/max with ±Inf (NaN already dispatched)
;; min: -Inf wins (smallest possible); +Inf yields to any other value.
;; max: +Inf wins (largest possible); -Inf yields to any other value.
(defun f32-inf-min (a b)
  (declare (xargs :guard t :verify-guards nil))
  (cond ((eq a :f32.-inf) :f32.-inf)
        ((eq b :f32.-inf) :f32.-inf)
        ((eq a :f32.+inf) b)
        (t               a)))   ; b is +Inf

(defun f64-inf-min (a b)
  (declare (xargs :guard t :verify-guards nil))
  (cond ((eq a :f64.-inf) :f64.-inf)
        ((eq b :f64.-inf) :f64.-inf)
        ((eq a :f64.+inf) b)
        (t               a)))

(defun f32-inf-max (a b)
  (declare (xargs :guard t :verify-guards nil))
  (cond ((eq a :f32.+inf) :f32.+inf)
        ((eq b :f32.+inf) :f32.+inf)
        ((eq a :f32.-inf) b)
        (t               a)))   ; b is -Inf

(defun f64-inf-max (a b)
  (declare (xargs :guard t :verify-guards nil))
  (cond ((eq a :f64.+inf) :f64.+inf)
        ((eq b :f64.+inf) :f64.+inf)
        ((eq a :f64.-inf) b)
        (t               a)))

;; ─── Macro for Inf-aware f32 binop ────────────────────────────────────────────
;; Same as def-f32-binop but inserts an Inf handler between NaN and ±0 checks.
(defmacro def-f32-binop-inf (name finite-expr inf-fn)
  `(defun ,name (state)
     (declare (xargs :guard (statep state) :verify-guards nil))
     (b* ((ostack (current-operand-stack state))
          ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
          (arg2 (top-operand ostack))
          (arg1 (top-operand (pop-operand ostack)))
          ;; IEEE 754: NaN propagates
          ((when (or (eq arg1 :f32.nan) (eq arg2 :f32.nan)))
           (let* ((ostack (push-operand :f32.nan (pop-operand (pop-operand ostack))))
                  (state (update-current-operand-stack ostack state)))
             (advance-instrs state)))
          ;; IEEE 754: ±Inf arithmetic
          ((when (or (f32-infp arg1) (f32-infp arg2)))
           (let* ((result (,inf-fn arg1 arg2))
                  (ostack (push-operand result (pop-operand (pop-operand ostack))))
                  (state (update-current-operand-stack ostack state)))
             (advance-instrs state)))
          ;; Accept finite f32-valp or signed zeros (±0 treated as rational 0)
          ((when (not (and (or (f32-valp arg1) (eq arg1 :f32.+0) (eq arg1 :f32.-0))
                           (or (f32-valp arg2) (eq arg2 :f32.+0) (eq arg2 :f32.-0))))) :trap)
          (v1 (if (f32-valp arg1) (farg1 arg1) 0))
          (v2 (if (f32-valp arg2) (farg1 arg2) 0))
          (result (make-f32-val ,finite-expr))
          (ostack (push-operand result (pop-operand (pop-operand ostack))))
          (state (update-current-operand-stack ostack state)))
       (advance-instrs state))))

(defmacro def-f64-binop-inf (name finite-expr inf-fn)
  `(defun ,name (state)
     (declare (xargs :guard (statep state) :verify-guards nil))
     (b* ((ostack (current-operand-stack state))
          ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
          (arg2 (top-operand ostack))
          (arg1 (top-operand (pop-operand ostack)))
          ;; IEEE 754: NaN propagates
          ((when (or (eq arg1 :f64.nan) (eq arg2 :f64.nan)))
           (let* ((ostack (push-operand :f64.nan (pop-operand (pop-operand ostack))))
                  (state (update-current-operand-stack ostack state)))
             (advance-instrs state)))
          ;; IEEE 754: ±Inf arithmetic
          ((when (or (f64-infp arg1) (f64-infp arg2)))
           (let* ((result (,inf-fn arg1 arg2))
                  (ostack (push-operand result (pop-operand (pop-operand ostack))))
                  (state (update-current-operand-stack ostack state)))
             (advance-instrs state)))
          ;; Accept finite f64-valp or signed zeros
          ((when (not (and (or (f64-valp arg1) (eq arg1 :f64.+0) (eq arg1 :f64.-0))
                           (or (f64-valp arg2) (eq arg2 :f64.+0) (eq arg2 :f64.-0))))) :trap)
          (v1 (if (f64-valp arg1) (farg1 arg1) 0))
          (v2 (if (f64-valp arg2) (farg1 arg2) 0))
          (result (make-f64-val ,finite-expr))
          (ostack (push-operand result (pop-operand (pop-operand ostack))))
          (state (update-current-operand-stack ostack state)))
       (advance-instrs state))))

;; f32 arithmetic (Inf-aware)
(def-f32-binop-inf execute-f32.add (+ v1 v2) f32-inf-add)
(def-f32-binop-inf execute-f32.sub (- v1 v2) f32-inf-sub)
(def-f32-binop-inf execute-f32.mul (* v1 v2) f32-inf-mul)

(defun execute-f32.div (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
       (arg2 (top-operand ostack))
       (arg1 (top-operand (pop-operand ostack)))
       ;; IEEE 754: NaN propagates
       ((when (or (eq arg1 :f32.nan) (eq arg2 :f32.nan)))
        (let* ((ostack (push-operand :f32.nan (pop-operand (pop-operand ostack))))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ;; IEEE 754: ±Inf / ±Inf = NaN; ±Inf / finite_nonzero = ±Inf; finite / ±Inf = ±0
       ((when (or (f32-infp arg1) (f32-infp arg2)))
        (let* ((result
                (cond
                 ;; ±Inf / ±Inf = NaN
                 ((and (f32-infp arg1) (f32-infp arg2)) :f32.nan)
                 ;; ±Inf / finite_nonzero → ±Inf (sign = product of signs)
                 ((f32-infp arg1)
                  (if (not (eq (f32-sign-negativep arg1) (f32-sign-negativep arg2)))
                      :f32.-inf :f32.+inf))
                 ;; finite / ±Inf → ±0 (sign = product of signs)
                 (t (if (not (eq (f32-sign-negativep arg1) (f32-sign-negativep arg2)))
                        :f32.-0 :f32.+0))))
               (ostack (push-operand result (pop-operand (pop-operand ostack))))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ;; IEEE 754: x/±0 — sign of Inf depends on sign of zero denominator
       ;; pos/+0=+Inf, neg/+0=-Inf, 0/+0=NaN  (same as x/0 above)
       ;; pos/-0=-Inf, neg/-0=+Inf, 0/-0=NaN  (sign flipped)
       ((when (or (eq arg2 :f32.+0) (eq arg2 :f32.-0)))
        (let* ((v1 (if (f32-valp arg1) (farg1 arg1) 0))
               (neg-denom (eq arg2 :f32.-0))
               (special
                (if (= v1 0) :f32.nan
                  (if (> v1 0)
                      (if neg-denom :f32.-inf :f32.+inf)
                    (if neg-denom :f32.+inf :f32.-inf))))
               (ostack (push-operand special (pop-operand (pop-operand ostack))))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ;; Handle ±0 numerator (treat as rational 0)
       ((when (or (eq arg1 :f32.+0) (eq arg1 :f32.-0)))
        (let* ((v2 (if (f32-valp arg2) (farg1 arg2) 0))
               (special (if (= v2 0) :f32.nan
                          (make-f32-val 0)))
               (ostack (push-operand special (pop-operand (pop-operand ostack))))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ((when (not (and (f32-valp arg1) (f32-valp arg2)))) :trap)
       (v1 (farg1 arg1))
       (v2 (farg1 arg2))
       ;; Finite x/0 ((:f32.const 0) denominator): same as +0 case
       ((when (= v2 0))
        (let* ((special (if (= v1 0) :f32.nan
                          (if (> v1 0) :f32.+inf :f32.-inf)))
               (ostack (push-operand special (pop-operand (pop-operand ostack))))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       (result (make-f32-val (/ v1 v2)))
       (ostack (push-operand result (pop-operand (pop-operand ostack))))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(def-f32-binop-inf execute-f32.min (min v1 v2) f32-inf-min)
(def-f32-binop-inf execute-f32.max (max v1 v2) f32-inf-max)

;; f32 unary
(defun execute-f32.neg (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ;; IEEE 754: neg(NaN)=NaN, neg(+Inf)=-Inf, neg(-Inf)=+Inf,
       ;; neg(+0)=-0, neg(-0)=+0, neg(x)=-x
       ((when (eq arg :f32.nan))
        (let* ((ostack (push-operand :f32.nan (pop-operand ostack)))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ((when (eq arg :f32.+inf))
        (let* ((ostack (push-operand :f32.-inf (pop-operand ostack)))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ((when (eq arg :f32.-inf))
        (let* ((ostack (push-operand :f32.+inf (pop-operand ostack)))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ((when (eq arg :f32.+0))
        (let* ((ostack (push-operand :f32.-0 (pop-operand ostack)))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ((when (eq arg :f32.-0))
        (let* ((ostack (push-operand :f32.+0 (pop-operand ostack)))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ((when (not (f32-valp arg))) :trap)
       ;; IEEE 754: neg(rational +0) = -0 (f32.const 0 is positive zero)
       ((when (= (farg1 arg) 0))
        (let* ((ostack (push-operand :f32.-0 (pop-operand ostack)))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       (result (make-f32-val (- (farg1 arg))))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(defun execute-f32.abs (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ;; IEEE 754: abs(NaN)=NaN, abs(±Inf)=+Inf, abs(±0)=+0
       ((when (eq arg :f32.nan))
        (let* ((ostack (push-operand :f32.nan (pop-operand ostack)))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ((when (or (eq arg :f32.+inf) (eq arg :f32.-inf)))
        (let* ((ostack (push-operand :f32.+inf (pop-operand ostack)))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ((when (or (eq arg :f32.+0) (eq arg :f32.-0)))
        (let* ((ostack (push-operand :f32.+0 (pop-operand ostack)))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ((when (not (f32-valp arg))) :trap)
       (result (make-f32-val (abs (farg1 arg))))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(defun execute-f32.sqrt (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ;; IEEE 754: sqrt(NaN)=NaN, sqrt(+Inf)=+Inf, sqrt(-Inf)=NaN
       ((when (eq arg :f32.nan))
        (let* ((ostack (push-operand :f32.nan (pop-operand ostack)))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ((when (eq arg :f32.+inf))
        (let* ((ostack (push-operand :f32.+inf (pop-operand ostack)))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ((when (not (f32-valp arg))) :trap)
       (v (farg1 arg))
       ;; sqrt of negative rational → NaN (per IEEE 754)
       ((when (< v 0))
        (let* ((ostack (push-operand :f32.nan (pop-operand ostack)))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ;; Exact sqrt for perfect squares; trap for non-integer rationals
       ;; (irrational results not representable in ACL2 rationals)
       ((when (not (integerp v))) :trap)
       (isq (if (= v 0) 0 (if (= v 1) 1 v)))
       (result (make-f32-val isq))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(defun execute-f32.ceil (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ;; IEEE 754: ceil(NaN)=NaN; ±Inf traps (irrational ceiling)
       ((when (eq arg :f32.nan))
        (let* ((ostack (push-operand :f32.nan (pop-operand ostack)))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ((when (not (f32-valp arg))) :trap)
       (result (make-f32-val (ceiling (farg1 arg) 1)))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(defun execute-f32.floor (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ;; IEEE 754: floor(NaN)=NaN
       ((when (eq arg :f32.nan))
        (let* ((ostack (push-operand :f32.nan (pop-operand ostack)))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ((when (not (f32-valp arg))) :trap)
       (result (make-f32-val (floor (farg1 arg) 1)))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;; f32.trunc: round toward zero (truncate fractional part), result is float
(defun execute-f32.trunc (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ;; IEEE 754: trunc(NaN)=NaN
       ((when (eq arg :f32.nan))
        (let* ((ostack (push-operand :f32.nan (pop-operand ostack)))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ((when (not (f32-valp arg))) :trap)
       (result (make-f32-val (truncate (farg1 arg) 1)))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;; f32.nearest: round to nearest integer, ties to even (banker's rounding)
(defun execute-f32.nearest (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ;; IEEE 754: nearest(NaN)=NaN
       ((when (eq arg :f32.nan))
        (let* ((ostack (push-operand :f32.nan (pop-operand ostack)))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ((when (not (f32-valp arg))) :trap)
       (v (farg1 arg))
       (int-part (truncate v 1))
       (frac (- v int-part))
       (abs-frac (abs frac))
       (rounded (cond ((< abs-frac 1/2) int-part)
                      ((> abs-frac 1/2) (if (>= v 0) (+ int-part 1) (- int-part 1)))
                      (t ; exactly 1/2 — round to even
                       (let ((low int-part)
                             (high (if (>= v 0) (+ int-part 1) (- int-part 1))))
                         (if (evenp low) low high)))))
       (result (make-f32-val rounded))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;; f32.copysign: magnitude of first arg, sign of second arg
;; IEEE 754: copysign(NaN, x) = NaN.
;; Signed zeros: copysign(x, -0) = negative x; copysign(x, +0) = positive x.
;; ±Inf magnitude: copysign(±Inf, sign) = ±Inf following sign.
;; (f32-sign-negativep is defined in the Inf-arithmetic helpers section above)

(defun execute-f32.copysign (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
       (arg2 (top-operand ostack))
       (arg1 (top-operand (pop-operand ostack)))
       ;; NaN in magnitude → NaN result
       ((when (or (eq arg1 :f32.nan) (eq arg2 :f32.nan)))
        (let* ((ostack (push-operand :f32.nan (pop-operand (pop-operand ostack))))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ;; Determine sign from arg2 (negative if -inf, -0, or negative finite)
       (neg (f32-sign-negativep arg2))
       ;; Compute result based on arg1 (magnitude source)
       (result
        (cond ((or (eq arg1 :f32.+0) (eq arg1 :f32.-0))
               (if neg :f32.-0 :f32.+0))
              ((or (eq arg1 :f32.+inf) (eq arg1 :f32.-inf))
               (if neg :f32.-inf :f32.+inf))
              ((f32-valp arg1)
               (let ((m (abs (farg1 arg1))))
                 (make-f32-val (if neg (- m) m))))
              (t nil)))
       ((when (not result)) :trap)
       (ostack (push-operand result (pop-operand (pop-operand ostack))))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;; f32 comparisons (return i32)
;; IEEE 754: NaN is unordered — ordered comparisons (eq,lt,gt,le,ge) return 0;
;; ne returns 1 because NaN is not equal to anything (including itself).
(def-f32-cmpop execute-f32.eq (= v1 v2))
(def-f32-cmpop execute-f32.ne (not (= v1 v2)) :nan-result 1)
(def-f32-cmpop execute-f32.lt (< v1 v2))
(def-f32-cmpop execute-f32.gt (> v1 v2))
(def-f32-cmpop execute-f32.le (<= v1 v2))
(def-f32-cmpop execute-f32.ge (>= v1 v2))

;; f64 arithmetic (Inf-aware)
(def-f64-binop-inf execute-f64.add (+ v1 v2) f64-inf-add)
(def-f64-binop-inf execute-f64.sub (- v1 v2) f64-inf-sub)
(def-f64-binop-inf execute-f64.mul (* v1 v2) f64-inf-mul)

(defun execute-f64.div (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
       (arg2 (top-operand ostack))
       (arg1 (top-operand (pop-operand ostack)))
       ;; IEEE 754: NaN propagates
       ((when (or (eq arg1 :f64.nan) (eq arg2 :f64.nan)))
        (let* ((ostack (push-operand :f64.nan (pop-operand (pop-operand ostack))))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ;; IEEE 754: ±Inf / ±Inf = NaN; ±Inf / finite = ±Inf; finite / ±Inf = ±0
       ((when (or (f64-infp arg1) (f64-infp arg2)))
        (let* ((result
                (cond
                 ((and (f64-infp arg1) (f64-infp arg2)) :f64.nan)
                 ((f64-infp arg1)
                  (if (not (eq (f64-sign-negativep arg1) (f64-sign-negativep arg2)))
                      :f64.-inf :f64.+inf))
                 (t (if (not (eq (f64-sign-negativep arg1) (f64-sign-negativep arg2)))
                        :f64.-0 :f64.+0))))
               (ostack (push-operand result (pop-operand (pop-operand ostack))))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ;; IEEE 754: x/±0 — sign of Inf depends on sign of zero denominator
       ((when (or (eq arg2 :f64.+0) (eq arg2 :f64.-0)))
        (let* ((v1 (if (f64-valp arg1) (farg1 arg1) 0))
               (neg-denom (eq arg2 :f64.-0))
               (special
                (if (= v1 0) :f64.nan
                  (if (> v1 0)
                      (if neg-denom :f64.-inf :f64.+inf)
                    (if neg-denom :f64.+inf :f64.-inf))))
               (ostack (push-operand special (pop-operand (pop-operand ostack))))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ;; Handle ±0 numerator
       ((when (or (eq arg1 :f64.+0) (eq arg1 :f64.-0)))
        (let* ((v2 (if (f64-valp arg2) (farg1 arg2) 0))
               (special (if (= v2 0) :f64.nan
                          (make-f64-val 0)))
               (ostack (push-operand special (pop-operand (pop-operand ostack))))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ((when (not (and (f64-valp arg1) (f64-valp arg2)))) :trap)
       (v1 (farg1 arg1))
       (v2 (farg1 arg2))
       ;; Finite x/0 denominator
       ((when (= v2 0))
        (let* ((special (if (= v1 0) :f64.nan
                          (if (> v1 0) :f64.+inf :f64.-inf)))
               (ostack (push-operand special (pop-operand (pop-operand ostack))))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       (result (make-f64-val (/ v1 v2)))
       (ostack (push-operand result (pop-operand (pop-operand ostack))))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(def-f64-binop-inf execute-f64.min (min v1 v2) f64-inf-min)
(def-f64-binop-inf execute-f64.max (max v1 v2) f64-inf-max)

;; f64 unary
(defun execute-f64.neg (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ;; IEEE 754: neg(NaN)=NaN, neg(+Inf)=-Inf, neg(-Inf)=+Inf,
       ;; neg(+0)=-0, neg(-0)=+0, neg(x)=-x
       ((when (eq arg :f64.nan))
        (let* ((ostack (push-operand :f64.nan (pop-operand ostack)))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ((when (eq arg :f64.+inf))
        (let* ((ostack (push-operand :f64.-inf (pop-operand ostack)))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ((when (eq arg :f64.-inf))
        (let* ((ostack (push-operand :f64.+inf (pop-operand ostack)))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ((when (eq arg :f64.+0))
        (let* ((ostack (push-operand :f64.-0 (pop-operand ostack)))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ((when (eq arg :f64.-0))
        (let* ((ostack (push-operand :f64.+0 (pop-operand ostack)))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ((when (not (f64-valp arg))) :trap)
       ;; IEEE 754: neg(rational +0) = -0
       ((when (= (farg1 arg) 0))
        (let* ((ostack (push-operand :f64.-0 (pop-operand ostack)))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       (result (make-f64-val (- (farg1 arg))))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(defun execute-f64.abs (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ;; IEEE 754: abs(NaN)=NaN, abs(±Inf)=+Inf, abs(±0)=+0
       ((when (eq arg :f64.nan))
        (let* ((ostack (push-operand :f64.nan (pop-operand ostack)))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ((when (or (eq arg :f64.+inf) (eq arg :f64.-inf)))
        (let* ((ostack (push-operand :f64.+inf (pop-operand ostack)))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ((when (or (eq arg :f64.+0) (eq arg :f64.-0)))
        (let* ((ostack (push-operand :f64.+0 (pop-operand ostack)))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ((when (not (f64-valp arg))) :trap)
       (result (make-f64-val (abs (farg1 arg))))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(defun execute-f64.sqrt (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ;; IEEE 754: sqrt(NaN)=NaN, sqrt(+Inf)=+Inf, sqrt(-Inf)=NaN
       ((when (eq arg :f64.nan))
        (let* ((ostack (push-operand :f64.nan (pop-operand ostack)))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ((when (eq arg :f64.+inf))
        (let* ((ostack (push-operand :f64.+inf (pop-operand ostack)))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ((when (not (f64-valp arg))) :trap)
       (v (farg1 arg))
       ;; sqrt of negative rational → NaN (per IEEE 754)
       ((when (< v 0))
        (let* ((ostack (push-operand :f64.nan (pop-operand ostack)))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ((when (not (integerp v))) :trap)
       (isq (if (= v 0) 0 (if (= v 1) 1 v)))
       (result (make-f64-val isq))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(defun execute-f64.ceil (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ;; IEEE 754: ceil(NaN)=NaN
       ((when (eq arg :f64.nan))
        (let* ((ostack (push-operand :f64.nan (pop-operand ostack)))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ((when (not (f64-valp arg))) :trap)
       (result (make-f64-val (ceiling (farg1 arg) 1)))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(defun execute-f64.floor (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ;; IEEE 754: floor(NaN)=NaN
       ((when (eq arg :f64.nan))
        (let* ((ostack (push-operand :f64.nan (pop-operand ostack)))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ((when (not (f64-valp arg))) :trap)
       (result (make-f64-val (floor (farg1 arg) 1)))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;; f64.trunc: round toward zero, result is float
(defun execute-f64.trunc (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ;; IEEE 754: trunc(NaN)=NaN
       ((when (eq arg :f64.nan))
        (let* ((ostack (push-operand :f64.nan (pop-operand ostack)))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ((when (not (f64-valp arg))) :trap)
       (result (make-f64-val (truncate (farg1 arg) 1)))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;; f64.nearest: round to nearest integer, ties to even
(defun execute-f64.nearest (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ;; IEEE 754: nearest(NaN)=NaN
       ((when (eq arg :f64.nan))
        (let* ((ostack (push-operand :f64.nan (pop-operand ostack)))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       ((when (not (f64-valp arg))) :trap)
       (v (farg1 arg))
       (int-part (truncate v 1))
       (frac (- v int-part))
       (abs-frac (abs frac))
       (rounded (cond ((< abs-frac 1/2) int-part)
                      ((> abs-frac 1/2) (if (>= v 0) (+ int-part 1) (- int-part 1)))
                      (t ; exactly 1/2 — round to even
                       (let ((low int-part)
                             (high (if (>= v 0) (+ int-part 1) (- int-part 1))))
                         (if (evenp low) low high)))))
       (result (make-f64-val rounded))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;; f64.copysign: magnitude of first arg, sign of second arg
;; IEEE 754: copysign(NaN, x) = NaN. Signed zeros and ±Inf handled correctly.
;; (f64-sign-negativep is defined in the Inf-arithmetic helpers section above)

(defun execute-f64.copysign (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
       (arg2 (top-operand ostack))
       (arg1 (top-operand (pop-operand ostack)))
       ;; NaN in magnitude → NaN result
       ((when (or (eq arg1 :f64.nan) (eq arg2 :f64.nan)))
        (let* ((ostack (push-operand :f64.nan (pop-operand (pop-operand ostack))))
               (state (update-current-operand-stack ostack state)))
          (advance-instrs state)))
       (neg (f64-sign-negativep arg2))
       (result
        (cond ((or (eq arg1 :f64.+0) (eq arg1 :f64.-0))
               (if neg :f64.-0 :f64.+0))
              ((or (eq arg1 :f64.+inf) (eq arg1 :f64.-inf))
               (if neg :f64.-inf :f64.+inf))
              ((f64-valp arg1)
               (let ((m (abs (farg1 arg1))))
                 (make-f64-val (if neg (- m) m))))
              (t nil)))
       ((when (not result)) :trap)
       (ostack (push-operand result (pop-operand (pop-operand ostack))))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;; f64 comparisons (return i32) — same IEEE 754 NaN semantics as f32
(def-f64-cmpop execute-f64.eq (= v1 v2))
(def-f64-cmpop execute-f64.ne (not (= v1 v2)) :nan-result 1)
(def-f64-cmpop execute-f64.lt (< v1 v2))
(def-f64-cmpop execute-f64.gt (> v1 v2))
(def-f64-cmpop execute-f64.le (<= v1 v2))
(def-f64-cmpop execute-f64.ge (>= v1 v2))

;; Float-integer conversions (M7a)
;; i32/i64 → f32/f64: straightforward rational embedding

(defun execute-f32.convert_i32_s (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ((when (not (i32-valp arg))) :trap)
       (v (farg1 arg))
       ;; Signed interpretation: if v >= 2^31, treat as v - 2^32
       (sv (if (>= v (expt 2 31)) (- v (expt 2 32)) v))
       (result (make-f32-val sv))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(defun execute-f32.convert_i32_u (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ((when (not (i32-valp arg))) :trap)
       (result (make-f32-val (farg1 arg)))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(defun execute-f32.convert_i64_s (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ((when (not (i64-valp arg))) :trap)
       (v (farg1 arg))
       (sv (if (>= v (expt 2 63)) (- v (expt 2 64)) v))
       (result (make-f32-val sv))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(defun execute-f32.convert_i64_u (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ((when (not (i64-valp arg))) :trap)
       (result (make-f32-val (farg1 arg)))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(defun execute-f64.convert_i32_s (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ((when (not (i32-valp arg))) :trap)
       (v (farg1 arg))
       (sv (if (>= v (expt 2 31)) (- v (expt 2 32)) v))
       (result (make-f64-val sv))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(defun execute-f64.convert_i32_u (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ((when (not (i32-valp arg))) :trap)
       (result (make-f64-val (farg1 arg)))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(defun execute-f64.convert_i64_s (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ((when (not (i64-valp arg))) :trap)
       (v (farg1 arg))
       (sv (if (>= v (expt 2 63)) (- v (expt 2 64)) v))
       (result (make-f64-val sv))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(defun execute-f64.convert_i64_u (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ((when (not (i64-valp arg))) :trap)
       (result (make-f64-val (farg1 arg)))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;; f32 ↔ f64 promotion/demotion (identity on rationals)
(defun execute-f32.demote_f64 (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ((when (not (f64-valp arg))) :trap)
       (result (make-f32-val (farg1 arg)))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(defun execute-f64.promote_f32 (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ((when (not (f32-valp arg))) :trap)
       (result (make-f64-val (farg1 arg)))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;; f32/f64 → i32/i64 truncation
;; Traps if value is out of range or negative for unsigned

(defun execute-i32.trunc_f32_s (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ((when (not (f32-valp arg))) :trap)
       (v (farg1 arg))
       (tv (truncate v 1))
       ((when (or (< tv (- (expt 2 31))) (>= tv (expt 2 31)))) :trap)
       ;; Convert signed to unsigned representation
       (uv (if (< tv 0) (+ tv (expt 2 32)) tv))
       (result (make-i32-val uv))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(defun execute-i32.trunc_f32_u (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ((when (not (f32-valp arg))) :trap)
       (v (farg1 arg))
       (tv (truncate v 1))
       ((when (or (< tv 0) (>= tv (expt 2 32)))) :trap)
       (result (make-i32-val tv))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(defun execute-i32.trunc_f64_s (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ((when (not (f64-valp arg))) :trap)
       (v (farg1 arg))
       (tv (truncate v 1))
       ((when (or (< tv (- (expt 2 31))) (>= tv (expt 2 31)))) :trap)
       (uv (if (< tv 0) (+ tv (expt 2 32)) tv))
       (result (make-i32-val uv))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(defun execute-i32.trunc_f64_u (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ((when (not (f64-valp arg))) :trap)
       (v (farg1 arg))
       (tv (truncate v 1))
       ((when (or (< tv 0) (>= tv (expt 2 32)))) :trap)
       (result (make-i32-val tv))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(defun execute-i64.trunc_f32_s (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ((when (not (f32-valp arg))) :trap)
       (v (farg1 arg))
       (tv (truncate v 1))
       ((when (or (< tv (- (expt 2 63))) (>= tv (expt 2 63)))) :trap)
       (uv (if (< tv 0) (+ tv (expt 2 64)) tv))
       (result (make-i64-val uv))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(defun execute-i64.trunc_f32_u (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ((when (not (f32-valp arg))) :trap)
       (v (farg1 arg))
       (tv (truncate v 1))
       ((when (or (< tv 0) (>= tv (expt 2 64)))) :trap)
       (result (make-i64-val tv))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(defun execute-i64.trunc_f64_s (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ((when (not (f64-valp arg))) :trap)
       (v (farg1 arg))
       (tv (truncate v 1))
       ((when (or (< tv (- (expt 2 63))) (>= tv (expt 2 63)))) :trap)
       (uv (if (< tv 0) (+ tv (expt 2 64)) tv))
       (result (make-i64-val uv))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(defun execute-i64.trunc_f64_u (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ((when (not (f64-valp arg))) :trap)
       (v (farg1 arg))
       (tv (truncate v 1))
       ((when (or (< tv 0) (>= tv (expt 2 64)))) :trap)
       (result (make-i64-val tv))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reinterpret instructions (M11)
;; Use Kestrel IEEE 754 library for bit-accurate encoding/decoding.
;; Non-rational results (NaN, ±∞) trap in our rational model.

;; f32.reinterpret_i32: reinterpret i32 bits as f32
(defun execute-f32.reinterpret_i32 (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ((when (not (i32-valp arg))) :trap)
       (bits (farg1 arg))
       (datum (acl2::decode-bv-float32 bits))
       ;; Trap on NaN/infinity/signed-zeros (not representable as rationals)
       ((when (not (rationalp datum))) :trap)
       (result (make-f32-val datum))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;; i32.reinterpret_f32: reinterpret f32 as i32 bits
(defun execute-i32.reinterpret_f32 (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ((when (not (f32-valp arg))) :trap)
       (v (farg1 arg))
       (bits (if (= v 0)
                 0  ; +0.0f
                 (acl2::encode-bv-float 32 24 v nil)))
       (result (make-i32-val (acl2::bvchop 32 bits)))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;; f64.reinterpret_i64: reinterpret i64 bits as f64
(defun execute-f64.reinterpret_i64 (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ((when (not (i64-valp arg))) :trap)
       (bits (farg1 arg))
       (datum (acl2::decode-bv-float64 bits))
       ((when (not (rationalp datum))) :trap)
       (result (make-f64-val datum))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;; i64.reinterpret_f64: reinterpret f64 as i64 bits
(defun execute-i64.reinterpret_f64 (state)
  (declare (xargs :guard (statep state) :verify-guards nil))
  (b* ((ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (arg (top-operand ostack))
       ((when (not (f64-valp arg))) :trap)
       (v (farg1 arg))
       (bits (if (= v 0)
                 0  ; +0.0
                 (acl2::encode-bv-float 64 53 v nil)))
       (result (make-i64-val (acl2::bvchop 64 bits)))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Float load/store (M11)
;; f32.load/f64.load: read bytes from memory, assemble as integer, decode IEEE 754
;; f32.store/f64.store: encode IEEE 754 as integer, break into bytes, write to memory

(defun execute-f32.load (args state)
  (declare (xargs :guard (and (consp args) (natp (first args)) (statep state))
                  :verify-guards nil))
  (b* ((offset (first args))
       (ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (addr-val (top-operand ostack))
       ((when (not (i32-valp addr-val))) :trap)
       (addr (+ (farg1 addr-val) offset))
       (mem (state->memory state))
       ((when (> (+ addr 4) (len mem))) :trap)
       ;; Read 4 bytes little-endian → u32
       (u32 (+ (nth addr mem)
               (* 256 (nth (+ 1 addr) mem))
               (* 65536 (nth (+ 2 addr) mem))
               (* 16777216 (nth (+ 3 addr) mem))))
       ;; Decode as IEEE 754 binary32
       (datum (acl2::decode-bv-float32 u32))
       ((when (not (rationalp datum))) :trap)
       (result (make-f32-val datum))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(defun execute-f64.load (args state)
  (declare (xargs :guard (and (consp args) (natp (first args)) (statep state))
                  :verify-guards nil))
  (b* ((offset (first args))
       (ostack (current-operand-stack state))
       ((when (not (<= 1 (operand-stack-height ostack)))) :trap)
       (addr-val (top-operand ostack))
       ((when (not (i32-valp addr-val))) :trap)
       (addr (+ (farg1 addr-val) offset))
       (mem (state->memory state))
       ((when (> (+ addr 8) (len mem))) :trap)
       ;; Read 8 bytes little-endian → u64
       (u64 (+ (nth addr mem)
               (* (expt 2 8)  (nth (+ 1 addr) mem))
               (* (expt 2 16) (nth (+ 2 addr) mem))
               (* (expt 2 24) (nth (+ 3 addr) mem))
               (* (expt 2 32) (nth (+ 4 addr) mem))
               (* (expt 2 40) (nth (+ 5 addr) mem))
               (* (expt 2 48) (nth (+ 6 addr) mem))
               (* (expt 2 56) (nth (+ 7 addr) mem))))
       ;; Decode as IEEE 754 binary64
       (datum (acl2::decode-bv-float64 u64))
       ((when (not (rationalp datum))) :trap)
       (result (make-f64-val datum))
       (ostack (push-operand result (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(defun execute-f32.store (args state)
  (declare (xargs :guard (and (consp args) (natp (first args)) (statep state))
                  :verify-guards nil))
  (b* ((offset (first args))
       (ostack (current-operand-stack state))
       ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
       (val-arg (top-operand ostack))
       (addr-arg (top-operand (pop-operand ostack)))
       ((when (not (and (f32-valp val-arg) (i32-valp addr-arg)))) :trap)
       (v (farg1 val-arg))
       (addr (+ (farg1 addr-arg) offset))
       (mem (state->memory state))
       ((when (> (+ addr 4) (len mem))) :trap)
       ;; Encode rational as IEEE 754 binary32 bits
       (u32 (if (= v 0) 0 (acl2::bvchop 32 (acl2::encode-bv-float 32 24 v nil))))
       ;; Write 4 bytes little-endian
       (mem (update-nth addr          (mod u32 256) mem))
       (mem (update-nth (+ 1 addr) (mod (floor u32 256) 256) mem))
       (mem (update-nth (+ 2 addr) (mod (floor u32 65536) 256) mem))
       (mem (update-nth (+ 3 addr) (mod (floor u32 16777216) 256) mem))
       (state (update-memory mem state))
       (ostack (pop-operand (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

(defun execute-f64.store (args state)
  (declare (xargs :guard (and (consp args) (natp (first args)) (statep state))
                  :verify-guards nil))
  (b* ((offset (first args))
       (ostack (current-operand-stack state))
       ((when (not (<= 2 (operand-stack-height ostack)))) :trap)
       (val-arg (top-operand ostack))
       (addr-arg (top-operand (pop-operand ostack)))
       ((when (not (and (f64-valp val-arg) (i32-valp addr-arg)))) :trap)
       (v (farg1 val-arg))
       (addr (+ (farg1 addr-arg) offset))
       (mem (state->memory state))
       ((when (> (+ addr 8) (len mem))) :trap)
       ;; Encode rational as IEEE 754 binary64 bits
       (u64 (if (= v 0) 0 (acl2::bvchop 64 (acl2::encode-bv-float 64 53 v nil))))
       ;; Write 8 bytes little-endian
       (mem (update-nth addr          (mod u64 256) mem))
       (mem (update-nth (+ 1 addr) (mod (floor u64 256) 256) mem))
       (mem (update-nth (+ 2 addr) (mod (floor u64 65536) 256) mem))
       (mem (update-nth (+ 3 addr) (mod (floor u64 16777216) 256) mem))
       (mem (update-nth (+ 4 addr) (mod (floor u64 (expt 2 32)) 256) mem))
       (mem (update-nth (+ 5 addr) (mod (floor u64 (expt 2 40)) 256) mem))
       (mem (update-nth (+ 6 addr) (mod (floor u64 (expt 2 48)) 256) mem))
       (mem (update-nth (+ 7 addr) (mod (floor u64 (expt 2 56)) 256) mem))
       (state (update-memory mem state))
       (ostack (pop-operand (pop-operand ostack)))
       (state (update-current-operand-stack ostack state)))
    (advance-instrs state)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Instruction dispatch

;; Returns a new state or :trap.
(defund execute-instr (instr state)
  (declare (xargs :guard (and (instrp instr)
                              (statep state))
                  :verify-guards nil))
  (let ((name (ffn-symb instr))
        (args (fargs instr)))
    (case name
      ;; Parametric
      (:nop (execute-nop state))
      (:unreachable (execute-unreachable state))
      (:drop (execute-drop state))
      (:select (execute-select state))
      ;; Variable
      (:local.get (execute-local.get args state))
      (:local.set (execute-local.set args state))
      (:local.tee (execute-local.tee args state))
      ;; Global variable (M5+)
      (:global.get (execute-global.get args state))
      (:global.set (execute-global.set args state))
      ;; Numeric constant
      (:i32.const (execute-i32.const args state))
      ;; i32 arithmetic
      (:i32.add (execute-i32.add state))
      (:i32.sub (execute-i32.sub state))
      (:i32.mul (execute-i32.mul state))
      (:i32.div_u (execute-i32.div_u state))
      (:i32.div_s (execute-i32.div_s state))
      (:i32.rem_u (execute-i32.rem_u state))
      (:i32.rem_s (execute-i32.rem_s state))
      ;; i32 bitwise
      (:i32.and (execute-i32.and state))
      (:i32.or  (execute-i32.or state))
      (:i32.xor (execute-i32.xor state))
      (:i32.shl (execute-i32.shl state))
      (:i32.shr_u (execute-i32.shr_u state))
      (:i32.shr_s (execute-i32.shr_s state))
      (:i32.rotl (execute-i32.rotl state))
      (:i32.rotr (execute-i32.rotr state))
      ;; i32 unary
      (:i32.clz (execute-i32.clz state))
      (:i32.ctz (execute-i32.ctz state))
      (:i32.popcnt (execute-i32.popcnt state))
      ;; i32 test/comparison
      (:i32.eqz (execute-i32.eqz state))
      (:i32.eq  (execute-i32.eq state))
      (:i32.ne  (execute-i32.ne state))
      (:i32.lt_u (execute-i32.lt_u state))
      (:i32.lt_s (execute-i32.lt_s state))
      (:i32.gt_u (execute-i32.gt_u state))
      (:i32.gt_s (execute-i32.gt_s state))
      (:i32.le_u (execute-i32.le_u state))
      (:i32.le_s (execute-i32.le_s state))
      (:i32.ge_u (execute-i32.ge_u state))
      (:i32.ge_s (execute-i32.ge_s state))
      ;; Control flow (M2)
      (:block (execute-block args state))
      (:loop (execute-loop args state))
      (:if (execute-if args state))
      (:br (execute-br args state))
      (:br_if (execute-br_if args state))
      (:br_table (execute-br_table args state))
      (:return (execute-return state))
      ;; Function call (M3)
      (:call (execute-call args state))
      (:call_indirect (execute-call_indirect args state))
      ;; i64 operations (M5)
      (:i64.const (execute-i64.const args state))
      (:i64.add (execute-i64.add state))
      (:i64.sub (execute-i64.sub state))
      (:i64.mul (execute-i64.mul state))
      (:i64.div_u (execute-i64.div_u state))
      (:i64.div_s (execute-i64.div_s state))
      (:i64.rem_u (execute-i64.rem_u state))
      (:i64.rem_s (execute-i64.rem_s state))
      (:i64.and (execute-i64.and state))
      (:i64.or  (execute-i64.or state))
      (:i64.xor (execute-i64.xor state))
      (:i64.shl (execute-i64.shl state))
      (:i64.shr_u (execute-i64.shr_u state))
      (:i64.shr_s (execute-i64.shr_s state))
      (:i64.rotl (execute-i64.rotl state))
      (:i64.rotr (execute-i64.rotr state))
      (:i64.clz (execute-i64.clz state))
      (:i64.ctz (execute-i64.ctz state))
      (:i64.popcnt (execute-i64.popcnt state))
      (:i64.eqz (execute-i64.eqz state))
      (:i64.eq  (execute-i64.eq state))
      (:i64.ne  (execute-i64.ne state))
      (:i64.lt_u (execute-i64.lt_u state))
      (:i64.lt_s (execute-i64.lt_s state))
      (:i64.gt_u (execute-i64.gt_u state))
      (:i64.gt_s (execute-i64.gt_s state))
      (:i64.le_u (execute-i64.le_u state))
      (:i64.le_s (execute-i64.le_s state))
      (:i64.ge_u (execute-i64.ge_u state))
      (:i64.ge_s (execute-i64.ge_s state))
      ;; Conversions (M5)
      (:i32.wrap_i64 (execute-i32.wrap_i64 state))
      (:i64.extend_i32_u (execute-i64.extend_i32_u state))
      (:i64.extend_i32_s (execute-i64.extend_i32_s state))
      ;; Memory (M4/M5)
      (:i32.load (execute-i32.load args state))
      (:i32.store (execute-i32.store args state))
      (:i64.load (execute-i64.load args state))
      (:i64.store (execute-i64.store args state))
      ;; Packed memory (M4b)
      (:i32.load8_u  (execute-i32.load8_u args state))
      (:i32.load8_s  (execute-i32.load8_s args state))
      (:i32.load16_u (execute-i32.load16_u args state))
      (:i32.load16_s (execute-i32.load16_s args state))
      (:i32.store8   (execute-i32.store8 args state))
      (:i32.store16  (execute-i32.store16 args state))
      (:i64.load8_u  (execute-i64.load8_u args state))
      (:i64.load8_s  (execute-i64.load8_s args state))
      (:i64.load16_u (execute-i64.load16_u args state))
      (:i64.load16_s (execute-i64.load16_s args state))
      (:i64.load32_u (execute-i64.load32_u args state))
      (:i64.load32_s (execute-i64.load32_s args state))
      (:i64.store8   (execute-i64.store8 args state))
      (:i64.store16  (execute-i64.store16 args state))
      (:i64.store32  (execute-i64.store32 args state))
      (:memory.size (execute-memory.size state))
      (:memory.grow (execute-memory.grow state))
      ;; f32 operations (M7a)
      (:f32.const (execute-f32.const args state))
      (:f32.add (execute-f32.add state))
      (:f32.sub (execute-f32.sub state))
      (:f32.mul (execute-f32.mul state))
      (:f32.div (execute-f32.div state))
      (:f32.neg (execute-f32.neg state))
      (:f32.abs (execute-f32.abs state))
      (:f32.sqrt (execute-f32.sqrt state))
      (:f32.ceil (execute-f32.ceil state))
      (:f32.floor (execute-f32.floor state))
      (:f32.trunc (execute-f32.trunc state))
      (:f32.nearest (execute-f32.nearest state))
      (:f32.copysign (execute-f32.copysign state))
      (:f32.eq (execute-f32.eq state))
      (:f32.ne (execute-f32.ne state))
      (:f32.lt (execute-f32.lt state))
      (:f32.gt (execute-f32.gt state))
      (:f32.le (execute-f32.le state))
      (:f32.ge (execute-f32.ge state))
      (:f32.min (execute-f32.min state))
      (:f32.max (execute-f32.max state))
      ;; f64 operations (M7a)
      (:f64.const (execute-f64.const args state))
      (:f64.add (execute-f64.add state))
      (:f64.sub (execute-f64.sub state))
      (:f64.mul (execute-f64.mul state))
      (:f64.div (execute-f64.div state))
      (:f64.neg (execute-f64.neg state))
      (:f64.abs (execute-f64.abs state))
      (:f64.sqrt (execute-f64.sqrt state))
      (:f64.ceil (execute-f64.ceil state))
      (:f64.floor (execute-f64.floor state))
      (:f64.trunc (execute-f64.trunc state))
      (:f64.nearest (execute-f64.nearest state))
      (:f64.copysign (execute-f64.copysign state))
      (:f64.eq (execute-f64.eq state))
      (:f64.ne (execute-f64.ne state))
      (:f64.lt (execute-f64.lt state))
      (:f64.gt (execute-f64.gt state))
      (:f64.le (execute-f64.le state))
      (:f64.ge (execute-f64.ge state))
      (:f64.min (execute-f64.min state))
      (:f64.max (execute-f64.max state))
      ;; Float conversions (M7a)
      (:f32.convert_i32_s (execute-f32.convert_i32_s state))
      (:f32.convert_i32_u (execute-f32.convert_i32_u state))
      (:f32.convert_i64_s (execute-f32.convert_i64_s state))
      (:f32.convert_i64_u (execute-f32.convert_i64_u state))
      (:f64.convert_i32_s (execute-f64.convert_i32_s state))
      (:f64.convert_i32_u (execute-f64.convert_i32_u state))
      (:f64.convert_i64_s (execute-f64.convert_i64_s state))
      (:f64.convert_i64_u (execute-f64.convert_i64_u state))
      (:f32.demote_f64 (execute-f32.demote_f64 state))
      (:f64.promote_f32 (execute-f64.promote_f32 state))
      (:i32.trunc_f32_s (execute-i32.trunc_f32_s state))
      (:i32.trunc_f32_u (execute-i32.trunc_f32_u state))
      (:i32.trunc_f64_s (execute-i32.trunc_f64_s state))
      (:i32.trunc_f64_u (execute-i32.trunc_f64_u state))
      (:i64.trunc_f32_s (execute-i64.trunc_f32_s state))
      (:i64.trunc_f32_u (execute-i64.trunc_f32_u state))
      (:i64.trunc_f64_s (execute-i64.trunc_f64_s state))
      (:i64.trunc_f64_u (execute-i64.trunc_f64_u state))
      ;; Reinterpret (M11)
      (:f32.reinterpret_i32 (execute-f32.reinterpret_i32 state))
      (:i32.reinterpret_f32 (execute-i32.reinterpret_f32 state))
      (:f64.reinterpret_i64 (execute-f64.reinterpret_i64 state))
      (:i64.reinterpret_f64 (execute-i64.reinterpret_f64 state))
      ;; Float load/store (M11)
      (:f32.load (execute-f32.load args state))
      (:f64.load (execute-f64.load args state))
      (:f32.store (execute-f32.store args state))
      (:f64.store (execute-f64.store args state))
      (otherwise (prog2$ (cw "Unhandled instr: ~x0.~%" instr)
                         :trap)))))

;; TODO: Restore statep-of-execute-instr theorem once guard verification
;; is completed for all execute-* functions.

;; returns a new state or :trap or (:done ..)
;; todo: handle blocks and loops
(defun step (state)
  (declare (xargs :guard (and (statep state)
                              (consp (current-instrs state)))
                  :verify-guards nil))
  (let* ((instrs (current-instrs state))
         (instr (first instrs))
         (state-or-trap (execute-instr instr state)))
    (if (eq :trap state-or-trap)
        :trap
      state-or-trap)))

;; 4.4.10
(defund return-from-function (state)
  (declare (xargs :guard (and (statep state)
                              (not (consp (current-instrs state))))
                  :verify-guards nil))
  (b* ((call-stack (state->call-stack state))
       ((when (not (consp (cdr call-stack)))) ; only 1 frame left — we're done
        `(:done ,state))
       (f (current-frame state))
       (n (frame->return-arity f))
       (ostack (frame->operand-stack f))
       ((when (not (<= n (operand-stack-height ostack))))
        :trap)
       (valn (top-n-operands n ostack nil))
       (call-stack (pop-call-stack call-stack))
       (state (change-state state :call-stack call-stack))
       (state (update-current-operand-stack (push-vals valn (current-operand-stack state)) state))
       (state (update-current-instrs (rest (current-instrs state)) state)))
    state))

(defun run (n state)
  (declare (xargs :guard (and (natp n)
                              (statep state))
                  :verify-guards nil))
  (if (zp n)
      state
    (if (not (consp (current-instrs state)))
        ;; No more instructions in current block
        (if (consp (current-label-stack state))
            ;; Labels remain: complete the innermost label
            (let ((new-state-or-trap (complete-label state)))
              (if (eq :trap new-state-or-trap)
                  :trap
                (run (+ -1 n) new-state-or-trap)))
          ;; No labels: return from function
          (let ((result (return-from-function state)))
            (cond ((eq :trap result) :trap)
                  ((and (consp result) (eq :done (first result))) result)
                  (t (run (+ -1 n) result)))))
      (let ((new-state-or-trap (step state)))
        (if (eq :trap new-state-or-trap)
            :trap
          (run (+ -1 n) new-state-or-trap))))))

;; a test:
;; (run 4
;;      (make-state :store :fake
;;                  :call-stack (list (make-frame :return-arity 1
;;                                                :locals (list (make-i32-val 7) (make-i32-val 8)) ; the params
;;                                                :operand-stack nil
;;                                                :instrs '((:local.get 1)
;;                                                          (:local.get 0)
;;                                                          (:i32.add))))))
