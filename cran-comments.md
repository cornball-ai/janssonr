# cran-comments for janssonr 0.1.2

## Resubmission

This is a resubmission, following CRAN's review of 0.1.1. Both requests
are addressed; no code changed.

- The single quotes around NA and NaN in the Description are removed.
  The only quoted term left is 'Jansson', the name of the C library.

- Authors@R now names every author and copyright holder of the bundled
  Jansson sources (src/jansson/), found by reading every file header in
  that directory. Previously only Jansson's author was listed, as cph.
  Added:
  - Petri Lehtinen: ctb as well as cph (author of Jansson; holds
    copyright on the library and on most of its files).
  - Basile Starynkevitch, ctb and cph: memory.c.
  - Graeme Smecher, ctb and cph: pack_unpack.c.
  - Sean Bright, ctb and cph: version.c.
  - David M. Gay, ctb, and Lucent Technologies, cph: dtoa.c, which
    Jansson bundles under Lucent's own permissive notice. That notice
    is preserved in the file header and in src/jansson/LICENSE.
  - Bob Jenkins, ctb: lookup3.h, which is public domain, so there is
    no copyright holder to list.

  A new Copyright field points at inst/COPYRIGHTS, which lists these
  per file together with each license statement.

The 0.1.1 submission had cleared the incoming pretest findings on 0.1.0
(a `sprintf` reference and two `-Wformat` warnings in the bundled
sources, and a possible bashism in configure); those changes are
carried over unchanged and described in NEWS.md.

## Test environments

The package sources are identical to 0.1.1 apart from DESCRIPTION,
NEWS.md and the new inst/COPYRIGHTS. Re-checked for this submission:

- Debian, R-devel, newest gcc, bundled Jansson (CRAN's Debian flavor),
  via `tools/cran-check.sh`
- Ubuntu 24.04, R 4.6.1, `R CMD check --as-cran`: system Jansson 2.14
  and bundled 2.15.1

Checked on 0.1.1 (unchanged code): Rocker R 4.4.3 (the declared R
floor); GitHub Actions ubuntu-latest and macos-latest with and without
a system Jansson, plus a leg linking Jansson 2.11 from source; Windows
R 4.6.0 and R-devel with Rtools45; win-builder release and devel.

## R CMD check results

0 errors | 0 warnings | 1 note

- New submission.

## System requirements

Links the system Jansson C library (>= 2.11) when one is found. When
none is - CRAN's macOS builders and Windows ship none - the bundled
Jansson 2.15.1 sources compile into the package. Jansson is
MIT-licensed; its author and every other copyright holder of the
bundled files are listed in Authors@R, the bundled LICENSE is retained
under src/jansson/, inst/COPYRIGHTS gives the per-file statements, and
every local modification is documented in src/jansson/PATCHES.md.
