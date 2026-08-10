#ifndef JR_JANSSON_H
#define JR_JANSSON_H

/* The single seam to the Jansson library. Only jr_common.c, decode.c and
 * encode.c may include this header; nothing Jansson-typed leaves them.
 * Vendoring Jansson later must touch only configure/Makevars, never code.
 *
 * Never call json_object_seed() or json_set_alloc_funcs(): libjansson.so
 * is process-global state shared with any other in-process user.
 */
#include <jansson.h>

#if JANSSON_VERSION_HEX < 0x020b00
#error "janssonr requires jansson >= 2.11"
#endif

#define JR_LOAD_FLAGS (JSON_REJECT_DUPLICATES | JSON_DECODE_ANY)
#define JR_DUMP_FLAGS (JSON_COMPACT | JSON_ENCODE_ANY | JSON_REAL_PRECISION(17))

/* |n| <= 2^53 is exactly representable as an R double */
#define JR_MAX_SAFE_INT 9007199254740992LL

/* janssonr's own authoritative nesting limit, deliberately below every
 * Jansson-internal limit in any supported version (parser cap 2048;
 * 2.15.1 added a dump recursion cap), so the boundary never depends on
 * the backend version. */
#define JR_MAX_DEPTH 1024

const char *jr_error_code_name(json_error_t *err);

#endif
