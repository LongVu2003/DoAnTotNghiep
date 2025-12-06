/*
 * rng.c
 *
 * Code generation for function 'rng'
 *
 */

/* Include files */
#include "rng.h"
#include "rt_nonfinite.h"
#include "sm_ostbc_core_data.h"

/* Function Definitions */
void rng(double varargin_1)
{
  int mti;
  unsigned int r;
  if (varargin_1 < 4.294967296E+9) {
    if (varargin_1 >= 0.0) {
      r = (unsigned int)varargin_1;
    } else {
      r = 0U;
    }
  } else if (varargin_1 >= 4.294967296E+9) {
    r = MAX_uint32_T;
  } else {
    r = 0U;
  }
  if (r == 0U) {
    r = 5489U;
  }
  state[0] = r;
  for (mti = 0; mti < 623; mti++) {
    r = ((r ^ r >> 30U) * 1812433253U + (unsigned int)mti) + 1U;
    state[mti + 1] = r;
  }
  state[624] = 624U;
}

/* End of code generation (rng.c) */
