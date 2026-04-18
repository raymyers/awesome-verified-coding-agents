;; WASM 1.0 ACL2 — M8.10: Local variable and drop instruction proofs
;;
;; Theorems:
;; 1. local.set → local.get roundtrip: stored value is retrievable
;; 2. local.tee preserves value on stack (and stores it)
;; 3. drop removes top of stack, exposing second value

(in-package "ACL2")
(ld "/tmp/acl2-full/books/kestrel/wasm/package.lsp")
(in-package "WASM")
(include-book "kestrel/wasm/execution" :dir :system)

;; Theory for local variable proofs
;; Note: execute-local.set, execute-local.tee are defun (auto-enabled)
(defconst *local-theory*
  '(run execute-instr
    execute-local.get execute-i32.const
    current-frame current-instrs current-operand-stack
    current-label-stack current-locals
    update-current-operand-stack update-current-instrs
    update-current-locals
    complete-label return-from-function
    make-i32-val i32-valp i32-const-argsp
    local-idx-argsp no-argsp
    push-operand top-operand pop-operand top-n-operands push-vals
    operand-stack-height empty-operand-stack operand-stackp
    localsp framep top-frame push-call-stack pop-call-stack call-stackp
    valp i64-valp u32p u64p
    nth-local update-nth-local))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 1: local.set → local.get roundtrip
;; For all u32 v: (i32.const v) (local.set 0) (local.get 0) → v

(defthm local-set-get-roundtrip
  (implies
   (unsigned-byte-p 32 v)
   (equal
    (top-operand
     (current-operand-stack
      (run 3
           (make-state
            :store nil
            :call-stack (list (make-frame
                              :return-arity 1
                              :locals (list (make-i32-val 0))
                              :operand-stack (empty-operand-stack)
                              :instrs (list (list :i32.const v)
                                            '(:local.set 0)
                                            '(:local.get 0))
                              :label-stack nil))
            :memory nil
            :globals nil))))
    (make-i32-val v)))
  :hints (("Goal" :in-theory (enable . #.*local-theory*)
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 2: local.tee preserves value on stack
;; For all u32 v: (i32.const v) (local.tee 0) → v on stack

(defthm local-tee-preserves-value
  (implies
   (unsigned-byte-p 32 v)
   (equal
    (top-operand
     (current-operand-stack
      (run 2
           (make-state
            :store nil
            :call-stack (list (make-frame
                              :return-arity 1
                              :locals (list (make-i32-val 0))
                              :operand-stack (empty-operand-stack)
                              :instrs (list (list :i32.const v)
                                            '(:local.tee 0))
                              :label-stack nil))
            :memory nil
            :globals nil))))
    (make-i32-val v)))
  :hints (("Goal" :in-theory (enable . #.*local-theory*)
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 3: drop removes top of stack
;; For all u32 a, b: (i32.const a) (i32.const b) (drop) → a on top

(defthm drop-removes-top
  (implies
   (and (unsigned-byte-p 32 a) (unsigned-byte-p 32 b))
   (equal
    (top-operand
     (current-operand-stack
      (run 3
           (make-state
            :store nil
            :call-stack (list (make-frame
                              :return-arity 1
                              :locals nil
                              :operand-stack (empty-operand-stack)
                              :instrs (list (list :i32.const a)
                                            (list :i32.const b)
                                            '(:drop))
                              :label-stack nil))
            :memory nil
            :globals nil))))
    (make-i32-val a)))
  :hints (("Goal" :in-theory (enable run execute-instr execute-drop
                                     execute-i32.const
                                     current-frame current-instrs current-operand-stack
                                     current-label-stack
                                     update-current-operand-stack update-current-instrs
                                     complete-label return-from-function
                                     make-i32-val i32-valp i32-const-argsp no-argsp
                                     push-operand top-operand pop-operand
                                     operand-stack-height empty-operand-stack operand-stackp
                                     localsp framep top-frame push-call-stack pop-call-stack call-stackp
                                     valp i64-valp u32p u64p)
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))))))

(cw "~% - local-set-get-roundtrip: local.set→local.get (Q.E.D.)~%")
(cw " - local-tee-preserves-value: local.tee keeps stack val (Q.E.D.)~%")
(cw " - drop-removes-top: drop pops value (Q.E.D.)~%")
