/*
 * find.c
 *
 * Code generation for function 'find'
 *
 */

/* Include files */
#include "find.h"
#include "rt_nonfinite.h"

/* Function Definitions */
int b_eml_find(const boolean_T x[8], int i_data[])
{
  int i_size;
  int ii;
  boolean_T exitg1;
  i_size = 0;
  ii = 0;
  exitg1 = false;
  while ((!exitg1) && (ii < 8)) {
    if (x[ii]) {
      i_size++;
      i_data[i_size - 1] = ii + 1;
      if (i_size >= 8) {
        exitg1 = true;
      } else {
        ii++;
      }
    } else {
      ii++;
    }
  }
  if (i_size < 1) {
    i_size = 0;
  }
  return i_size;
}

void eml_find(const boolean_T x[4], int i_data[], int i_size[2])
{
  int idx;
  int ii;
  boolean_T exitg1;
  idx = 0;
  i_size[0] = 1;
  ii = 0;
  exitg1 = false;
  while ((!exitg1) && (ii < 4)) {
    if (x[ii]) {
      idx++;
      i_data[idx - 1] = ii + 1;
      if (idx >= 4) {
        exitg1 = true;
      } else {
        ii++;
      }
    } else {
      ii++;
    }
  }
  if (idx < 1) {
    i_size[1] = 0;
  } else {
    i_size[1] = idx;
  }
}

/* End of code generation (find.c) */
