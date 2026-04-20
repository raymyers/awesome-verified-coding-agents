;; WASM 1.0 ACL2 — Spec Conformance Edge Case Proofs
;;
;; Oracle: tests/oracle/edge_cases.wat compiled + run via Node.js V8
;;
;; Tests trap correctness, shift modular semantics, rotation,
;; bit counting, signed comparison boundaries, and conversions.
;; All expected values are oracle-derived — see TEST_GUIDELINES.md Rule 1.

(in-package "ACL2")
(ld "/tmp/acl2-full/books/kestrel/wasm/package.lsp")
(in-package "WASM")
(include-book "kestrel/wasm/execution" :dir :system)

(set-guard-checking :none)

;; Helper: 1-frame state for inline instruction sequences
(defund mk (instrs)
  (declare (xargs :guard t :verify-guards nil))
  (make-state
   :store nil
   :call-stack (list (make-frame
                      :return-arity 1
                      :locals nil
                      :operand-stack (empty-operand-stack)
                      :instrs instrs
                      :label-stack nil))
   :memory nil
   :globals nil))

;; Constants (unsigned representation)
(defconst *i32-min-s*  (expt 2 31))         ; 2147483648 = -2^31 unsigned
(defconst *i32-neg1*   (1- (expt 2 32)))    ; 4294967295 = -1 unsigned
(defconst *i32-neg7*   (- (expt 2 32) 7))   ; 4294967289 = -7 unsigned

;; Theory for unfolding inline instruction execution
(defconst *edge-theory*
  '(mk run step execute-instr
    execute-i32.const execute-i64.const
    execute-i32.div_s execute-i32.div_u execute-i32.rem_s execute-i32.rem_u
    execute-i32.shl execute-i32.shr_s execute-i32.shr_u
    execute-i32.rotl execute-i32.rotr
    execute-i32.clz execute-i32.ctz execute-i32.popcnt
    execute-i32.lt_s execute-i32.ge_s
    execute-i32.wrap_i64 execute-i64.extend_i32_s execute-i64.extend_i32_u
    i32-clz-helper i32-ctz-helper i32-popcnt-helper
    current-frame current-instrs current-operand-stack
    current-label-stack current-locals
    update-current-operand-stack update-current-instrs
    complete-label return-from-function
    make-i32-val make-i64-val i32-valp i64-valp f32-valp f64-valp
    i32-const-argsp i64-const-argsp no-argsp
    push-operand top-operand pop-operand top-n-operands push-vals
    operand-stack-height empty-operand-stack operand-stackp
    localsp framep top-frame push-call-stack pop-call-stack call-stackp
    valp u32p u64p))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §1. TRAP CORRECTNESS
;;
;; WASM spec requires traps for:
;;   - i32.div_s(MIN_INT, -1) → trap (overflow)
;;   - i32.div_s(x, 0) → trap (divide by zero)
;;   - i32.div_u(x, 0) → trap
;;   - i32.rem_s(x, 0) → trap
;;   - i32.rem_u(x, 0) → trap
;; But:
;;   - i32.rem_s(MIN_INT, -1) → 0 (not a trap!)

