# cran-comments for janssonr 0.1.1

## Resubmission

This is a resubmission. The incoming pretest for 0.1.0 reported the
following, all of them in the bundled Jansson C sources:

- `Found '__sprintf_chk', possibly from 'sprintf'` in `strconv.o`
  (Debian). That translation unit no longer calls the printf family at
  all: the decimal separator comes from `localeconv()` instead of
  printing 1.0 into a three-byte buffer, and the exponent is written
  digit by digit. Worth noting for anyone hitting the same check:
  substituting `snprintf` does *not* clear it, because gcc folds an
  `snprintf` whose output it can prove fits back into `sprintf`. Encoded
  output is unchanged, verified byte-for-byte over 1039 doubles, 1009 of
  them in exponent form.
- `-Wformat-truncation` at `load.c:112` and `load.c:126` (Debian,
  gcc 16). Both `snprintf` calls now bound their conversions with
  explicit precisions, so the trailing literal is provably never
  truncated. No message Jansson can produce is shortened.
- `-Wformat` on `%p` at `value.c:50` (Windows and Debian). The argument
  is now cast to `const void *`.
- `Possibly misspelled words in DESCRIPTION: NUL`. Reworded.

We also fixed a possible bashism in `configure` (`command -v`) that the
pretest did not report but our own check under gcc 16 did.

These sources compile only when no system Jansson library is present,
which is true of CRAN's machines and was not true of our test machines;
that is why the warnings did not appear before submission. That
configuration is now checked explicitly, under the newest gcc, and the
check fails on warnings rather than printing them.

## Test environments

- Debian, R-devel, gcc 16.2.0, bundled Jansson (reproduces the flavor
  that rejected 0.1.0), via `tools/cran-check.sh`
- Ubuntu 24.04, R 4.6.1: system Jansson 2.14 and bundled 2.15.1, full
  suite under valgrind
- Rocker container, R 4.4.3 (the declared R floor), bundled
- GitHub Actions: ubuntu-latest and macos-latest, each with and without
  a system Jansson; a leg linking Jansson 2.11 from source (the declared
  Jansson floor)
- Windows: R 4.6.0 and R-devel with Rtools45

## R CMD check results

0 errors | 0 warnings | 1 note

- New submission.

## System requirements

Links the system Jansson C library (>= 2.11) when one is found. When
none is - CRAN's macOS builders and Windows ship none - the bundled
Jansson 2.15.1 sources compile into the package. Jansson is
MIT-licensed; its author is listed as cph in Authors@R, the bundled
LICENSE is retained under src/jansson/, and every local modification is
documented in src/jansson/PATCHES.md.
