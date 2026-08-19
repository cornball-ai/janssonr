# janssonr 0.1.0

First CRAN release.

- configure falls back to compiling the bundled Jansson 2.15.1 when no
  usable system libjansson (>= 2.11) is found; CRAN's macOS builders
  ship none. The system library is still preferred when present, and
  `JANSSONR_VENDOR=1` (via `--configure-vars`) forces the bundled copy.
  A system jansson older than 2.11 now selects the bundled copy instead
  of failing the install; explicit `INCLUDE_DIR`/`LIB_DIR` that do not
  yield a usable jansson remain a hard error.
- The hand-written private configs for the bundled sources moved out of
  `src/jansson/` into `src/config-win/` and the new `src/config-unix/`
  (a config next to the sources would shadow the `-I` selection via
  `jansson_private.h`'s quoted include).
- The apt repository under `docs/` no longer reaches the source tarball
  (`.Rbuildignore`).

# janssonr 0.0.1.3

- Stable error taxonomy: integer-form overflow beyond long long
  (`12345678901234567890`) now reports `"integer_precision"` like the
  2^53 refusal, instead of leaking jansson's `"numeric_overflow"`;
  that code is reserved for real-form overflow (`1e999`). Classified
  from the numeric token at the error position in the input, never
  from jansson's message text. Lexical integer overflow carries source
  coordinates and an NA `path`; the post-parse 2^53 refusal carries NA
  coordinates and an RFC 6901 pointer.

# janssonr 0.0.1.2

- Windows support: Rtools bundles no jansson, so `Makevars.win` compiles
  Jansson 2.15.1 sources vendored under `src/jansson/` (MIT, Petri
  Lehtinen; cph added). Unix builds still link the system library.
  `OS_type: unix` dropped.

# janssonr 0.0.1.1

- Wording: integer literals beyond 2^53 are refused for being outside
  the safe-integer range (within which a double represents every
  integer exactly), not as individually unrepresentable; the error
  message and metadata now say so.
- `tools/valgrind.sh` shows the installation log when the temp install
  fails instead of discarding it.

# janssonr 0.0.1

- Initial version: `from_json()` and `to_json()`, an R-safe profile of
  RFC 8259 backed by the system Jansson library (>= 2.11); needs
  R >= 4.4 (verified in a container; 4.4 predates `ANY_ATTRIB`, covered
  by a version shim).
- The integer exactness guarantee is scoped to integer literals: number
  literals with a fraction or exponent use ordinary correctly rounded
  double conversion (documented and pinned).
- `-0` encodes as `-0.0` so every finite double, signed zero included,
  round-trips bit-identically.
- Parser rejects malformed input, trailing content, duplicate keys at any
  depth, invalid UTF-8, NUL escapes, reals overflowing double, and
  integer literals whose magnitude exceeds 2^53 (the safe-integer range
  of a double); errors are classed conditions with source coordinates.
- Encoder writes compact UTF-8 JSON in insertion order, spells integral
  doubles as integers, and refuses values with no faithful JSON
  representation.
