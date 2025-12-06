module Rq_cal #(
	parameter  N = 16,
	parameter  Q = 8
) (
	input  signed [N-1:0] xi1_in, xi2_in,xq1_in,xq2_in,
	output signed [N-1:0] Rq_out
);

wire signed [N-1:0] tmp_rq1,tmp_rq2,tmp_rq3,tmp_rq4;
wire ovr_rq1,ovr_rq2,ovr_rq3,ovr_rq4;

qmult #(.Q(Q), .N(N)) qmul_rq1 (
    .i_multiplicand(xi1_in),
    .i_multiplier(xi1_in),
    .o_result(tmp_rq1),
    .ovr(ovr_rq1)
);

qmult #(.Q(Q), .N(N)) qmul_rq2 (
    .i_multiplicand(xi2_in),
    .i_multiplier(xi2_in),
    .o_result(tmp_rq2),
    .ovr(ovr_rq2)
);

qmult #(.Q(Q), .N(N)) qmul_rq3 (
    .i_multiplicand(xq1_in),
    .i_multiplier(xq1_in),
    .o_result(tmp_rq3),
    .ovr(ovr_rq3)
);
qmult #(.Q(Q), .N(N)) qmul_rq4 (
    .i_multiplicand(xq2_in),
    .i_multiplier(xq2_in),
    .o_result(tmp_rq4),
    .ovr(ovr_rq4)
);

assign Rq_out = tmp_rq1 + tmp_rq2 + tmp_rq3 + tmp_rq4;

endmodule
