# Deltas from upstream Jansson 2.15.1

These sources are upstream Jansson v2.15.1
(https://github.com/akheron/jansson, MIT) with seven minimal patches,
each marked with a "janssonr patch" comment at the site. Re-apply all
seven when refreshing the vendored copy; all are candidates for
upstreaming. Patches 3-5 came from CRAN's incoming pretest, whose
compilers (gcc 16 on Debian, gcc 14.3 on Windows) are newer than any
we build with locally. Patches 6-7 came from CRAN's gcc-UBSAN check
(`-fsanitize=undefined,bounds-strict`), which `tools/ubsan-check.sh`
now reproduces.

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

3. `strconv.c` (`jsonp_dtostr`): the exponent is written digit by digit
   instead of with `sprintf`. CRAN's "compiled code" check rejects any
   object referencing `sprintf` (it surfaces as `__sprintf_chk` under
   `_FORTIFY_SOURCE`) regardless of whether the call is provably safe,
   and this one is: the size check at the top of the function already
   reserves 5 bytes for the exponent.

   Swapping in `snprintf` does **not** fix it, which is worth knowing
   before anyone "simplifies" this back: gcc folds an `snprintf` whose
   output it can prove fits into a plain `sprintf`, so `strconv.o` kept
   referencing `__sprintf_chk` with no `sprintf` anywhere in the source.
   Leaving the printf family entirely is what makes the object clean,
   on any compiler. The digits are emitted exactly as `"%d"` emitted
   them (minus sign only, no `+`, no padding), so output bytes are
   unchanged; `exp_len`, now unused, is dropped from the declarations.

4. `load.c` (`error_set`): the two `snprintf` calls that append context
   to a message use explicit precisions (`%.131s near '%.20s'` and
   `%.142s near end of file`) instead of bare `%s`. Bounding both
   conversions makes the maximum output 159 bytes + NUL, which lets
   gcc 16 prove the trailing literal is never truncated away
   (`-Wformat-truncation`, a significant warning under R CMD check).
   The precisions are the largest that fit `JSON_ERROR_TEXT_LENGTH`
   (160); `saved_text` is already guarded to 20 bytes at the call
   site, so no message jansson can actually produce is shortened.

5. `value.c` (`jsonp_loop_check`): the `%p` argument is cast to
   `const void *`. C requires a pointer to void there, and gcc 14+
   makes passing `const json_t *` a `-Wformat` warning.

6. `hashtable.h` (`struct hashtable_pair`): the trailing `key` member
   is a C99 flexible array member (`char key[]`) instead of the
   pre-C99 one-element array `char key[1]`. `init_pair()` already
   sizes each pair as `offsetof(pair_t, key) + key_len + 1`, so the
   layout and every allocation are unchanged; only the declared type
   is. With `char key[1]`, the store `pair->key[key_len] = '\0'` and
   the `memcpy` before it index past the declared array for every
   key, and gcc's `-fsanitize=bounds-strict` reports the first object
   parsed (`index 1 out of bounds for type 'char [1]'`, CRAN's
   gcc-UBSAN report of 2026-09-12). A flexible array member has no
   declared bound, so nothing is reported and nothing else changes.
   The `container_of()` in `hashtable_key_to_iter` still works:
   `offsetof` on a flexible array member is well defined.

7. `dtoa.c` (`struct Bigint`, `Balloc()`): the same change for the
   trailing `x` member (`ULong x[]`, was `ULong x[1]`). Because
   `sizeof(Bigint)` no longer includes an element of `x`, `Balloc()`
   sizes a block as `sizeof(Bigint) + x*sizeof(ULong)` instead of
   `(x-1)*sizeof(ULong)`, in both the private-memory and `MALLOC`
   branches. The block still holds the header plus `x` words; on LP64
   it is 4 bytes smaller than before because the old `sizeof` carried
   the struct's tail padding, on ILP32 it is identical. `Bcopy()`
   copies from `sign` through the words and is unaffected: `x` still
   follows `wds` directly. The two other places that spell out a
   block's size, `rv_alloc()` and the `blen` that `dtoa_r()` derives
   for a block it allocated itself, drop their `- sizeof(ULong)` /
   `- 1` for the same reason; both are only used when the caller
   passes no buffer, which jansson never does (`jsonp_dtostr()` hands
   in its own 25-byte array). This site is reached only when the 64-bit
   fast path in `dtoa_r()` gives up, which shortest-form (mode 0)
   conversion does for some whole-number doubles above 2^53, e.g.
   29006543789128832; CRAN's run had not hit it, and
   `test_roundtrip.R` now encodes such values so sanitizer runs do.

`jansson_config.h` is the autotools-generated public config (gcc
values, platform-neutral). The private configs are hand-written, one
per platform, in `../config-win/` and `../config-unix/` — outside this
directory because `jansson_private.h` includes
`jansson_private_config.h` with a quoted include, which searches its
own directory before any `-I` path; see their header comments.
