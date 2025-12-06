/*
 * sm_ostbc_core_initialize.c
 *
 * Code generation for function 'sm_ostbc_core_initialize'
 *
 */

/* Include files */
#include "sm_ostbc_core_initialize.h"
#include "eml_rand_mt19937ar_stateful.h"
#include "rt_nonfinite.h"
#include "sm_ostbc_core_data.h"

/* Function Definitions */
void sm_ostbc_core_initialize(void)
{
  c_eml_rand_mt19937ar_stateful_i();
  isInitialized_sm_ostbc_core = true;
}

/* End of code generation (sm_ostbc_core_initialize.c) */
