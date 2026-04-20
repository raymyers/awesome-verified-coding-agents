;; WASM 1.0 ACL2 — Associativity Theorems
;;
;; Symbolic proofs that associative WASM operations yield the same result
;; regardless of how sub-expressions are parenthesized.
;;
;; Two distinct instruction sequences (differing in stack interleaving) are
;; proved to produce identical outputs for all valid inputs:
;;
;;   Left-assoc  sequence: push a  push b  op  push c  op  → (a⊕b)⊕c
;;   Right-assoc sequence: push a  push b  push c  op  op  → a⊕(b⊕c)
;;
;; The theorem (a⊕b)⊕c = a⊕(b⊕c) then lifts from the BV library
;; (bvplus-associative, bvand-associative, etc.) to the full WASM
;; execution model, for both i32 and i64.

(in-package "ACL2")
(ld "/tmp/acl2-full/books/kestrel/wasm/package.lsp")
(in-package "WASM")
(include-book "kestrel/wasm/execution" :dir :system)

(set-guard-checking :none)

;; ─── State constructors ───────────────────────────────────────────────────────

;; Left-associative:  (a op b) op c
;;   Instruction stream: [i32.const a] [i32.const b] [op] [i32.const c] [op]
(defund mk-left-assoc32 (a b c op)
  (declare (xargs :guard t :verify-guards nil))
  (make-state
   :store nil
   :call-stack (list (make-frame
                      :return-arity 1
                      :locals nil
                      :operand-stack (empty-operand-stack)
                      :instrs (list (list :i32.const a)
                                    (list :i32.const b)
                                    (list op)
                                    (list :i32.const c)
                                    (list op))
                      :label-stack nil))
   :memory nil
   :globals nil))

;; Right-associative:  a op (b op c)
;;   Instruction stream: [i32.const a] [i32.const b] [i32.const c] [op] [op]
(defund mk-right-assoc32 (a b c op)
  (declare (xargs :guard t :verify-guards nil))
  (make-state
   :store nil
   :call-stack (list (make-frame
                      :return-arity 1
                      :locals nil
                      :operand-stack (empty-operand-stack)
                      :instrs (list (list :i32.const a)
                                    (list :i32.const b)
                                    (list :i32.const c)
                                    (list op)
                                    (list op))
                      :label-stack nil))
   :memory nil
   :globals nil))

(defund mk-left-assoc64 (a b c op)
  (declare (xargs :guard t :verify-guards nil))
  (make-state
   :store nil
   :call-stack (list (make-frame
                      :return-arity 1
                      :locals nil
                      :operand-stack (empty-operand-stack)
                      :instrs (list (list :i64.const a)
                                    (list :i64.const b)
                                    (list op)
                                    (list :i64.const c)
                                    (list op))
                      :label-stack nil))
   :memory nil
   :globals nil))

(defund mk-right-assoc64 (a b c op)
  (declare (xargs :guard t :verify-guards nil))
  (make-state
   :store nil
   :call-stack (list (make-frame
                      :return-arity 1
                      :locals nil
                      :operand-stack (empty-operand-stack)
                      :instrs (list (list :i64.const a)
                                    (list :i64.const b)
                                    (list :i64.const c)
                                    (list op)
                                    (list op))
                      :label-stack nil))
   :memory nil
   :globals nil))

(defund as-result32 (n s)
  (declare (xargs :guard t :verify-guards nil))
  (top-operand (current-operand-stack (run n s))))

(defund as-result64 (n s)
  (declare (xargs :guard t :verify-guards nil))
  (top-operand (current-operand-stack (run n s))))

;; ─── Theory constants ─────────────────────────────────────────────────────────

(defconst *as32-theory*
  '(mk-left-assoc32 mk-right-assoc32 as-result32
    run step execute-instr
    execute-i32.const execute-i32.add execute-i32.mul
    execute-i32.and execute-i32.or execute-i32.xor
    current-frame current-instrs current-operand-stack
    current-label-stack current-locals
    update-current-operand-stack update-current-instrs
    complete-label return-from-function
    make-i32-val i32-valp i32-const-argsp no-argsp
    i64-valp f32-valp f64-valp
    push-operand top-operand pop-operand top-n-operands push-vals
    operand-stack-height empty-operand-stack operand-stackp
    localsp framep top-frame push-call-stack pop-call-stack call-stackp
    valp u32p u64p))

