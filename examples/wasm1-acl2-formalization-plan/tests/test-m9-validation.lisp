;; WASM 1.0 ACL2 — M9: Validation / Type Checking Tests
;;
;; Tests for the type checker defined in validation.lisp.
;; Verifies that valid programs pass and invalid programs are rejected.

(in-package "ACL2")
(ld "/tmp/acl2-full/books/kestrel/wasm/package.lsp")
(in-package "WASM")
(ld "/workspace/project/awesome-verified-coding-agents/examples/wasm1-acl2-formalization-plan/validation.lisp")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Helper: check that a sequence type-checks to expected stack result
(defmacro check-valid (label ctx instrs expected-stack)
  `(assert-event
    (equal (type-check-instrs ,ctx ,instrs nil) ,expected-stack)
    :msg ,(concatenate 'string "FAIL: " label)))

(defmacro check-invalid (label ctx instrs)
  `(assert-event
    (equal (type-check-instrs ,ctx ,instrs nil) :invalid)
    :msg ,(concatenate 'string "FAIL: " label)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 9.1 Numeric instruction typing

;; Constants
(check-valid "i32.const" *empty-ctx* '((:i32.const 42)) '(:i32))
(check-valid "i64.const" *empty-ctx* '((:i64.const 100)) '(:i64))
(check-valid "f32.const" *empty-ctx* (list (list :f32.const 1)) '(:f32))
(check-valid "f64.const" *empty-ctx* (list (list :f64.const 314)) '(:f64))

;; Two constants push two types
(check-valid "two-consts" *empty-ctx* '((:i32.const 1) (:i32.const 2)) '(:i32 :i32))

;; Binary ops
(check-valid "i32.add" *empty-ctx*
             '((:i32.const 1) (:i32.const 2) (:i32.add)) '(:i32))
(check-valid "i64.mul" *empty-ctx*
             '((:i64.const 3) (:i64.const 4) (:i64.mul)) '(:i64))
(check-valid "f64.add" *empty-ctx*
             '((:f64.const 1) (:f64.const 2) (:f64.add)) '(:f64))

;; Binary op type mismatch
(check-invalid "i32.add-type-mismatch" *empty-ctx*
               '((:i32.const 1) (:i64.const 2) (:i32.add)))
(check-invalid "i32.add-underflow" *empty-ctx*
               '((:i32.const 1) (:i32.add)))

;; Unary ops
(check-valid "i32.clz" *empty-ctx*
             '((:i32.const 0) (:i32.clz)) '(:i32))
(check-valid "f64.neg" *empty-ctx*
             '((:f64.const 1) (:f64.neg)) '(:f64))

;; Test ops: t → i32
(check-valid "i32.eqz" *empty-ctx*
             '((:i32.const 0) (:i32.eqz)) '(:i32))
(check-valid "i64.eqz" *empty-ctx*
             '((:i64.const 0) (:i64.eqz)) '(:i32))

;; Relational ops: t t → i32
(check-valid "i32.lt_u" *empty-ctx*
             '((:i32.const 1) (:i32.const 2) (:i32.lt_u)) '(:i32))
(check-valid "f64.eq" *empty-ctx*
             '((:f64.const 1) (:f64.const 1) (:f64.eq)) '(:i32))

;; Conversion ops
(check-valid "i32.wrap_i64" *empty-ctx*
             '((:i64.const 0) (:i32.wrap_i64)) '(:i32))
(check-valid "i64.extend_i32_u" *empty-ctx*
             '((:i32.const 5) (:i64.extend_i32_u)) '(:i64))
(check-valid "f64.convert_i32_s" *empty-ctx*
             '((:i32.const -1) (:f64.convert_i32_s)) '(:f64))
(check-invalid "i32.wrap_wrong-type" *empty-ctx*
               '((:i32.const 0) (:i32.wrap_i64)))

(cw "~%9.1 Numeric instruction typing: all pass~%")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 9.2 Variable instruction typing

(defconst *var-ctx*
  (make-ctx nil nil '(:i32 :i64) nil nil '((:var . :i32) (:const . :f64)) 0 0))

;; local.get
(check-valid "local.get-0" *var-ctx* '((:local.get 0)) '(:i32))
(check-valid "local.get-1" *var-ctx* '((:local.get 1)) '(:i64))
(check-invalid "local.get-oob" *var-ctx* '((:local.get 2)))

;; local.set
(check-valid "local.set-0" *var-ctx* '((:i32.const 5) (:local.set 0)) nil)
(check-invalid "local.set-wrong-type" *var-ctx* '((:i64.const 5) (:local.set 0)))

;; local.tee
(check-valid "local.tee-0" *var-ctx* '((:i32.const 5) (:local.tee 0)) '(:i32))
(check-invalid "local.tee-wrong-type" *var-ctx* '((:i64.const 5) (:local.tee 0)))

;; global.get
(check-valid "global.get-0" *var-ctx* '((:global.get 0)) '(:i32))
(check-valid "global.get-1" *var-ctx* '((:global.get 1)) '(:f64))
(check-invalid "global.get-oob" *var-ctx* '((:global.get 2)))

;; global.set (mutable)
(check-valid "global.set-mut" *var-ctx* '((:i32.const 42) (:global.set 0)) nil)
;; global.set (immutable) should fail
(check-invalid "global.set-const" *var-ctx* '((:f64.const 1) (:global.set 1)))

(cw "9.2 Variable instruction typing: all pass~%")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 9.3 Parametric instruction typing

;; drop
(check-valid "drop" *empty-ctx* '((:i32.const 1) (:drop)) nil)
(check-invalid "drop-empty" *empty-ctx* '((:drop)))

;; select: t t i32 → t
(check-valid "select" *empty-ctx*
             '((:i32.const 1) (:i32.const 2) (:i32.const 0) (:select)) '(:i32))
(check-invalid "select-type-mismatch" *empty-ctx*
               '((:i32.const 1) (:i64.const 2) (:i32.const 0) (:select)))

;; nop
(check-valid "nop" *empty-ctx* '((:nop)) nil)
(check-valid "nop-preserves" *empty-ctx* '((:i32.const 1) (:nop)) '(:i32))

(cw "9.3 Parametric instruction typing: all pass~%")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 9.4 Control flow typing

;; unreachable → polymorphic (matches anything)
(check-valid "unreachable-void" *empty-ctx* '((:unreachable)) '(:polymorphic))

;; block with result
(check-valid "block-result" *empty-ctx*
             '((:block 1 ((:i32.const 42)))) '(:i32))

;; block void
(check-valid "block-void" *empty-ctx*
             '((:block 0 ((:nop)))) nil)

;; block type mismatch (says arity 1 but body produces nothing)
(check-invalid "block-mismatch" *empty-ctx*
               '((:block 1 ((:nop)))))

;; loop
(check-valid "loop-void" *empty-ctx*
             '((:loop 0 ((:nop)))) nil)

;; if/else
(check-valid "if-else" *empty-ctx*
             '((:i32.const 1)
               (:if 1
                    ((:i32.const 10))
                    ((:i32.const 20)))) '(:i32))

;; if/else type mismatch (then returns i32, else returns nothing)
(check-invalid "if-mismatch" *empty-ctx*
               '((:i32.const 1) (:if 1 ((:i32.const 10)) ((:nop)))))

;; if needs i32 condition
(check-invalid "if-no-cond" *empty-ctx*
               '((:if 0 ((:nop)) ((:nop)))))

;; br inside block (polymorphic)
(defconst *block-ctx*
  (make-ctx nil nil nil '((:i32)) nil nil 0 0))

(check-valid "br-0" *block-ctx*
             '((:i32.const 42) (:br 0)) '(:polymorphic))

;; br label out of range
(check-invalid "br-oob" *empty-ctx* '((:i32.const 42) (:br 0)))

;; br_if
(check-valid "br_if-0" *block-ctx*
             '((:i32.const 42) (:i32.const 1) (:br_if 0)) '(:i32))

;; return
(defconst *func-ctx*
  (make-ctx nil nil '(:i32) nil '(:i32) nil 0 0))

(check-valid "return" *func-ctx*
             '((:i32.const 42) (:return)) '(:polymorphic))

(cw "9.4 Control flow typing: all pass~%")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 9.5 Memory instruction typing

(defconst *mem-ctx*
  (make-ctx nil nil nil nil nil nil 1 0))

(check-valid "i32.load" *mem-ctx* '((:i32.const 0) (:i32.load)) '(:i32))
(check-valid "i32.store" *mem-ctx* '((:i32.const 0) (:i32.const 42) (:i32.store)) nil)
(check-valid "i64.load" *mem-ctx* '((:i32.const 0) (:i64.load)) '(:i64))
(check-valid "f64.store" *mem-ctx* '((:i32.const 0) (:f64.const 1) (:f64.store)) nil)
(check-valid "memory.size" *mem-ctx* '((:memory.size)) '(:i32))
(check-valid "memory.grow" *mem-ctx* '((:i32.const 1) (:memory.grow)) '(:i32))

;; No memory → invalid
(check-invalid "load-no-mem" *empty-ctx* '((:i32.const 0) (:i32.load)))
(check-invalid "store-no-mem" *empty-ctx* '((:i32.const 0) (:i32.const 42) (:i32.store)))

;; Load type mismatch (address must be i32)
(check-invalid "load-wrong-addr" *mem-ctx* '((:i64.const 0) (:i32.load)))

(cw "9.5 Memory instruction typing: all pass~%")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 9.6 Function call typing

(defconst *call-ctx*
  (make-ctx '(((:i32) . (:i32)))                ;; types (for call_indirect)
            '(((:i32) . (:i32))                  ;; func 0: i32 → i32
              ((:i32 :i32) . (:i32)))            ;; func 1: i32 i32 → i32
            '(:i32 :i32)                          ;; locals
            nil nil nil 0 1))                     ;; 0 mems, 1 table

(check-valid "call-0" *call-ctx*
             '((:i32.const 5) (:call 0)) '(:i32))
(check-valid "call-1" *call-ctx*
             '((:i32.const 1) (:i32.const 2) (:call 1)) '(:i32))
(check-invalid "call-wrong-type" *call-ctx*
               '((:i64.const 5) (:call 0)))
(check-invalid "call-oob" *call-ctx*
               '((:i32.const 5) (:call 5)))

;; call_indirect: t1* i32 → t2?  (requires table)
(check-valid "call_indirect" *call-ctx*
             '((:i32.const 5) (:i32.const 0) (:call_indirect 0)) '(:i32))
(check-invalid "call_indirect-no-table"
               (make-ctx '(((:i32) . (:i32))) nil nil nil nil nil 0 0)
               '((:i32.const 5) (:i32.const 0) (:call_indirect 0)))

(cw "9.6 Function call typing: all pass~%")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 9.7 Composite program validation

;; Validate: abs(x) function body
;; params: (i32), result: (i32), body as in our proof
(defconst *abs-body*
  '((:local.get 0)
    (:i32.const 0)
    (:i32.lt_s)
    (:if 1
         ((:i32.const 0) (:local.get 0) (:i32.sub))
         ((:local.get 0)))))

(assert-event
 (validate-func-body *empty-ctx* '(:i32) '(:i32) nil *abs-body*)
 :msg "FAIL: abs function body validation")

;; Validate: sum loop body
(defconst *sum-body*
  '((:loop 0
           ((:local.get 1)
            (:local.get 0)
            (:i32.add)
            (:local.set 1)
            (:local.get 0)
            (:i32.const 1)
            (:i32.sub)
            (:local.tee 0)
            (:br_if 0)))
    (:local.get 1)))

(assert-event
 (validate-func-body *empty-ctx* '(:i32) '(:i32) '(:i32) *sum-body*)
 :msg "FAIL: sum loop function body validation")

;; Invalid: function claims to return i32 but body returns nothing
(assert-event
 (not (validate-func-body *empty-ctx* nil '(:i32) nil '((:nop))))
 :msg "FAIL: void-body-claiming-result should be invalid")

;; Invalid: function uses wrong local type
(assert-event
 (not (validate-func-body *empty-ctx* '(:i32) '(:i32) nil
                          '((:i64.const 5) (:local.set 0) (:local.get 0))))
 :msg "FAIL: wrong-local-type should be invalid")

(cw "9.7 Composite program validation: all pass~%")

(cw "~%=== ALL M9 VALIDATION TESTS PASSED ===~%")
