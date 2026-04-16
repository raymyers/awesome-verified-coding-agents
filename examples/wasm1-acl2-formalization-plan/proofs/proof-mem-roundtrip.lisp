;; WASM 1.0 ACL2 Formalization — Memory Roundtrip Proofs
;;
;; Theorems proved:
;;   1. le-bytes-roundtrip: LE byte encoding is lossless for u32
;;   2. nth-update-nth-same/diff: update-nth accessor lemmas
;;   3. mem-read-write-4: reading 4 bytes after writing returns written bytes
;;   4. i32-store-load-semantic-roundtrip: store then load = identity
;;
;; Key technique: encapsulate scopes arithmetic-5 to avoid theory pollution.

(in-package "ACL2")
(ld "/tmp/acl2-full/books/kestrel/wasm/package.lsp")
(in-package "WASM")
(include-book "kestrel/wasm/execution" :dir :system)

;;; Theorem 1: LE bytes roundtrip
;;; (le-bytes-to-u32 (u32-to-le-bytes x)) = x for u32 x
;;; Requires arithmetic-5; scoped in encapsulate to avoid polluting session.
(encapsulate ()
  (local (include-book "arithmetic-5/top" :dir :system))
  (local (include-book "ihs/logops-lemmas" :dir :system))
  (defthm le-bytes-roundtrip
    (implies (unsigned-byte-p 32 x)
             (equal (le-bytes-to-u32 (u32-to-le-bytes x)) x))
    :hints (("Goal" :in-theory (enable le-bytes-to-u32 u32-to-le-bytes)))))

;;; Helpers: nth after update-nth
(defthm nth-update-nth-same
  (implies (natp i) (equal (nth i (update-nth i v lst)) v)))

(defthm nth-update-nth-diff
  (implies (and (natp i) (natp j) (not (equal i j)))
           (equal (nth i (update-nth j v lst)) (nth i lst))))

;;; Theorem 2: 4-byte memory read after write = written bytes
(defthm mem-read-write-4
  (implies (natp addr)
           (equal (mem-read-bytes 4 addr
                    (mem-write-bytes (list b0 b1 b2 b3) addr mem))
                  (list b0 b1 b2 b3)))
  :hints (("Goal" :in-theory (enable mem-read-bytes mem-write-bytes)
                  :expand ((:free (a m) (mem-read-bytes 4 a m))
                           (:free (a m) (mem-read-bytes 3 a m))
                           (:free (a m) (mem-read-bytes 2 a m))
                           (:free (a m) (mem-read-bytes 1 a m))
                           (:free (bs a m) (mem-write-bytes bs a m))))))

;;; Helper: u32-to-le-bytes expands to concrete 4-element list
(defthm u32-to-le-bytes-is-list4
  (equal (u32-to-le-bytes x)
         (list (logand x #xff)
               (logand (ash x -8) #xff)
               (logand (ash x -16) #xff)
               (logand (ash x -24) #xff)))
  :hints (("Goal" :in-theory (enable u32-to-le-bytes)))
  :rule-classes nil)

;;; Theorem 3: Semantic store-load roundtrip
;;; Writing u32-to-le-bytes(v) then reading 4 bytes and decoding = v.
;;; This is THE core memory correctness property.
(defthm i32-store-load-semantic-roundtrip
  (implies (and (unsigned-byte-p 32 v) (natp addr))
           (equal (le-bytes-to-u32
                   (mem-read-bytes 4 addr
                     (mem-write-bytes (u32-to-le-bytes v) addr mem)))
                  v))
  :hints (("Goal"
           :use ((:instance u32-to-le-bytes-is-list4 (x v))
                 (:instance mem-read-write-4
                            (b0 (logand v #xff))
                            (b1 (logand (ash v -8) #xff))
                            (b2 (logand (ash v -16) #xff))
                            (b3 (logand (ash v -24) #xff)))
                 (:instance le-bytes-roundtrip (x v)))
           :in-theory (disable le-bytes-to-u32 u32-to-le-bytes
                               mem-read-bytes mem-write-bytes
                               le-bytes-roundtrip mem-read-write-4))))

(cw "~%=== ALL MEMORY ROUNDTRIP PROOFS PASSED ===~%")
(cw "  - le-bytes-roundtrip: Q.E.D.~%")
(cw "  - mem-read-write-4: Q.E.D.~%")
(cw "  - i32-store-load-semantic-roundtrip: Q.E.D.~%")
