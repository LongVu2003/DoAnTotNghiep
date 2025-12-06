/*
* Module: trace_calculator
* Chức năng: Tính tử số trace(YH * G) cho khối x_metric_calculator.
* Y có kích thước 4x2, G có kích thước 4x2. YH là 2x4. Tích YH*G là 2x2.
*/
module trace_calculator #(
    parameter N = 16,
    parameter Q = 8,
    parameter ACC_WIDTH = 32
)
(
    input clk,
    input rst,
    input  cal_en, // Bắt đầu tính

    input signed [N-1:0] y_r0_r,y_r0_i,
    input signed [N-1:0] y_r1_r,y_r1_i,

    input signed [N-1:0] g_c0_r,g_c0_i,
    input signed [N-1:0] g_c1_r,g_c1_i,

    output signed [N-1:0] trace_result_r,
    output signed [N-1:0] trace_result_i
);
wire signed [N-1:0] value00_r,value00_i,value11_r,value11_i;
wire value00_valid, value11_valid;
 c_mac #(
        .Q(Q),
        .N(N)
    ) value00_inst (
        .clk(clk),
        .rst(rst),
        .mac_en(cal_en),
        .in_ar(y_r0_r),
        .in_ai(y_r0_i),
        .in_br(g_c0_r),
        .in_bi(g_c0_i),
        .mac_r_out(value00_r),
        .mac_i_out(value00_i),
        .mac_result_valid(value00_valid)
    );
 c_mac #(
        .Q(Q),
        .N(N)
    ) value11_inst (
        .clk(clk),
        .rst(rst),
        .mac_en(cal_en),
        .in_ar(y_r1_r),
        .in_ai(y_r1_i),
        .in_br(g_c1_r),
        .in_bi(g_c1_i),
        .mac_r_out(value11_r),
        .mac_i_out(value11_i),
        .mac_result_valid(value11_valid)
    );

assign trace_result_r = value00_r + value11_r;
assign trace_result_i = value00_i + value11_i;

endmodule
