% tinyrox says don't edit this manually, but it can't stop you!
\name{from_json}
\alias{from_json}
\title{Parse JSON strictly}
\usage{
from_json(x)
}
\arguments{
\item{x}{A length-1, non-NA character vector, or a raw vector holding
UTF-8 bytes.}
}
\value{
The corresponding R value; see the mapping above.
}
\description{
Parses one JSON document under janssonr's R-safe profile of RFC 8259.
The parser refuses, with a classed condition: malformed or truncated
input, trailing content, duplicate object keys at any depth, invalid
UTF-8, embedded NUL escapes, numbers overflowing double, and integer
literals whose magnitude exceeds 2^53. The exactness guarantee is for integer
literals only: number literals with a fraction or exponent
(\code{1.5}, \code{9007199254740993.0}, \code{1e-999}) convert by
ordinary correctly rounded IEEE 754 double conversion.
}
\details{
Mapping: a JSON object becomes a named list in key order (an empty
object keeps a \code{character(0)} names attribute, distinguishing it
from an empty array); an array becomes an unnamed list, never an atomic
vector; a string becomes \code{character(1)}; an integer fitting R's
integer range becomes \code{integer(1)} (except -2147483648, R's NA
sentinel, which becomes double); any other number becomes
\code{double(1)}; \code{true}/\code{false} become \code{logical(1)};
\code{null} becomes \code{NULL}. Nesting beyond 1024 containers
refuses.

Character input is translated to UTF-8; raw input is taken byte for
byte and must already be valid UTF-8.

Errors have class \code{c("janssonr_parse_error", "janssonr_error",
"error", "condition")} and carry \code{line}, \code{column},
\code{position} (byte offset) for lexical errors, plus \code{code}, a
stable string such as \code{"duplicate_key"} or \code{"invalid_utf8"}.
Refusals detected after parsing (\code{"integer_precision"},
\code{"depth_limit"}) carry NA coordinates; \code{"integer_precision"}
also carries \code{path}, an RFC 6901 JSON Pointer to the offending
value.

}
\examples{
from_json('{"a": 1, "b": [true, null]}')
from_json("[1, 2, 3]")
}
