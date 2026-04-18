;; WASM 1.0 ACL2 — M8.12: Global variable specification proofs
;;
;; Theorems:
;; 1. global.set → global.get roundtrip on mutable globals
;; 2. global.set on immutable (const) global traps

(in-package "ACL2")
(ld "/tmp/acl2-full/books/kestrel/wasm/package.lsp")
(in-package "WASM")
(include-book "kestrel/wasm/execution" :dir :system)

(defconst *global-theory*
  '(run execute-instr execute-i32.const
    current-frame current-instrs current-operand-stack
    current-label-stack current-locals
    update-current-operand-stack update-current-instrs
    complete-label return-from-function
    make-i32-val i32-valp i32-const-argsp
    local-idx-argsp no-argsp
    push-operand top-operand pop-operand
    operand-stack-height empty-operand-stack operand-stackp
    localsp framep top-frame push-call-stack pop-call-stack call-stackp
    valp i64-valp u32p u64p))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 1: Mutable global set/get roundtrip
;; For all u32 v: (i32.const v) (global.set 0) (global.get 0) → v

(defthm global-set-get-roundtrip
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
                              :locals nil
                              :operand-stack (empty-operand-stack)
                              :instrs (list (list :i32.const v)
                                            '(:global.set 0)
                                            '(:global.get 0))
                              :label-stack nil))
            :memory nil
            :globals (list (make-globalinst :mutability :var
                                           :value (make-i32-val 0)))))))
    (make-i32-val v)))
  :hints (("Goal" :in-theory (enable . #.*global-theory*)
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 2: Immutable global mutation traps
;; Setting a :const global produces :trap

(defthm global-set-const-traps
  (equal
   (run 2
        (make-state
         :store nil
         :call-stack (list (make-frame
                           :return-arity 1
                           :locals nil
                           :operand-stack (list (make-i32-val 42))
                           :instrs (list '(:global.set 0))
                           :label-stack nil))
         :memory nil
         :globals (list (make-globalinst :mutability :const
                                        :value (make-i32-val 0)))))
   :trap)
  :hints (("Goal" :in-theory (enable . #.*global-theory*)
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))))))

(cw "~% - global-set-get-roundtrip: mutable global round-trip (Q.E.D.)~%")
(cw " - global-set-const-traps: immutable global mutation traps (Q.E.D.)~%")