;; Oracle: div_s(MIN,-1)=TRAP
(defthm i32-div-s-overflow-traps
  (equal (run 3 (mk (list (list :i32.const *i32-min-s*)
                           (list :i32.const *i32-neg1*)
                           '(:i32.div_s))))
         :trap)
  :hints (("Goal" :in-theory (enable . #.*edge-theory*))))

;; Oracle: div_s(1,0)=TRAP
(defthm i32-div-s-zero-traps
  (equal (run 3 (mk (list '(:i32.const 1)
                           '(:i32.const 0)
                           '(:i32.div_s))))
         :trap)
  :hints (("Goal" :in-theory (enable . #.*edge-theory*))))

;; Oracle: div_u(1,0)=TRAP
(defthm i32-div-u-zero-traps
  (equal (run 3 (mk (list '(:i32.const 1)
                           '(:i32.const 0)
                           '(:i32.div_u))))
         :trap)
  :hints (("Goal" :in-theory (enable . #.*edge-theory*))))

;; Oracle: rem_s(1,0)=TRAP
(defthm i32-rem-s-zero-traps
  (equal (run 3 (mk (list '(:i32.const 1)
                           '(:i32.const 0)
                           '(:i32.rem_s))))
         :trap)
  :hints (("Goal" :in-theory (enable . #.*edge-theory*))))

;; Oracle: rem_u(1,0)=TRAP
(defthm i32-rem-u-zero-traps
  (equal (run 3 (mk (list '(:i32.const 1)
                           '(:i32.const 0)
                           '(:i32.rem_u))))
         :trap)
  :hints (("Goal" :in-theory (enable . #.*edge-theory*))))

;; Oracle: rem_s(MIN,-1)=0  (NOT a trap — this is a notorious edge case)
(defthm i32-rem-s-min-neg1-is-zero
  (equal (top-operand
          (current-operand-stack
           (run 3 (mk (list (list :i32.const *i32-min-s*)
                             (list :i32.const *i32-neg1*)
                             '(:i32.rem_s))))))
         (make-i32-val 0))
  :hints (("Goal" :in-theory (enable . #.*edge-theory*))))

;; Oracle: div_s(-7,2)=-3  (truncation toward zero)
;; -7 unsigned = 4294967289, -3 unsigned = 4294967293
(defthm i32-div-s-truncates-toward-zero
  (equal (top-operand
          (current-operand-stack
           (run 3 (mk (list (list :i32.const *i32-neg7*)
                             '(:i32.const 2)
                             '(:i32.div_s))))))
         (make-i32-val (- (expt 2 32) 3)))
  :hints (("Goal" :in-theory (enable . #.*edge-theory*))))

;; Oracle: rem_s(-7,2)=-1  (sign follows dividend)
;; -1 unsigned = 4294967295
(defthm i32-rem-s-sign-follows-dividend
  (equal (top-operand
          (current-operand-stack
           (run 3 (mk (list (list :i32.const *i32-neg7*)
                             '(:i32.const 2)
                             '(:i32.rem_s))))))
         (make-i32-val *i32-neg1*))
  :hints (("Goal" :in-theory (enable . #.*edge-theory*))))

;; Oracle: rem_u(7,2)=1
(defthm i32-rem-u-basic
  (equal (top-operand
          (current-operand-stack
           (run 3 (mk (list '(:i32.const 7)
                             '(:i32.const 2)
                             '(:i32.rem_u))))))
         (make-i32-val 1))
  :hints (("Goal" :in-theory (enable . #.*edge-theory*))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §2. SHIFT MODULAR SEMANTICS
;;
;; WASM spec: shift amount is taken mod 32 for i32, mod 64 for i64.
;; So shl(1, 32) = shl(1, 0) = 1.

;; Oracle: shl(1,31)=2147483648
(defthm i32-shl-to-sign-bit
  (equal (top-operand
          (current-operand-stack
           (run 3 (mk (list '(:i32.const 1)
                             '(:i32.const 31)
                             '(:i32.shl))))))
         (make-i32-val (expt 2 31)))
  :hints (("Goal" :in-theory (enable . #.*edge-theory*))))

;; Oracle: shl(1,32)=1  (mod 32: shift by 0)
(defthm i32-shl-mod-32-wraps
  (equal (top-operand
          (current-operand-stack
           (run 3 (mk (list '(:i32.const 1)
                             '(:i32.const 32)
                             '(:i32.shl))))))
         (make-i32-val 1))
  :hints (("Goal" :in-theory (enable . #.*edge-theory*))))

;; Oracle: shr_s(MIN,1)=-1073741824 unsigned=3221225472
(defthm i32-shr-s-sign-extends
  (equal (top-operand
          (current-operand-stack
           (run 3 (mk (list (list :i32.const *i32-min-s*)
                             '(:i32.const 1)
                             '(:i32.shr_s))))))
         (make-i32-val 3221225472))
  :hints (("Goal" :in-theory (enable . #.*edge-theory*))))

;; Oracle: shr_u(MIN,1)=1073741824
(defthm i32-shr-u-zero-extends
  (equal (top-operand
          (current-operand-stack
           (run 3 (mk (list (list :i32.const *i32-min-s*)
                             '(:i32.const 1)
                             '(:i32.shr_u))))))
         (make-i32-val 1073741824))
  :hints (("Goal" :in-theory (enable . #.*edge-theory*))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §3. ROTATION
;;
;; Oracle: rotl(0xFF000000, 4)=0xF000000F=4026531855
;; Oracle: rotr(0x000000FF, 4)=0xF000000F=4026531855

(defthm i32-rotl-boundary
  (equal (top-operand
          (current-operand-stack
           (run 3 (mk (list '(:i32.const #xFF000000)
                             '(:i32.const 4)
                             '(:i32.rotl))))))
         (make-i32-val #xF000000F))
  :hints (("Goal" :in-theory (enable . #.*edge-theory*))))

(defthm i32-rotr-boundary
  (equal (top-operand
          (current-operand-stack
           (run 3 (mk (list '(:i32.const #x000000FF)
                             '(:i32.const 4)
                             '(:i32.rotr))))))
         (make-i32-val #xF000000F))
  :hints (("Goal" :in-theory (enable . #.*edge-theory*))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §4. BIT COUNTING
;;
;; clz(0)=32, clz(1)=31, clz(MIN)=0
;; ctz(0)=32, ctz(1)=0, ctz(MIN)=31
;; popcnt(0)=0, popcnt(MAX_U)=32, popcnt(0xAAAAAAAA)=16

(defthm i32-clz-zero
  (equal (top-operand
          (current-operand-stack
           (run 2 (mk (list '(:i32.const 0) '(:i32.clz))))))
         (make-i32-val 32))
  :hints (("Goal" :in-theory (enable . #.*edge-theory*))))

(defthm i32-clz-one
  (equal (top-operand
          (current-operand-stack
           (run 2 (mk (list '(:i32.const 1) '(:i32.clz))))))
         (make-i32-val 31))
  :hints (("Goal" :in-theory (enable . #.*edge-theory*))))

(defthm i32-clz-min
  (equal (top-operand
          (current-operand-stack
           (run 2 (mk (list (list :i32.const *i32-min-s*) '(:i32.clz))))))
         (make-i32-val 0))
  :hints (("Goal" :in-theory (enable . #.*edge-theory*))))

(defthm i32-ctz-zero
  (equal (top-operand
          (current-operand-stack
           (run 2 (mk (list '(:i32.const 0) '(:i32.ctz))))))
         (make-i32-val 32))
  :hints (("Goal" :in-theory (enable . #.*edge-theory*))))

(defthm i32-ctz-one
  (equal (top-operand
          (current-operand-stack
           (run 2 (mk (list '(:i32.const 1) '(:i32.ctz))))))
         (make-i32-val 0))
  :hints (("Goal" :in-theory (enable . #.*edge-theory*))))

(defthm i32-ctz-min
  (equal (top-operand
          (current-operand-stack
           (run 2 (mk (list (list :i32.const *i32-min-s*) '(:i32.ctz))))))
         (make-i32-val 31))
  :hints (("Goal" :in-theory (enable . #.*edge-theory*))))

(defthm i32-popcnt-zero
  (equal (top-operand
          (current-operand-stack
           (run 2 (mk (list '(:i32.const 0) '(:i32.popcnt))))))
         (make-i32-val 0))
  :hints (("Goal" :in-theory (enable . #.*edge-theory*))))

(defthm i32-popcnt-max
  (equal (top-operand
          (current-operand-stack
           (run 2 (mk (list (list :i32.const *i32-neg1*) '(:i32.popcnt))))))
         (make-i32-val 32))
  :hints (("Goal" :in-theory (enable . #.*edge-theory*))))

(defthm i32-popcnt-alternating
  (equal (top-operand
          (current-operand-stack
           (run 2 (mk (list '(:i32.const #xAAAAAAAA) '(:i32.popcnt))))))
         (make-i32-val 16))
  :hints (("Goal" :in-theory (enable . #.*edge-theory*))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §5. SIGNED COMPARISON BOUNDARIES
;;
;; Oracle: lt_s(MIN,0)=1  (MIN_INT < 0)
;; Oracle: lt_s(0,MIN)=0
;; Oracle: ge_s(MAX,MIN)=1

(defthm i32-lt-s-min-is-negative
  (equal (top-operand
          (current-operand-stack
           (run 3 (mk (list (list :i32.const *i32-min-s*)
                             '(:i32.const 0)
                             '(:i32.lt_s))))))
         (make-i32-val 1))
  :hints (("Goal" :in-theory (enable . #.*edge-theory*))))

(defthm i32-lt-s-zero-not-less-than-min
  (equal (top-operand
          (current-operand-stack
           (run 3 (mk (list '(:i32.const 0)
                             (list :i32.const *i32-min-s*)
                             '(:i32.lt_s))))))
         (make-i32-val 0))
  :hints (("Goal" :in-theory (enable . #.*edge-theory*))))

(defthm i32-ge-s-max-ge-min
  (equal (top-operand
          (current-operand-stack
           (run 3 (mk (list '(:i32.const 2147483647)
                             (list :i32.const *i32-min-s*)
                             '(:i32.ge_s))))))
         (make-i32-val 1))
  :hints (("Goal" :in-theory (enable . #.*edge-theory*))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §6. CONVERSION EDGE CASES
;;
;; Oracle: wrap(0x100000001)=1
;; Oracle: wrap(0xFFFFFFFFFFFFFFFF)=4294967295
;; Oracle: extend_s(-1 as u32)=-1 as u64 = 18446744073709551615
;; Oracle: extend_u(MAX_U)=4294967295 (same bits, zero-extended)

(defthm i32-wrap-truncates
  (equal (top-operand
          (current-operand-stack
           (run 2 (mk (list '(:i64.const #x100000001) '(:i32.wrap_i64))))))
         (make-i32-val 1))
  :hints (("Goal" :in-theory (enable . #.*edge-theory*))))

(defthm i32-wrap-all-ones
  (equal (top-operand
          (current-operand-stack
           (run 2 (mk (list (list :i64.const (1- (expt 2 64))) '(:i32.wrap_i64))))))
         (make-i32-val *i32-neg1*))
  :hints (("Goal" :in-theory (enable . #.*edge-theory*))))

(defthm i64-extend-s-neg1
  (equal (top-operand
          (current-operand-stack
           (run 2 (mk (list (list :i32.const *i32-neg1*) '(:i64.extend_i32_s))))))
         (make-i64-val (1- (expt 2 64))))
  :hints (("Goal" :in-theory (enable . #.*edge-theory*))))

(defthm i64-extend-u-max
  (equal (top-operand
          (current-operand-stack
           (run 2 (mk (list (list :i32.const *i32-neg1*) '(:i64.extend_i32_u))))))
         (make-i64-val *i32-neg1*))
  :hints (("Goal" :in-theory (enable . #.*edge-theory*))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §7. SYMBOLIC TRAP PROOF
;;
;; Universal: for ALL x, div_s(x, 0) traps.

;; Symbolic proofs need :expand hints on the fully-unfolded state form
;; since mk is expanded before run is attempted.

(defthm i32-div-s-any-by-zero-traps
  (implies (u32p x)
           (equal (run 3 (mk (list (list :i32.const x)
                                    '(:i32.const 0)
                                    '(:i32.div_s))))
                  :trap))
  :hints (("Goal" :in-theory (enable . #.*edge-theory*)
                  :expand ((:free (n s) (run n s))))))

(defthm i32-div-u-any-by-zero-traps
  (implies (u32p x)
           (equal (run 3 (mk (list (list :i32.const x)
                                    '(:i32.const 0)
                                    '(:i32.div_u))))
                  :trap))
  :hints (("Goal" :in-theory (enable . #.*edge-theory*)
                  :expand ((:free (n s) (run n s))))))

(defthm i32-rem-s-any-by-zero-traps
  (implies (u32p x)
           (equal (run 3 (mk (list (list :i32.const x)
                                    '(:i32.const 0)
                                    '(:i32.rem_s))))
                  :trap))
  :hints (("Goal" :in-theory (enable . #.*edge-theory*)
                  :expand ((:free (n s) (run n s))))))

(defthm i32-rem-u-any-by-zero-traps
  (implies (u32p x)
           (equal (run 3 (mk (list (list :i32.const x)
                                    '(:i32.const 0)
                                    '(:i32.rem_u))))
                  :trap))
  :hints (("Goal" :in-theory (enable . #.*edge-theory*)
                  :expand ((:free (n s) (run n s))))))

;; All done — no FAILED if this file loads cleanly.
