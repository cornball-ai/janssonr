# cran-comments for janssonr 0.1.3

## Update fixing an issue reported by CRAN

0.1.2 was published on 2026-09-12. This update fixes the gcc-UBSAN
finding reported on it under "Additional issues"
(https://www.stats.ox.ac.uk/pub/bdr/memtests/gcc-UBSAN/janssonr/):

    jansson/hashtable.c:217:14: runtime error: index 1 out of bounds for type 'char [1]'

The bundled Jansson's `struct hashtable_pair` ended in the pre-C99
one-element array `char key[1]`, with each pair allocated at
`offsetof(pair, key) + key_len + 1` bytes and the key written past
element 0. The member is now a C99 flexible array member (`char key[]`).
Allocation sizes and layout are unchanged; only the declared type is,
so `-fsanitize=bounds-strict` has nothing to report.

The same pattern in the bundled dtoa.c (`struct Bigint`, `ULong x[1]`)
is fixed the same way, with `Balloc()`'s size arithmetic adjusted for
the new `sizeof`. CRAN's run had not reached that code (dtoa's 64-bit
fast path handles nearly every double), but shortest-form encoding of
some whole-number doubles above 2^53 does reach it and trips the same
check; the test suite now covers such values.

Both changes are confined to the bundled sources under src/jansson/,
which compile only when no system Jansson >= 2.11 is found, and are
documented in src/jansson/PATCHES.md.

## Test environments

- CRAN's gcc-UBSAN configuration reproduced (bundled Jansson compiled
  with `-fsanitize=undefined,bounds-strict`, then `R CMD check`), via
  the new `tools/ubsan-check.sh`: the 0.1.2 sources reproduce the
  report, the 0.1.3 sources produce no sanitizer output from the
  examples or the tests. Ubuntu 24.04 gcc 13 / R 4.6.1, and Debian
  R-devel with the newest gcc in the rocker/r-devel container.
- Debian, R-devel, newest gcc, bundled Jansson (CRAN's Debian flavor),
  `R CMD check --as-cran` via `tools/cran-check.sh`
- Ubuntu 24.04, R 4.6.1, `R CMD check --as-cran`: system Jansson 2.14
  and bundled 2.15.1
- valgrind over the full test suite, bundled Jansson: 0 errors, no
  bytes lost

Checked on 0.1.1 and 0.1.2 (identical apart from the changes above):
Rocker R 4.4.3 (the declared R floor); GitHub Actions ubuntu-latest and
macos-latest with and without a system Jansson, plus a leg linking
Jansson 2.11 from source; Windows R 4.6.0 and R-devel with Rtools45;
win-builder release and devel.

## R CMD check results

0 errors | 0 warnings | 1 note

- Days since last update: the update comes shortly after 0.1.2 because
  it answers CRAN's gcc-UBSAN report on that version.

## System requirements

Links the system Jansson C library (>= 2.11) when one is found. When
none is - CRAN's macOS builders and Windows ship none - the bundled
Jansson 2.15.1 sources compile into the package. Jansson is
MIT-licensed; its author and every other copyright holder of the
bundled files are listed in Authors@R, the bundled LICENSE is retained
under src/jansson/, inst/COPYRIGHTS gives the per-file statements, and
every local modification is documented in src/jansson/PATCHES.md.
