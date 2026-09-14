#!/bin/bash
# Reproduce CRAN's gcc-UBSAN check (Prof Ripley's memtests,
# https://www.stats.ox.ac.uk/pub/bdr/memtests/README.txt): the package
# compiled with
#
#   gcc -fsanitize=undefined,bounds-strict -fno-omit-frame-pointer
#
# then R CMD check, where every "runtime error" line the sanitizer
# prints into the example and test output is a finding. 0.1.2 was
# reported for a pre-C99 one-element-array struct hack in the bundled
# Jansson that only bounds-strict flags, so this gate compiles the
# BUNDLED sources (JANSSONR_VENDOR=1), the configuration CRAN checks.
#
# UBSAN only: a sanitized shared object loads into an ordinary R, so no
# sanitizer build of R is needed. CRAN's ASAN leg needs one and is not
# reproduced here.
#
# Runs locally (gcc with libubsan, as any Debian/Ubuntu gcc package
# has) or in the Debian R-devel container the way tools/cran-check.sh
# does, where it installs the newest gcc available:
#
#   tools/ubsan-check.sh
#   docker run --rm -v "$PWD":/src:ro rocker/r-devel:latest bash /src/tools/ubsan-check.sh
#
# Mount read-only: the container runs as root, and anything it writes
# into a read-write bind mount lands in your tree owned by root.
#
# FAILS on any sanitizer report, and first proves the run is worth
# trusting: the shared object must link libubsan (the sanitizer was
# really compiled in), must not link a system libjansson, and the
# tests must have run.
set -eu
SRC=${SRC:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}
export DEBIAN_FRONTEND=noninteractive

CC_USE=gcc
if [ "$(id -u)" = 0 ] && command -v apt-get > /dev/null 2>&1; then
    # container: newest gcc we can get, as cran-check.sh does; each
    # gcc release instruments a little more than the last
    apt-get update -qq > /dev/null 2>&1
    for c in gcc-16 gcc-15 gcc-14; do
        if apt-get install -y -qq "$c" > /dev/null 2>&1; then CC_USE=$c; break; fi
    done
fi

RBIN=R
command -v RD > /dev/null 2>&1 && RBIN=RD

echo "=== compiler: $($CC_USE --version | head -1)"
echo "=== R:        $($RBIN --version | head -1)"

$RBIN -e 'if (length(find.package("tinytest", quiet = TRUE)) == 0) install.packages("tinytest", repos = "https://cloud.r-project.org")' > /dev/null 2>&1

work=$(mktemp -d)
cp -r "$SRC/." "$work/pkg/" 2>/dev/null || { mkdir -p "$work/pkg" && cp -r "$SRC/." "$work/pkg/"; }
cd "$work"
# host build artifacts must never leak into the sanitized build
rm -rf pkg/.git pkg/docs pkg/dist pkg/dist-ci pkg/repo-ci \
       pkg/src/*.o pkg/src/*.so pkg/src/jansson/*.o pkg/src/Makevars

# CRAN's config.site puts the sanitizer flags in CC itself, so they
# reach the link step too (SHLIB_LD is $(CC)); R_MAKEVARS_USER keeps
# this out of ~/.R/Makevars
cat > Makevars.ubsan <<EOF
CC = $CC_USE -fsanitize=undefined,bounds-strict -fno-omit-frame-pointer
CFLAGS = -g -O2 -Wall -pedantic -fno-omit-frame-pointer
EOF
export R_MAKEVARS_USER="$work/Makevars.ubsan"

$RBIN CMD build --no-build-vignettes --no-manual pkg > build.log 2>&1 || {
    echo "R CMD build failed:"; cat build.log; exit 1; }
tarball=$(ls janssonr_*.tar.gz)
echo "=== built $tarball"

# print_stacktrace: CRAN's reports carry the trace, and it is what
# tells a hashtable.c line apart from the R call that reached it
export JANSSONR_VENDOR=1 _R_CHECK_FORCE_SUGGESTS_=false
export UBSAN_OPTIONS=print_stacktrace=1
set +e
$RBIN CMD check --no-manual "$tarball" > check.log 2>&1
set -e

log=janssonr.Rcheck/00check.log
if [ ! -f "$log" ]; then
    echo "no 00check.log produced - the check did not run" >&2
    tail -40 check.log >&2
    exit 1
fi

so=janssonr.Rcheck/janssonr/libs/janssonr.so
if [ ! -f "$so" ]; then
    echo "FAIL: no shared object was built" >&2
    grep -A20 "can be installed" "$log" >&2 || true
    exit 1
fi
if ! ldd "$so" | grep -qi libubsan; then
    echo "FAIL: the shared object does not link libubsan; the sanitizer was not compiled in" >&2
    exit 1
fi
echo "=== confirmed: libubsan linked (sanitizer compiled in)"
if ldd "$so" | grep -qi libjansson; then
    echo "FAIL: linked a system libjansson; this gate must test the bundled copy" >&2
    exit 1
fi
echo "=== confirmed: no libjansson linkage (bundled sources compiled)"

if ! grep -q "Running .tinytest.R" "$log"; then
    echo "FAIL: the test suite did not run" >&2
    grep -B2 -A8 "checking tests" "$log" >&2 || true
    exit 1
fi
echo "=== confirmed: tests ran"

echo "=== $(grep -E '^Status' "$log")"
if grep -qE "^Status:.*ERROR" "$log"; then
    echo "FAIL: R CMD check reported an ERROR" >&2
    grep -B2 -A12 -E "\.\.\. ERROR" "$log" >&2
    exit 1
fi

# the findings themselves: every sanitizer line in anything the check
# wrote (examples, tests, install log)
if grep -rn "runtime error" janssonr.Rcheck > ubsan.txt; then
    echo "FAIL: sanitizer reports:" >&2
    cat ubsan.txt >&2
    exit 1
fi
echo "PASS: no sanitizer reports from the examples or the tests"
