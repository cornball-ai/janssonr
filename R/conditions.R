# Condition taxonomy, in one place:
#   janssonr_input_error  - R-level argument validation (from_json)
#   janssonr_parse_error  - from_json refusals; fields line/column/position
#                           (NA for post-parse refusals), code, path
#   janssonr_encode_error - to_json refusals
# All three also carry class "janssonr_error".
.input_error <- function(message) {
    structure(
        class = c("janssonr_input_error", "janssonr_error", "error",
                  "condition"),
        list(message = message, call = NULL))
}
