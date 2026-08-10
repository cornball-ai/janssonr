#include "janssonr.h"
#include "jr_jansson.h"

/* The holder owns the jansson tree: it is created (with a NULL address)
 * BEFORE any jansson call, so a longjmp at any later point leaves the
 * finalizer to decref whatever was attached. */

static void jr_holder_finalize(SEXP p)
{
    json_t *root = (json_t *) R_ExternalPtrAddr(p);
    if (root != NULL) {
        R_ClearExternalPtr(p);
        json_decref(root);
    }
}

SEXP jr_holder_create(void)
{
    SEXP holder = PROTECT(R_MakeExternalPtr(NULL, R_NilValue, R_NilValue));
    R_RegisterCFinalizerEx(holder, jr_holder_finalize, FALSE);
    UNPROTECT(1);
    return holder;
}

void jr_holder_set(SEXP holder, void *root)
{
    R_SetExternalPtrAddr(holder, root);
}

/* Clear before the caller decrefs, with no R API call in between, so the
 * finalizer can never see a stale address and double-decref. */
void *jr_holder_release(SEXP holder)
{
    void *root = R_ExternalPtrAddr(holder);
    R_ClearExternalPtr(holder);
    return root;
}

const char *jr_error_code_name(json_error_t *err)
{
    switch (json_error_code(err)) {
    case json_error_unknown: return "unknown";
    case json_error_out_of_memory: return "out_of_memory";
    case json_error_stack_overflow: return "stack_overflow";
    case json_error_cannot_open_file: return "cannot_open_file";
    case json_error_invalid_argument: return "invalid_argument";
    case json_error_invalid_utf8: return "invalid_utf8";
    case json_error_premature_end_of_input: return "premature_end_of_input";
    case json_error_end_of_input_expected: return "end_of_input_expected";
    case json_error_invalid_syntax: return "invalid_syntax";
    case json_error_invalid_format: return "invalid_format";
    case json_error_wrong_type: return "wrong_type";
    case json_error_null_character: return "null_character";
    case json_error_null_value: return "null_value";
    case json_error_null_byte_in_key: return "null_byte_in_key";
    case json_error_duplicate_key: return "duplicate_key";
    case json_error_numeric_overflow: return "numeric_overflow";
    case json_error_item_not_found: return "item_not_found";
    case json_error_index_out_of_range: return "index_out_of_range";
    }
    return "unknown";
}

SEXP jr_version(void)
{
    SEXP out = PROTECT(Rf_allocVector(STRSXP, 2));
    SET_STRING_ELT(out, 0, Rf_mkChar(JANSSON_VERSION));
#if JANSSON_VERSION_HEX >= 0x020d01
    /* jansson_version_str() exists in headers from 2.13.0 but was missing
     * from the shared library's exports until 2.13.1 */
    SET_STRING_ELT(out, 1, Rf_mkChar(jansson_version_str()));
#else
    SET_STRING_ELT(out, 1, NA_STRING);
#endif
    SEXP names = PROTECT(Rf_allocVector(STRSXP, 2));
    SET_STRING_ELT(names, 0, Rf_mkChar("compiled"));
    SET_STRING_ELT(names, 1, Rf_mkChar("runtime"));
    Rf_setAttrib(out, R_NamesSymbol, names);
    UNPROTECT(2);
    return out;
}
