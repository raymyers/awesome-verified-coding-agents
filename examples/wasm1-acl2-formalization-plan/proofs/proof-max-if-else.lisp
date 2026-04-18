;; WASM 1.0 ACL2 — M8.8: max(a,b) using if/else correctness proof
;;
;; Theorem: The WASM program that computes max via i32.gt_u + if/else
;; produces the correct result for all u32 inputs.
;;
;; This is the FIRST proof involving control flow:
;;   - execute-if dispatches to then/else branch
;;   - label stack push/pop via complete-label
;;
;; Proof technique:
;;   - Split into two cases (a>b and a<=b) to avoid case-split explosion
;;   - Use :expand hints for recursive defund functions (run, top-n-operands, push-vals)
;;   - Omit instrp from theory (150+ cases, not needed with :verify-guards nil)
;;   - Combine via :use instances

(in-package "ACL2")
(ld "/tmp/acl2-full/books/kestrel/wasm/package.lsp")
(in-package "WASM")
(include-book "kestrel/wasm/execution" :dir :system)

;; The max(a,b) program:
;;   local.get 0           ; push a
;;   local.get 1           ; push b
;;   i32.gt_u              ; compare: a > b?
;;   if (result i32)       ; branch on condition
;;     local.get 0         ;   then: push a
;;   else
;;     local.get 1         ;   else: push b
;;   end
;; Takes 6 steps: 3 setup + 1 if + 1 body + 1 label-complete

(defun make-max-state (a b)
  (declare (xargs :guard t :verify-guards nil))
  (make-state
   :store nil
   :call-stack (list (make-frame
                     :return-arity 1
                     :locals (list (make-i32-val a) (make-i32-val b))
                     :operand-stack (empty-operand-stack)
                     :instrs (list '(:local.get 0)
                                   '(:local.get 1)
                                   '(:i32.gt_u)
                                   '(:if 1
                                         ((:local.get 0))
                                         ((:local.get 1))))
                     :label-stack nil))
   :memory nil
   :globals nil))

;; Theory for if/else proofs: execution functions + label stack ops
;; Note: instrp intentionally omitted (150+ instruction cases cause rewrite explosion)
(defconst *max-theory*
  '(run execute-instr
    execute-local.get execute-i32.gt_u execute-if
    complete-label return-from-function
    current-frame current-instrs current-operand-stack
    current-label-stack current-locals
    update-current-operand-stack update-current-instrs
    update-current-label-stack
    make-i32-val i32-valp i32-const-argsp
    local-idx-argsp no-argsp
    push-operand top-operand pop-operand top-n-operands push-vals
    operand-stack-height empty-operand-stack operand-stackp
    localsp framep top-frame push-call-stack pop-call-stack call-stackp
    valp i64-valp u32p u64p val-listp
    label-entryp label-entry->arity label-entry->continuation
    label-entry->is-loop push-label pop-label top-label
    nth-local make-max-state))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 1: When a > b, the program returns a

(defthm max-when-a-greater
  (implies
   (and (unsigned-byte-p 32 a)
        (unsigned-byte-p 32 b)
        (> a b))
   (equal
    (top-operand
     (current-operand-stack
      (run 6 (make-max-state a b))))
    (make-i32-val a)))
  :hints (("Goal" :in-theory (enable . #.*max-theory*)
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))
                           (:free (n s a) (top-n-operands n s a))
                           (:free (v s) (push-vals v s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 2: When a <= b, the program returns b

(defthm max-when-b-geq
  (implies
   (and (unsigned-byte-p 32 a)
        (unsigned-byte-p 32 b)
        (<= a b))
   (equal
    (top-operand
     (current-operand-stack
      (run 6 (make-max-state a b))))
    (make-i32-val b)))
  :hints (("Goal" :in-theory (enable . #.*max-theory*)
                  :do-not '(generalize)
                  :expand ((:free (n s) (run n s))
                           (:free (n s a) (top-n-operands n s a))
                           (:free (v s) (push-vals v s))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Theorem 3: Combined — the program computes max(a,b)

(defthm max-if-else-correct
  (implies
   (and (unsigned-byte-p 32 a)
        (unsigned-byte-p 32 b))
   (equal
    (top-operand
     (current-operand-stack
      (run 6 (make-max-state a b))))
    (if (> a b) (make-i32-val a) (make-i32-val b))))
  :hints (("Goal" :use ((:instance max-when-a-greater)
                         (:instance max-when-b-geq))
                  :in-theory (disable max-when-a-greater max-when-b-geq
                                      make-max-state run))))

(cw "~% - max-when-a-greater: a > b → returns a (Q.E.D.)~%")
(cw " - max-when-b-geq: a <= b → returns b (Q.E.D.)~%")
(cw " - max-if-else-correct: combined max theorem (Q.E.D.)~%")
