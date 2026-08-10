# Byte-exact goldens for structure, strings, integers, escaping and
# compactness. Deliberately NO byte goldens for non-integral real
# spellings: those are jansson-version-dependent (2.14.1 moved real
# conversion to dtoa); their contract is value-level round-trip, tested
# in test_roundtrip.R.

## ---- containers ----
expect_identical(to_json(list()), "[]")
expect_identical(to_json(structure(list(), names = character(0))), "{}")
expect_identical(to_json(NULL), "null")
expect_identical(to_json(list(list())), "[[]]")
expect_identical(to_json(list(x = NULL)), "{\"x\":null}")

## ---- scalars ----
expect_identical(to_json(TRUE), "true")
expect_identical(to_json(FALSE), "false")
expect_identical(to_json(1L), "1")
expect_identical(to_json("a"), "\"a\"")

## ---- integral doubles spell as integers ----
expect_identical(to_json(1), "1")
expect_identical(to_json(list(x = 1)), "{\"x\":1}")
expect_identical(to_json(-3), "-3")
expect_identical(to_json(0), "0")
# -0 loses its sign bit, documented
expect_identical(to_json(-0), "0")
# the 2^53 boundary, as an exact literal
expect_identical(to_json(9007199254740992), "9007199254740992")
expect_identical(to_json(-9007199254740992), "-9007199254740992")

## ---- structural goldens ----
expect_identical(to_json(list(a = 1L, b = 42L, c = TRUE, d = "s")),
                 "{\"a\":1,\"b\":42,\"c\":true,\"d\":\"s\"}")
expect_identical(to_json(list(x = c(1L, 2L))), "{\"x\":[1,2]}")
expect_identical(to_json(list(b = 1L, a = 2L)), "{\"b\":1,\"a\":2}")
expect_identical(to_json(list(o = list(y = 1L, x = 2L))),
                 "{\"o\":{\"y\":1,\"x\":2}}")
expect_identical(to_json(integer(0)), "[]")
expect_identical(to_json(c(1L, 2L, 3L)), "[1,2,3]")

## ---- auto-unbox asymmetry ----
expect_identical(to_json(1L), "1")
expect_identical(to_json(list(1L)), "[1]")
expect_identical(to_json(list(list(1L))), "[[1]]")
expect_identical(to_json(list(x = "a")), "{\"x\":\"a\"}")
expect_identical(to_json(list(x = list("a"))), "{\"x\":[\"a\"]}")

## ---- empty keys are valid ----
expect_identical(to_json(setNames(list(1L), "")), "{\"\":1}")
expect_identical(to_json(list(a = 1L, 2L)), "{\"a\":1,\"\":2}")

## ---- string escaping ----
expect_identical(to_json("a\"b\\c\nd"), "\"a\\\"b\\\\c\\nd\"")
expect_identical(to_json("\b\f\r\t"), "\"\\b\\f\\r\\t\"")
expect_identical(to_json("\u0001"), "\"\\u0001\"")
# the solidus is NOT escaped, and non-ASCII passes through as UTF-8
expect_identical(to_json("a/b"), "\"a/b\"")
expect_identical(to_json("caf\u00e9"), "\"caf\u00e9\"")

## ---- compactness ----
out <- to_json(list(a = list(1L, "x"), b = TRUE))
expect_identical(out, "{\"a\":[1,\"x\"],\"b\":true}")
expect_false(grepl("[ \n\r\t]", out))
expect_identical(Encoding(to_json("caf\u00e9")), "UTF-8")

## ---- Latin-1-marked strings transcode on encode ----
lat <- iconv("caf\u00e9", "UTF-8", "latin1")
expect_identical(to_json(lat), "\"caf\u00e9\"")
