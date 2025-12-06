/*
 * sm_ostbc_core.c
 *
 * Code generation for function 'sm_ostbc_core'
 *
 */

/* Include files */
#include "sm_ostbc_core.h"
#include "find.h"
#include "minOrMax.h"
#include "rand.h"
#include "randn.h"
#include "rng.h"
#include "rt_nonfinite.h"
#include "sm_ostbc_core_data.h"
#include "sm_ostbc_core_initialize.h"
#include "sum.h"
#include "rt_nonfinite.h"
#include <math.h>
#include <string.h>

/* Function Declarations */
static double rt_powd_snf(double u0, double u1);

/* Function Definitions */
static double rt_powd_snf(double u0, double u1)
{
  double y;
  if (rtIsNaN(u0) || rtIsNaN(u1)) {
    y = rtNaN;
  } else {
    double d;
    y = fabs(u0);
    d = fabs(u1);
    if (rtIsInf(u1)) {
      if (y == 1.0) {
        y = 1.0;
      } else if (y > 1.0) {
        if (u1 > 0.0) {
          y = rtInf;
        } else {
          y = 0.0;
        }
      } else if (u1 > 0.0) {
        y = 0.0;
      } else {
        y = rtInf;
      }
    } else if (d == 0.0) {
      y = 1.0;
    } else if (d == 1.0) {
      if (u1 > 0.0) {
        y = u0;
      } else {
        y = 1.0 / u0;
      }
    } else if (u1 == 2.0) {
      y = u0 * u0;
    } else if ((u1 == 0.5) && (u0 >= 0.0)) {
      y = sqrt(u0);
    } else if ((u0 < 0.0) && (u1 > floor(u1))) {
      y = rtNaN;
    } else {
      y = pow(u0, u1);
    }
  }
  return y;
}