(defconst *as64-theory*
  '(mk-left-assoc64 mk-right-assoc64 as-result64
    run step execute-instr
    execute-i64.const execute-i64.add execute-i64.mul
    execute-i64.and execute-i64.or execute-i64.xor
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
;; §1. i32 ASSOCIATIVITY

;; i32.add: (a+b)+c = a+(b+c)
(defthm i32-add-associative
  (implies (and (u32p a) (u32p b) (u32p c))
           (equal (as-result32 5 (mk-left-assoc32 a b c :i32.add))
                  (as-result32 5 (mk-right-assoc32 a b c :i32.add))))
  :hints (("Goal" :in-theory (enable . #.*as32-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i32.mul: (a*b)*c = a*(b*c)
(defthm i32-mul-associative
  (implies (and (u32p a) (u32p b) (u32p c))
           (equal (as-result32 5 (mk-left-assoc32 a b c :i32.mul))
                  (as-result32 5 (mk-right-assoc32 a b c :i32.mul))))
  :hints (("Goal" :in-theory (enable . #.*as32-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i32.and: (a&b)&c = a&(b&c)
(defthm i32-and-associative
  (implies (and (u32p a) (u32p b) (u32p c))
           (equal (as-result32 5 (mk-left-assoc32 a b c :i32.and))
                  (as-result32 5 (mk-right-assoc32 a b c :i32.and))))
  :hints (("Goal" :in-theory (enable . #.*as32-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i32.or: (a|b)|c = a|(b|c)
(defthm i32-or-associative
  (implies (and (u32p a) (u32p b) (u32p c))
           (equal (as-result32 5 (mk-left-assoc32 a b c :i32.or))
                  (as-result32 5 (mk-right-assoc32 a b c :i32.or))))
  :hints (("Goal" :in-theory (enable . #.*as32-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i32.xor: (a^b)^c = a^(b^c)
(defthm i32-xor-associative
  (implies (and (u32p a) (u32p b) (u32p c))
           (equal (as-result32 5 (mk-left-assoc32 a b c :i32.xor))
                  (as-result32 5 (mk-right-assoc32 a b c :i32.xor))))
  :hints (("Goal" :in-theory (enable . #.*as32-theory*)
                  :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §2. i64 ASSOCIATIVITY

;; i64.add: (a+b)+c = a+(b+c)
(defthm i64-add-associative
  (implies (and (u64p a) (u64p b) (u64p c))
           (equal (as-result64 5 (mk-left-assoc64 a b c :i64.add))
                  (as-result64 5 (mk-right-assoc64 a b c :i64.add))))
  :hints (("Goal" :in-theory (enable . #.*as64-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i64.mul: (a*b)*c = a*(b*c)
(defthm i64-mul-associative
  (implies (and (u64p a) (u64p b) (u64p c))
           (equal (as-result64 5 (mk-left-assoc64 a b c :i64.mul))
                  (as-result64 5 (mk-right-assoc64 a b c :i64.mul))))
  :hints (("Goal" :in-theory (enable . #.*as64-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i64.and: (a&b)&c = a&(b&c)
(defthm i64-and-associative
  (implies (and (u64p a) (u64p b) (u64p c))
           (equal (as-result64 5 (mk-left-assoc64 a b c :i64.and))
                  (as-result64 5 (mk-right-assoc64 a b c :i64.and))))
  :hints (("Goal" :in-theory (enable . #.*as64-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i64.or: (a|b)|c = a|(b|c)
(defthm i64-or-associative
  (implies (and (u64p a) (u64p b) (u64p c))
           (equal (as-result64 5 (mk-left-assoc64 a b c :i64.or))
                  (as-result64 5 (mk-right-assoc64 a b c :i64.or))))
  :hints (("Goal" :in-theory (enable . #.*as64-theory*)
                  :expand ((:free (n s) (run n s))))))

;; i64.xor: (a^b)^c = a^(b^c)
(defthm i64-xor-associative
  (implies (and (u64p a) (u64p b) (u64p c))
           (equal (as-result64 5 (mk-left-assoc64 a b c :i64.xor))
                  (as-result64 5 (mk-right-assoc64 a b c :i64.xor))))
  :hints (("Goal" :in-theory (enable . #.*as64-theory*)
                  :expand ((:free (n s) (run n s))))))
