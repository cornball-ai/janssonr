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
