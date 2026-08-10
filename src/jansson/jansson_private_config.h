/* Hand-written private config for the bundled Jansson 2.15.1 sources,
 * targeting Windows (mingw-w64 ucrt64 via Rtools). Unix builds link the
 * system libjansson through configure and never compile these sources.
 * No WORDS_BIGENDIAN: dtoa.c then selects IEEE_8087 (little-endian),
 * correct for every Windows target R supports. */
#define DTOA_ENABLED 1
#define HAVE_ATOMIC_BUILTINS 1
#define HAVE_SYNC_BUILTINS 1
#define HAVE_FCNTL_H 1
#define HAVE_INTTYPES_H 1
#define HAVE_LOCALE_H 1
#define HAVE_SETLOCALE 1
#define HAVE_STDINT_H 1
#define HAVE_STDIO_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRING_H 1
#define HAVE_STRINGS_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_SYS_TIME_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_UNISTD_H 1
#define HAVE_GETPID 1
#define HAVE_GETTIMEOFDAY 1
#define HAVE_LONG_LONG_INT 1
#define HAVE_UNSIGNED_LONG_LONG_INT 1
#define HAVE_STRTOLL 1
#define INITIAL_HASHTABLE_ORDER 3
#define STDC_HEADERS 1
#define USE_WINDOWS_CRYPTOAPI 1
