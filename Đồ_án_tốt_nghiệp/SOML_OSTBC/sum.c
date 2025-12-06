/*
 * sum.c
 *
 * Code generation for function 'sum'
 *
 */

/* Include files */
#include "sum.h"
#include "rt_nonfinite.h"
#include <string.h>

/* Function Definitions */
void b_sum(const double x[32], double y[16])
{
  int xi;
  for (xi = 0; xi < 16; xi++) {
    int xpageoffset;
    xpageoffset = xi << 1;
    y[xi] = x[xpageoffset] + x[xpageoffset + 1];
  }
}

void c_sum(const double x[64], double y[32])
{
  int xi;
  for (xi = 0; xi < 32; xi++) {
    int xpageoffset;
    xpageoffset = xi << 1;
    y[xi] = x[xpageoffset] + x[xpageoffset + 1];
  }
}

void d_sum(const double x[64], double y[16])
{
  int k;
  int xj;
  memcpy(&y[0], &x[0], 16U * sizeof(double));
  for (k = 0; k < 3; k++) {
    int xoffset;
    xoffset = (k + 1) << 4;
    for (xj = 0; xj < 16; xj++) {
      y[xj] += x[xoffset + xj];
    }
  }
}

void sum(const creal_T x[128], creal_T y[32])
{
  int xi;
  for (xi = 0; xi < 32; xi++) {
    int xpageoffset;
    xpageoffset = xi << 2;
    y[xi].re =
        ((x[xpageoffset].re + x[xpageoffset + 1].re) + x[xpageoffset + 2].re) +
        x[xpageoffset + 3].re;
    y[xi].im =
        ((x[xpageoffset].im + x[xpageoffset + 1].im) + x[xpageoffset + 2].im) +
        x[xpageoffset + 3].im;
  }
}

/* End of code generation (sum.c) */
