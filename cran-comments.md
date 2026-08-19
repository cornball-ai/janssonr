# cran-comments for janssonr 0.1.0

## Test environments

- Ubuntu 24.04, R 4.6.1: system jansson 2.14 and the bundled 2.15.1
  (both link modes), full suite under valgrind
- Rocker container, R 4.4.3 (the declared R floor)
- GitHub Actions: ubuntu-latest and macos-latest, each with and without
  a system jansson; a leg linking jansson 2.11 built from source (the
  declared jansson floor)
- Windows (local): R 4.6.0 and R-devel with Rtools45

## R CMD check results

0 errors | 0 warnings | 1 note

- New submission.

## System requirements

Links the system Jansson C library (>= 2.11) when one is found. When
none is — CRAN's macOS builders and Windows ship no jansson — the
bundled Jansson 2.15.1 sources compile into the package. Jansson is
MIT-licensed; its author is listed as cph in Authors@R and the bundled
LICENSE is retained under src/jansson/.
