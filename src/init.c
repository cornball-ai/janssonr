#include "janssonr.h"
#include <R_ext/Rdynload.h>

static const R_CallMethodDef CallEntries[] = {
    {"jr_parse",   (DL_FUNC) &jr_parse,   1},
    {"jr_encode",  (DL_FUNC) &jr_encode,  1},
    {"jr_version", (DL_FUNC) &jr_version, 0},
    {NULL, NULL, 0}
};

void R_init_janssonr(DllInfo *dll)
{
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
    R_forceSymbols(dll, TRUE);
}
