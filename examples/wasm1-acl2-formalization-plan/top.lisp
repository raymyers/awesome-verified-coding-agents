; Top-level convenience book: bundles the core WASM 1.0 operational
; semantics and the type validator so downstream users can
; (include-book "top") to get the library. Individual proof and test
; books are certified separately (see the Makefile); they are not
; include-book'd here because some share theorem names across files.

(in-package "WASM")
(include-book "execution")
(include-book "validation")
