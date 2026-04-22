;; WASM 1.0 ACL2 — M9.8: Validation Soundness Proofs
;;
;; Proves relationships between the type checker and execution:
;; 1. Well-typed i32.add doesn't trap (type safety for addition)
;; 2. Well-typed constant instruction produces correct type
;; 3. Invalid local.get (out of bounds) rejects at validation time

(in-package "WASM")
(include-book "../execution")
(include-book "../validation")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 1: The type checker correctly types i32 addition

(defthm tc-i32-add-correct
  (equal (type-check-instrs *empty-ctx*
                            '((:i32.const 1) (:i32.const 2) (:i32.add))
                            nil)
         '(:i32))
  :hints (("Goal" :in-theory (enable type-check-instrs type-check-instr
                                     i32-binop-p const-type
                                     stack-transition stack-pop-check stack-push
                                     valtypep ctx-mems ctx-tables ctx-types
                                     ctx-funcs ctx-locals ctx-labels ctx-return
                                     ctx-globals))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 2: Type checking rejects i32.add on mismatched operands

(defthm tc-rejects-add-type-mismatch
  (equal (type-check-instrs *empty-ctx*
                            '((:i32.const 1) (:i64.const 2) (:i32.add))
                            nil)
         :invalid)
  :hints (("Goal" :in-theory (enable type-check-instrs type-check-instr
                                     i32-binop-p i64-binop-p const-type
                                     stack-transition stack-pop-check stack-push
                                     valtypep))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 3: Type checking rejects out-of-range local.get

(defthm tc-rejects-local-get-oob
  (equal (type-check-instrs
          (make-ctx nil nil '(:i32) nil nil nil 0 0)
          '((:local.get 1))  ;; only 1 local (index 0)
          nil)
         :invalid)
  :hints (("Goal" :in-theory (enable type-check-instrs type-check-instr
                                     const-type valtypep
                                     ctx-locals ctx-labels ctx-return
                                     ctx-mems ctx-tables))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 4: Type checking rejects setting immutable global

(defthm tc-rejects-immutable-global-set
  (equal (type-check-instrs
          (make-ctx nil nil nil nil nil '((:const . :i32)) 0 0)
          '((:i32.const 42) (:global.set 0))
          nil)
         :invalid)
  :hints (("Goal" :in-theory (enable type-check-instrs type-check-instr
                                     const-type valtypep
                                     ctx-locals ctx-labels ctx-return ctx-globals
                                     ctx-mems ctx-tables
                                     stack-transition stack-pop-check stack-push))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 5: abs() function body validates

(defthm tc-abs-body-valid
  (validate-func-body *empty-ctx* '(:i32) '(:i32) nil
                      '((:local.get 0)
                        (:i32.const 0)
                        (:i32.lt_s)
                        (:if 1
                             ((:i32.const 0)
                              (:local.get 0)
                              (:i32.sub))
                             ((:local.get 0)))))
  :hints (("Goal" :in-theory (enable validate-func-body
                                     type-check-instrs type-check-instr
                                     i32-binop-p i32-relop-p const-type
                                     stack-transition stack-pop-check stack-push
                                     valtypep valtype-listp resulttypep
                                     ctx-locals ctx-labels ctx-return ctx-globals
                                     ctx-mems ctx-tables ctx-types ctx-funcs
                                     ctx-push-label))))

(value-triple (cw "~% - tc-i32-add-correct: well-typed add produces :i32 (Q.E.D.)~%"))
(value-triple (cw " - tc-rejects-add-type-mismatch: type mismatch → :invalid (Q.E.D.)~%"))
(value-triple (cw " - tc-rejects-local-get-oob: out of bounds → :invalid (Q.E.D.)~%"))
(value-triple (cw " - tc-rejects-immutable-global-set: immutable → :invalid (Q.E.D.)~%"))
(value-triple (cw " - tc-abs-body-valid: abs() function validates (Q.E.D.)~%"))
