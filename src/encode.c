#include "janssonr.h"
#include "jr_jansson.h"
#include <math.h>
#include <string.h>
#include <limits.h>
#include <stdio.h>

/* Attach-immediately discipline: every json_t is created and attached to
 * its rooted parent (or the holder, for the root) in the same breath, with
 * no R API call in between, so at every instant the only owned reference
 * is the rooted tree and any longjmp is leak-free. json_object_set_new and
 * json_array_append_new decref the value themselves on failure.
 *
 * Only documented R API entry points are used here: ATTRIB/TAG/CDR are
 * gone from the package API as of R 4.6 (an implicit declaration truncates
 * their returned pointers to int), so attribute checks go through
 * ANY_ATTRIB, Rf_getAttrib, and an attributes() eval for the rare
 * named-list-with-extra-attributes case. */

static void jr_attach(json_t *node, json_t *parent, const char *key,
                      SEXP holder)
{
    if (node == NULL)
        jr_stop_encode_error("jansson allocation failed");
    if (parent == NULL) {
        jr_holder_set(holder, node);
    } else if (json_is_object(parent)) {
        if (json_object_set_new(parent, key, node) != 0)
            jr_stop_encode_error("cannot add object member (object key is not valid UTF-8?)");
    } else {
        if (json_array_append_new(parent, node) != 0)
            jr_stop_encode_error("cannot append array element");
    }
}

/* x has a names attribute and at least one other attribute bit set;
 * refuse unless names is the only attribute present. */
static void jr_check_only_names(SEXP x)
{
    SEXP call = PROTECT(Rf_lang2(Rf_install("attributes"), x));
    SEXP at = PROTECT(Rf_eval(call, R_BaseEnv));
    SEXP atnm = Rf_getAttrib(at, R_NamesSymbol);
    R_xlen_t n = XLENGTH(at), i;

    for (i = 0; i < n; i++) {
        if (strcmp(CHAR(STRING_ELT(atnm, i)), "names") != 0) {
            UNPROTECT(2);
            jr_stop_encode_error("cannot encode a list with attributes other than names");
        }
    }
    UNPROTECT(2);
}

/* Returns a NEW json_t for one atomic element, or longjmps. All checks
 * precede creation, so a refusal never strands a node. */
static json_t *jr_scalar(SEXP x, R_xlen_t i)
{
    switch (TYPEOF(x)) {
    case LGLSXP: {
        int v = LOGICAL(x)[i];
        if (v == NA_LOGICAL)
            jr_stop_encode_error("cannot encode NA in JSON");
        return json_boolean(v);
    }
    case INTSXP: {
        int v = INTEGER(x)[i];
        if (v == NA_INTEGER)
            jr_stop_encode_error("cannot encode NA in JSON");
        return json_integer((json_int_t) v);
    }
    case REALSXP: {
        double v = REAL(x)[i];
        if (ISNA(v))
            jr_stop_encode_error("cannot encode NA in JSON");
        if (R_IsNaN(v))
            jr_stop_encode_error("cannot encode NaN in JSON");
        if (!R_FINITE(v))
            jr_stop_encode_error("cannot encode a non-finite number in JSON");
        /* integral doubles up to 2^53 spell as integers ("1", not the
         * "1.0" jansson forces onto integral reals); -0 becomes "0" */
        if (v == floor(v) && fabs(v) <= (double) JR_MAX_SAFE_INT)
            return json_integer((json_int_t) v);
        return json_real(v);
    }
    case STRSXP: {
        SEXP s = STRING_ELT(x, i);
        const char *utf8;
        json_t *node;
        if (s == NA_STRING)
            jr_stop_encode_error("cannot encode NA in JSON");
        if (Rf_getCharCE(s) == CE_BYTES)
            jr_stop_encode_error("cannot encode a \"bytes\"-encoded string in JSON");
        utf8 = Rf_translateCharUTF8(s);
        node = json_string(utf8);
        if (node == NULL)
            jr_stop_encode_error("cannot encode invalid UTF-8 in a JSON string");
        return node;
    }
    }
    jr_stop_encode_error("internal: jr_scalar on a non-atomic type");
    return NULL; /* not reached */
}

/* depth = number of enclosing containers; a container at depth >= 1024
 * would be the 1025th nesting level and refuses. */
