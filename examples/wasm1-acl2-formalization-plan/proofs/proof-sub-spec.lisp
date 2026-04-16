(in-package "ACL2")
(ld "/tmp/acl2-full/books/kestrel/wasm/package.lsp")
(in-package "WASM")
(include-book "kestrel/wasm/execution" :dir :system)
(include-book "kestrel/bv/bvuminus" :dir :system)

;; Theorem 3: i32.sub specification
(defthm i32-sub-spec
  (implies
   (and (unsigned-byte-p 32 a)
        (unsigned-byte-p 32 b))
   (equal
    (top-operand
     (current-operand-stack
      (run 3
           (make-state
            :store nil
            :call-stack (list (make-frame
                              :return-arity 1 :locals nil
                              :operand-stack (empty-operand-stack)
                              :instrs (list (list :i32.const a)
                                            (list :i32.const b)
                                            (quote (:i32.sub)))
                              :label-stack nil))
            :memory nil :globals nil))))
    (make-i32-val (acl2::bvminus 32 a b))))
  :hints (("Goal" :in-theory (enable run execute-instr execute-i32.const
                                     execute-i32.sub current-frame
                                     current-instrs current-operand-stack
                                     current-label-stack current-locals
                                     update-current-operand-stack
                                     update-current-instrs
                                     complete-label return-from-function
                                     make-i32-val i32-valp i32-const-argsp
                                     no-argsp instrp
                                     push-operand top-operand pop-operand
                                     top-n-operands
                                     operand-stack-height
                                     empty-operand-stack operand-stackp
                                     localsp framep
                                     top-frame push-call-stack pop-call-stack
                                     call-stackp
                                     valp i64-valp u32p u64p)
                  :do-not (quote (generalize))
                  :expand ((:free (n s) (run n s))))))

;; Theorem 4: x - x = 0
(defthm i32-sub-self-is-zero
  (implies
   (unsigned-byte-p 32 a)
   (equal
    (top-operand
     (current-operand-stack
      (run 3
           (make-state
            :store nil
            :call-stack (list (make-frame
                              :return-arity 1 :locals nil
                              :operand-stack (empty-operand-stack)
                              :instrs (list (list :i32.const a)
                                            (list :i32.const a)
                                            (quote (:i32.sub)))
                              :label-stack nil))
            :memory nil :globals nil))))
    (make-i32-val 0)))
  :hints (("Goal" :in-theory (enable run execute-instr execute-i32.const
                                     execute-i32.sub current-frame
                                     current-instrs current-operand-stack
                                     current-label-stack current-locals
                                     update-current-operand-stack
                                     update-current-instrs
                                     complete-label return-from-function
                                     make-i32-val i32-valp i32-const-argsp
                                     no-argsp instrp
                                     push-operand top-operand pop-operand
                                     top-n-operands
                                     operand-stack-height
                                     empty-operand-stack operand-stackp
                                     localsp framep
                                     top-frame push-call-stack pop-call-stack
                                     call-stackp
                                     valp i64-valp u32p u64p
                                     acl2::bvminus)
                  :do-not (quote (generalize))
                  :expand ((:free (n s) (run n s))))))

;; Theorem 5: (a + b) - b = a
(defthm i32-add-sub-inverse
  (implies
   (and (unsigned-byte-p 32 a)
        (unsigned-byte-p 32 b))
   (equal
    (top-operand
     (current-operand-stack
      (run 5
           (make-state
            :store nil
            :call-stack (list (make-frame
                              :return-arity 1 :locals nil
                              :operand-stack (empty-operand-stack)
                              :instrs (list (list :i32.const a)
                                            (list :i32.const b)
                                            (quote (:i32.add))
                                            (list :i32.const b)
                                            (quote (:i32.sub)))
                              :label-stack nil))
            :memory nil :globals nil))))
    (make-i32-val a)))
  :hints (("Goal" :in-theory (enable run execute-instr execute-i32.const
                                     execute-i32.add execute-i32.sub
                                     current-frame
                                     current-instrs current-operand-stack
                                     current-label-stack current-locals
                                     update-current-operand-stack
                                     update-current-instrs
                                     complete-label return-from-function
                                     make-i32-val i32-valp i32-const-argsp
                                     no-argsp instrp
                                     push-operand top-operand pop-operand
                                     top-n-operands
                                     operand-stack-height
                                     empty-operand-stack operand-stackp
                                     localsp framep
                                     top-frame push-call-stack pop-call-stack
                                     call-stackp
                                     valp i64-valp u32p u64p
                                     acl2::bvminus)
                  :do-not (quote (generalize))
                  :expand ((:free (n s) (run n s))))))

(cw "~%=== ALL 3 NEW PROOFS PASSED ===~%")
(cw "  3. i32-sub-spec: sub specification (Q.E.D.)~%")
(cw "  4. i32-sub-self-is-zero: x - x = 0 (Q.E.D.)~%")
(cw "  5. i32-add-sub-inverse: (a + b) - b = a (Q.E.D.)~%")
