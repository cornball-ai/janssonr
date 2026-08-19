/* Hand-written private config for the bundled Jansson 2.15.1 sources
 * on Unix, used only when configure finds no usable system libjansson
 * (CRAN's macOS builders ship none). Selected via -Iconfig-unix; kept
 * outside jansson/ because jansson_private.h's quoted include searches
 * its own directory first (see config-win/ for the Windows twin).
 *
 * Seeding: /dev/urandom (USE_URANDOM + HAVE_OPEN/CLOSE/READ), with the
 * gettimeofday/getpid fallback jansson uses when the read fails.
 * Endianness for dtoa.c comes from the compiler rather than a
 * hand-picked value, so big-endian targets (e.g. s390x) stay correct.
 * No HAVE_ENDIAN_H: <endian.h> is glibc-specific and macOS lacks it;
 * lookup3.h only loses a hash micro-optimization without it. */
#define DTOA_ENABLED 1
#define HAVE_ATOMIC_BUILTINS 1
#define HAVE_SYNC_BUILTINS 1
#define HAVE_FCNTL_H 1
#define HAVE_INTTYPES_H 1
#define HAVE_LOCALE_H 1
#define HAVE_SETLOCALE 1
#define HAVE_SCHED_H 1
#define HAVE_SCHED_YIELD 1
#define HAVE_STDINT_H 1
#define HAVE_STDIO_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRING_H 1
#define HAVE_STRINGS_H 1
#define HAVE_SYS_PARAM_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_SYS_TIME_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_UNISTD_H 1
#define HAVE_GETPID 1
#define HAVE_GETTIMEOFDAY 1
#define HAVE_LONG_LONG_INT 1
#define HAVE_UNSIGNED_LONG_LONG_INT 1
#define HAVE_STRTOLL 1
#define HAVE_OPEN 1
#define HAVE_CLOSE 1
#define HAVE_READ 1
#define USE_URANDOM 1
#define INITIAL_HASHTABLE_ORDER 3
#define STDC_HEADERS 1

#if defined(__BYTE_ORDER__) && defined(__ORDER_BIG_ENDIAN__) && \
    __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
#define WORDS_BIGENDIAN 1
#endif
