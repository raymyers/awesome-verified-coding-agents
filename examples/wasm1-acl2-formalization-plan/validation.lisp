;; WASM 1.0 ACL2 — Milestone 9: Type Validation
;;
;; Implements the typing rules from WASM 1.0 SpecTec 6-typing.spectec.
;; The type checker walks instruction sequences, threading a "type stack"
;; (list of value types) and a validation context (locals, labels, etc.).
;;
;; Key design:
;;   (type-check-instr ctx instr stack) → new-stack | :invalid
;;   (type-check-instrs ctx instrs stack) → final-stack | :invalid
;;
;; The type stack is a list of value type keywords (:i32 :i64 :f32 :f64).
;; :polymorphic marks unreachable code (after br, return, unreachable).

(in-package "WASM")
(include-book "execution")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 9.1 Value types and validation context

(defun valtypep (x)
  (declare (xargs :guard t :verify-guards nil))
  (member-equal x '(:i32 :i64 :f32 :f64)))

(defun valtype-listp (x)
  (declare (xargs :guard t :verify-guards nil))
  (if (atom x)
      (null x)
    (and (valtypep (car x))
         (valtype-listp (cdr x)))))

;; Result type: nil (void) or a list containing one valtype
(defun resulttypep (x)
  (declare (xargs :guard t :verify-guards nil))
  (or (null x)
      (and (consp x) (null (cdr x)) (valtypep (car x)))))

;; Validation context
;; :types — list of function types (each is (params . results))
;; :funcs — list of function types for each function index
;; :locals — list of value types for each local variable
;; :labels — list of result types for each label (innermost first)
;; :return — result type of current function (or nil)
;; :globals — list of (mutability . valtype) pairs
;; :mems — number of memories (0 or 1 in WASM 1.0)
;; :tables — number of tables (0 or 1 in WASM 1.0)

(defun make-ctx (types funcs locals labels return-type globals mems tables)
  (declare (xargs :guard t :verify-guards nil))
  (list (cons :types types)
        (cons :funcs funcs)
        (cons :locals locals)
        (cons :labels labels)
        (cons :return return-type)
        (cons :globals globals)
        (cons :mems mems)
        (cons :tables tables)))

(defun ctx-types (ctx)   (declare (xargs :guard t :verify-guards nil)) (cdr (assoc-equal :types ctx)))
(defun ctx-funcs (ctx)   (declare (xargs :guard t :verify-guards nil)) (cdr (assoc-equal :funcs ctx)))
(defun ctx-locals (ctx)  (declare (xargs :guard t :verify-guards nil)) (cdr (assoc-equal :locals ctx)))
(defun ctx-labels (ctx)  (declare (xargs :guard t :verify-guards nil)) (cdr (assoc-equal :labels ctx)))
(defun ctx-return (ctx)  (declare (xargs :guard t :verify-guards nil)) (cdr (assoc-equal :return ctx)))
(defun ctx-globals (ctx) (declare (xargs :guard t :verify-guards nil)) (cdr (assoc-equal :globals ctx)))
(defun ctx-mems (ctx)    (declare (xargs :guard t :verify-guards nil)) (cdr (assoc-equal :mems ctx)))
(defun ctx-tables (ctx)  (declare (xargs :guard t :verify-guards nil)) (cdr (assoc-equal :tables ctx)))

;; Push a new label onto the context (for block/loop/if)
(defun ctx-push-label (result-type ctx)
  (declare (xargs :guard t :verify-guards nil))
  (let ((labels (ctx-labels ctx)))
    (put-assoc-equal :labels (cons result-type labels) ctx)))

;; Empty context for simple validation
(defconst *empty-ctx*
  (make-ctx nil nil nil nil nil nil 0 0))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Type stack operations

;; Pop n types from the stack, checking they match expected types
(defun stack-pop-check (expected stack)
  (declare (xargs :guard t
                  :measure (len expected)))
  (cond
   ;; Polymorphic stack matches anything
   ((equal stack '(:polymorphic)) '(:polymorphic))
   ((atom expected) stack)
   ((atom stack) :invalid)
   ;; Check top of stack matches last expected type
   ;; Expected is consumed left-to-right, but stack is top-first
   ;; So we need to check in reverse: expected = (bottom ... top)
   ;; stack = (top ... bottom)
   ((not (equal (car expected) (car stack))) :invalid)
   (t (stack-pop-check (cdr expected) (cdr stack)))))

;; Push types onto stack (result types go on top)
(defun stack-push (types stack)
  (declare (xargs :guard t :verify-guards nil))
  (if (equal stack :invalid)
      :invalid
    (if (atom types)
        stack
      (if (equal stack '(:polymorphic))
          '(:polymorphic)
        (append types stack)))))

;; Pop expected types and push result types
(defun stack-transition (consume produce stack)
  (declare (xargs :guard t :verify-guards nil))
  (if (equal stack :invalid)
      :invalid
    (let ((after-pop (stack-pop-check (reverse consume) stack)))
      (if (equal after-pop :invalid)
          :invalid
        (stack-push produce after-pop)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 9.2 Instruction classification helpers

;; Get the value type of a numeric constant instruction
(defun const-type (opcode)
  (declare (xargs :guard t :verify-guards nil))
  (case opcode
    (:i32.const :i32)
    (:i64.const :i64)
    (:f32.const :f32)
    (:f64.const :f64)
    (otherwise nil)))

;; Get the operand type of a unary/binary/test/rel op
(defun i32-binop-p (opcode)
  (declare (xargs :guard t :verify-guards nil))
  (member-equal opcode '(:i32.add :i32.sub :i32.mul :i32.div_u :i32.div_s
                         :i32.rem_u :i32.rem_s
                         :i32.and :i32.or :i32.xor
                         :i32.shl :i32.shr_u :i32.shr_s :i32.rotl :i32.rotr)))

(defun i64-binop-p (opcode)
  (declare (xargs :guard t :verify-guards nil))
  (member-equal opcode '(:i64.add :i64.sub :i64.mul :i64.div_u :i64.div_s
                         :i64.rem_u :i64.rem_s
                         :i64.and :i64.or :i64.xor
                         :i64.shl :i64.shr_u :i64.shr_s :i64.rotl :i64.rotr)))

(defun f32-binop-p (opcode)
  (declare (xargs :guard t :verify-guards nil))
  (member-equal opcode '(:f32.add :f32.sub :f32.mul :f32.div
                         :f32.min :f32.max :f32.copysign)))

(defun f64-binop-p (opcode)
  (declare (xargs :guard t :verify-guards nil))
  (member-equal opcode '(:f64.add :f64.sub :f64.mul :f64.div
                         :f64.min :f64.max :f64.copysign)))

(defun i32-unop-p (opcode)
  (declare (xargs :guard t :verify-guards nil))
  (member-equal opcode '(:i32.clz :i32.ctz :i32.popcnt)))

(defun i64-unop-p (opcode)
  (declare (xargs :guard t :verify-guards nil))
  (member-equal opcode '(:i64.clz :i64.ctz :i64.popcnt)))

(defun f32-unop-p (opcode)
  (declare (xargs :guard t :verify-guards nil))
  (member-equal opcode '(:f32.abs :f32.neg :f32.sqrt :f32.ceil :f32.floor
                         :f32.trunc :f32.nearest)))

(defun f64-unop-p (opcode)
  (declare (xargs :guard t :verify-guards nil))
  (member-equal opcode '(:f64.abs :f64.neg :f64.sqrt :f64.ceil :f64.floor
                         :f64.trunc :f64.nearest)))

(defun i32-testop-p (opcode)
  (declare (xargs :guard t :verify-guards nil))
  (equal opcode :i32.eqz))

(defun i64-testop-p (opcode)
  (declare (xargs :guard t :verify-guards nil))
  (equal opcode :i64.eqz))

(defun i32-relop-p (opcode)
  (declare (xargs :guard t :verify-guards nil))
  (member-equal opcode '(:i32.eq :i32.ne
                         :i32.lt_u :i32.lt_s :i32.gt_u :i32.gt_s
                         :i32.le_u :i32.le_s :i32.ge_u :i32.ge_s)))

(defun i64-relop-p (opcode)
  (declare (xargs :guard t :verify-guards nil))
  (member-equal opcode '(:i64.eq :i64.ne
                         :i64.lt_u :i64.lt_s :i64.gt_u :i64.gt_s
                         :i64.le_u :i64.le_s :i64.ge_u :i64.ge_s)))

(defun f32-relop-p (opcode)
  (declare (xargs :guard t :verify-guards nil))
  (member-equal opcode '(:f32.eq :f32.ne :f32.lt :f32.gt :f32.le :f32.ge)))

(defun f64-relop-p (opcode)
  (declare (xargs :guard t :verify-guards nil))
  (member-equal opcode '(:f64.eq :f64.ne :f64.lt :f64.gt :f64.le :f64.ge)))

;; Conversion ops: source type → result type
(defun cvtop-types (opcode)
  (declare (xargs :guard t :verify-guards nil))
  (case opcode
    ;; i32 ← i64
    (:i32.wrap_i64          '(:i64 . :i32))
    ;; i64 ← i32
    (:i64.extend_i32_u      '(:i32 . :i64))
    (:i64.extend_i32_s      '(:i32 . :i64))
    ;; i32 ← f32/f64
    (:i32.trunc_f32_s       '(:f32 . :i32))
    (:i32.trunc_f32_u       '(:f32 . :i32))
    (:i32.trunc_f64_s       '(:f64 . :i32))
    (:i32.trunc_f64_u       '(:f64 . :i32))
    ;; i64 ← f32/f64
    (:i64.trunc_f32_s       '(:f32 . :i64))
    (:i64.trunc_f32_u       '(:f32 . :i64))
    (:i64.trunc_f64_s       '(:f64 . :i64))
    (:i64.trunc_f64_u       '(:f64 . :i64))
    ;; f32 ← i32/i64/f64
    (:f32.convert_i32_s     '(:i32 . :f32))
    (:f32.convert_i32_u     '(:i32 . :f32))
    (:f32.convert_i64_s     '(:i64 . :f32))
    (:f32.convert_i64_u     '(:i64 . :f32))
    (:f32.demote_f64        '(:f64 . :f32))
    ;; f64 ← i32/i64/f32
    (:f64.convert_i32_s     '(:i32 . :f64))
    (:f64.convert_i32_u     '(:i32 . :f64))
    (:f64.convert_i64_s     '(:i64 . :f64))
    (:f64.convert_i64_u     '(:i64 . :f64))
    (:f64.promote_f32       '(:f32 . :f64))
    ;; Reinterpret
    (:i32.reinterpret_f32   '(:f32 . :i32))
    (:i64.reinterpret_f64   '(:f64 . :i64))
    (:f32.reinterpret_i32   '(:i32 . :f32))
    (:f64.reinterpret_i64   '(:i64 . :f64))
    (otherwise nil)))

;; Load/store value type
(defun load-store-type (opcode)
  (declare (xargs :guard t :verify-guards nil))
  (case opcode
    ((:i32.load :i32.store :i32.load8_u :i32.load8_s
      :i32.load16_u :i32.load16_s :i32.store8 :i32.store16) :i32)
    ((:i64.load :i64.store :i64.load8_u :i64.load8_s
      :i64.load16_u :i64.load16_s :i64.load32_u :i64.load32_s
      :i64.store8 :i64.store16 :i64.store32) :i64)
    ((:f32.load :f32.store) :f32)
    ((:f64.load :f64.store) :f64)
    (otherwise nil)))

(defun load-op-p (opcode)
  (declare (xargs :guard t :verify-guards nil))
  (member-equal opcode '(:i32.load :i64.load :f32.load :f64.load
                         :i32.load8_u :i32.load8_s :i32.load16_u :i32.load16_s
                         :i64.load8_u :i64.load8_s :i64.load16_u :i64.load16_s
                         :i64.load32_u :i64.load32_s)))

(defun store-op-p (opcode)
  (declare (xargs :guard t :verify-guards nil))
  (member-equal opcode '(:i32.store :i64.store :f32.store :f64.store
                         :i32.store8 :i32.store16
                         :i64.store8 :i64.store16 :i64.store32)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 9.3-9.4 Type-check instructions (mutually recursive)

(mutual-recursion

(defun type-check-instr (ctx instr stack)
  (declare (xargs :guard t
                  :verify-guards nil
                  :measure (acl2-count instr)))
  (if (equal stack :invalid)
      :invalid
    (if (not (consp instr))
        :invalid
      (let ((opcode (car instr)))
        (cond
         ;; nop: eps → eps
         ((equal opcode :nop) stack)

         ;; unreachable: t1* → t2*  (polymorphic)
         ((equal opcode :unreachable) '(:polymorphic))

         ;; drop: t → eps
         ((equal opcode :drop)
          (if (or (equal stack '(:polymorphic))
                  (and (consp stack) (valtypep (car stack))))
              (if (equal stack '(:polymorphic))
                  '(:polymorphic)
                (cdr stack))
            :invalid))

         ;; select: t t i32 → t
         ((equal opcode :select)
          (cond
           ((equal stack '(:polymorphic)) '(:polymorphic))
           ((and (consp stack)
                 (equal (car stack) :i32)
                 (consp (cdr stack))
                 (valtypep (cadr stack))
                 (consp (cddr stack))
                 (equal (cadr stack) (caddr stack)))
            (cddr stack))
           (t :invalid)))

         ;; Constants: eps → t
         ((const-type opcode)
          (cons (const-type opcode) stack))

         ;; i32 binary ops: i32 i32 → i32
         ((i32-binop-p opcode) (stack-transition '(:i32 :i32) '(:i32) stack))
         ;; i64 binary ops: i64 i64 → i64
         ((i64-binop-p opcode) (stack-transition '(:i64 :i64) '(:i64) stack))
         ;; f32 binary ops: f32 f32 → f32
         ((f32-binop-p opcode) (stack-transition '(:f32 :f32) '(:f32) stack))
         ;; f64 binary ops: f64 f64 → f64
         ((f64-binop-p opcode) (stack-transition '(:f64 :f64) '(:f64) stack))

         ;; i32 unary ops: i32 → i32
         ((i32-unop-p opcode) (stack-transition '(:i32) '(:i32) stack))
         ;; i64 unary ops: i64 → i64
         ((i64-unop-p opcode) (stack-transition '(:i64) '(:i64) stack))
         ;; f32 unary ops: f32 → f32
         ((f32-unop-p opcode) (stack-transition '(:f32) '(:f32) stack))
         ;; f64 unary ops: f64 → f64
         ((f64-unop-p opcode) (stack-transition '(:f64) '(:f64) stack))

         ;; Test ops: t → i32
         ((i32-testop-p opcode) (stack-transition '(:i32) '(:i32) stack))
         ((i64-testop-p opcode) (stack-transition '(:i64) '(:i32) stack))

         ;; Relational ops: t t → i32
         ((i32-relop-p opcode) (stack-transition '(:i32 :i32) '(:i32) stack))
         ((i64-relop-p opcode) (stack-transition '(:i64 :i64) '(:i32) stack))
         ((f32-relop-p opcode) (stack-transition '(:f32 :f32) '(:i32) stack))
         ((f64-relop-p opcode) (stack-transition '(:f64 :f64) '(:i32) stack))

         ;; Conversion ops: src → dst
         ((cvtop-types opcode)
          (let ((types (cvtop-types opcode)))
            (stack-transition (list (car types)) (list (cdr types)) stack)))

         ;; local.get x: eps → t  (where C.locals[x] = t)
         ((equal opcode :local.get)
          (let* ((idx (if (consp (cdr instr)) (cadr instr) -1))
                 (locals (ctx-locals ctx))
                 (t1 (and (natp idx) (< idx (len locals))
                          (nth idx locals))))
            (if (valtypep t1)
                (cons t1 stack)
              :invalid)))

         ;; local.set x: t → eps
         ((equal opcode :local.set)
          (let* ((idx (if (consp (cdr instr)) (cadr instr) -1))
                 (locals (ctx-locals ctx))
                 (t1 (and (natp idx) (< idx (len locals))
                          (nth idx locals))))
            (if (valtypep t1)
                (stack-transition (list t1) nil stack)
              :invalid)))

         ;; local.tee x: t → t
         ((equal opcode :local.tee)
          (let* ((idx (if (consp (cdr instr)) (cadr instr) -1))
                 (locals (ctx-locals ctx))
                 (t1 (and (natp idx) (< idx (len locals))
                          (nth idx locals))))
            (if (valtypep t1)
                (stack-transition (list t1) (list t1) stack)
              :invalid)))

         ;; global.get x: eps → t
         ((equal opcode :global.get)
          (let* ((idx (if (consp (cdr instr)) (cadr instr) -1))
                 (globals (ctx-globals ctx))
                 (entry (and (natp idx) (< idx (len globals))
                             (nth idx globals)))
                 (t1 (if (consp entry) (cdr entry) nil)))
            (if (valtypep t1)
                (cons t1 stack)
              :invalid)))

         ;; global.set x: t → eps  (must be mutable)
         ((equal opcode :global.set)
          (let* ((idx (if (consp (cdr instr)) (cadr instr) -1))
                 (globals (ctx-globals ctx))
                 (entry (and (natp idx) (< idx (len globals))
                             (nth idx globals)))
                 (mut (if (consp entry) (car entry) nil))
                 (t1 (if (consp entry) (cdr entry) nil)))
            (if (and (valtypep t1) (equal mut :var))
                (stack-transition (list t1) nil stack)
              :invalid)))

         ;; Load ops: i32 → t  (requires memory)
         ((load-op-p opcode)
          (if (< 0 (nfix (ctx-mems ctx)))
              (let ((t1 (load-store-type opcode)))
                (if t1
                    (stack-transition '(:i32) (list t1) stack)
                  :invalid))
            :invalid))

         ;; Store ops: i32 t → eps  (requires memory)
         ((store-op-p opcode)
          (if (< 0 (nfix (ctx-mems ctx)))
              (let ((t1 (load-store-type opcode)))
                (if t1
                    (stack-transition (list :i32 t1) nil stack)
                  :invalid))
            :invalid))

         ;; memory.size: eps → i32
         ((equal opcode :memory.size)
          (if (< 0 (nfix (ctx-mems ctx)))
              (cons :i32 stack)
            :invalid))

         ;; memory.grow: i32 → i32
         ((equal opcode :memory.grow)
          (if (< 0 (nfix (ctx-mems ctx)))
              (stack-transition '(:i32) '(:i32) stack)
            :invalid))

         ;; Block instructions (structured control flow)
         ;; block arity body: eps → t?
         ((equal opcode :block)
          (let* ((arity (if (and (consp (cdr instr))
                                (natp (cadr instr)))
                            (cadr instr) 0))
                 (body (if (consp (cddr instr)) (caddr instr) nil))
                 (result-type (if (= arity 1) '(:i32) nil))
                 (inner-ctx (ctx-push-label result-type ctx))
                 (body-result (type-check-instrs inner-ctx body nil)))
            (if (equal body-result :invalid)
                :invalid
              ;; Check body produces the declared result type
              (if (or (equal body-result '(:polymorphic))
                      (equal body-result result-type))
                  (stack-push result-type stack)
                :invalid))))

         ;; loop arity body: eps → t?
         ((equal opcode :loop)
          (let* ((arity (if (and (consp (cdr instr))
                                (natp (cadr instr)))
                            (cadr instr) 0))
                 (body (if (consp (cddr instr)) (caddr instr) nil))
                 (result-type (if (= arity 1) '(:i32) nil))
                 ;; Loop label type is eps (br back to loop consumes nothing)
                 (inner-ctx (ctx-push-label nil ctx))
                 (body-result (type-check-instrs inner-ctx body nil)))
            (if (equal body-result :invalid)
                :invalid
              (if (or (equal body-result '(:polymorphic))
                      (equal body-result result-type))
                  (stack-push result-type stack)
                :invalid))))

         ;; if arity then-body else-body: i32 → t?
         ((equal opcode :if)
          (let* ((arity (if (and (consp (cdr instr))
                                (natp (cadr instr)))
                            (cadr instr) 0))
                 (then-body (if (consp (cddr instr)) (caddr instr) nil))
                 (else-body (if (consp (cdddr instr)) (cadddr instr) nil))
                 (result-type (if (= arity 1) '(:i32) nil))
                 (inner-ctx (ctx-push-label result-type ctx))
                 ;; Pop condition i32
                 (after-cond (stack-transition '(:i32) nil stack)))
            (if (equal after-cond :invalid)
                :invalid
              (let ((then-result (type-check-instrs inner-ctx then-body nil))
                    (else-result (type-check-instrs inner-ctx else-body nil)))
                (if (or (equal then-result :invalid)
                        (equal else-result :invalid))
                    :invalid
                  ;; Both branches must produce the same result type
                  (if (and (or (equal then-result '(:polymorphic))
                               (equal then-result result-type))
                           (or (equal else-result '(:polymorphic))
                               (equal else-result result-type)))
                      (stack-push result-type after-cond)
                    :invalid))))))

         ;; br l: t1* t? → t2*  (polymorphic — control never continues)
         ((equal opcode :br)
          (let* ((l (if (consp (cdr instr)) (cadr instr) -1))
                 (labels (ctx-labels ctx))
                 (target-type (and (natp l) (< l (len labels))
                                   (nth l labels))))
            ;; Check stack has the label's result type, then go polymorphic
            (if (natp l)
                (if (< l (len labels))
                    (let ((check (stack-pop-check (reverse target-type) stack)))
                      (if (equal check :invalid)
                          :invalid
                        '(:polymorphic)))
                  :invalid)
              :invalid)))

         ;; br_if l: t? i32 → t?
         ((equal opcode :br_if)
          (let* ((l (if (consp (cdr instr)) (cadr instr) -1))
                 (labels (ctx-labels ctx))
                 (target-type (and (natp l) (< l (len labels))
                                   (nth l labels))))
            (if (and (natp l) (< l (len labels)))
                ;; Pop i32 condition, check label type matches
                (let ((after-cond (stack-transition '(:i32) nil stack)))
                  (if (equal after-cond :invalid)
                      :invalid
                    (let ((check (stack-pop-check (reverse target-type) after-cond)))
                      (if (equal check :invalid)
                          :invalid
                        ;; On not-taken branch, stack has t? still
                        after-cond))))
              :invalid)))

         ;; return: t1* t? → t2*  (polymorphic)
         ((equal opcode :return)
          (let ((ret (ctx-return ctx)))
            (if ret
                (let ((check (stack-pop-check (reverse ret) stack)))
                  (if (equal check :invalid)
                      :invalid
                    '(:polymorphic)))
              ;; void return
              '(:polymorphic))))

         ;; call x: t1* → t2?
         ((equal opcode :call)
          (let* ((x (if (consp (cdr instr)) (cadr instr) -1))
                 (funcs (ctx-funcs ctx))
                 (ftype (and (natp x) (< x (len funcs))
                             (nth x funcs))))
            (if (consp ftype)
                (let ((params (car ftype))
                      (results (cdr ftype)))
                  (stack-transition params results stack))
              :invalid)))

         ;; call_indirect x: t1* i32 → t2?
         ((equal opcode :call_indirect)
          (if (< 0 (nfix (ctx-tables ctx)))
              (let* ((x (if (consp (cdr instr)) (cadr instr) -1))
                     (types (ctx-types ctx))
                     (ftype (and (natp x) (< x (len types))
                                 (nth x types))))
                (if (consp ftype)
                    (let ((params (car ftype))
                          (results (cdr ftype)))
                      ;; Pop i32 table index, then params
                      (stack-transition (append params '(:i32)) results stack))
                  :invalid))
            :invalid))

         ;; Unknown instruction
         (t :invalid))))))

(defun type-check-instrs (ctx instrs stack)
  (declare (xargs :guard t
                  :verify-guards nil
                  :measure (acl2-count instrs)))
  (if (equal stack :invalid)
      :invalid
    (if (atom instrs)
        stack
      (let ((new-stack (type-check-instr ctx (car instrs) stack)))
        (type-check-instrs ctx (cdr instrs) new-stack)))))

) ;; end mutual-recursion

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 9.5 Function body validation

;; Validate a function body given its type and the module context
(defun validate-func-body (ctx param-types result-types local-types body)
  (declare (xargs :guard t :verify-guards nil))
  (let* ((all-locals (append param-types local-types))
         (result-type result-types) ;; list of valtypes
         (func-ctx (put-assoc-equal
                    :return result-type
                    (put-assoc-equal :locals all-locals ctx)))
         (body-result (type-check-instrs func-ctx body nil)))
    (if (equal body-result :invalid)
        nil  ;; invalid
      (or (equal body-result '(:polymorphic))
          (equal body-result result-type)))))

(value-triple (cw "~%validation.lisp loaded successfully~%"))
