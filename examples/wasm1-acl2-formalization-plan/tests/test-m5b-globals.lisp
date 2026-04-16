(in-package "ACL2")
(ld "/tmp/acl2-full/books/kestrel/wasm/package.lsp")
(in-package "WASM")
(include-book "kestrel/wasm/execution" :dir :system)

;; Helper: extract result from run output
(defun get-result (r)
  (declare (xargs :guard t :verify-guards nil))
  (if (and (consp r) (eq :done (first r)))
      (let* ((st (second r))
             (cs (state->call-stack st))
             (f (car cs)))
        (top-operand (frame->operand-stack f)))
    (if (statep r) (top-operand (current-operand-stack r)) r)))

;; Test 1: global.get reads a const global
(assert-event
 (equal (get-result
         (run 10
              (make-state :store nil
                          :call-stack (list (make-frame :return-arity 1
                                                        :locals nil
                                                        :operand-stack (empty-operand-stack)
                                                        :instrs '((:global.get 0))
                                                        :label-stack nil))
                          :memory nil
                          :globals (list (make-globalinst :mutability :const
                                                          :value (make-i32-val 42))))))
        (make-i32-val 42)))

;; Test 2: global.get reads second global (i64)
(assert-event
 (equal (get-result
         (run 10
              (make-state :store nil
                          :call-stack (list (make-frame :return-arity 1
                                                        :locals nil
                                                        :operand-stack (empty-operand-stack)
                                                        :instrs '((:global.get 1))
                                                        :label-stack nil))
                          :memory nil
                          :globals (list (make-globalinst :mutability :const
                                                          :value (make-i32-val 0))
                                         (make-globalinst :mutability :var
                                                          :value (make-i64-val 999))))))
        (make-i64-val 999)))

;; Test 3: global.set writes a var global, then global.get reads it back
(assert-event
 (equal (get-result
         (run 10
              (make-state :store nil
                          :call-stack (list (make-frame :return-arity 1
                                                        :locals nil
                                                        :operand-stack (empty-operand-stack)
                                                        :instrs '((:i32.const 100)
                                                                   (:global.set 0)
                                                                   (:global.get 0))
                                                        :label-stack nil))
                          :memory nil
                          :globals (list (make-globalinst :mutability :var
                                                          :value (make-i32-val 0))))))
        (make-i32-val 100)))

;; Test 4: global.set to const global → trap
(assert-event
 (equal (run 10
             (make-state :store nil
                         :call-stack (list (make-frame :return-arity 1
                                                       :locals nil
                                                       :operand-stack (empty-operand-stack)
                                                       :instrs '((:i32.const 1) (:global.set 0))
                                                       :label-stack nil))
                         :memory nil
                         :globals (list (make-globalinst :mutability :const
                                                         :value (make-i32-val 42)))))
        :trap))

;; Test 5: global.get out of bounds → trap
(assert-event
 (equal (run 10
             (make-state :store nil
                         :call-stack (list (make-frame :return-arity 1
                                                       :locals nil
                                                       :operand-stack (empty-operand-stack)
                                                       :instrs '((:global.get 5))
                                                       :label-stack nil))
                         :memory nil
                         :globals nil))
        :trap))

;; Test 6: Use global as a counter in a loop
;; global[0] = counter (var, starts at 0), loop 5 times incrementing
(assert-event
 (equal (get-result
         (run 100
              (make-state :store nil
                          :call-stack (list (make-frame :return-arity 1
                                                        :locals (list (make-i32-val 5))
                                                        :operand-stack (empty-operand-stack)
                                                        :instrs '((:block 0
                                                                    ((:loop 0
                                                                      (;; counter += 1
                                                                       (:global.get 0)
                                                                       (:i32.const 1)
                                                                       (:i32.add)
                                                                       (:global.set 0)
                                                                       ;; i -= 1
                                                                       (:local.get 0)
                                                                       (:i32.const 1)
                                                                       (:i32.sub)
                                                                       (:local.tee 0)
                                                                       ;; if i > 0, loop
                                                                       (:br_if 0)))))
                                                                  (:global.get 0))
                                                        :label-stack nil))
                          :memory nil
                          :globals (list (make-globalinst :mutability :var
                                                          :value (make-i32-val 0))))))
        (make-i32-val 5)))

;; Test 7: global.set with i64 value
(assert-event
 (equal (get-result
         (run 10
              (make-state :store nil
                          :call-stack (list (make-frame :return-arity 1
                                                        :locals nil
                                                        :operand-stack (empty-operand-stack)
                                                        :instrs '((:i64.const 9999999999)
                                                                   (:global.set 0)
                                                                   (:global.get 0))
                                                        :label-stack nil))
                          :memory nil
                          :globals (list (make-globalinst :mutability :var
                                                          :value (make-i64-val 0))))))
        (make-i64-val 9999999999)))

(cw "~%All globals tests passed! (get/set/const-trap/bounds/loop-counter/i64)~%")
