#' Parse JSON strictly
#'
#' Parses one JSON document under janssonr's R-safe profile of RFC 8259.
#' The parser refuses, with a classed condition, anything that cannot be
#' represented faithfully in R: malformed or truncated input, trailing
#' content, duplicate object keys at any depth, invalid UTF-8, embedded
#' NUL escapes, numbers overflowing double, and integers whose magnitude
#' exceeds 2^53.
#'
#' Mapping: a JSON object becomes a named list in key order (an empty
#' object keeps a \code{character(0)} names attribute, distinguishing it
#' from an empty array); an array becomes an unnamed list, never an atomic
#' vector; a string becomes \code{character(1)}; an integer fitting R's
#' integer range becomes \code{integer(1)} (except -2147483648, R's NA
#' sentinel, which becomes double); any other number becomes
#' \code{double(1)}; \code{true}/\code{false} become \code{logical(1)};
#' \code{null} becomes \code{NULL}. Nesting beyond 1024 containers
#' refuses.
#'
#' Character input is translated to UTF-8; raw input is taken byte for
#' byte and must already be valid UTF-8.
#'
#' Errors have class \code{c("janssonr_parse_error", "janssonr_error",
#' "error", "condition")} and carry \code{line}, \code{column},
#' \code{position} (byte offset) for lexical errors, plus \code{code}, a
#' stable string such as \code{"duplicate_key"} or \code{"invalid_utf8"}.
#' Refusals detected after parsing (\code{"integer_precision"},
#' \code{"depth_limit"}) carry NA coordinates; \code{"integer_precision"}
#' also carries \code{path}, an RFC 6901 JSON Pointer to the offending
#' value.
#'
#' @param x A length-1, non-NA character vector, or a raw vector holding
#'   UTF-8 bytes.
#' @return The corresponding R value; see the mapping above.
#' @examples
#' from_json('{"a": 1, "b": [true, null]}')
#' from_json("[1, 2, 3]")
#' @useDynLib janssonr, .registration = TRUE, .fixes = "C_"
#' @export
from_json <- function(x) {
    if (!(is.raw(x) || (is.character(x) && length(x) == 1L && !is.na(x)))) {
        stop(.input_error(
            "x must be a length-1, non-NA character vector or a raw vector"))
    }
    .Call(C_jr_parse, x)
}
