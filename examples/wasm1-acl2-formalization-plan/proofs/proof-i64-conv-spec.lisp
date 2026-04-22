;; WASM 1.0 ACL2 — M8.15: i64 arithmetic and type conversion proofs
;;
;; Theorems:
;; 1. i64.add spec: (i64.const a) (i64.const b) (i64.add) → bvplus 64
;; 2. i64.sub spec: → bvminus 64
;; 3. i64.mul spec: → bvmult 64
;; 4. i32.wrap_i64: → bvchop 32 (truncate to low 32 bits)
;; 5. i64.extend_i32_u: → identity (zero-extend preserves value)

(in-package "WASM")
(include-book "../execution")

;; Base theory for i64 instruction proofs
(local (defconst *i64-theory*
  '(run execute-instr execute-i64.const
    current-frame current-instrs current-operand-stack
    current-label-stack current-locals
    update-current-operand-stack update-current-instrs
    complete-label return-from-function
    make-i64-val i64-valp i64-const-argsp no-argsp
    push-operand top-operand pop-operand
    operand-stack-height empty-operand-stack operand-stackp
    localsp framep top-frame push-call-stack pop-call-stack call-stackp
    valp i32-valp u32p u64p)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 1: i64.add specification

(defthm i64-add-spec
  (implies
   (and (unsigned-byte-p 64 a)
        (unsigned-byte-p 64 b))
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
                              :instrs (list (list :i64.const a)
                                            (list :i64.const b)
                                            '(:i64.add))
                              :label-stack nil))
            :memory nil
            :globals nil))))
    (make-i64-val (bvplus 64 a b))))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) (append '(execute-i64.add) *i64-theory*))
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 2: i64.sub specification

(defthm i64-sub-spec
  (implies
   (and (unsigned-byte-p 64 a)
        (unsigned-byte-p 64 b))
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
                              :instrs (list (list :i64.const a)
                                            (list :i64.const b)
                                            '(:i64.sub))
                              :label-stack nil))
            :memory nil
            :globals nil))))
    (make-i64-val (acl2::bvminus 64 a b))))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) (append '(execute-i64.sub) *i64-theory*))
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 3: i64.mul specification

(defthm i64-mul-spec
  (implies
   (and (unsigned-byte-p 64 a)
        (unsigned-byte-p 64 b))
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
                              :instrs (list (list :i64.const a)
                                            (list :i64.const b)
                                            '(:i64.mul))
                              :label-stack nil))
            :memory nil
            :globals nil))))
    (make-i64-val (acl2::bvmult 64 a b))))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) (append '(execute-i64.mul) *i64-theory*))
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 4: i32.wrap_i64 truncates to low 32 bits

(defthm i32-wrap-i64-spec
  (implies
   (unsigned-byte-p 64 x)
   (equal
    (top-operand
     (current-operand-stack
      (run 2
           (make-state
            :store nil
            :call-stack (list (make-frame
                              :return-arity 1
                              :locals nil
                              :operand-stack (empty-operand-stack)
                              :instrs (list (list :i64.const x)
                                            '(:i32.wrap_i64))
                              :label-stack nil))
            :memory nil
            :globals nil))))
    (make-i32-val (acl2::bvchop 32 x))))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) (append '(execute-i32.wrap_i64) *i64-theory*))
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 5: i64.extend_i32_u preserves value (zero-extension)
;; For unsigned i32 values, zero-extension to i64 doesn't change the value.

(defthm i64-extend-i32-u-spec
  (implies
   (unsigned-byte-p 32 x)
   (equal
    (top-operand
     (current-operand-stack
      (run 2
           (make-state
            :store nil
            :call-stack (list (make-frame
                              :return-arity 1
                              :locals nil
                              :operand-stack (empty-operand-stack)
                              :instrs (list (list :i32.const x)
                                            '(:i64.extend_i32_u))
                              :label-stack nil))
            :memory nil
            :globals nil))))
    (make-i64-val x)))
  :hints (("Goal" :in-theory (union-theories (current-theory :here) (append '(execute-i64.extend_i32_u execute-i32.const
                                     make-i32-val i32-valp i32-const-argsp) *i64-theory*))
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))))))

(value-triple (cw "~% - i64-add-spec (Q.E.D.)~%"))
(value-triple (cw " - i64-sub-spec (Q.E.D.)~%"))
(value-triple (cw " - i64-mul-spec (Q.E.D.)~%"))
(value-triple (cw " - i32-wrap-i64-spec: truncation (Q.E.D.)~%"))
(value-triple (cw " - i64-extend-i32-u-spec: zero-extension (Q.E.D.)~%"))
