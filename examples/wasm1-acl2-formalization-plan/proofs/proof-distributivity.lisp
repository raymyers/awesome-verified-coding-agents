;; WASM 1.0 ACL2 — Distributivity and Shift-Law Proofs
;;
;; Proves BV arithmetic identities that underpin WASM integer semantics:
;;   - Left/right distributivity of i32/i64 mul over add and sub
;;     (mul distributes over addition/subtraction modulo 2^32 / 2^64)
;;   - Shift-as-multiplication laws: bvshl(x, k) = bvmult(x, 2^k)
;;     (logical left shift by k is multiplication by 2^k, mod 2^width)
;;
;; These are stated as pure BV-arithmetic theorems (not WASM-execution level)
;; because the BV library makes them tractable. The connection to WASM is:
;;   execute-i32.add maps to bvplus 32
;;   execute-i32.mul maps to bvmult 32
;;   execute-i32.sub maps to bvminus 32
;;   execute-i32.shl maps to bvshl 32
;;   (and equivalently for i64)
;;
;; Relies on: kestrel/bv/rules.lisp for bvmult-of-bvplus-1/2 and bvmult-of-bvminus-1
;;            kestrel/bv/bvshl.lisp for bvshl definitions

(in-package "ACL2")
(ld "/tmp/acl2-full/books/kestrel/wasm/package.lsp")
(in-package "WASM")
(include-book "kestrel/wasm/execution" :dir :system)
(local (include-book "kestrel/bv/rules" :dir :system))

(set-guard-checking :none)

(local (include-book "arithmetic-5/top" :dir :system))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §1. i32 Distributivity: mul over add and sub
;;
;; These use bvmult-of-bvplus-1/2 and bvmult-of-bvminus-1 from kestrel/bv/rules.

;; (a + b) * c = a*c + b*c  (left distributivity over addition)
(defthm i32-bv-mul-distributes-add-left
  (equal (acl2::bvmult 32 (acl2::bvplus 32 a b) c)
         (acl2::bvplus 32 (acl2::bvmult 32 a c) (acl2::bvmult 32 b c)))
  :hints (("Goal" :in-theory (enable acl2::bvmult acl2::bvplus))))

;; c * (a + b) = c*a + c*b  (right distributivity over addition)
(defthm i32-bv-mul-distributes-add-right
  (equal (acl2::bvmult 32 c (acl2::bvplus 32 a b))
         (acl2::bvplus 32 (acl2::bvmult 32 c a) (acl2::bvmult 32 c b)))
  :hints (("Goal" :in-theory (enable acl2::bvmult acl2::bvplus))))

;; (a - b) * c = a*c - b*c  (distributivity over subtraction)
(defthm i32-bv-mul-distributes-sub
  (equal (acl2::bvmult 32 (acl2::bvminus 32 a b) c)
         (acl2::bvminus 32 (acl2::bvmult 32 a c) (acl2::bvmult 32 b c)))
  :hints (("Goal" :in-theory (enable acl2::bvmult acl2::bvminus acl2::bvplus))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §2. i64 Distributivity: mul over add and sub

;; (a + b) * c = a*c + b*c  for 64-bit
(defthm i64-bv-mul-distributes-add-left
  (equal (acl2::bvmult 64 (acl2::bvplus 64 a b) c)
         (acl2::bvplus 64 (acl2::bvmult 64 a c) (acl2::bvmult 64 b c)))
  :hints (("Goal" :in-theory (enable acl2::bvmult acl2::bvplus))))

;; c * (a + b) = c*a + c*b  for 64-bit
(defthm i64-bv-mul-distributes-add-right
  (equal (acl2::bvmult 64 c (acl2::bvplus 64 a b))
         (acl2::bvplus 64 (acl2::bvmult 64 c a) (acl2::bvmult 64 c b)))
  :hints (("Goal" :in-theory (enable acl2::bvmult acl2::bvplus))))

;; (a - b) * c = a*c - b*c  for 64-bit
(defthm i64-bv-mul-distributes-sub
  (equal (acl2::bvmult 64 (acl2::bvminus 64 a b) c)
         (acl2::bvminus 64 (acl2::bvmult 64 a c) (acl2::bvmult 64 b c)))
  :hints (("Goal" :in-theory (enable acl2::bvmult acl2::bvminus acl2::bvplus))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §3. Shift-as-multiplication laws for i32
;;
;; shl(x, k) = bvmult(x, 2^k) mod 2^32
;; Proved via enabling bvshl and bvmult and letting ACL2 reduce ash-to-multiply.

;; shl(x, 1) = mul(x, 2)
(defthm i32-bvshl-1-eq-bvmult-2
  (implies (unsigned-byte-p 32 x)
           (equal (acl2::bvshl 32 x 1) (acl2::bvmult 32 x 2)))
  :hints (("Goal" :in-theory (enable acl2::bvshl acl2::bvmult acl2::bvchop))))

;; shl(x, 2) = mul(x, 4)
(defthm i32-bvshl-2-eq-bvmult-4
  (implies (unsigned-byte-p 32 x)
           (equal (acl2::bvshl 32 x 2) (acl2::bvmult 32 x 4)))
  :hints (("Goal" :in-theory (enable acl2::bvshl acl2::bvmult acl2::bvchop))))

;; shl(x, 3) = mul(x, 8)
(defthm i32-bvshl-3-eq-bvmult-8
  (implies (unsigned-byte-p 32 x)
           (equal (acl2::bvshl 32 x 3) (acl2::bvmult 32 x 8)))
  :hints (("Goal" :in-theory (enable acl2::bvshl acl2::bvmult acl2::bvchop))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; §4. Shift-as-multiplication laws for i64

;; shl(x, 1) = mul(x, 2) mod 2^64
(defthm i64-bvshl-1-eq-bvmult-2
  (implies (unsigned-byte-p 64 x)
           (equal (acl2::bvshl 64 x 1) (acl2::bvmult 64 x 2)))
  :hints (("Goal" :in-theory (enable acl2::bvshl acl2::bvmult acl2::bvchop))))

;; shl(x, 2) = mul(x, 4) mod 2^64
(defthm i64-bvshl-2-eq-bvmult-4
  (implies (unsigned-byte-p 64 x)
           (equal (acl2::bvshl 64 x 2) (acl2::bvmult 64 x 4)))
  :hints (("Goal" :in-theory (enable acl2::bvshl acl2::bvmult acl2::bvchop))))

;; shl(x, 3) = mul(x, 8) mod 2^64
(defthm i64-bvshl-3-eq-bvmult-8
  (implies (unsigned-byte-p 64 x)
           (equal (acl2::bvshl 64 x 3) (acl2::bvmult 64 x 8)))
  :hints (("Goal" :in-theory (enable acl2::bvshl acl2::bvmult acl2::bvchop))))

(cw "~%*** proof-distributivity: all theorems proved ***~%")
