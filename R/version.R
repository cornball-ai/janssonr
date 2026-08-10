# Internal: the Jansson versions in play. "compiled" is the header the
# package was built against; "runtime" is what the loaded shared library
# reports, or NA when built against headers below 2.13.1 (where
# jansson_version_str() was absent from the library's exports). CI asserts
# compiled == runtime to catch a header/library mismatch.
jansson_version <- function() {
    .Call(C_jr_version)
}
