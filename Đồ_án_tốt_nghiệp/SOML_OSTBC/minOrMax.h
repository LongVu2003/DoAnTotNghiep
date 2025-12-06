/*
 * minOrMax.h
 *
 * Code generation for function 'minOrMax'
 *
 */

#ifndef MINORMAX_H
#define MINORMAX_H

/* Include files */
#include "rtwtypes.h"
#include <stddef.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Function Declarations */
double b_minimum(const double x[16], int *idx);

void minimum(const double x[64], double ex[16], int idx[16]);

#ifdef __cplusplus
}
#endif

#endif
/* End of code generation (minOrMax.h) */
