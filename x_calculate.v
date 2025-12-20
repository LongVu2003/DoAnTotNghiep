module x_calculate #(
    parameter Q = 22,
    parameter N = 32
)
(
    // --- Interface ---
    input clk,
    input rst,

    
    // --- INPUT  ---
    input wire start_hq_calc,

    input wire signed [0 :N*8-1] H_row0_r,
    input wire signed [0 :N*8-1] H_row0_i,
    input wire signed [0 :N*8-1] H_row1_r,
    input wire signed [0 :N*8-1] H_row1_i,
    input wire signed [0 :N*8-1] H_row2_r,
    input wire signed [0 :N*8-1] H_row2_i,
    input wire signed [0 :N*8-1] H_row3_r,
    input wire signed [0 :N*8-1] H_row3_i,

    input wire [N-1:0] y_r0_r,
    input wire [N-1:0] y_r0_i,
    input wire [N-1:0] y_r1_r,
    input wire [N-1:0] y_r1_i,
    output wire g_valid,

    output wire signed [N-1:0] Dh_out,
    output wire invDh_valid,

    output wire signed [N-1:0] xI1_out,
    output wire signed [N-1:0] xQ1_out,
    output wire signed [N-1:0] xI2_out,
    output wire signed [N-1:0] xQ2_out
    
);


// Hq signals
wire hq_done, hq_valid, all_16_hq_done;
wire signed [N-1:0] hq_r, hq_i;

matrix_multiplier  #(.N(N), .Q(Q)) hq_calc_inst(
    .clk(clk),
    .rst(rst),
    .start(start_hq_calc),

    .H_row0_r(H_row0_r),
    .H_row0_i(H_row0_i),
    .H_row1_r(H_row1_r),
    .H_row1_i(H_row1_i),
    .H_row2_r(H_row2_r),
    .H_row2_i(H_row2_i),
    .H_row3_r(H_row3_r),
    .H_row3_i(H_row3_i),
    .hq_one_matrix_done(hq_done),
    .all_16_hq_done(all_16_hq_done),
    .Hq_valid(hq_valid),
    .Hq_out_r(hq_r),
    .Hq_out_i(hq_i)
);

wire Dh_result_valid;
Dh_cal #(.N(N), .Q(Q)) dh_calc_inst(
      .clk(clk),
      .rst(rst),
      .Dh_en(hq_valid),
      .in_real(hq_r),
      .in_im(hq_i),
      .Dh_out(Dh_out),
      .Dh_result_valid(Dh_result_valid)
);

wire div_ovr;
wire [N-1:0]  inversDh;

delay_module #(.N(1), .NUM_DELAY(35)) invDh_Valid_inst(
    .clk(clk),
    .rst(rst),
    .in(Dh_result_valid),
    .out(invDh_valid)
);		
fxp_div_pipe #( 
    .WIIA  (N-Q),
    .WIFA  (Q),
    .WIIB  (N-Q),
    .WIFB  (Q),
    .WOI   (N-Q),
    .WOF   (Q),
    .ROUND (0)
) invDh_inst(
    .rstn(!rst),
    .clk(clk),
    .dividend(32'd1<<Q),
    .divisor(Dh_out),
    .out(inversDh),
    .overflow(div_ovr)
);

wire signed [N-1:0] Ga1_c0_r, Ga1_c0_i, Ga1_c1_r, Ga1_c1_i;
wire signed [N-1:0] Ga2_c0_r, Ga2_c0_i, Ga2_c1_r, Ga2_c1_i;
wire signed [N-1:0] Gb1_c0_r, Gb1_c0_i, Gb1_c1_r, Gb1_c1_i;
wire signed [N-1:0] Gb2_c0_r, Gb2_c0_i, Gb2_c1_r, Gb2_c1_i;

g_matrix_calculator #(.N(N)) g_matrix_inst(
	.clk(clk),
	.rst(rst),
	.Hq_in_valid(hq_valid),
	.Hq_in_r(hq_r),
	.Hq_in_i(hq_i),
	.G_valid(g_valid),
	.Ga1_c0_r(Ga1_c0_r), .Ga1_c0_i(Ga1_c0_i), .Ga1_c1_r(Ga1_c1_r), .Ga1_c1_i(Ga1_c1_i),
	.Ga2_c0_r(Ga2_c0_r), .Ga2_c0_i(Ga2_c0_i), .Ga2_c1_r(Ga2_c1_r), .Ga2_c1_i(Ga2_c1_i),
	.Gb1_c0_r(Gb1_c0_r), .Gb1_c0_i(Gb1_c0_i), .Gb1_c1_r(Gb1_c1_r), .Gb1_c1_i(Gb1_c1_i),
	.Gb2_c0_r(Gb2_c0_r), .Gb2_c0_i(Gb2_c0_i), .Gb2_c1_r(Gb2_c1_r), .Gb2_c1_i(Gb2_c1_i)
);


