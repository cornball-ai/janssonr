# Every encoder refusal: values with no faithful JSON representation
# error with class janssonr_encode_error instead of being coerced.

eerr <- function(x) expect_error(to_json(x), class = "janssonr_encode_error")

## ---- NA of any type, bare and nested ----
eerr(NA)
eerr(NA_integer_)
eerr(NA_real_)
eerr(NA_character_)
eerr(c(1, NA))
eerr(c(TRUE, NA))
eerr(c("a", NA))
eerr(list(a = NA))
eerr(list(a = list(1, list(b = NA_real_))))

## ---- non-finite doubles ----
eerr(NaN)
eerr(Inf)
eerr(-Inf)
eerr(list(x = Inf))
eerr(c(1, NaN, 3))

## ---- named atomic vectors and attributes ----
expect_error(to_json(c(a = 1)), pattern = "named atomic",
             class = "janssonr_encode_error")
eerr(structure(1:3, foo = "bar"))
eerr(matrix(1:4, 2))
eerr(structure(list(1), foo = "bar"))
eerr(structure(list(a = 1), foo = "bar"))

## ---- classed objects ----
expect_error(to_json(factor("a")), pattern = "classed",
             class = "janssonr_encode_error")
eerr(Sys.Date())
eerr(data.frame(x = 1))
eerr(y ~ x)
eerr(structure(list(), class = "myclass"))

## ---- keys ----
expect_error(to_json(list(a = 1, a = 2)), pattern = "duplicate",
             class = "janssonr_encode_error")
eerr(list(a = 1, b = 2, a = 3))
eerr(list(a = list(b = 1, b = 2)))
# a repeated "" is a duplicate like any other
eerr(structure(list(1, 2), names = c("", "")))
eerr(structure(list(1, 2), names = c("a", NA)))

## ---- unsupported types ----
eerr(as.raw(1))
eerr(1i)
eerr(mean)
eerr(new.env())
eerr(quote(x))
eerr(expression(x + 1))
eerr(pairlist(1))

## ---- invalid UTF-8 ----
bad <- rawToChar(as.raw(c(0x61, 0xff)))
Encoding(bad) <- "UTF-8"
eerr(bad)
eerr(list(x = bad))

## ---- depth: janssonr's own limit, both boundary sides ----
x <- 1L
for (i in seq_len(1024L)) x <- list(x)
expect_silent(to_json(x))
x <- list(x)
expect_error(to_json(x), pattern = "1024",
             class = "janssonr_encode_error")

## ---- refusals leave no partial state: encoder still works after ----
expect_error(to_json(list(a = Inf)), class = "janssonr_encode_error")
expect_identical(to_json(list(a = 1L)), "{\"a\":1}")
