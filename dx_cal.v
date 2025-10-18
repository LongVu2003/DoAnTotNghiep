module dx_cal #(
	parameter  N = 16,
	parameter  Q = 8
)(
	input  signed [N-1:0] x_in,
	output signed [N-1:0] d_out
);

wire  signed [N-1:0] dx_1, dx_2, dx_3, dx_4, dx_5;
wire ovr_dx1,ovr_dx2,ovr_dx3,ovr_dx4;

wire signed [N-1:0] v1,v2,v3,v4;
wire signed [N-1:0] tmp_1,tmp_2,tmp_3,tmp_4;

assign v1 = -3 << Q;
assign v2 = -1 << Q;
assign v3 =  1 << Q;
assign v4 =  3 << Q;
 
assign tmp_1 = v1 - xi1_in;
assign tmp_2 = v2 - xi1_in;
assign tmp_3 = v3 - xi1_in;
assign tmp_4 = v4 - xi1_in;

qmult #(.Q(Q), .N(N)) qmul_rq1 (
    .i_multiplicand(tmp_1),
    .i_multiplier(tmp_1),
    .o_result(dx_1),
    .ovr(ovr_dx1)
);

qmult #(.Q(Q), .N(N)) qmul_rq2 (
    .i_multiplicand(tmp_2),
    .i_multiplier(tmp_2),
    .o_result(dx_2),
    .ovr(ovr_dx2)
);

qmult #(.Q(Q), .N(N)) qmul_rq3 (
    .i_multiplicand(tmp_3),
    .i_multiplier(tmp_3),
    .o_result(dx_3),
    .ovr(ovr_dx3)
);
qmult #(.Q(Q), .N(N)) qmul_rq4 (
    .i_multiplicand(tmp_4),
    .i_multiplier(tmp_4),
    .o_result(dx_4),
    .ovr(ovr_dx4)
);