void sm_ostbc_core(double SNRdB, double seed_val, double *numErrors,
                   creal_T H_out[16], creal_T Y_out[8])
{
  static const creal_T c_y[8] = {{
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     -0.5, /* re */
                                     0.0   /* im */
                                 },
                                 {
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     0.0, /* re */
                                     0.5  /* im */
                                 },
                                 {
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     0.0, /* re */
                                     0.5  /* im */
                                 },
                                 {
                                     0.5, /* re */
                                     0.0  /* im */
                                 }};
  static const creal_T d_y[8] = {{
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     -0.5, /* re */
                                     0.0   /* im */
                                 },
                                 {
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     -0.0, /* re */
                                     -0.5  /* im */
                                 },
                                 {
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     -0.0, /* re */
                                     -0.5  /* im */
                                 },
                                 {
                                     0.5, /* re */
                                     0.0  /* im */
                                 }};
  static const creal_T e_y[8] = {{
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     -0.5, /* re */
                                     0.0   /* im */
                                 },
                                 {
                                     -0.5, /* re */
                                     0.0   /* im */
                                 },
                                 {
                                     0.0, /* re */
                                     0.5  /* im */
                                 },
                                 {
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     0.0, /* re */
                                     0.5  /* im */
                                 },
                                 {
                                     -0.5, /* re */
                                     0.0   /* im */
                                 }};
  static const creal_T f_y[8] = {{
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     -0.5, /* re */
                                     0.0   /* im */
                                 },
                                 {
                                     -0.5, /* re */
                                     0.0   /* im */
                                 },
                                 {
                                     -0.0, /* re */
                                     -0.5  /* im */
                                 },
                                 {
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     -0.0, /* re */
                                     -0.5  /* im */
                                 },
                                 {
                                     -0.5, /* re */
                                     0.0   /* im */
                                 }};
  static const creal_T g_y[8] = {{
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     -0.5, /* re */
                                     0.0   /* im */
                                 },
                                 {
                                     0.0, /* re */
                                     0.5  /* im */
                                 },
                                 {
                                     -0.5, /* re */
                                     0.0   /* im */
                                 },
                                 {
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     0.0, /* re */
                                     0.5  /* im */
                                 }};
  static const creal_T h_y[8] = {{
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     -0.5, /* re */
                                     0.0   /* im */
                                 },
                                 {
                                     0.0, /* re */
                                     0.5  /* im */
                                 },
                                 {
                                     0.0, /* re */
                                     0.5  /* im */
                                 },
                                 {
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     0.0, /* re */
                                     0.5  /* im */
                                 },
                                 {
                                     0.0, /* re */
                                     0.5  /* im */
                                 }};
  static const creal_T i_y[8] = {{
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     -0.5, /* re */
                                     0.0   /* im */
                                 },
                                 {
                                     0.0, /* re */
                                     0.5  /* im */
                                 },
                                 {
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     -0.5, /* re */
                                     0.0   /* im */
                                 },
                                 {
                                     0.0, /* re */
                                     0.5  /* im */
                                 }};
  static const creal_T j_y[8] = {{
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     -0.5, /* re */
                                     0.0   /* im */
                                 },
                                 {
                                     0.0, /* re */
                                     0.5  /* im */
                                 },
                                 {
                                     -0.0, /* re */
                                     -0.5  /* im */
                                 },
                                 {
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     -0.0, /* re */
                                     -0.5  /* im */
                                 },
                                 {
                                     0.0, /* re */
                                     0.5  /* im */
                                 }};
  static const creal_T k_y[8] = {{
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     -0.5, /* re */
                                     0.0   /* im */
                                 },
                                 {
                                     -0.0, /* re */
                                     -0.5  /* im */
                                 },
                                 {
                                     -0.5, /* re */
                                     0.0   /* im */
                                 },
                                 {
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     -0.0, /* re */
                                     -0.5  /* im */
                                 }};
  static const creal_T l_y[8] = {{
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     -0.5, /* re */
                                     0.0   /* im */
                                 },
                                 {
                                     -0.0, /* re */
                                     -0.5  /* im */
                                 },
                                 {
                                     0.0, /* re */
                                     0.5  /* im */
                                 },
                                 {
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     0.0, /* re */
                                     0.5  /* im */
                                 },
                                 {
                                     -0.0, /* re */
                                     -0.5  /* im */
                                 }};
  static const creal_T m_y[8] = {{
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     -0.5, /* re */
                                     0.0   /* im */
                                 },
                                 {
                                     -0.0, /* re */
                                     -0.5  /* im */
                                 },
                                 {
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     -0.5, /* re */
                                     0.0   /* im */
                                 },
                                 {
                                     -0.0, /* re */
                                     -0.5  /* im */
                                 }};
  static const creal_T n_y[8] = {{
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     -0.5, /* re */
                                     0.0   /* im */
                                 },
                                 {
                                     -0.0, /* re */
                                     -0.5  /* im */
                                 },
                                 {
                                     -0.0, /* re */
                                     -0.5  /* im */
                                 },
                                 {
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     0.5, /* re */
                                     0.0  /* im */
                                 },
                                 {
                                     -0.0, /* re */
                                     -0.5  /* im */
                                 },
                                 {
                                     -0.0, /* re */
                                     -0.5  /* im */
                                 }};
  static const double dv[8] = {0.5, -0.5, 0.5, -0.5, 0.5, 0.5, 0.5, 0.5};
  static const double dv1[8] = {0.5, -0.5, 0.5, 0.5, 0.5, 0.5, -0.5, 0.5};
  static const double dv3[8] = {0.5, -0.5, -0.5, -0.5, 0.5, 0.5, 0.5, -0.5};
  static const double dv4[8] = {0.5, -0.5, -0.5, 0.5, 0.5, 0.5, -0.5, -0.5};
  static const signed char b_Bs[64] = {
      0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1,
      1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1,
      0, 0, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1};
  static const signed char dI_q_tmp[64] = {
      -3, -1, 1, 3, -3, -1, 1, 3, -3, -1, 1, 3, -3, -1, 1, 3,
      -3, -1, 1, 3, -3, -1, 1, 3, -3, -1, 1, 3, -3, -1, 1, 3,
      -3, -1, 1, 3, -3, -1, 1, 3, -3, -1, 1, 3, -3, -1, 1, 3,
      -3, -1, 1, 3, -3, -1, 1, 3, -3, -1, 1, 3, -3, -1, 1, 3};
  static const unsigned char uv[64] = {
      0U,   3U,   4U,   7U,   8U,   11U,  12U,  15U,  16U,  19U,  20U,
      23U,  24U,  27U,  28U,  31U,  32U,  35U,  36U,  39U,  40U,  43U,
      44U,  47U,  48U,  51U,  52U,  55U,  56U,  59U,  60U,  63U,  64U,
      67U,  68U,  71U,  72U,  75U,  76U,  79U,  80U,  83U,  84U,  87U,
      88U,  91U,  92U,  95U,  96U,  99U,  100U, 103U, 104U, 107U, 108U,
      111U, 112U, 115U, 116U, 119U, 120U, 123U, 124U, 127U};
  static const signed char Bv[8] = {0, 0, 1, 1, 0, 1, 1, 0};
  creal_T Hq[128];
  creal_T S[128];
  creal_T YH[64];
  creal_T dcv[32];
  creal_T b_S[8];
  creal_T x[8];
  creal_T b_A[4];
  double dI_q[64];
  double dtemp2[64];
  double dv6[32];
  double xI_q[32];
  double xQ_q[32];
  double Dh[16];
  double b_b[16];
  double dv5[16];
  double dv7[16];
  double dv8[16];
  double b[8];
  double dv2[8];
  double I_data[2];
  double Q_data[2];
  double H_out_re_tmp;
  double Sid;
  double ar;
  double b_H_out_re_tmp;
  double b_y;
  double c_H_out_re_tmp;
  double d_H_out_re_tmp;
  double e_H_out_re_tmp;
  double f_H_out_re_tmp;
  double g_H_out_re_tmp;
  double h_H_out_re_tmp;
  double i_H_out_re_tmp;
  double im;
  double re;
  double x_re;
  double y;
  int mIQ[64];
  int idx[16];
  int tmp_data[8];
  int b_tmp_data[4];
  int Bv_tmp;
  int S_re_tmp;
  int b_Bv_tmp;
  int i;
  int i1;
  int i2;
  int k1;
  int re_tmp;
  signed char A[8];
  signed char B[8];
  boolean_T b_Bv[8];
  boolean_T Bs[4];
  if (!isInitialized_sm_ostbc_core) {
    sm_ostbc_core_initialize();
  }
  /*  Input:  */
  /*    - SNRdB: Tỉ số tín hiệu trên nhiễu */
  /*    - seed_val: Giá trị khởi tạo (12-bit) để tái tạo ngẫu nhiên */
  /*  Output: */
  /*    - numErrors: Số lỗi bit (dùng để debug) */
  /*    - H_out: Ma trận kênh truyền (4x4) gửi sang FPGA */
  /*    - Y_out: Ma trận tín hiệu nhận (4x2) gửi sang FPGA */
  /*  --- 1. CẤU HÌNH HỆ THỐNG --- */
  /*  Khởi tạo bộ sinh số ngẫu nhiên dựa trên Seed đầu vào */
  /*  Điều này đảm bảo ESP32 và FPGA sẽ làm việc trên cùng bộ dữ liệu nếu cùng
   * seed */
  rng(seed_val);
  y = sqrt(rt_powd_snf(10.0, SNRdB / 10.0)) / 4.47213595499958;
  /*  --- 2. KHỞI TẠO HẰNG SỐ --- */
  A[0] = 1;
  A[4] = 0;
  A[1] = 0;
  A[5] = 1;
  A[2] = 0;
  A[6] = -1;
  A[3] = 1;
  A[7] = 0;
  B[0] = 1;
  B[4] = 0;
  B[1] = 0;
  B[5] = 1;
  B[2] = 0;
  B[6] = 1;
  B[3] = -1;
  B[7] = 0;
  /*  Khởi tạo phức cho S để tránh lỗi Coder */
  for (i = 0; i < 2; i++) {
    re_tmp = i << 2;
    S[re_tmp].re = dv[re_tmp];
    S[re_tmp].im = 0.0;
    S[re_tmp + 8] = c_y[re_tmp];
    S[re_tmp + 16].re = dv1[re_tmp];
    S[re_tmp + 16].im = 0.0;
    S[re_tmp + 24] = d_y[re_tmp];
    S[re_tmp + 32].re = dv3[re_tmp];
    S[re_tmp + 32].im = 0.0;
    S[re_tmp + 40] = e_y[re_tmp];
    S[re_tmp + 48].re = dv4[re_tmp];
    S[re_tmp + 48].im = 0.0;
    S[re_tmp + 56] = f_y[re_tmp];
    S[re_tmp + 64] = g_y[re_tmp];
    S[re_tmp + 72] = h_y[re_tmp];
    S[re_tmp + 80] = i_y[re_tmp];
    S[re_tmp + 88] = j_y[re_tmp];
    S[re_tmp + 96] = k_y[re_tmp];
    S[re_tmp + 104] = l_y[re_tmp];
    S[re_tmp + 112] = m_y[re_tmp];
    S[re_tmp + 120] = n_y[re_tmp];
    S[re_tmp + 1].re = dv[re_tmp + 1];
    S[re_tmp + 1].im = 0.0;
    S[re_tmp + 9] = c_y[re_tmp + 1];
    S[re_tmp + 17].re = dv1[re_tmp + 1];
    S[re_tmp + 17].im = 0.0;
    S[re_tmp + 25] = d_y[re_tmp + 1];
    S[re_tmp + 33].re = dv3[re_tmp + 1];
    S[re_tmp + 33].im = 0.0;
    S[re_tmp + 41] = e_y[re_tmp + 1];
    S[re_tmp + 49].re = dv4[re_tmp + 1];
    S[re_tmp + 49].im = 0.0;
    S[re_tmp + 57] = f_y[re_tmp + 1];
    S[re_tmp + 65] = g_y[re_tmp + 1];
    S[re_tmp + 73] = h_y[re_tmp + 1];
    S[re_tmp + 81] = i_y[re_tmp + 1];
    S[re_tmp + 89] = j_y[re_tmp + 1];
    S[re_tmp + 97] = k_y[re_tmp + 1];
    S[re_tmp + 105] = l_y[re_tmp + 1];
    S[re_tmp + 113] = m_y[re_tmp + 1];
    S[re_tmp + 121] = n_y[re_tmp + 1];
    S[re_tmp + 2].re = dv[re_tmp + 2];
    S[re_tmp + 2].im = 0.0;
    S[re_tmp + 10] = c_y[re_tmp + 2];
    S[re_tmp + 18].re = dv1[re_tmp + 2];
    S[re_tmp + 18].im = 0.0;
    S[re_tmp + 26] = d_y[re_tmp + 2];
    S[re_tmp + 34].re = dv3[re_tmp + 2];
    S[re_tmp + 34].im = 0.0;
    S[re_tmp + 42] = e_y[re_tmp + 2];
    S[re_tmp + 50].re = dv4[re_tmp + 2];
    S[re_tmp + 50].im = 0.0;
    S[re_tmp + 58] = f_y[re_tmp + 2];
    S[re_tmp + 66] = g_y[re_tmp + 2];
    S[re_tmp + 74] = h_y[re_tmp + 2];
    S[re_tmp + 82] = i_y[re_tmp + 2];
    S[re_tmp + 90] = j_y[re_tmp + 2];
    S[re_tmp + 98] = k_y[re_tmp + 2];
    S[re_tmp + 106] = l_y[re_tmp + 2];
    S[re_tmp + 114] = m_y[re_tmp + 2];
    S[re_tmp + 122] = n_y[re_tmp + 2];
    S[re_tmp + 3].re = dv[re_tmp + 3];
    S[re_tmp + 3].im = 0.0;
    S[re_tmp + 11] = c_y[re_tmp + 3];
    S[re_tmp + 19].re = dv1[re_tmp + 3];
    S[re_tmp + 19].im = 0.0;
    S[re_tmp + 27] = d_y[re_tmp + 3];
    S[re_tmp + 35].re = dv3[re_tmp + 3];
    S[re_tmp + 35].im = 0.0;
    S[re_tmp + 43] = e_y[re_tmp + 3];
    S[re_tmp + 51].re = dv4[re_tmp + 3];
    S[re_tmp + 51].im = 0.0;
    S[re_tmp + 59] = f_y[re_tmp + 3];
    S[re_tmp + 67] = g_y[re_tmp + 3];
    S[re_tmp + 75] = h_y[re_tmp + 3];
    S[re_tmp + 83] = i_y[re_tmp + 3];
    S[re_tmp + 91] = j_y[re_tmp + 3];
    S[re_tmp + 99] = k_y[re_tmp + 3];
    S[re_tmp + 107] = l_y[re_tmp + 3];
    S[re_tmp + 115] = m_y[re_tmp + 3];
    S[re_tmp + 123] = n_y[re_tmp + 3];
  }
  /*  --- 3. SINH DỮ LIỆU (1 MẪU DUY NHẤT) --- */
  Sid = b_rand();
  b_y = floor(Sid * 16.0);
  randn(b);
  randn(dv2);
  for (i = 0; i < 8; i++) {
    Sid = b[i];
    x[i].re = dv2[i] + 0.0 * Sid;
    x[i].im = Sid;
  }
  b_randn(b_b);
  b_randn(dv5);
  for (i = 0; i < 16; i++) {
    Sid = b_b[i];
    ar = dv5[i] + 0.0 * Sid;
    if (Sid == 0.0) {
      H_out[i].re = ar / 1.4142135623730951;
      H_out[i].im = 0.0;
    } else if (ar == 0.0) {
      H_out[i].re = 0.0;
      H_out[i].im = Sid / 1.4142135623730951;
    } else {
      H_out[i].re = ar / 1.4142135623730951;
      H_out[i].im = Sid / 1.4142135623730951;
    }
  }
  c_rand(I_data);
  I_data[0] = floor(I_data[0] * 4.0) + 1.0;
  I_data[1] = floor(I_data[1] * 4.0) + 1.0;
  c_rand(Q_data);
  Q_data[0] = floor(Q_data[0] * 4.0) + 1.0;
  Q_data[1] = floor(Q_data[1] * 4.0) + 1.0;
  /*  --- 4. MÔ PHỎNG PHÁT --- */
  Bv_tmp = 2 * ((signed char)I_data[0] - 1) - 3;
  b_Bv_tmp = 2 * ((signed char)Q_data[0] - 1) - 3;
  i1 = 2 * ((signed char)I_data[1] - 1) - 3;
  i2 = 2 * ((signed char)Q_data[1] - 1) - 3;
  for (i = 0; i < 2; i++) {
    int i3;
    int im_tmp;
    im_tmp = i << 1;
    b_A[im_tmp].re = A[im_tmp] * Bv_tmp + A[im_tmp + 4] * i1;
    b_A[im_tmp].im = B[im_tmp] * b_Bv_tmp + B[im_tmp + 4] * i2;
    b_A[im_tmp + 1].re = A[im_tmp + 1] * Bv_tmp + A[im_tmp + 5] * i1;
    b_A[im_tmp + 1].im = B[im_tmp + 1] * b_Bv_tmp + B[im_tmp + 5] * i2;
    i3 = i << 2;
    x_re = 0.0;
    H_out_re_tmp = 0.0;
    b_H_out_re_tmp = 0.0;
    c_H_out_re_tmp = 0.0;
    d_H_out_re_tmp = 0.0;
    e_H_out_re_tmp = 0.0;
    h_H_out_re_tmp = 0.0;
    f_H_out_re_tmp = 0.0;
    for (k1 = 0; k1 < 2; k1++) {
      re_tmp = k1 + im_tmp;
      re = b_A[re_tmp].re;
      im = b_A[re_tmp].im;
      S_re_tmp = (k1 << 2) + (((int)(b_y + 1.0) - 1) << 3);
      Sid = S[S_re_tmp].re;
      ar = S[S_re_tmp].im;
      x_re += Sid * re - ar * im;
      H_out_re_tmp += Sid * im + ar * re;
      Sid = S[S_re_tmp + 1].re;
      ar = S[S_re_tmp + 1].im;
      b_H_out_re_tmp += Sid * re - ar * im;
      c_H_out_re_tmp += Sid * im + ar * re;
      Sid = S[S_re_tmp + 2].re;
      ar = S[S_re_tmp + 2].im;
      d_H_out_re_tmp += Sid * re - ar * im;
      e_H_out_re_tmp += Sid * im + ar * re;
      Sid = S[S_re_tmp + 3].re;
      ar = S[S_re_tmp + 3].im;
      h_H_out_re_tmp += Sid * re - ar * im;
      f_H_out_re_tmp += Sid * im + ar * re;
    }
    b_S[i3 + 3].im = f_H_out_re_tmp;
    b_S[i3 + 3].re = h_H_out_re_tmp;
    b_S[i3 + 2].im = e_H_out_re_tmp;
    b_S[i3 + 2].re = d_H_out_re_tmp;
    b_S[i3 + 1].im = c_H_out_re_tmp;
    b_S[i3 + 1].re = b_H_out_re_tmp;
    b_S[i3].im = H_out_re_tmp;
    b_S[i3].re = x_re;
  }
  for (i = 0; i < 4; i++) {
    H_out_re_tmp = H_out[i].re;
    b_H_out_re_tmp = H_out[i].im;
    c_H_out_re_tmp = H_out[i + 4].re;
    d_H_out_re_tmp = H_out[i + 4].im;
    e_H_out_re_tmp = H_out[i + 8].re;
    f_H_out_re_tmp = H_out[i + 8].im;
    re = H_out[i + 12].re;
    g_H_out_re_tmp = H_out[i + 12].im;
    for (k1 = 0; k1 < 2; k1++) {
      double j_H_out_re_tmp;
      double k_H_out_re_tmp;
      double l_H_out_re_tmp;
      double m_H_out_re_tmp;
      double n_H_out_re_tmp;
      re_tmp = k1 << 2;
      i_H_out_re_tmp = b_S[re_tmp].im;
      h_H_out_re_tmp = b_S[re_tmp].re;
      im = b_S[re_tmp + 1].im;
      j_H_out_re_tmp = b_S[re_tmp + 1].re;
      k_H_out_re_tmp = b_S[re_tmp + 2].im;
      l_H_out_re_tmp = b_S[re_tmp + 2].re;
      m_H_out_re_tmp = b_S[re_tmp + 3].im;
      n_H_out_re_tmp = b_S[re_tmp + 3].re;
      re_tmp += i;
      Sid = x[re_tmp].re;
      ar = x[re_tmp].im;
      if (ar == 0.0) {
        Sid /= 1.4142135623730951;
        ar = 0.0;
      } else if (Sid == 0.0) {
        Sid = 0.0;
        ar /= 1.4142135623730951;
      } else {
        Sid /= 1.4142135623730951;
        ar /= 1.4142135623730951;
      }
      if (ar == 0.0) {
        x_re = Sid / y;
        Sid = 0.0;
      } else if (Sid == 0.0) {
        x_re = 0.0;
        Sid = ar / y;
      } else {
        x_re = Sid / y;
        Sid = ar / y;
      }
      Y_out[re_tmp].re =
          ((((H_out_re_tmp * h_H_out_re_tmp - b_H_out_re_tmp * i_H_out_re_tmp) +
             (c_H_out_re_tmp * j_H_out_re_tmp - d_H_out_re_tmp * im)) +
            (e_H_out_re_tmp * l_H_out_re_tmp -
             f_H_out_re_tmp * k_H_out_re_tmp)) +
           (re * n_H_out_re_tmp - g_H_out_re_tmp * m_H_out_re_tmp)) +
          x_re;
      Y_out[re_tmp].im =
          ((((H_out_re_tmp * i_H_out_re_tmp + b_H_out_re_tmp * h_H_out_re_tmp) +
             (c_H_out_re_tmp * im + d_H_out_re_tmp * j_H_out_re_tmp)) +
            (e_H_out_re_tmp * k_H_out_re_tmp +
             f_H_out_re_tmp * l_H_out_re_tmp)) +
           (re * m_H_out_re_tmp + g_H_out_re_tmp * n_H_out_re_tmp)) +
          Sid;
    }
  }
  /*  --- 5. GÁN OUTPUT --- */
  /*  --- 6. GIẢI MÃ (DETECTION) --- */
  for (i = 0; i < 32; i++) {
    S_re_tmp = i << 2;
    x_re = 0.0;
    H_out_re_tmp = 0.0;
    b_H_out_re_tmp = 0.0;
    c_H_out_re_tmp = 0.0;
    g_H_out_re_tmp = 0.0;
    d_H_out_re_tmp = 0.0;
    e_H_out_re_tmp = 0.0;
    i_H_out_re_tmp = 0.0;
    for (k1 = 0; k1 < 4; k1++) {
      re_tmp = k1 + S_re_tmp;
      re = S[re_tmp].re;
      im = S[re_tmp].im;
      re_tmp = k1 << 2;
      Sid = H_out[re_tmp].re;
      ar = H_out[re_tmp].im;
      x_re += Sid * re - ar * im;
      H_out_re_tmp += Sid * im + ar * re;
      Sid = H_out[re_tmp + 1].re;
      ar = H_out[re_tmp + 1].im;
      b_H_out_re_tmp += Sid * re - ar * im;
      c_H_out_re_tmp += Sid * im + ar * re;
      Sid = H_out[re_tmp + 2].re;
      ar = H_out[re_tmp + 2].im;
      g_H_out_re_tmp += Sid * re - ar * im;
      d_H_out_re_tmp += Sid * im + ar * re;
      Sid = H_out[re_tmp + 3].re;
      ar = H_out[re_tmp + 3].im;
      e_H_out_re_tmp += Sid * re - ar * im;
      i_H_out_re_tmp += Sid * im + ar * re;
    }
    Hq[S_re_tmp + 3].im = i_H_out_re_tmp;
    Hq[S_re_tmp + 3].re = e_H_out_re_tmp;
    Hq[S_re_tmp + 2].im = d_H_out_re_tmp;
    Hq[S_re_tmp + 2].re = g_H_out_re_tmp;
    Hq[S_re_tmp + 1].im = c_H_out_re_tmp;
    Hq[S_re_tmp + 1].re = b_H_out_re_tmp;
    Hq[S_re_tmp].im = H_out_re_tmp;
    Hq[S_re_tmp].re = x_re;
  }
  /*  Ép kiểu real() để an toàn cho Coder */
  for (i = 0; i < 128; i++) {
    Sid = Hq[i].re;
    ar = Hq[i].im;
    S[i].re = Sid * Sid - ar * -ar;
    S[i].im = Sid * -ar + ar * Sid;
  }
  sum(S, dcv);
  for (i = 0; i < 32; i++) {
    dv6[i] = dcv[i].re;
  }
  b_sum(dv6, Dh);
  for (i = 0; i < 32; i++) {
    re_tmp = i << 1;
    Sid = 0.0;
    ar = 0.0;
    b_H_out_re_tmp = 0.0;
    c_H_out_re_tmp = 0.0;
    for (k1 = 0; k1 < 4; k1++) {
      S_re_tmp = k1 + (i << 2);
      re = Hq[S_re_tmp].re;
      im = Hq[S_re_tmp].im;
      x_re = Y_out[k1].re;
      H_out_re_tmp = -Y_out[k1].im;
      Sid += x_re * re - H_out_re_tmp * im;
      ar += x_re * im + H_out_re_tmp * re;
      x_re = Y_out[k1 + 4].re;
      H_out_re_tmp = -Y_out[k1 + 4].im;
      b_H_out_re_tmp += x_re * re - H_out_re_tmp * im;
      c_H_out_re_tmp += x_re * im + H_out_re_tmp * re;
    }
    YH[re_tmp + 1].im = c_H_out_re_tmp;
    YH[re_tmp + 1].re = b_H_out_re_tmp;
    YH[re_tmp].im = ar;
    YH[re_tmp].re = Sid;
  }
  memset(&S[0], 0, 128U * sizeof(creal_T));
  memset(&Hq[0], 0, 128U * sizeof(creal_T));
  for (i = 0; i < 32; i++) {
    re_tmp = i << 1;
    Sid = YH[re_tmp].re;
    b_H_out_re_tmp = YH[re_tmp].im;
    ar = 0.0 * b_H_out_re_tmp;
    c_H_out_re_tmp = 0.0 * Sid;
    g_H_out_re_tmp = c_H_out_re_tmp - ar;
    h_H_out_re_tmp = ar + c_H_out_re_tmp;
    d_H_out_re_tmp = YH[re_tmp + 1].re;
    f_H_out_re_tmp = YH[re_tmp + 1].im;
    e_H_out_re_tmp = 0.0 * f_H_out_re_tmp;
    re = 0.0 * d_H_out_re_tmp;
    i_H_out_re_tmp = (Sid - ar) + (re - e_H_out_re_tmp);
    S[re_tmp].re = i_H_out_re_tmp;
    x_re = (b_H_out_re_tmp + c_H_out_re_tmp) + (e_H_out_re_tmp + re);
    S[re_tmp].im = x_re;
    H_out_re_tmp = g_H_out_re_tmp + (d_H_out_re_tmp - e_H_out_re_tmp);
    S[re_tmp + 1].re = H_out_re_tmp;
    b_H_out_re_tmp = h_H_out_re_tmp + (f_H_out_re_tmp + re);
    S[re_tmp + 1].im = b_H_out_re_tmp;
    ar = g_H_out_re_tmp + (-d_H_out_re_tmp - e_H_out_re_tmp);
    S[re_tmp + 64].re = ar;
    Sid = h_H_out_re_tmp + (-f_H_out_re_tmp + re);
    S[re_tmp + 64].im = Sid;
    S[re_tmp + 65].re = i_H_out_re_tmp;
    S[re_tmp + 65].im = x_re;
    Hq[re_tmp].re = i_H_out_re_tmp;
    Hq[re_tmp].im = x_re;
    Hq[re_tmp + 1].re = ar;
    Hq[re_tmp + 1].im = Sid;
    Hq[re_tmp + 64].re = H_out_re_tmp;
    Hq[re_tmp + 64].im = b_H_out_re_tmp;
    Hq[re_tmp + 65].re = i_H_out_re_tmp;
    Hq[re_tmp + 65].im = x_re;
  }
  for (i = 0; i < 64; i++) {
    dI_q[i] = S[uv[i]].re;
  }
  c_sum(dI_q, dv6);
  for (i = 0; i < 16; i++) {
    re_tmp = i << 1;
    Sid = Dh[i];
    xI_q[re_tmp] = dv6[i] / Sid;
    xI_q[re_tmp + 1] = dv6[i + 16] / Sid;
  }
  for (i = 0; i < 64; i++) {
    dI_q[i] = Hq[uv[i]].im;
  }
  c_sum(dI_q, dv6);
  for (i = 0; i < 16; i++) {
    re_tmp = i << 1;
    Sid = Dh[i];
    xQ_q[re_tmp] = -dv6[i] / Sid;
    xQ_q[re_tmp + 1] = -dv6[i + 16] / Sid;
  }
  for (k1 = 0; k1 < 2; k1++) {
    for (i = 0; i < 16; i++) {
      re_tmp = i << 2;
      Sid = xI_q[k1 + (i << 1)];
      dI_q[re_tmp] = (double)dI_q_tmp[re_tmp] - Sid;
      dI_q[re_tmp + 1] = (double)dI_q_tmp[re_tmp + 1] - Sid;
      dI_q[re_tmp + 2] = (double)dI_q_tmp[re_tmp + 2] - Sid;
      dI_q[re_tmp + 3] = (double)dI_q_tmp[re_tmp + 3] - Sid;
    }
    for (i = 0; i < 64; i++) {
      Sid = dI_q[i];
      Sid *= Sid;
      dI_q[i] = Sid;
    }
    minimum(dI_q, b_b, idx);
    S_re_tmp = (k1 + 1) << 1;
    for (i = 0; i < 16; i++) {
      re_tmp = i + ((S_re_tmp - 2) << 4);
      dtemp2[re_tmp] = b_b[i];
      mIQ[re_tmp] = idx[i];
      re_tmp = i << 2;
      Sid = xQ_q[k1 + (i << 1)];
      dI_q[re_tmp] = (double)dI_q_tmp[re_tmp] - Sid;
      dI_q[re_tmp + 1] = (double)dI_q_tmp[re_tmp + 1] - Sid;
      dI_q[re_tmp + 2] = (double)dI_q_tmp[re_tmp + 2] - Sid;
      dI_q[re_tmp + 3] = (double)dI_q_tmp[re_tmp + 3] - Sid;
    }
    for (i = 0; i < 64; i++) {
      Sid = dI_q[i];
      Sid *= Sid;
      dI_q[i] = Sid;
    }
    minimum(dI_q, b_b, idx);
    memcpy(&dtemp2[S_re_tmp * 16 + -16], &b_b[0], 16U * sizeof(double));
    memcpy(&mIQ[S_re_tmp * 16 + -16], &idx[0], 16U * sizeof(int));
  }
  d_sum(dtemp2, dv5);
  for (i = 0; i < 32; i++) {
    Sid = xI_q[i];
    Sid *= Sid;
    xI_q[i] = Sid;
    Sid = xQ_q[i];
    Sid *= Sid;
    xQ_q[i] = Sid;
  }
  b_sum(xI_q, b_b);
  b_sum(xQ_q, dv7);
  for (i = 0; i < 16; i++) {
    dv8[i] = (dv5[i] - (b_b[i] + dv7[i])) * Dh[i];
  }
  b_minimum(dv8, &re_tmp);
  Bs[0] = (b_Bs[re_tmp - 1] != b_Bs[(int)(b_y + 1.0) - 1]);
  Bs[1] = (b_Bs[re_tmp + 15] != b_Bs[(int)(b_y + 1.0) + 15]);
  Bs[2] = (b_Bs[re_tmp + 31] != b_Bs[(int)(b_y + 1.0) + 31]);
  Bs[3] = (b_Bs[re_tmp + 47] != b_Bs[(int)(b_y + 1.0) + 47]);
  S_re_tmp = mIQ[re_tmp - 1];
  A[0] = Bv[S_re_tmp - 1];
  Bv_tmp = mIQ[re_tmp + 15];
  A[4] = Bv[Bv_tmp - 1];
  B[0] = Bv[(int)I_data[0] - 1];
  B[4] = Bv[(int)Q_data[0] - 1];
  b_Bv_tmp = mIQ[re_tmp + 31];
  A[1] = Bv[b_Bv_tmp - 1];
  re_tmp = mIQ[re_tmp + 47];
  A[5] = Bv[re_tmp - 1];
  B[1] = Bv[(int)I_data[1] - 1];
  B[5] = Bv[(int)Q_data[1] - 1];
  A[2] = Bv[S_re_tmp + 3];
  A[6] = Bv[Bv_tmp + 3];
  B[2] = Bv[(int)I_data[0] + 3];
  B[6] = Bv[(int)Q_data[0] + 3];
  A[3] = Bv[b_Bv_tmp + 3];
  A[7] = Bv[re_tmp + 3];
  B[3] = Bv[(int)I_data[1] + 3];
  B[7] = Bv[(int)Q_data[1] + 3];
  for (i = 0; i < 8; i++) {
    b_Bv[i] = (A[i] != B[i]);
  }
  int tmp_size[2];
  re_tmp = b_eml_find(b_Bv, tmp_data);
  eml_find(Bs, b_tmp_data, tmp_size);
  *numErrors = re_tmp + tmp_size[1];
}

/* End of code generation (sm_ostbc_core.c) */
