# Certify all books in this directory with cert.pl.
#
#   ACL2  - path to the ACL2 image (default: $ACL2 env var, or /opt/acl2/bin/acl2)
#   CERT  - path to books/build/cert.pl (default: /home/acl2/books/build/cert.pl)
#   JOBS  - parallelism for cert.pl -j (default: 4)
#
# Usage:
#   make             # certify top + every proof + every test
#   make top         # certify just the library (execution + validation)
#   make proofs      # certify every proofs/*.lisp book
#   make tests       # certify every tests/*.lisp book
#   make clean       # remove .cert and related build artifacts

ACL2 ?= /opt/acl2/bin/acl2
CERT ?= /home/acl2/books/build/cert.pl
JOBS ?= 4

PROOF_BOOKS := $(patsubst %.lisp,%,$(wildcard proofs/proof-*.lisp))
TEST_BOOKS  := $(patsubst %.lisp,%,$(wildcard tests/test-*.lisp))

.PHONY: all top proofs tests clean

# Single cert.pl invocation so its internal dependency tracker avoids races
# on shared prerequisites like execution.cert.
all:
	$(CERT) --acl2 $(ACL2) -j $(JOBS) top $(PROOF_BOOKS) $(TEST_BOOKS)

top:
	$(CERT) --acl2 $(ACL2) -j $(JOBS) top

proofs:
	$(CERT) --acl2 $(ACL2) -j $(JOBS) $(PROOF_BOOKS)

tests:
	$(CERT) --acl2 $(ACL2) -j $(JOBS) $(TEST_BOOKS)

clean:
	find . \( -name '*.cert' -o -name '*.cert.out' -o -name '*.port' \
	       -o -name '*.lx64fsl' -o -name '*.fasl' -o -name '*.pcert0' \
	       -o -name '*.pcert1' -o -name 'Makefile-tmp' \
	       -o -name '*.cert.time' -o -name '*.out' \
	       -o -name '*.lx86cl64fsl' -o -name '*.dx64fsl' \) -delete
