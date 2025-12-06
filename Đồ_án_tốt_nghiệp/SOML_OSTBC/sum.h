/*
 * sum.h
 *
 * Code generation for function 'sum'
 *
 */

#ifndef SUM_H
#define SUM_H

/* Include files */
#include "rtwtypes.h"
#include <stddef.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Function Declarations */
void b_sum(const double x[32], double y[16]);

void c_sum(const double x[64], double y[32]);

void d_sum(const double x[64], double y[16]);

void sum(const creal_T x[128], creal_T y[32]);

#ifdef __cplusplus
}
#endif

#endif
/* End of code generation (sum.h) */
