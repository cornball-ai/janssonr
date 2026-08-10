# The intended consumer pattern is a strict parse layer (janssonr) under
# a semantic validation layer (the caller). This corpus pins the split:
# janssonr rejects everything not well-formed under its profile, and
# accepts everything well-formed no matter how semantically wrong, so a
# caller's schema checks always run against a faithfully decoded value.

corpus <- list(
    # well-formed: janssonr accepts; semantics are the caller's problem
    list(txt = "{\"ok\":true,\"persisted\":true}",        parses = TRUE),
    list(txt = "{\"ok\":true,\"count\":3,\"tags\":[\"a\",\"b\"]}",
         parses = TRUE),
    list(txt = "{}",                                       parses = TRUE),
    list(txt = "{\"ok\":\"true\"}",                        parses = TRUE),
    list(txt = "{\"unknown\":1,\"extra\":2}",              parses = TRUE),
    list(txt = "{\"outer\":{\"inner\":[{\"k\":\"v\"}]}}",  parses = TRUE),
    list(txt = "\"scalar\"",                               parses = TRUE),
    list(txt = "[1,2,3]",                                  parses = TRUE),
    list(txt = "{\"\":1}",                                 parses = TRUE),

    # not well-formed under the profile: janssonr rejects at parse
    list(txt = "{\"ok\":true,\"ok\":true}",                parses = FALSE),
    list(txt = "{\"ok\":true,\"x\":{\"a\":1,\"a\":2}}",    parses = FALSE),
    list(txt = "{\"ok\":true,\"x\":[{\"a\":1,\"a\":2}]}",  parses = FALSE),
    list(txt = "{\"ok\":true} trailing",                   parses = FALSE),
    list(txt = "{\"ok\":true",                             parses = FALSE),
    list(txt = "",                                         parses = FALSE),
    list(txt = "{\"a\":01}",                               parses = FALSE),
    list(txt = "{\"a\":NaN}",                              parses = FALSE)
)

for (case in corpus) {
    got <- tryCatch({ from_json(case$txt); TRUE },
                    janssonr_parse_error = function(e) FALSE)
    expect_identical(got, case$parses, info = case$txt)
}

## ---- decoded shapes a validation layer relies on ----
v <- from_json("{\"ok\":true,\"persisted\":true}")
expect_true(is.list(v))
expect_identical(names(v), c("ok", "persisted"))
expect_true(is.logical(v$ok) && length(v$ok) == 1L && !is.na(v$ok))

# a well-formed wrong-type value arrives faithfully, not coerced
v <- from_json("{\"ok\":\"true\"}")
expect_true(is.character(v$ok))

# a JSON array body is a list, so an is-object check can refuse it
expect_true(is.list(from_json("[1,2,3]")))
expect_null(names(from_json("[1,2,3]")))

# an empty object body passes the is-object check and fails key checks
v <- from_json("{}")
expect_true(is.list(v) && length(v) == 0L)
expect_false(is.null(names(v)))

# strings survive verbatim for regex validation
v <- from_json("{\"id\":\"00000000000000000001-0123456789abcdef\"}")
expect_true(grepl("^[0-9]{20}-[0-9a-f]{16}$", v$id))
