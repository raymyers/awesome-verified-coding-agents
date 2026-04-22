;; WASM 1.0 ACL2 — Algebraic Instruction Properties
;;
;; Symbolic (universal) theorems about WASM instruction semantics.
;; These prove that the ACL2 formalization correctly captures the
;; algebraic structure of WASM's integer operations.
;;
;; All theorems are of the form: ∀ x,y ∈ u32. property(x,y)
;; These are proved by ACL2's rewriter + BV library rules.

(in-package "WASM")
(include-book "../execution")


;; State constructor for binary ops: (i32.const a) (i32.const b) (op)
(defund mk-binop (a b op)
  (declare (xargs :guard t :verify-guards nil))
  (make-state
   :store nil
   :call-stack (list (make-frame
                      :return-arity 1
                      :locals nil
                      :operand-stack (empty-operand-stack)
                      :instrs (list (list :i32.const a)
                                    (list :i32.const b)
                                    (list op))
                      :label-stack nil))
   :memory nil
   :globals nil))

;; State constructor for unary ops: (i32.const a) (op)
(defund mk-unop (a op)
  (declare (xargs :guard t :verify-guards nil))
  (make-state
   :store nil
   :call-stack (list (make-frame
                      :return-arity 1
                      :locals nil
                      :operand-stack (empty-operand-stack)
                      :instrs (list (list :i32.const a)
                                    (list op))
                      :label-stack nil))
   :memory nil
   :globals nil))

;; Result extractor for inline execution
(defund result (n state)
  (declare (xargs :guard t :verify-guards nil))
  (top-operand (current-operand-stack (run n state))))

;; Common theory
(local (defconst *alg-theory*
  '(mk-binop mk-unop result
    run step execute-instr
    execute-i32.const execute-i32.add execute-i32.sub execute-i32.mul
    execute-i32.and execute-i32.or execute-i32.xor
    execute-i32.shl execute-i32.shr_u execute-i32.shr_s
    execute-i32.rotl execute-i32.rotr
    execute-i32.eqz execute-i32.eq execute-i32.ne
    execute-i32.lt_u execute-i32.gt_u execute-i32.le_u execute-i32.ge_u
    execute-i32.lt_s execute-i32.gt_s execute-i32.le_s execute-i32.ge_s
    execute-i32.clz execute-i32.ctz execute-i32.popcnt
    i32-clz-helper i32-ctz-helper i32-popcnt-helper
    current-frame current-instrs current-operand-stack
    current-label-stack current-locals
    update-current-operand-stack update-current-instrs
    complete-label return-from-function
    make-i32-val i32-valp i32-const-argsp no-argsp
    f32-valp f64-valp i64-valp
    push-operand top-operand pop-operand top-n-operands push-vals
    operand-stack-height empty-operand-stack operand-stackp
    localsp framep top-frame push-call-stack pop-call-stack call-stackp
    valp u32p u64p)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §1. ADDITIVE PROPERTIES

;; add(x, 0) = x  (right identity)
(defthm i32-add-right-identity
  (implies (u32p x)
           (equal (result 3 (mk-binop x 0 :i32.add))
                  (make-i32-val x)))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) *alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; add(0, x) = x  (left identity)
(defthm i32-add-left-identity
  (implies (u32p x)
           (equal (result 3 (mk-binop 0 x :i32.add))
                  (make-i32-val x)))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) *alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; sub(x, 0) = x
(defthm i32-sub-right-identity
  (implies (u32p x)
           (equal (result 3 (mk-binop x 0 :i32.sub))
                  (make-i32-val x)))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) *alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; sub(x, x) = 0
(defthm i32-sub-self-is-zero
  (implies (u32p x)
           (equal (result 3 (mk-binop x x :i32.sub))
                  (make-i32-val 0)))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) (append '(acl2::bvminus acl2::bvplus
                                      acl2::bvuminus acl2::bvchop) *alg-theory*))
                  :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §2. MULTIPLICATIVE PROPERTIES

;; mul(x, 1) = x  (right identity)
(defthm i32-mul-right-identity
  (implies (u32p x)
           (equal (result 3 (mk-binop x 1 :i32.mul))
                  (make-i32-val x)))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) *alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; mul(1, x) = x  (left identity)
(defthm i32-mul-left-identity
  (implies (u32p x)
           (equal (result 3 (mk-binop 1 x :i32.mul))
                  (make-i32-val x)))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) *alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; mul(x, 0) = 0  (zero annihilator)
(defthm i32-mul-zero-annihilates
  (implies (u32p x)
           (equal (result 3 (mk-binop x 0 :i32.mul))
                  (make-i32-val 0)))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) *alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §3. BITWISE PROPERTIES

;; and(x, 0) = 0  (zero annihilator)
(defthm i32-and-zero-annihilates
  (implies (u32p x)
           (equal (result 3 (mk-binop x 0 :i32.and))
                  (make-i32-val 0)))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) *alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; and(x, MAX) = x  (identity with all-ones)
