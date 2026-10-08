# Fixed Make/GitHub Actions command interface. Bootstrap compilers build ICK;
# every maintained C source below is consumed by the pinned ICK frontend.
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
BUILD_ROOT ?= $(ROOT)/_/qualification
ICK_SOURCE ?= $(ROOT)/_/ick
REFERENCE_SOURCE ?= $(ROOT)/_/reference
AICI_SOURCE ?= $(ROOT)/_/ai-ci
ICK ?= $(BUILD_ROOT)/producer/stage/bin/gcc
BINS := $(BUILD_ROOT)/binaries
BUILD_JOBS ?= 2
HELPERS := google-drive-download-state google-oauth-loopback zip-central-directory
VALUE_TESTS := transfer-values callback-spans
FLAGS := -fno-link-libatomic -std=c99 -O2 -Wall -Wextra -Wpedantic -Werror
APT_INDEX_OPTIONS := -o Dir::Etc::sourcelist=$(ROOT)/qualification/buster-sources.list -o Dir::Etc::sourceparts=- -o Acquire::Check-Valid-Until=false

.PHONY: dependencies compiler helpers tests guard receipt
dependencies:
	apt-get $(APT_INDEX_OPTIONS) update
	apt-get $(APT_INDEX_OPTIONS) install -y --no-install-recommends bison flex libgmp-dev libmpfr-dev libmpc-dev python3

compiler:
	test "$$(git -C "$(ICK_SOURCE)" rev-parse HEAD)" = 143e29580c2644ea0f345fe609fa5673d036865d
	$(MAKE) -f "$(ICK_SOURCE)/qualification/native-polar/Makefile" build BUILD_ROOT="$(BUILD_ROOT)/producer" BUILD_JOBS=$(BUILD_JOBS)

helpers: $(addprefix $(BINS)/,$(HELPERS)) $(addprefix $(BINS)/,$(VALUE_TESTS))

$(BINS)/%: $(ROOT)/commands/%.c
	mkdir -p "$(@D)"
	$(ICK) $(FLAGS) "$<" -o "$@"

$(BINS)/%: $(ROOT)/qualification/tests/%.c
	mkdir -p "$(@D)"
	$(ICK) $(FLAGS) "$<" -o "$@"

$(BINS)/transfer-values: $(ROOT)/qualification/tests/transfer-values.c $(ROOT)/commands/google-drive-download-state.c
$(BINS)/callback-spans: $(ROOT)/qualification/tests/callback-spans.c $(ROOT)/commands/google-oauth-loopback.c

$(BINS)/source-guard: $(AICI_SOURCE)/c-source/assignments.c
	mkdir -p "$(@D)"
	$(ICK) $(filter-out -std=c99,$(FLAGS)) -std=c17 "$<" -o "$@"

guard: $(BINS)/source-guard
	"$(BINS)/source-guard" check $(addprefix $(ROOT)/commands/,$(addsuffix .c,$(HELPERS))) $(addprefix $(ROOT)/qualification/tests/,$(addsuffix .c,$(VALUE_TESTS)))

tests: helpers
	"$(BINS)/transfer-values"
	"$(BINS)/callback-spans"
	ICK="$(ICK)" ZIP_CENTRAL_DIRECTORY_SOURCE="$(ROOT)/commands/zip-central-directory.c" sh "$(ROOT)/tests/zip-central-directory.sh"
	ICK="$(ICK)" ZIP_CENTRAL_DIRECTORY_SOURCE="$(REFERENCE_SOURCE)/commands/zip-central-directory.c" sh "$(ROOT)/tests/zip-central-directory.sh"

receipt: helpers
	git -C "$(ROOT)" rev-parse HEAD > "$(BINS)/consumer-commit.txt"
	git -C "$(ICK_SOURCE)" rev-parse HEAD > "$(BINS)/compiler-commit.txt"
	$(ICK) --version > "$(BINS)/compiler-version.txt"
	dpkg-query -W libc6 libc6-dev > "$(BINS)/scalar-runtime-packages.tsv"
	cd "$(ROOT)" && sha256sum $(addprefix commands/,$(addsuffix .c,$(HELPERS))) > "$(BINS)/source.sha256"
	cd "$(BINS)" && sha256sum $(HELPERS) $(VALUE_TESTS) > "$(BINS)/binaries.sha256"
	sha256sum "$(BUILD_ROOT)/producer/stage/lib/gcc/x86_64-pc-linux-gnu/17.0.0/libgcc.a" "$(BUILD_ROOT)/producer/stage/lib64/libatomic.a" > "$(BINS)/compiler-runtime.sha256"
