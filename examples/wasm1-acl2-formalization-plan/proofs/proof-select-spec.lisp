;; WASM 1.0 ACL2 — select instruction specification proofs (2 Q.E.D.s)
;;
;; 1. select-nonzero-returns-first: non-zero condition selects first value
;; 2. select-zero-returns-second: zero condition selects second value
;;
;; The select instruction is WASM's ternary operator:
;; (i32.const a) (i32.const b) (i32.const c) select → a if c≠0, else b

(in-package "ACL2")
(ld "/tmp/acl2-full/books/kestrel/wasm/package.lsp")
(in-package "WASM")
(include-book "kestrel/wasm/execution" :dir :system)

(defconst *wasm-exec-theory*
  '(run execute-instr execute-i32.const execute-select
    current-frame current-instrs current-operand-stack
    current-label-stack current-locals
    update-current-operand-stack update-current-instrs
    complete-label return-from-function
    make-i32-val i32-valp i32-const-argsp no-argsp instrp
    push-operand top-operand pop-operand top-n-operands
    operand-stack-height empty-operand-stack operand-stackp
    localsp framep top-frame push-call-stack pop-call-stack
    call-stackp valp i64-valp u32p u64p))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 1: select with non-zero condition returns first value (val1)

(defthm select-nonzero-returns-first
  (implies
   (and (unsigned-byte-p 32 a)
        (unsigned-byte-p 32 b)
        (unsigned-byte-p 32 c)
        (not (= c 0)))
   (equal
    (top-operand
     (current-operand-stack
      (run 4
           (make-state
            :store nil
            :call-stack (list (make-frame
                              :return-arity 1
                              :locals nil
                              :operand-stack (empty-operand-stack)
                              :instrs (list (list :i32.const a)
                                            (list :i32.const b)
                                            (list :i32.const c)
                                            '(:select))
                              :label-stack nil))
            :memory nil
            :globals nil))))
    (make-i32-val a)))
  :hints (("Goal" :in-theory (enable . #.*wasm-exec-theory*)
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 2: select with zero condition returns second value (val2)

(defthm select-zero-returns-second
  (implies
   (and (unsigned-byte-p 32 a)
        (unsigned-byte-p 32 b))
   (equal
    (top-operand
     (current-operand-stack
      (run 4
           (make-state
            :store nil
            :call-stack (list (make-frame
                              :return-arity 1
                              :locals nil
                              :operand-stack (empty-operand-stack)
                              :instrs (list (list :i32.const a)
                                            (list :i32.const b)
                                            (list :i32.const 0)
                                            '(:select))
                              :label-stack nil))
            :memory nil
            :globals nil))))
    (make-i32-val b)))
  :hints (("Goal" :in-theory (enable . #.*wasm-exec-theory*)
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))))))

(cw "~%All select proofs passed!~%")
(cw "  - select-nonzero-returns-first: c!=0 -> val1 (Q.E.D.)~%")
(cw "  - select-zero-returns-second: c==0 -> val2 (Q.E.D.)~%")
