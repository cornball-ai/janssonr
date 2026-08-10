#ifndef JANSSONR_H
#define JANSSONR_H

#include <R.h>
#include <Rinternals.h>
#include <Rversion.h>

/* ANY_ATTRIB appeared in the package API in R 4.5. Older R still
 * declares ATTRIB in the normal section (it moved behind
 * ENABLE_LEGACY_NONAPI_FUNS only in 4.6), so it is the natural
 * fallback there. */
#if R_VERSION < R_Version(4, 5, 0)
# define JR_HAS_ATTRIBS(x) (ATTRIB(x) != R_NilValue)
#else
# define JR_HAS_ATTRIBS(x) (ANY_ATTRIB(x) != 0)
#endif

/* entry points (init.c registers these) */
SEXP jr_parse(SEXP input);
SEXP jr_encode(SEXP value);
SEXP jr_version(void);

/* conditions.c: raise classed conditions; these never return.
 * line/column/position < 0 become NA; path NULL becomes NA. */
void jr_stop_parse_error(const char *msg, int line, int column, int position,
                         const char *code, const char *path);
void jr_stop_encode_error(const char *msg);

/* jr_common.c: external-pointer holder owning a jansson tree via its
 * finalizer, so any longjmp between load/build and return cannot leak. */
SEXP jr_holder_create(void);
void jr_holder_set(SEXP holder, void *root);
void *jr_holder_release(SEXP holder);

#endif
