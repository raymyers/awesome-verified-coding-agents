(in-package "ACL2")
(ld "/tmp/acl2-full/books/kestrel/wasm/package.lsp")
(in-package "WASM")
(include-book "kestrel/wasm/execution" :dir :system)

;; Helper: extract result from state or (:done state) — reusable
(defun get-result (r)
  (declare (xargs :guard t :verify-guards nil))
  (if (and (consp r) (eq :done (first r)))
      (let* ((st (second r))
             (cs (state->call-stack st))
             (f (car cs)))
        (top-operand (frame->operand-stack f)))
    (if (statep r)
        (top-operand (current-operand-stack r))
      r)))

(defun get-state (r)
  (declare (xargs :guard t :verify-guards nil))
  (if (and (consp r) (eq :done (first r)))
      (second r)
    r))

(defmacro run-wasm-mem (steps locals instrs mem)
  `(run ,steps
        (make-state :store nil
                    :call-stack (list (make-frame :return-arity 1
                                                  :locals ,locals
                                                  :operand-stack (empty-operand-stack)
                                                  :instrs ,instrs
                                                  :label-stack nil))
                    :memory ,mem)))

(defmacro check-mem-result (steps locals instrs mem expected)
  `(assert-event
    (equal (get-result (run-wasm-mem ,steps ,locals ,instrs ,mem))
           ,expected)))

(defconst *test-mem* (list 0 0 0 0 42 0 0 0 1 0 1 0 255 255 255 255))

;; Test M4.1: i32.load from addr 4 → 42
(check-mem-result 10 nil '((:i32.const 4) (:i32.load 0)) *test-mem* (make-i32-val 42))

;; Test M4.2: i32.load from addr 8 → 65537
(check-mem-result 10 nil '((:i32.const 8) (:i32.load 0)) *test-mem* (make-i32-val 65537))

;; Test M4.3: i32.load with offset
(check-mem-result 10 nil '((:i32.const 0) (:i32.load 4)) *test-mem* (make-i32-val 42))

;; Test M4.4: i32.store then i32.load roundtrip
(check-mem-result 10 nil
                  '((:i32.const 0) (:i32.const 99) (:i32.store 0)
                    (:i32.const 0) (:i32.load 0))
                  *test-mem* (make-i32-val 99))

;; Test M4.5: memory.size (16 bytes < 1 page → 0)
(check-mem-result 10 nil '((:memory.size)) *test-mem* (make-i32-val 0))

;; Test M4.6: memory.size with 1 full page
(check-mem-result 10 nil '((:memory.size))
                  (make-list 65536 :initial-element 0) (make-i32-val 1))

;; Test M4.7: Out of bounds → trap
(assert-event
 (equal (run-wasm-mem 10 nil '((:i32.const 14) (:i32.load 0)) *test-mem*) :trap))

;; Test M4.8: LE byte order verification
(assert-event
 (let* ((r (run-wasm-mem 10 nil
                         '((:i32.const 0) (:i32.const 305419896) (:i32.store 0))
                         (make-list 8 :initial-element 0)))
        (st (get-state r)))
   (and (statep st)
        (equal (nth 0 (state->memory st)) #x78)
        (equal (nth 1 (state->memory st)) #x56)
        (equal (nth 2 (state->memory st)) #x34)
        (equal (nth 3 (state->memory st)) #x12))))

(cw "~%All M4 tests passed! (memory load/store/size/LE)~%")
