#!/bin/sh
# Build the r-cornball-janssonr binary .deb so target machines need the
# Jansson RUNTIME (libjansson4), not a compiler and libjansson-dev.
# Mirrors the cornball deb pattern: no root required, staged
# site-library, dpkg-deb --root-owner-group; the name fits raptd's
# ^r-[a-z]+-[a-z0-9.]+$ allowlist.
#
# The compiled .so is an amd64 artifact built against this machine's R
# and libjansson, hence Architecture from dpkg and an r-base-core floor
# matching the BUILD R minor (the source package's R floor stays 4.4).
#
#     tools/build-deb.sh [output-dir]     # default: ./dist
set -eu

pkgdir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
dist=${1:-"$pkgdir/dist"}
mkdir -p "$dist"

ver=$(awk '/^Version:/ { print $2; exit }' "$pkgdir/DESCRIPTION")
arch=$(dpkg --print-architecture)
rminor=$(R --version | awk 'NR==1 { split($3, v, "."); print v[1] "." v[2] ".0" }')
deb=r-cornball-janssonr

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
lib="$stage/usr/lib/R/site-library"
mkdir -p "$lib" "$stage/DEBIAN"

(cd "$stage" && R CMD build --no-build-vignettes --no-manual "$pkgdir" \
    > /dev/null 2>&1)
R CMD INSTALL -l "$lib" "$stage/janssonr_${ver}.tar.gz" > install.log 2>&1 || {
    echo "install failed:" >&2
    cat install.log >&2
    exit 1
}
rm -f "$stage/janssonr_${ver}.tar.gz" install.log

# the staged tree must not depend on dev headers: assert the .so links
# the runtime soname
ldd "$lib/janssonr/libs/janssonr.so" | grep -q "libjansson\.so\.4" || {
    echo "janssonr.so does not link libjansson.so.4" >&2
    exit 1
}

{
    printf 'Package: %s\n' "$deb"
    printf 'Version: %s\n' "$ver"
    printf 'Architecture: %s\n' "$arch"
    printf 'Section: gnu-r\n'
    printf 'Priority: optional\n'
    printf 'Maintainer: cornball.ai <troy@cornball.ai>\n'
    printf 'Depends: r-base-core (>= %s), libjansson4 (>= 2.11)\n' "$rminor"
    printf 'Homepage: https://github.com/cornball-ai/janssonr\n'
    printf 'Description: strict JSON encode/decode for R via system libjansson\n'
    printf ' An R-safe profile of RFC 8259: duplicate-key rejection at any\n'
    printf ' depth, NUL and invalid-UTF-8 rejection, exact double round-trip,\n'
    printf ' classed error conditions. Binary build; needs only the Jansson\n'
    printf ' runtime library, not libjansson-dev.\n'
} > "$stage/DEBIAN/control"

dpkg-deb --build --root-owner-group "$stage" \
    "$dist/${deb}_${ver}_${arch}.deb" > /dev/null
echo "built $dist/${deb}_${ver}_${arch}.deb"
