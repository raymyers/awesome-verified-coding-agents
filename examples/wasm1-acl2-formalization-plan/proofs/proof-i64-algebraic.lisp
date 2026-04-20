;; WASM 1.0 ACL2 — i64 Algebraic Instruction Properties
;;
;; Symbolic (universal) theorems about WASM i64 instruction semantics.
;; These prove that the ACL2 formalization correctly captures the
;; algebraic structure of WASM's 64-bit integer operations.
;;
;; All theorems are of the form: ∀ x,y ∈ u64. property(x,y)
;; These are proved by ACL2's rewriter + BV library rules.
;;
;; Companion to proof-algebraic-properties.lisp (which covers i32).

(in-package "ACL2")
(ld "/tmp/acl2-full/books/kestrel/wasm/package.lsp")
(in-package "WASM")
(include-book "kestrel/wasm/execution" :dir :system)
(include-book "kestrel/bv/bvuminus" :dir :system)
(local (include-book "arithmetic-5/top" :dir :system))

(set-guard-checking :none)

;; ─── Helpers ─────────────────────────────────────────────────────────────────

;; State with  i64.const a, i64.const b, (op)  on the instruction list
(defund mk-i64-binop (a b op)
  (declare (xargs :guard t :verify-guards nil))
  (make-state
   :store nil
   :call-stack (list (make-frame
                      :return-arity 1
                      :locals nil
                      :operand-stack (empty-operand-stack)
                      :instrs (list (list :i64.const a)
                                    (list :i64.const b)
                                    (list op))
                      :label-stack nil))
   :memory nil
   :globals nil))

;; State with  i64.const a, (op)  on the instruction list
(defund mk-i64-unop (a op)
  (declare (xargs :guard t :verify-guards nil))
  (make-state
   :store nil
   :call-stack (list (make-frame
                      :return-arity 1
                      :locals nil
                      :operand-stack (empty-operand-stack)
                      :instrs (list (list :i64.const a)
                                    (list op))
                      :label-stack nil))
   :memory nil
   :globals nil))

;; Extract top of operand stack after N steps
(defund i64-result (n state)
  (declare (xargs :guard t :verify-guards nil))
  (top-operand (current-operand-stack (run n state))))

;; ─── Theory ──────────────────────────────────────────────────────────────────

(defconst *i64-alg-theory*
  '(mk-i64-binop mk-i64-unop i64-result
    run step execute-instr
    execute-i64.const
    execute-i64.add execute-i64.sub execute-i64.mul
    execute-i64.and execute-i64.or execute-i64.xor
    execute-i64.shl execute-i64.shr_u
    execute-i64.rotl execute-i64.rotr
    execute-i64.eqz execute-i64.eq execute-i64.ne
    execute-i64.lt_u execute-i64.gt_u execute-i64.le_u execute-i64.ge_u
    current-frame current-instrs current-operand-stack
    current-label-stack current-locals
    update-current-operand-stack update-current-instrs
    complete-label return-from-function
    make-i64-val i64-valp i64-const-argsp no-argsp
    i32-valp f32-valp f64-valp
    push-operand top-operand pop-operand top-n-operands push-vals
    operand-stack-height empty-operand-stack operand-stackp
    localsp framep top-frame push-call-stack pop-call-stack call-stackp
    valp u32p u64p))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §1. ADDITIVE PROPERTIES

