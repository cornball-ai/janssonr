#!/bin/sh
# Build the r-cornball-janssonr binary .deb the Debian way, inside a
# clean container of the TARGET SUITE (rapt's pattern): debhelper
# computes ${shlibs:Depends}/${misc:Depends} (libc6, libjansson4),
# strips the .so, fixes permissions; the version takes the packaging
# revision from pkg/debian/changelog plus a ~suite suffix so artifacts
# from different suites never collide under one version. lintian gates
# the result (fails on errors). Build output is streamed, not hidden.
#
#     tools/build-deb.sh [suite] [output-dir]   # default: noble, ./dist/<suite>
set -eu

suite=${1:-noble}
pkgdir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
dist=${2:-"$pkgdir/dist/$suite"}
mkdir -p "$dist"

docker run --rm \
    -e SUITE="$suite" -e HOSTUID="$(id -u)" -e HOSTGID="$(id -g)" \
    -v "$pkgdir":/src:ro -v "$dist":/out \
    "rocker/r2u:$suite" /src/tools/build-deb-inner.sh
