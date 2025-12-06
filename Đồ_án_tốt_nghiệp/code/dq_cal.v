module dq_cal #(
	parameter N = 16,
	parameter Q = 8
)(
	input clk,rst,
	input signed [N-1:0] dI1,dI2,dQ1,dQ2,
	input signed [N-1:0] Rq,
	input signed [N-1:0] Dh,
	output signed [N-1:0] dq_out  
);

wire ovr_dq;
reg signed [N-1:0] add1,add2,add3,add4,Rq_d,Rq_dd,Dh_d,Dh_dd,Dh_ddd;

always @(posedge clk) begin
	if(rst) begin
	end
	else begin
		add1 <= dI1 + dQ1;
		add2 <= dI2 + dQ2;
		add3 <= add1 + add2;
		add4 <= add3 - Rq_dd; 
	end
end

always @(posedge clk) begin
	if(rst) begin
	
	end
	else begin
		Rq_d  <= Rq;
		Rq_dd <= Rq_d;
		Dh_d  <= Dh;
		Dh_dd <= Dh_d;
		Dh_ddd<= Dh_dd;
	end
end
qmult #(.Q(Q), .N(N)) qmult_dq (
    .i_multiplicand(Dh_ddd),
    .i_multiplier(add4),
    .o_result(dq_out),
    .ovr(ovr_dq)
);
endmodule	
