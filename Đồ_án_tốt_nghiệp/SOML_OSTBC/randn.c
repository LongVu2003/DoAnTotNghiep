/*
 * randn.c
 *
 * Code generation for function 'randn'
 *
 */

/* Include files */
#include "randn.h"
#include "eml_rand_mt19937ar.h"
#include "rt_nonfinite.h"
#include "sm_ostbc_core_data.h"

/* Function Definitions */
void b_randn(double r[16])
{
  int k;
  for (k = 0; k < 16; k++) {
    r[k] = eml_rand_mt19937ar(state);
  }
}

void randn(double r[8])
{
  int k;
  for (k = 0; k < 8; k++) {
    r[k] = eml_rand_mt19937ar(state);
  }
}

/* End of code generation (randn.c) */
