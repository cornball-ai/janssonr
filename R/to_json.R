#' Serialize to JSON strictly
#'
#' Serializes an R value to one compact UTF-8 JSON document (no
#' whitespace, no trailing newline). Values with no faithful JSON
#' representation refuse with a classed condition instead of being
#' coerced.
#'
#' Mapping: a list with a names attribute becomes an object in insertion
#' order (\code{""} is a valid key, so unnamed slots of a partially-named
#' list encode as \code{""}; duplicate keys refuse); an unnamed list
#' becomes an array (a length-1 list stays a 1-element array); a length-1
#' unnamed atomic becomes a bare scalar; any other atomic becomes an
#' array; \code{NULL} becomes \code{null}. Integral doubles with
#' magnitude at most 2^53 are written as integers (\code{1}, not
#' \code{1.0}), except \code{-0}, which stays a real (\code{-0.0}) so
#' its sign bit survives; other doubles are written with 17 significant
#' digits. Every finite double, signed zero included, round-trips to the
#' exact same value. The lexical spelling of non-integral doubles is not
#' guaranteed byte-stable across Jansson versions.
#'
#' Refused: NA of any type, NaN, infinities, named atomic vectors,
#' atomics or lists with other attributes, classed objects, duplicate or
#' NA keys, raw, complex, functions, environments, and nesting beyond
#' 1024 containers. Errors have class
#' \code{c("janssonr_encode_error", "janssonr_error", "error",
#' "condition")}.
#'
#' @param x An R value made of named or unnamed lists, atomic vectors of
#'   type logical, integer, double or character, and \code{NULL}.
#' @return A length-1 UTF-8 character vector holding the JSON document.
#' @examples
#' to_json(list(a = 1L, b = list(TRUE, NULL)))
#' to_json(list())
#' to_json(structure(list(), names = character(0)))
#' @export
to_json <- function(x) {
    .Call(C_jr_encode, x)
}
