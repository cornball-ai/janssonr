#include "janssonr.h"

/* Raise a classed R condition from plain C values. No jansson types here:
 * by the time these run, the caller holds no unmanaged jansson reference
 * (the holder's finalizer owns the tree), so the longjmp is leak-free. */

static void jr_stop_condition(SEXP cond)
{
    SEXP call = PROTECT(Rf_lang2(Rf_install("stop"), cond));
    Rf_eval(call, R_BaseEnv);
    UNPROTECT(2); /* not reached */
}

void jr_stop_parse_error(const char *msg, int line, int column, int position,
                         const char *code, const char *path)
{
    SEXP cond = PROTECT(Rf_allocVector(VECSXP, 7));
    SEXP names = PROTECT(Rf_allocVector(STRSXP, 7));

    SET_STRING_ELT(names, 0, Rf_mkChar("message"));
    SET_STRING_ELT(names, 1, Rf_mkChar("call"));
    SET_STRING_ELT(names, 2, Rf_mkChar("line"));
    SET_STRING_ELT(names, 3, Rf_mkChar("column"));
    SET_STRING_ELT(names, 4, Rf_mkChar("position"));
    SET_STRING_ELT(names, 5, Rf_mkChar("code"));
    SET_STRING_ELT(names, 6, Rf_mkChar("path"));

    SET_VECTOR_ELT(cond, 0, Rf_ScalarString(Rf_mkCharCE(msg, CE_UTF8)));
    SET_VECTOR_ELT(cond, 1, R_NilValue);
    SET_VECTOR_ELT(cond, 2, Rf_ScalarInteger(line >= 0 ? line : NA_INTEGER));
    SET_VECTOR_ELT(cond, 3, Rf_ScalarInteger(column >= 0 ? column : NA_INTEGER));
    SET_VECTOR_ELT(cond, 4, Rf_ScalarInteger(position >= 0 ? position : NA_INTEGER));
    SET_VECTOR_ELT(cond, 5, Rf_ScalarString(Rf_mkCharCE(code, CE_UTF8)));
    SET_VECTOR_ELT(cond, 6, path != NULL
        ? Rf_ScalarString(Rf_mkCharCE(path, CE_UTF8))
        : Rf_ScalarString(NA_STRING));
    Rf_setAttrib(cond, R_NamesSymbol, names);

    SEXP klass = PROTECT(Rf_allocVector(STRSXP, 4));
    SET_STRING_ELT(klass, 0, Rf_mkChar("janssonr_parse_error"));
    SET_STRING_ELT(klass, 1, Rf_mkChar("janssonr_error"));
    SET_STRING_ELT(klass, 2, Rf_mkChar("error"));
    SET_STRING_ELT(klass, 3, Rf_mkChar("condition"));
    Rf_setAttrib(cond, R_ClassSymbol, klass);

    jr_stop_condition(cond);
}

void jr_stop_encode_error(const char *msg)
{
    SEXP cond = PROTECT(Rf_allocVector(VECSXP, 2));
    SEXP names = PROTECT(Rf_allocVector(STRSXP, 2));

    SET_STRING_ELT(names, 0, Rf_mkChar("message"));
    SET_STRING_ELT(names, 1, Rf_mkChar("call"));
    SET_VECTOR_ELT(cond, 0, Rf_ScalarString(Rf_mkCharCE(msg, CE_UTF8)));
    SET_VECTOR_ELT(cond, 1, R_NilValue);
    Rf_setAttrib(cond, R_NamesSymbol, names);

    SEXP klass = PROTECT(Rf_allocVector(STRSXP, 4));
    SET_STRING_ELT(klass, 0, Rf_mkChar("janssonr_encode_error"));
    SET_STRING_ELT(klass, 1, Rf_mkChar("janssonr_error"));
    SET_STRING_ELT(klass, 2, Rf_mkChar("error"));
    SET_STRING_ELT(klass, 3, Rf_mkChar("condition"));
    Rf_setAttrib(cond, R_ClassSymbol, klass);

    jr_stop_condition(cond);
}
