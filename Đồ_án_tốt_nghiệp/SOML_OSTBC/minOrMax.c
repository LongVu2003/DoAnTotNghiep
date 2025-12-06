/*
 * minOrMax.c
 *
 * Code generation for function 'minOrMax'
 *
 */

/* Include files */
#include "minOrMax.h"
#include "rt_nonfinite.h"
#include "rt_nonfinite.h"

/* Function Definitions */
double b_minimum(const double x[16], int *idx)
{
  double ex;
  int b_idx;
  int b_k;
  if (!rtIsNaN(x[0])) {
    b_idx = 1;
  } else {
    int k;
    boolean_T exitg1;
    b_idx = 0;
    k = 2;
    exitg1 = false;
    while ((!exitg1) && (k < 17)) {
      if (!rtIsNaN(x[k - 1])) {
        b_idx = k;
        exitg1 = true;
      } else {
        k++;
      }
    }
  }
  if (b_idx == 0) {
    ex = x[0];
    *idx = 1;
  } else {
    ex = x[b_idx - 1];
    *idx = b_idx;
    b_idx++;
    for (b_k = b_idx; b_k < 17; b_k++) {
      double d;
      d = x[b_k - 1];
      if (ex > d) {
        ex = d;
        *idx = b_k;
      }
    }
  }
  return ex;
}

void minimum(const double x[64], double ex[16], int idx[16])
{
  int i;
  int j;
  for (j = 0; j < 16; j++) {
    int ex_tmp;
    idx[j] = 1;
    ex_tmp = j << 2;
    ex[j] = x[ex_tmp];
    for (i = 0; i < 3; i++) {
      double d;
      boolean_T p;
      d = x[(i + ex_tmp) + 1];
      if (rtIsNaN(d)) {
        p = false;
      } else {
        double d1;
        d1 = ex[j];
        if (rtIsNaN(d1)) {
          p = true;
        } else {
          p = (d1 > d);
        }
      }
      if (p) {
        ex[j] = d;
        idx[j] = i + 2;
      }
    }
  }
}

/* End of code generation (minOrMax.c) */
