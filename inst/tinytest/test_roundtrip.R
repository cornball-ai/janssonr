# Property tests. Three distinct contracts:
#   1. doubles round-trip to the exact same VALUE (spelling is not pinned);
#   2. from_json(to_json(x)) equals the documented normalized R value;
#   3. normalization is idempotent: encoding a parsed document again is a
#      fixed point (raw text identity is broken by design: whitespace and
#      numeric normalization).

## ---- 1. exact double round-trip, several hundred values ----
set.seed(42)
corpus <- c(
    0, 1, -1, 0.5, -0.5, 0.1, 0.001, 1/3, 2/3, pi, -pi, exp(1),
    2.5, 1785000000.123456, 1e-7, 1e7, 1e-300, 1e300, 123.456789,
    .Machine$double.eps, .Machine$double.xmax, .Machine$double.xmin,
    5e-324,                       # smallest denormal
    2^53, 2^53 - 1, -(2^53),
    0.30000000000000004,          # 0.1 + 0.2
    runif(200), rnorm(200) * 1e6, 2^runif(100, -1020, 1020),
    -runif(50), 10^(-30:30)
)
# No near-xmax decimal LITERALS here: R's own parser (R_strtod)
# accumulates in long double, and on Apple's arm64 ABI long double IS
# double (generic AArch64 Linux uses 128-bit quad), so
# 1.7976931348623157e308 overflows to Inf at R parse time (macOS CI
# found this). .Machine$double.xmax above covers the extreme; jansson's
# strtod parse path is correctly rounded and is tested via round-trip.
expect_true(all(is.finite(corpus)))

# signed zero survives the round-trip bit-identically: identical(-0, 0)
# is TRUE in R, so assert through the sign of the reciprocal
expect_identical(1 / as.numeric(from_json(to_json(list(x = -0)))$x), -Inf)
expect_identical(1 / as.numeric(from_json(to_json(list(x = 0)))$x), Inf)
for (v in corpus) {
    # a refusal mid-corpus must name the value, not kill the file
    enc <- tryCatch(to_json(list(x = v)), error = function(e) e)
    if (inherits(enc, "error")) {
        expect_true(FALSE, info = sprintf("encode refused %.17g (%a): %s",
                                          v, v, conditionMessage(enc)))
        next
    }
    got <- from_json(enc)$x
    # as.numeric normalizes the documented whole-double -> integer
    # spelling; the VALUE must be bit-exact
    expect_identical(as.numeric(got), v,
                     info = sprintf("%.17g via %s", v, enc))
}
# and bare scalars round-trip the same way
for (v in c(1/3, 1e-300, 5e-324, .Machine$double.xmax)) {
    expect_identical(as.numeric(from_json(to_json(v))), v)
}

## ---- 2. structural round-trip over decode-shaped trees ----
# decode-shaped: unnamed/named lists of scalars, non-integral doubles,
# integers, strings, logicals, NULLs. For these, from_json(to_json(x))
# is the identity.
set.seed(1234)
rand_scalar <- function() {
    switch(sample.int(5L, 1L),
           sample(c(TRUE, FALSE), 1L),
           sample.int(20000L, 1L) - 10000L,
           { v <- rnorm(1L); while (v == floor(v)) v <- rnorm(1L); v },
           paste0(sample(c(letters, "\u00e9", "\u4e2d", "\"", "\\", "/"),
                         sample.int(8L, 1L), replace = TRUE),
                  collapse = ""),
           NULL)
}
rand_tree <- function(depth) {
    if (depth <= 0L || runif(1L) < 0.4) return(rand_scalar())
    n <- sample.int(4L, 1L)
    kids <- lapply(seq_len(n), function(i) rand_tree(depth - 1L))
    if (runif(1L) < 0.5) {
        names(kids) <- make.unique(replicate(n, paste0(
            sample(letters, 3L, replace = TRUE), collapse = "")))
    }
    kids
}
for (i in 1:200) {
    x <- rand_tree(4L)
    expect_identical(from_json(to_json(x)), x, info = paste("tree", i))
}

## ---- documented normalizations (not identity, pinned exactly) ----
# atomic vectors become lists of scalars
expect_identical(from_json(to_json(c(1L, 2L))), list(1L, 2L))
expect_identical(from_json(to_json(c("a", "b"))), list("a", "b"))
# integral doubles become integers
expect_identical(from_json(to_json(1)), 1L)
expect_identical(from_json(to_json(list(x = 2))), list(x = 2L))
# integral doubles beyond int range stay double
expect_identical(from_json(to_json(2^40)), 2^40)
expect_true(is.double(from_json(to_json(2^40))))

## ---- 3. normalization idempotence over a text corpus ----
texts <- c(
    "{\"x\": 1.0}",
    "{ \"a\" : [ 1 , 2.5 , null ] }",
    "[1e2, 0.1, -0.0]",
    "\"caf\u00e9\"",
    "{\"nested\": {\"deep\": [[1], {}, []]}}",
    "{\"\": 1, \"k\": \"\\u00e9\"}",
    "3.141592653589793",
    "[true, false, null]",
    "{\"big\": 9007199254740992}"
)
for (t in texts) {
    u <- to_json(from_json(t))
    expect_identical(to_json(from_json(u)), u, info = t)
}

## ---- boundary depth round-trips on every backend version ----
deep <- paste0(strrep("[", 1024L), strrep("]", 1024L))
expect_identical(to_json(from_json(deep)), deep)
