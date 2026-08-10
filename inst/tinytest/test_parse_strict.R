# The strictness corpus: everything here must refuse with a classed
# janssonr_parse_error. Boundary fixtures are literal input bytes that
# assert themselves before parsing.

perr <- function(txt) {
    tryCatch(list(val = from_json(txt), err = NULL),
             janssonr_parse_error = function(e) list(val = NULL, err = e))
}
code_of <- function(txt) {
    e <- perr(txt)$err
    if (is.null(e)) NA_character_ else e$code
}

## ---- truncated / premature end ----
for (txt in c("{", "{\"a\":1", "[1,2", "\"abc", "", "  ", "tru", "[")) {
    expect_error(from_json(txt), class = "janssonr_parse_error", info = txt)
}
expect_equal(code_of("{\"a\":1"), "premature_end_of_input")

## ---- trailing content ----
for (txt in c("{} {}", "1 2", "true false", "[1] x",
              "{\"ok\":true,\"persisted\":true} trailing")) {
    expect_error(from_json(txt), class = "janssonr_parse_error", info = txt)
    expect_equal(code_of(txt), "end_of_input_expected", info = txt)
}

## ---- bad escapes, control chars, wrong literals ----
for (txt in c("\"\\x\"", "\"\\u12\"", "\"\\u12G4\"",
              "{'a':1}", "NaN", "Infinity", "-Infinity", "None",
              "undefined", "// x\n1", "/* x */ 1")) {
    expect_error(from_json(txt), class = "janssonr_parse_error", info = txt)
}
# literal control characters inside a string are refused
expect_error(from_json(rawToChar(as.raw(c(0x22, 0x0a, 0x22)))),
             class = "janssonr_parse_error")
expect_error(from_json(rawToChar(as.raw(c(0x22, 0x01, 0x22)))),
             class = "janssonr_parse_error")

## ---- malformed numbers ----
for (txt in c("01", "-01", "1.", ".5", "+1", "1e", "0x10", "1.2.3")) {
    expect_error(from_json(txt), class = "janssonr_parse_error", info = txt)
}

## ---- duplicate keys, at any depth ----
expect_equal(code_of("{\"a\":1,\"a\":2}"), "duplicate_key")
expect_equal(code_of("{\"a\":{\"b\":1,\"b\":2}}"), "duplicate_key")
# inside an array of objects: the hole a names-walk over a simplified
# data.frame cannot see
expect_equal(code_of("[{\"x\":1},{\"y\":1,\"y\":2}]"), "duplicate_key")

# escaped-equivalent key: \u0061 is "a"; assert the six escape bytes are
# really in the fixture before parsing (mutation-resistant)
dup_esc <- "{\"a\":1,\"\\u0061\":2}"
expect_true(grepl("\\u0061", dup_esc, fixed = TRUE))
expect_equal(code_of(dup_esc), "duplicate_key")

## ---- NUL escapes ----
nul_str <- "\"a\\u0000b\""
expect_true(grepl("\\u0000", nul_str, fixed = TRUE))
expect_equal(code_of(nul_str), "null_character")
nul_key <- "{\"a\\u0000b\":1}"
expect_true(grepl("\\u0000", nul_key, fixed = TRUE))
expect_error(from_json(nul_key), class = "janssonr_parse_error")
# a raw NUL byte inside raw input is seen (json_loadb, not json_loads)
expect_error(from_json(c(charToRaw("{}"), as.raw(0), charToRaw("{}"))),
             class = "janssonr_parse_error")

## ---- invalid UTF-8 and lone surrogates ----
expect_equal({
    e <- tryCatch(from_json(as.raw(c(0x22, 0xff, 0x22))),
                  error = function(e) e)
    e$code
}, "invalid_utf8")
# overlong / truncated sequences
expect_error(from_json(as.raw(c(0x22, 0xc0, 0xaf, 0x22))),
             class = "janssonr_parse_error")