static void jr_encode_value(SEXP x, json_t *parent, const char *key,
                            SEXP holder, int depth)
{
    if (Rf_isObject(x))
        jr_stop_encode_error("cannot encode a classed object in JSON");

    switch (TYPEOF(x)) {
    case NILSXP:
        jr_attach(json_null(), parent, key, holder);
        return;

    case VECSXP: {
        SEXP nm;
        R_xlen_t n = XLENGTH(x), i;

        if (depth >= JR_MAX_DEPTH)
            jr_stop_encode_error("nesting depth exceeds 1024");

        nm = Rf_getAttrib(x, R_NamesSymbol);
        if (ANY_ATTRIB(x)) {
            if (nm == R_NilValue)
                jr_stop_encode_error("cannot encode a list with attributes other than names");
            jr_check_only_names(x);
        }

        if (nm != R_NilValue) {
            /* any names attribute means object; "" is a valid JSON key,
             * so unnamed slots of a partially-named list encode as "" */
            json_t *obj;
            if (XLENGTH(nm) != n)
                jr_stop_encode_error("names attribute length does not match the list length");
            obj = json_object();
            jr_attach(obj, parent, key, holder);
            for (i = 0; i < n; i++) {
                SEXP ks = STRING_ELT(nm, i);
                const char *k;
                if (ks == NA_STRING)
                    jr_stop_encode_error("cannot encode an object key that is NA");
                if (Rf_getCharCE(ks) == CE_BYTES)
                    jr_stop_encode_error("cannot encode a \"bytes\"-encoded object key");
                k = Rf_translateCharUTF8(ks);
                if (json_object_get(obj, k) != NULL) {
                    char msg[256];
                    snprintf(msg, sizeof msg,
                             "duplicate object key: \"%.200s\"", k);
                    jr_stop_encode_error(msg);
                }
                jr_encode_value(VECTOR_ELT(x, i), obj, k, holder, depth + 1);
            }
        } else {
            json_t *arr = json_array();
            jr_attach(arr, parent, key, holder);
            for (i = 0; i < n; i++)
                jr_encode_value(VECTOR_ELT(x, i), arr, NULL, holder,
                                depth + 1);
        }
        return;
    }

    case LGLSXP:
    case INTSXP:
    case REALSXP:
    case STRSXP: {
        R_xlen_t n = XLENGTH(x), i;

        if (ANY_ATTRIB(x)) {
            if (Rf_getAttrib(x, R_NamesSymbol) != R_NilValue)
                jr_stop_encode_error("cannot encode a named atomic vector (use a named list for an object)");
            jr_stop_encode_error("cannot encode an atomic vector with attributes");
        }
        if (n == 1) {
            /* auto-unbox: a length-1 unnamed atomic is a bare scalar; a
             * length-1 list stays a 1-element array */
            jr_attach(jr_scalar(x, 0), parent, key, holder);
        } else {
            json_t *arr;
            if (depth >= JR_MAX_DEPTH)
                jr_stop_encode_error("nesting depth exceeds 1024");
            arr = json_array();
            jr_attach(arr, parent, key, holder);
            for (i = 0; i < n; i++)
                jr_attach(jr_scalar(x, i), arr, NULL, holder);
        }
        return;
    }

    default: {
        char msg[128];
        snprintf(msg, sizeof msg, "cannot encode value of type %s in JSON",
                 Rf_type2char((SEXPTYPE) TYPEOF(x)));
        jr_stop_encode_error(msg);
    }
    }
}

SEXP jr_encode(SEXP value)
{
    SEXP holder, out;
    json_t *root;
    size_t need, got;
    char *buf;

    holder = PROTECT(jr_holder_create());
    jr_encode_value(value, NULL, NULL, holder, 0);
    root = (json_t *) R_ExternalPtrAddr(holder);
    if (root == NULL)
        jr_stop_encode_error("internal: no root after encoding");

    need = json_dumpb(root, NULL, 0, JR_DUMP_FLAGS);
    if (need == 0)
        jr_stop_encode_error("jansson failed to serialize the value");
    if (need > (size_t) INT_MAX)
        jr_stop_encode_error("encoded JSON exceeds INT_MAX bytes");

    buf = R_alloc(need, 1); /* freed by R on return or longjmp */
    got = json_dumpb(root, buf, need, JR_DUMP_FLAGS);
    if (got != need)
        jr_stop_encode_error("internal: inconsistent serialization size");

    /* free the tree before building the CHARSXP: buf lives in the R_alloc
     * arena, so an allocation failure below leaks nothing */
    root = (json_t *) jr_holder_release(holder);
    json_decref(root);

    out = PROTECT(Rf_ScalarString(Rf_mkCharLenCE(buf, (int) need, CE_UTF8)));
    UNPROTECT(2);
    return out;
}
