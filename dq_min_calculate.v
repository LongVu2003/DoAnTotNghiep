module dq_min_calculate #(
	parameter N = 32,
	parameter Q = 22
)(
	input clk,rst,
	input signed [N-1:0] dI1,dI2,dQ1,dQ2,
	input signed [N-1:0] Rq,
	input signed [N-1:0] Dh_in,
    input [2:0] in_m_dI1,
    input [2:0] in_m_dI2,
    input [2:0] in_m_dQ1,
    input [2:0] in_m_dQ2,
    input invDh_valid,
    output reg signed [N-1:0]   out_dq_min,
    
    output reg                  out_min_valid,
    output reg                  busy,
    output reg signed [2:0]   out_min_m_dI1,
    output reg signed [2:0]   out_min_m_dI2,
    output reg signed [2:0]   out_min_m_dQ1,
    output reg signed [2:0]   out_min_m_dQ2,
    output reg [4:0]            out_q_min

);
wire signed [N-1:0] Dh_delay;
delay_module #(.N(N), .NUM_DELAY(35)) delay_dh(
    .clk(clk),
    .rst(rst),
    .in(Dh_in),
    .out(Dh_delay)
);

wire signed [N-1:0] dq_out;
wire dq_valid;
delay_module #(.N(1), .NUM_DELAY(3)) delay_valid(
    .clk(clk),
    .rst(rst),
    .in(invDh_valid),
    .out(dq_valid)
);

dq_cal #(.N(N),.Q(Q)) dq_calculate (
	.clk(clk),
	.rst(rst),
	.dI1(dI1),.dI2(dI2),.dQ1(dQ1),.dQ2(dQ2),
	.Rq(Rq),
	.Dh(Dh_delay),
	.dq_out(dq_out)
);

find_dq_min #(
    .N(32),
    .NUM_VALUES(16)
)
find_dq_min_inst (
    .clk(clk),
    .rst(rst),
    .dq_out(dq_out),
    .in_valid(dq_valid),
    .in_m_dI1(in_m_dI1),
    .in_m_dI2(in_m_dI2),
    .in_m_dQ1(in_m_dQ1),
    .in_m_dQ2(in_m_dQ2),
    .out_dq_min(out_dq_min),
    .out_min_valid(out_min_valid),
    .busy(busy),
    .out_min_m_dI1(out_min_m_dI1),
    .out_min_m_dI2(out_min_m_dI2),
    .out_min_m_dQ1(out_min_m_dQ1),
    .out_min_m_dQ2(out_min_m_dQ2),
    .out_q_min(out_q_min)
);

endmodule