expect_error(from_json(as.raw(c(0x22, 0xe2, 0x82, 0x22))),
             class = "janssonr_parse_error")
for (txt in c("\"\\uDEAD\"", "\"\\uD800\"", "\"\\uD800\\u0041\"")) {
    expect_error(from_json(txt), class = "janssonr_parse_error", info = txt)
}
# a UTF-8 BOM is not JSON
expect_error(from_json(c(as.raw(c(0xef, 0xbb, 0xbf)), charToRaw("{}"))),
             class = "janssonr_parse_error")

## ---- numeric limits (literal digit strings, never R arithmetic) ----
expect_equal(code_of("1e999"), "numeric_overflow")
expect_equal(code_of("-1e999"), "numeric_overflow")
# underflow is not an error: it parses as zero
expect_identical(from_json("1e-999"), 0)

# beyond long long: jansson refuses while lexing
expect_equal(code_of("9223372036854775808"), "numeric_overflow")
expect_equal(code_of("-9223372036854775809"), "numeric_overflow")

# in (2^53, LLONG_MAX]: parses as an exact integer janssonr refuses to
# round silently into a double
big1 <- "9007199254740993"
expect_identical(nchar(big1), 16L)
expect_equal(code_of(big1), "integer_precision")
expect_equal(code_of("-9007199254740993"), "integer_precision")
expect_equal(code_of("9223372036854775807"), "integer_precision")
# 2^53 itself is exact and accepted, as a double
expect_identical(from_json("9007199254740992"), 9007199254740992)

# the exactness guarantee is for INTEGER literals; a fraction or exponent
# opts into ordinary correctly rounded REAL conversion
expect_identical(from_json("9007199254740993.0"), 9007199254740992)
expect_identical(from_json("9007199254740993e0"), 9007199254740992)

## ---- integer_precision condition anatomy ----
e <- perr("{\"items\":[0,{\"id\":9007199254740993}]}")$err
expect_inherits(e, "janssonr_parse_error")
expect_inherits(e, "janssonr_error")
expect_equal(e$code, "integer_precision")
expect_identical(e$line, NA_integer_)
expect_identical(e$column, NA_integer_)
expect_identical(e$position, NA_integer_)
expect_identical(e$path, "/items/1/id")

## ---- RFC 6901 escaping in the path ----
e <- perr("{\"a/b\":{\"c~d\":9007199254740993}}")$err
expect_identical(e$path, "/a~1b/c~0d")

## ---- lexical-error condition anatomy ----
e <- perr("{\"a\":1,\"a\":2}")$err
expect_identical(class(e),
                 c("janssonr_parse_error", "janssonr_error", "error",
                   "condition"))
expect_true(is.integer(e$line) && e$line >= 1L)
expect_true(is.integer(e$column) && e$column >= 1L)
expect_true(is.integer(e$position) && e$position >= 1L)
expect_identical(e$path, NA_character_)
expect_true(nchar(conditionMessage(e)) > 0L)

## ---- depth: janssonr's own limit is authoritative at 1024 ----
deep_ok <- paste0(strrep("[", 1024L), strrep("]", 1024L))
expect_silent(from_json(deep_ok))
deep_bad <- paste0(strrep("[", 1025L), strrep("]", 1025L))
expect_equal(code_of(deep_bad), "depth_limit")
# far beyond, the jansson parser's own cap may fire first; either way it
# is a classed parse error
e <- perr(strrep("[", 3000L))$err
expect_inherits(e, "janssonr_parse_error")
expect_true(e$code %in% c("stack_overflow", "depth_limit",
                          "premature_end_of_input"))

## ---- R-level input validation ----
expect_error(from_json(1), class = "janssonr_input_error")
expect_error(from_json(c("a", "b")), class = "janssonr_input_error")
expect_error(from_json(NA_character_), class = "janssonr_input_error")
expect_error(from_json(NULL), class = "janssonr_input_error")
