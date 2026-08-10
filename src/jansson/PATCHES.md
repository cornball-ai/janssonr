# Deltas from upstream Jansson 2.15.1

These sources are upstream Jansson v2.15.1
(https://github.com/akheron/jansson, MIT) with two minimal patches,
each marked with a "janssonr patch" comment at the site. Re-apply both
when refreshing the vendored copy; both are candidates for upstreaming.

1. `jansson.h`: `JSON_INTEGER_FORMAT` is `"lld"` unconditionally.
   Upstream uses the MSVCRT-era `"I64d"` on `_WIN32`; R's Windows
   toolchain (Rtools, UCRT) supports `"lld"`, and gcc 14's format
   checker rejects `"I64d"`, which R CMD check counts as a significant
   warning.

2. `error.c` (`jsonp_error_set_source`): the two `strncpy` calls are
   `memcpy` of `length + 1` bytes. Equivalent under the surrounding
   bound checks (the NUL is included in the count) and avoids gcc's
   `-Wstringop-truncation` false positive, also a significant warning
   under R CMD check.

`jansson_config.h` is the autotools-generated public config (gcc
values, platform-neutral). `jansson_private_config.h` is hand-written
for the Windows build; see its header comment.
