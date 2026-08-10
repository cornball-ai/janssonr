#include "janssonr.h"
#include "jr_jansson.h"
#include <string.h>
#include <limits.h>
#include <stdio.h>

/* Path frames live on the C stack during the walk; on an integer_precision
 * refusal they are rendered as an RFC 6901 JSON Pointer. Jansson's AST
 * keeps no token coordinates, so post-parse refusals carry NA coordinates
 * plus this pointer instead. */
typedef struct jr_path_frame {
    const struct jr_path_frame *parent;
    const char *key;   /* object member name, or NULL for an array element */
    size_t index;      /* array index when key == NULL */
} jr_path_frame;

static char *jr_path_build(const jr_path_frame *frame)
{
    int n = 0, i;
    const jr_path_frame *f;
    const jr_path_frame **frames;
    size_t len;
    char *buf, *w;

    for (f = frame; f != NULL; f = f->parent) n++;
    frames = (const jr_path_frame **) R_alloc(n > 0 ? (size_t) n : 1,
                                              sizeof(*frames));
    i = n;
    for (f = frame; f != NULL; f = f->parent) frames[--i] = f;

    len = 1; /* trailing NUL; "" is the RFC 6901 root pointer */
    for (i = 0; i < n; i++) {
        if (frames[i]->key != NULL) {
            const char *p;
            for (p = frames[i]->key; *p; p++)
                len += (*p == '~' || *p == '/') ? 2 : 1;
            len += 1; /* leading '/' */
        } else {
            len += 24; /* '/' + decimal digits of a size_t */
        }
    }

    buf = R_alloc(len, 1);
    w = buf;
    for (i = 0; i < n; i++) {
        *w++ = '/';
        if (frames[i]->key != NULL) {
            const char *p;
            for (p = frames[i]->key; *p; p++) {
                if (*p == '~') { *w++ = '~'; *w++ = '0'; }
                else if (*p == '/') { *w++ = '~'; *w++ = '1'; }
                else *w++ = *p;
            }
        } else {
            w += snprintf(w, 22, "%lu", (unsigned long) frames[i]->index);
        }
    }
    *w = '\0';
    return buf;
}

static SEXP jr_decode_value(json_t *v, int depth, const jr_path_frame *frame)
{
    switch (json_typeof(v)) {
    case JSON_OBJECT: {
        size_t n = json_object_size(v);
        const char *key;
        json_t *val;
        R_xlen_t i = 0;
        SEXP out, nm;

        if (depth >= JR_MAX_DEPTH)
            jr_stop_parse_error("nesting depth exceeds 1024", -1, -1, -1,
                                "depth_limit", NULL);
        out = PROTECT(Rf_allocVector(VECSXP, (R_xlen_t) n));
        nm = PROTECT(Rf_allocVector(STRSXP, (R_xlen_t) n));
        json_object_foreach(v, key, val) {
            jr_path_frame child = {frame, key, 0};
            SET_STRING_ELT(nm, i, Rf_mkCharCE(key, CE_UTF8));
            SET_VECTOR_ELT(out, i, jr_decode_value(val, depth + 1, &child));
            i++;
        }
        /* set unconditionally: {} keeps a character(0) names attribute,
         * which is what distinguishes it from [] on the R side */
        Rf_setAttrib(out, R_NamesSymbol, nm);
        UNPROTECT(2);
        return out;
    }
    case JSON_ARRAY: {
        size_t n = json_array_size(v);
        size_t i;
        SEXP out;

        if (depth >= JR_MAX_DEPTH)
            jr_stop_parse_error("nesting depth exceeds 1024", -1, -1, -1,
                                "depth_limit", NULL);
        out = PROTECT(Rf_allocVector(VECSXP, (R_xlen_t) n));
        for (i = 0; i < n; i++) {
            jr_path_frame child = {frame, NULL, i};
            SET_VECTOR_ELT(out, (R_xlen_t) i,
                           jr_decode_value(json_array_get(v, i), depth + 1,
                                           &child));
        }
        UNPROTECT(1);
        return out;
    }
    case JSON_STRING: {
        size_t len = json_string_length(v);
        if (len > (size_t) INT_MAX)
            jr_stop_parse_error("string longer than INT_MAX bytes", -1, -1, -1,
                                "string_length", NULL);
        return Rf_ScalarString(Rf_mkCharLenCE(json_string_value(v), (int) len,
                                              CE_UTF8));
    }
    case JSON_INTEGER: {
        json_int_t iv = json_integer_value(v);
        /* -2147483648 is R's NA_INTEGER sentinel, hence the asymmetric
         * lower bound: it must map to double */
        if (iv >= -2147483647LL && iv <= 2147483647LL)
            return Rf_ScalarInteger((int) iv);
        if (iv >= -JR_MAX_SAFE_INT && iv <= JR_MAX_SAFE_INT)
            return Rf_ScalarReal((double) iv);
        {
            char *path = jr_path_build(frame);
            char msg[256];
            snprintf(msg, sizeof msg,
                     "integer %lld at \"%s\" cannot be represented exactly as an R double",
                     (long long) iv, path);
            jr_stop_parse_error(msg, -1, -1, -1, "integer_precision", path);
        }
    }
    case JSON_REAL:
        return Rf_ScalarReal(json_real_value(v));
    case JSON_TRUE:
        return Rf_ScalarLogical(1);
    case JSON_FALSE:
        return Rf_ScalarLogical(0);
    case JSON_NULL:
        return R_NilValue;
    }
    jr_stop_parse_error("unknown JSON value type", -1, -1, -1, "unknown", NULL);
    return R_NilValue; /* not reached */
}

SEXP jr_parse(SEXP input)
{
    const char *buf;
    size_t len;
    SEXP holder, out;
    json_error_t err;
    json_t *root;

    if (TYPEOF(input) == RAWSXP) {
        buf = (const char *) RAW(input);
        len = (size_t) XLENGTH(input);
    } else if (TYPEOF(input) == STRSXP && XLENGTH(input) == 1) {
        SEXP s = STRING_ELT(input, 0);
        if (s == NA_STRING)
            jr_stop_parse_error("input is NA", -1, -1, -1, "invalid_input",
                                NULL);
        if (Rf_getCharCE(s) == CE_BYTES)
            jr_stop_parse_error("input has \"bytes\" encoding and cannot be translated to UTF-8",
                                -1, -1, -1, "invalid_input", NULL);
        buf = Rf_translateCharUTF8(s);
        len = strlen(buf);
    } else {
        jr_stop_parse_error("input must be a length-1 character vector or a raw vector",
                            -1, -1, -1, "invalid_input", NULL);
        return R_NilValue; /* not reached */
    }

    holder = PROTECT(jr_holder_create());
    root = json_loadb(buf, len, JR_LOAD_FLAGS, &err);
    if (root == NULL) {
        UNPROTECT(1);
        jr_stop_parse_error(err.text, err.line, err.column, err.position,
                            jr_error_code_name(&err), NULL);
    }
    jr_holder_set(holder, root);

    out = PROTECT(jr_decode_value(root, 0, NULL));

    root = (json_t *) jr_holder_release(holder);
    json_decref(root);

    UNPROTECT(2);
    return out;
}
