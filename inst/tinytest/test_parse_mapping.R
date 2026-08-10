# The decode mapping: predictable R shapes, pinned exactly.

## ---- the {} / [] distinguisher ----
expect_identical(from_json("{}"), structure(list(), names = character(0)))
expect_identical(from_json("[]"), list())
expect_null(names(from_json("[]")))
expect_identical(names(from_json("{}")), character(0))

## ---- objects: named lists in key order ----
expect_identical(from_json("{\"b\":1,\"a\":2}"), list(b = 1L, a = 2L))
expect_identical(names(from_json("{\"z\":1,\"m\":2,\"a\":3}")),
                 c("z", "m", "a"))
expect_identical(from_json("{\"o\":{\"y\":1,\"x\":2}}"),
                 list(o = list(y = 1L, x = 2L)))

## ---- arrays: unnamed lists, never atomic ----
expect_identical(from_json("[1,2,3]"), list(1L, 2L, 3L))
expect_identical(from_json("[1,\"a\",true,null]"),
                 list(1L, "a", TRUE, NULL))
expect_identical(from_json("[[1],[]]"), list(list(1L), list()))

## ---- scalars (top-level allowed) ----
expect_identical(from_json("1"), 1L)
expect_identical(from_json("\"x\""), "x")
expect_identical(from_json("true"), TRUE)
expect_identical(from_json("false"), FALSE)
expect_null(from_json("null"))
expect_identical(from_json("1.5"), 1.5)
expect_identical(from_json("1e3"), 1000)

## ---- 1.0 is a double, never an integer ----
expect_identical(from_json("1.0"), 1)
expect_false(is.integer(from_json("1.0")))
expect_true(is.integer(from_json("1")))

## ---- integer/double boundary ----
expect_identical(from_json("2147483647"), 2147483647L)
expect_identical(from_json("-2147483647"), -2147483647L)
expect_identical(from_json("2147483648"), 2147483648)
# -2147483648 is R's NA_INTEGER sentinel and must come back as double
x <- from_json("-2147483648")
expect_true(is.double(x))
expect_identical(x, -2147483648)
expect_identical(from_json("9007199254740992"), 9007199254740992)

## ---- unicode ----
expect_identical(from_json("\"\\u00e9\""), "\u00e9")
expect_identical(Encoding(from_json("\"\\u00e9\"")), "UTF-8")
expect_identical(from_json("\"\\ud83d\\ude00\""), "\U0001f600")
expect_identical(from_json("\"\\\" \\\\ \\/ \\b \\f \\n \\r \\t\""),
                 "\" \\ / \b \f \n \r \t")
expect_identical(from_json("\"caf\u00e9\""), "caf\u00e9")

## ---- empty-key symmetry ----
x <- from_json("{\"\":1}")
expect_identical(names(x), "")
expect_identical(x[[1L]], 1L)

## ---- raw input is byte-identical to character input ----
corpus <- c("{\"a\":[1,2.5,null]}", "[]", "{}", "\"caf\u00e9\"", "true")
for (txt in corpus) {
    expect_identical(from_json(charToRaw(txt)), from_json(txt), info = txt)
}

## ---- Latin-1-marked input transcodes ----
lat <- iconv("\"caf\u00e9\"", "UTF-8", "latin1")
expect_identical(Encoding(lat), "latin1")
expect_identical(from_json(lat), "caf\u00e9")

## ---- whitespace tolerance (RFC-conformant, not strictness) ----
expect_identical(from_json(" { \"a\" : [ 1 , 2 ] } \n"),
                 list(a = list(1L, 2L)))