(defthm i32-and-all-ones-identity
  (implies (u32p x)
           (equal (result 3 (mk-binop x (1- (expt 2 32)) :i32.and))
                  (make-i32-val x)))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) *alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; or(x, 0) = x  (identity)
;; (already in proof-bitwise.lisp, but this version uses mk-binop)
(defthm i32-or-identity
  (implies (u32p x)
           (equal (result 3 (mk-binop x 0 :i32.or))
                  (make-i32-val x)))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) *alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; or(x, MAX) = MAX  (all-ones absorber)
(defthm i32-or-all-ones-absorbs
  (implies (u32p x)
           (equal (result 3 (mk-binop x (1- (expt 2 32)) :i32.or))
                  (make-i32-val (1- (expt 2 32)))))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) *alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; xor(x, 0) = x  (identity)
(defthm i32-xor-identity
  (implies (u32p x)
           (equal (result 3 (mk-binop x 0 :i32.xor))
                  (make-i32-val x)))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) *alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; xor(x, x) = 0  (self-inverse)
(defthm i32-xor-self-annihilates
  (implies (u32p x)
           (equal (result 3 (mk-binop x x :i32.xor))
                  (make-i32-val 0)))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) *alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §4. SHIFT PROPERTIES

;; shl(x, 0) = x  (identity)
(defthm i32-shl-zero-identity
  (implies (u32p x)
           (equal (result 3 (mk-binop x 0 :i32.shl))
                  (make-i32-val x)))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) *alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; shr_u(x, 0) = x  (identity)
(defthm i32-shr-u-zero-identity
  (implies (u32p x)
           (equal (result 3 (mk-binop x 0 :i32.shr_u))
                  (make-i32-val x)))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) *alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; Lemma: ash(x, -32) = 0 when x fits in 32 bits
;; Needs arithmetic library for floor reasoning
(local (include-book "arithmetic-5/top" :dir :system))
(defthm ash-neg32-of-u32
  (implies (unsigned-byte-p 32 x)
           (equal (ash x -32) 0)))

;; rotl(x, 0) = x  (identity)
(defthm i32-rotl-zero-identity
  (implies (u32p x)
           (equal (result 3 (mk-binop x 0 :i32.rotl))
                  (make-i32-val x)))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) *alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; rotr(x, 0) = x — proved concretely in proof-spec-edge-cases.lisp;
;; symbolic version requires logior-with-disjoint-ranges lemma (future work).

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §5. COMPARISON PROPERTIES

;; eq(x, x) = 1  (reflexive)
(defthm i32-eq-reflexive
  (implies (u32p x)
           (equal (result 3 (mk-binop x x :i32.eq))
                  (make-i32-val 1)))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) *alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; ne(x, x) = 0  (complement of reflexive)
(defthm i32-ne-anti-reflexive
  (implies (u32p x)
           (equal (result 3 (mk-binop x x :i32.ne))
                  (make-i32-val 0)))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) *alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; le_u(x, x) = 1  (reflexive)
(defthm i32-le-u-reflexive
  (implies (u32p x)
           (equal (result 3 (mk-binop x x :i32.le_u))
                  (make-i32-val 1)))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) *alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; ge_u(x, x) = 1  (reflexive)
(defthm i32-ge-u-reflexive
  (implies (u32p x)
           (equal (result 3 (mk-binop x x :i32.ge_u))
                  (make-i32-val 1)))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) *alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; lt_u(x, x) = 0  (irreflexive)
(defthm i32-lt-u-irreflexive
  (implies (u32p x)
           (equal (result 3 (mk-binop x x :i32.lt_u))
                  (make-i32-val 0)))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) *alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; gt_u(x, x) = 0  (irreflexive)
(defthm i32-gt-u-irreflexive
  (implies (u32p x)
           (equal (result 3 (mk-binop x x :i32.gt_u))
                  (make-i32-val 0)))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) *alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; le_s(x, x) = 1  (reflexive, signed)
(defthm i32-le-s-reflexive
  (implies (u32p x)
           (equal (result 3 (mk-binop x x :i32.le_s))
                  (make-i32-val 1)))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) *alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; ge_s(x, x) = 1  (reflexive, signed)
(defthm i32-ge-s-reflexive
  (implies (u32p x)
           (equal (result 3 (mk-binop x x :i32.ge_s))
                  (make-i32-val 1)))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) *alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §6. UNARY PROPERTIES

;; eqz(0) = 1
(defthm i32-eqz-zero-is-true
  (equal (result 2 (mk-unop 0 :i32.eqz))
         (make-i32-val 1))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) *alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; eqz(1) = 0
(defthm i32-eqz-one-is-false
  (equal (result 2 (mk-unop 1 :i32.eqz))
         (make-i32-val 0))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) *alg-theory*)
                  :expand ((:free (n s) (run n s))))))

;; All done.
