#!/bin/bash
# Reproduce CRAN's r-devel-linux-x86_64-debian-gcc incoming check, which
# is stricter than anything we build with locally in two ways that have
# already cost us a submission:
#
#   1. it compiles the BUNDLED Jansson (CRAN's machines have no system
#      jansson), so a system-linked check never sees that code at all;
#   2. its gcc is newer than Ubuntu's, and each release finds warnings
#      the last one did not.
#
# Runs inside a Debian R-devel container. Locally:
#
#   docker run --rm -v "$PWD":/src:ro rocker/r-devel:latest bash /src/tools/cran-check.sh
#
# Mount read-only: the container runs as root, and anything it writes
# into a read-write bind mount lands in your tree owned by root.
#
# Unlike `R CMD check` on its own, this FAILS on WARNINGs - a check that
# prints the reason CRAN will reject you and then exits 0 is not a gate.
set -eu
SRC=${SRC:-/src}
export DEBIAN_FRONTEND=noninteractive

apt-get update -qq > /dev/null 2>&1
# newest gcc we can get: CRAN's Debian leg runs ahead of every distro we
# build on, so pin to the newest rather than whatever is default
CC_USE=gcc
for c in gcc-16 gcc-15 gcc-14; do
    if apt-get install -y -qq "$c" > /dev/null 2>&1; then CC_USE=$c; break; fi
done
apt-get install -y -qq binutils > /dev/null 2>&1 || true

mkdir -p ~/.R
printf 'CC=%s\n' "$CC_USE" > ~/.R/Makevars

RBIN=R
command -v RD > /dev/null 2>&1 && RBIN=RD

echo "=== compiler: $($CC_USE --version | head -1)"
echo "=== R:        $($RBIN --version | head -1)"

$RBIN -e 'if (length(find.package("tinytest", quiet = TRUE)) == 0) install.packages("tinytest", repos = "https://cloud.r-project.org")' > /dev/null 2>&1

work=$(mktemp -d)
cp -r "$SRC/." "$work/pkg/" 2>/dev/null || { mkdir -p "$work/pkg" && cp -r "$SRC/." "$work/pkg/"; }
cd "$work"
# host build artifacts must never leak into the container build
rm -rf pkg/.git pkg/docs pkg/dist pkg/dist-ci pkg/repo-ci \
       pkg/src/*.o pkg/src/*.so pkg/src/jansson/*.o pkg/src/Makevars

$RBIN CMD build --no-build-vignettes --no-manual pkg > build.log 2>&1 || {
    echo "R CMD build failed:"; cat build.log; exit 1; }
tarball=$(ls janssonr_*.tar.gz)
echo "=== built $tarball"

export JANSSONR_VENDOR=1 _R_CHECK_FORCE_SUGGESTS_=false
set +e
$RBIN CMD check --as-cran --no-manual "$tarball" > check.log 2>&1
set -e

log=janssonr.Rcheck/00check.log
if [ ! -f "$log" ]; then
    echo "no 00check.log produced - the check did not run" >&2
    tail -40 check.log >&2
    exit 1
fi

# prove the bundled copy is what got compiled, so a silent fall-through
# to a system library cannot make this gate pass vacuously
so=janssonr.Rcheck/janssonr/libs/janssonr.so
if [ -f "$so" ]; then
    if ldd "$so" | grep -qi libjansson; then
        echo "FAIL: linked a system libjansson; this gate must test the bundled copy" >&2
        exit 1
    fi
    echo "=== confirmed: no libjansson linkage (bundled sources compiled)"
    # direct tripwire for the entry points CRAN forbids, independent of
    # whether R's own heuristics happen to name them
    if nm -u "$so" | grep -E "__sprintf_chk|[^n]sprintf|^ *U sprintf"; then
        echo "FAIL: the shared object references sprintf" >&2
        exit 1
    fi
    echo "=== confirmed: no sprintf symbols"
fi

echo "=== install-time compiler warnings ==="
grep -iE "warning:" janssonr.Rcheck/00install.out 2>/dev/null | head -30 || echo "(none)"

# show the NOTEs too: a gate whose output you have to guess at is a
# gate you will misread
echo "=== NOTEs ==="
grep -A4 -E "\.\.\. .*NOTE" "$log" || echo "(none)"

echo "=== $(grep -E '^Status' "$log")"
if grep -qE "^Status:.*(ERROR|WARNING)" "$log"; then
    echo "FAIL: R CMD check reported ERROR/WARNING" >&2
    grep -B2 -A8 -E "\.\.\. (ERROR|WARNING)" "$log" >&2
    exit 1
fi
echo "PASS: no ERRORs or WARNINGs"