;; i64.add(x, 0) = x  (right identity)
(defthm i64-add-right-identity
  (implies (u64p x)
           (equal (i64-result 3 (mk-i64-binop x 0 :i64.add))
                  (make-i64-val x)))
  :hints (("Goal" :in-theory (enable . #.*i64-alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i64.add(0, x) = x  (left identity)
(defthm i64-add-left-identity
  (implies (u64p x)
           (equal (i64-result 3 (mk-i64-binop 0 x :i64.add))
                  (make-i64-val x)))
  :hints (("Goal" :in-theory (enable . #.*i64-alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i64.sub(x, 0) = x
(defthm i64-sub-right-identity
  (implies (u64p x)
           (equal (i64-result 3 (mk-i64-binop x 0 :i64.sub))
                  (make-i64-val x)))
  :hints (("Goal" :in-theory (enable . #.*i64-alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i64.sub(x, x) = 0
(defthm i64-sub-self-is-zero
  (implies (u64p x)
           (equal (i64-result 3 (mk-i64-binop x x :i64.sub))
                  (make-i64-val 0)))
  :hints (("Goal" :in-theory (enable acl2::bvminus acl2::bvplus
                                      acl2::bvuminus acl2::bvchop
                                      . #.*i64-alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §2. MULTIPLICATIVE PROPERTIES

;; i64.mul(x, 1) = x  (right identity)
(defthm i64-mul-right-identity
  (implies (u64p x)
           (equal (i64-result 3 (mk-i64-binop x 1 :i64.mul))
                  (make-i64-val x)))
  :hints (("Goal" :in-theory (enable . #.*i64-alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i64.mul(1, x) = x  (left identity)
(defthm i64-mul-left-identity
  (implies (u64p x)
           (equal (i64-result 3 (mk-i64-binop 1 x :i64.mul))
                  (make-i64-val x)))
  :hints (("Goal" :in-theory (enable . #.*i64-alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i64.mul(x, 0) = 0  (zero annihilator)
(defthm i64-mul-zero-annihilates
  (implies (u64p x)
           (equal (i64-result 3 (mk-i64-binop x 0 :i64.mul))
                  (make-i64-val 0)))
  :hints (("Goal" :in-theory (enable . #.*i64-alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §3. BITWISE PROPERTIES

;; i64.and(x, 0) = 0  (zero annihilator)
(defthm i64-and-zero-annihilates
  (implies (u64p x)
           (equal (i64-result 3 (mk-i64-binop x 0 :i64.and))
                  (make-i64-val 0)))
  :hints (("Goal" :in-theory (enable . #.*i64-alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i64.and(x, MAX64) = x  (all-ones identity)
(defthm i64-and-all-ones-identity
  (implies (u64p x)
           (equal (i64-result 3 (mk-i64-binop x (1- (expt 2 64)) :i64.and))
                  (make-i64-val x)))
  :hints (("Goal" :in-theory (enable . #.*i64-alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i64.or(x, 0) = x  (zero identity)
(defthm i64-or-identity
  (implies (u64p x)
           (equal (i64-result 3 (mk-i64-binop x 0 :i64.or))
                  (make-i64-val x)))
  :hints (("Goal" :in-theory (enable . #.*i64-alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i64.or(x, MAX64) = MAX64  (all-ones absorber)
(defthm i64-or-all-ones-absorbs
  (implies (u64p x)
           (equal (i64-result 3 (mk-i64-binop x (1- (expt 2 64)) :i64.or))
                  (make-i64-val (1- (expt 2 64)))))
  :hints (("Goal" :in-theory (enable . #.*i64-alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i64.xor(x, 0) = x  (zero identity)
(defthm i64-xor-identity
  (implies (u64p x)
           (equal (i64-result 3 (mk-i64-binop x 0 :i64.xor))
                  (make-i64-val x)))
  :hints (("Goal" :in-theory (enable . #.*i64-alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i64.xor(x, x) = 0  (self-inverse)
(defthm i64-xor-self-annihilates
  (implies (u64p x)
           (equal (i64-result 3 (mk-i64-binop x x :i64.xor))
                  (make-i64-val 0)))
  :hints (("Goal" :in-theory (enable . #.*i64-alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §4. SHIFT PROPERTIES

;; i64.shl(x, 0) = x  (identity shift)
(defthm i64-shl-zero-identity
  (implies (u64p x)
           (equal (i64-result 3 (mk-i64-binop x 0 :i64.shl))
                  (make-i64-val x)))
  :hints (("Goal" :in-theory (enable . #.*i64-alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i64.shr_u(x, 0) = x  (identity shift)
(defthm i64-shr-u-zero-identity
  (implies (u64p x)
           (equal (i64-result 3 (mk-i64-binop x 0 :i64.shr_u))
                  (make-i64-val x)))
  :hints (("Goal" :in-theory (enable . #.*i64-alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; Lemma: ash(x, -64) = 0 for any 64-bit value
(defthm ash-neg64-of-u64
  (implies (unsigned-byte-p 64 x)
           (equal (ash x -64) 0)))

;; i64.rotl(x, 0) = x  (identity rotation)
(defthm i64-rotl-zero-identity
  (implies (u64p x)
           (equal (i64-result 3 (mk-i64-binop x 0 :i64.rotl))
                  (make-i64-val x)))
  :hints (("Goal" :in-theory (enable u64p . #.*i64-alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §5. COMPARISON PROPERTIES

;; i64.eq(x, x) = 1  (reflexive)
(defthm i64-eq-reflexive
  (implies (u64p x)
           (equal (i64-result 3 (mk-i64-binop x x :i64.eq))
                  (make-i32-val 1)))
  :hints (("Goal" :in-theory (enable . #.*i64-alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i64.ne(x, x) = 0  (anti-reflexive)
(defthm i64-ne-anti-reflexive
  (implies (u64p x)
           (equal (i64-result 3 (mk-i64-binop x x :i64.ne))
                  (make-i32-val 0)))
  :hints (("Goal" :in-theory (enable . #.*i64-alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i64.le_u(x, x) = 1  (reflexive)
(defthm i64-le-u-reflexive
  (implies (u64p x)
           (equal (i64-result 3 (mk-i64-binop x x :i64.le_u))
                  (make-i32-val 1)))
  :hints (("Goal" :in-theory (enable . #.*i64-alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i64.ge_u(x, x) = 1  (reflexive)
(defthm i64-ge-u-reflexive
  (implies (u64p x)
           (equal (i64-result 3 (mk-i64-binop x x :i64.ge_u))
                  (make-i32-val 1)))
  :hints (("Goal" :in-theory (enable . #.*i64-alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i64.lt_u(x, x) = 0  (irreflexive)
(defthm i64-lt-u-irreflexive
  (implies (u64p x)
           (equal (i64-result 3 (mk-i64-binop x x :i64.lt_u))
                  (make-i32-val 0)))
  :hints (("Goal" :in-theory (enable . #.*i64-alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i64.gt_u(x, x) = 0  (irreflexive)
(defthm i64-gt-u-irreflexive
  (implies (u64p x)
           (equal (i64-result 3 (mk-i64-binop x x :i64.gt_u))
                  (make-i32-val 0)))
  :hints (("Goal" :in-theory (enable . #.*i64-alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §6. UNARY PROPERTIES

;; i64.eqz(0) = 1  (zero test positive)
(defthm i64-eqz-zero-is-true
  (equal (i64-result 2 (mk-i64-unop 0 :i64.eqz))
         (make-i32-val 1))
  :hints (("Goal" :in-theory (enable . #.*i64-alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i64.eqz(1) = 0  (non-zero test negative)
(defthm i64-eqz-one-is-false
  (equal (i64-result 2 (mk-i64-unop 1 :i64.eqz))
         (make-i32-val 0))
  :hints (("Goal" :in-theory (enable . #.*i64-alg-theory*)
                  :expand ((:free (n s) (run n s))))))
