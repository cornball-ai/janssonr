# janssonr 0.0.1

- Initial version: `from_json()` and `to_json()`, an R-safe profile of
  RFC 8259 backed by the system Jansson library (>= 2.11).
- Parser rejects malformed input, trailing content, duplicate keys at any
  depth, invalid UTF-8, NUL escapes, and numbers that cannot round-trip
  into R doubles; errors are classed conditions with source coordinates.
- Encoder writes compact UTF-8 JSON in insertion order, spells integral
  doubles as integers, and refuses values with no faithful JSON
  representation.
