;; M7b: Tables and call_indirect tests
;; Tests indirect function calls through table lookup.

(in-package "ACL2")
(ld "/tmp/acl2-full/books/kestrel/wasm/package.lsp")
(in-package "WASM")
(include-book "kestrel/wasm/execution" :dir :system)

;; ============================================================
;; Setup: two simple functions in the store
;;
;; func 0: double(x) = x + x       (1 param, 0 extra locals, 1 return)
;; func 1: inc(x) = x + 1          (1 param, 0 extra locals, 1 return)

(defconst *test-store*
  (list
   ;; func 0: double(x) — local.get 0, local.get 0, i32.add
   (make-funcinst :param-count 1 :local-count 0 :return-arity 1
                  :body (list '(:local.get 0) '(:local.get 0) '(:i32.add)))
   ;; func 1: inc(x) — local.get 0, i32.const 1, i32.add
   (make-funcinst :param-count 1 :local-count 0 :return-arity 1
                  :body (list '(:local.get 0) '(:i32.const 1) '(:i32.add)))))

;; Table: [0 → func 0 (double), 1 → func 1 (inc)]
(defconst *test-table* '(0 1))

;; ============================================================
;; Test 1: call_indirect with table index 0 → calls double(5) = 10

(assert-event
 (equal
  (top-operand
   (current-operand-stack
    ;; 5 steps: push 5, push table-idx 0, call_indirect, run body (3 instrs)
    (run 6
         (make-state :store *test-store*
                     :call-stack
                     (list (make-frame
                            :return-arity 1 :locals nil
                            :operand-stack (empty-operand-stack)
                            :instrs (list '(:i32.const 5)
                                          '(:i32.const 0)       ; table idx
                                          '(:call_indirect 0))  ; type idx (unused)
                            :label-stack nil))
                     :memory nil :globals nil
                     :table *test-table*))))
  (make-i32-val 10)))

(cw "PASS: call_indirect table[0] → double(5) = 10~%")

;; ============================================================
;; Test 2: call_indirect with table index 1 → calls inc(42) = 43

(assert-event
 (equal
  (top-operand
   (current-operand-stack
    (run 6
         (make-state :store *test-store*
                     :call-stack
                     (list (make-frame
                            :return-arity 1 :locals nil
                            :operand-stack (empty-operand-stack)
                            :instrs (list '(:i32.const 42)
                                          '(:i32.const 1)       ; table idx
                                          '(:call_indirect 0))
                            :label-stack nil))
                     :memory nil :globals nil
                     :table *test-table*))))
  (make-i32-val 43)))

(cw "PASS: call_indirect table[1] → inc(42) = 43~%")

;; ============================================================
;; Test 3: call_indirect with out-of-bounds table index → trap

(assert-event
 (equal
  (run 3
       (make-state :store *test-store*
                   :call-stack
                   (list (make-frame
                          :return-arity 1 :locals nil
                          :operand-stack (empty-operand-stack)
                          :instrs (list '(:i32.const 5)
                                        '(:i32.const 99)       ; OOB
                                        '(:call_indirect 0))
                          :label-stack nil))
                   :memory nil :globals nil
                   :table *test-table*))
  :trap))

(cw "PASS: call_indirect OOB table index → trap~%")

;; ============================================================
;; Test 4: call_indirect with nil table entry → trap

(defconst *sparse-table* '(0 nil 1))  ; entry 1 is uninitialized

(assert-event
 (equal
  (run 3
       (make-state :store *test-store*
                   :call-stack
                   (list (make-frame
                          :return-arity 1 :locals nil
                          :operand-stack (empty-operand-stack)
                          :instrs (list '(:i32.const 5)
                                        '(:i32.const 1)        ; nil entry
                                        '(:call_indirect 0))
                          :label-stack nil))
                   :memory nil :globals nil
                   :table *sparse-table*))
  :trap))

(cw "PASS: call_indirect nil table entry → trap~%")

;; ============================================================
;; Test 5: call_indirect on empty table → trap

(assert-event
 (equal
  (run 3
       (make-state :store *test-store*
                   :call-stack
                   (list (make-frame
                          :return-arity 1 :locals nil
                          :operand-stack (empty-operand-stack)
                          :instrs (list '(:i32.const 5)
                                        '(:i32.const 0)
                                        '(:call_indirect 0))
                          :label-stack nil))
                   :memory nil :globals nil
                   :table nil))
  :trap))

(cw "PASS: call_indirect empty table → trap~%")

;; ============================================================
;; Test 6: call_indirect dispatching to different functions based on runtime index
;; Simulates a vtable/switch dispatch pattern

(assert-event
 (and
  ;; idx=0 → double(3) = 6
  (equal
   (top-operand
    (current-operand-stack
     (run 6
          (make-state :store *test-store*
                      :call-stack
                      (list (make-frame
                             :return-arity 1 :locals nil
                             :operand-stack (empty-operand-stack)
                             :instrs (list '(:i32.const 3)
                                           '(:i32.const 0)
                                           '(:call_indirect 0))
                             :label-stack nil))
                      :memory nil :globals nil
                      :table *test-table*))))
   (make-i32-val 6))
  ;; idx=1 → inc(3) = 4
  (equal
   (top-operand
    (current-operand-stack
     (run 6
          (make-state :store *test-store*
                      :call-stack
                      (list (make-frame
                             :return-arity 1 :locals nil
                             :operand-stack (empty-operand-stack)
                             :instrs (list '(:i32.const 3)
                                           '(:i32.const 1)
                                           '(:call_indirect 0))
                             :label-stack nil))
                      :memory nil :globals nil
                      :table *test-table*))))
   (make-i32-val 4))))

(cw "PASS: call_indirect vtable dispatch — double(3)=6, inc(3)=4~%")

(cw "~%=== ALL M7b TABLE TESTS PASSED (6/6) ===~%")
