/*
 * sm_ostbc_core.h
 *
 * Code generation for function 'sm_ostbc_core'
 *
 */

#ifndef SM_OSTBC_CORE_H
#define SM_OSTBC_CORE_H

/* Include files */
#include "rtwtypes.h"
#include <stddef.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Function Declarations */
extern void sm_ostbc_core(double SNRdB, double seed_val, double *numErrors,
                          creal_T H_out[16], creal_T Y_out[8]);

#ifdef __cplusplus
}
#endif

#endif
/* End of code generation (sm_ostbc_core.h) */