wire signed [N-1:0] ga1_r,ga1_i,ga2_r,ga2_i,gb1_r,gb1_i,gb2_r,gb2_i;

trace_calculator #(
  .N(N)
) traceGa1 (
  .clk(clk),
  .rst(rst),
  .cal_en(g_valid),
  .y_r0_r(y_r0_r),
  .y_r0_i(y_r0_i),
  .y_r1_r(y_r1_r),
  .y_r1_i(y_r1_i),
  .g_c0_r(Ga1_c0_r),
  .g_c0_i(Ga1_c0_i),
  .g_c1_r(Ga1_c1_r),
  .g_c1_i(Ga1_c1_i),
  .trace_result_r(ga1_r),
  .trace_result_i(ga1_i)
);
trace_calculator #(
  .N(N)
) traceGa2 (
  .clk(clk),
  .rst(rst),
  .cal_en(g_valid),
  .y_r0_r(y_r0_r),
  .y_r0_i(y_r0_i),
  .y_r1_r(y_r1_r),
  .y_r1_i(y_r1_i),
  .g_c0_r(Ga2_c0_r),
  .g_c0_i(Ga2_c0_i),
  .g_c1_r(Ga2_c1_r),
  .g_c1_i(Ga2_c1_i),
  .trace_result_r(ga2_r),
  .trace_result_i(ga2_i)
);

trace_calculator #(
  .N(N)
) traceGb1 (
  .clk(clk),
  .rst(rst),
  .cal_en(g_valid),
  .y_r0_r(y_r0_r),
  .y_r0_i(y_r0_i),
  .y_r1_r(y_r1_r),
  .y_r1_i(y_r1_i),
  .g_c0_r(Gb1_c0_r),
  .g_c0_i(Gb1_c0_i),
  .g_c1_r(Gb1_c1_r),
  .g_c1_i(Gb1_c1_i),
  .trace_result_r(gb1_r),
  .trace_result_i(gb1_i)
);

trace_calculator #(
  .N(N)
) traceGb2 (
  .clk(clk),
  .rst(rst),
  .cal_en(g_valid),
  .y_r0_r(y_r0_r),
  .y_r0_i(y_r0_i),
  .y_r1_r(y_r1_r),
  .y_r1_i(y_r1_i),
  .g_c0_r(Gb2_c0_r),
  .g_c0_i(Gb2_c0_i),
  .g_c1_r(Gb2_c1_r),
  .g_c1_i(Gb2_c1_i),
  .trace_result_r(gb2_r),
  .trace_result_i(gb2_i)
);

wire signed [N-1:0] ga1_r_delay, ga2_r_delay,gb1_i_delay,gb2_i_delay;
delay_module #(.N(N), .NUM_DELAY(23)) delay_ga1(
    .clk(clk),
    .rst(rst),
    .in(ga1_r),
    .out(ga1_r_delay)
);
delay_module #(.N(N), .NUM_DELAY(23)) delay_ga2(
    .clk(clk),
    .rst(rst),
    .in(ga2_r),
    .out(ga2_r_delay)
);
delay_module #(.N(N), .NUM_DELAY(23)) delay_gb1(
    .clk(clk),
    .rst(rst),
    .in(gb1_i),
    .out(gb1_i_delay)
);
delay_module #(.N(N), .NUM_DELAY(23)) delay_gb2(
    .clk(clk),
    .rst(rst),
    .in(gb2_i),
    .out(gb2_i_delay)
);

wire ovr_xi1,ovr_xi2,ovr_xq1,ovr_xq2;
wire signed [N-1:0] xI1_out_tmp,xI2_out_tmp,xQ1_out_tmp,xQ2_out_tmp;


qmult #(.Q(Q), .N(N)) xi1_cal_inst (
    .i_multiplicand(ga1_r_delay),
    .i_multiplier(inversDh),
    .o_result(xI1_out_tmp),
    .ovr(ovr_xi1)
);
qmult #(.Q(Q), .N(N)) xi2_cal_inst (
    .i_multiplicand(ga2_r_delay),
    .i_multiplier(inversDh),
    .o_result(xI2_out_tmp),
    .ovr(ovr_xi2)
);
qmult #(.Q(Q), .N(N)) xq1_cal_inst (
    .i_multiplicand(gb1_i_delay),
    .i_multiplier(inversDh),
    .o_result(xQ1_out_tmp),
    .ovr(ovr_xq1)
);
qmult #(.Q(Q), .N(N)) xq2_cal_inst (
    .i_multiplicand(gb2_i_delay),
    .i_multiplier(inversDh),
    .o_result(xQ2_out_tmp),
    .ovr(ovr_xq2)
);

assign xI1_out = xI1_out_tmp;
assign xI2_out = xI2_out_tmp;
assign xQ1_out = -xQ1_out_tmp;
assign xQ2_out = -xQ2_out_tmp;


endmodule