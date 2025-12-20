module soml_decoder_top #(
    parameter Q = 22,
    parameter N = 32
)
(
    // --- Interface ---
    input clk,
    input rst,
    input start,       

    // --- Giao diện nạp ma trận H ---
    input H_in_valid,
    input signed [N-1:0] H_in_r,
    input signed [N-1:0] H_in_i,

    // --- Giao diện nạp vector Y  ---
    input Y_in_valid,
    input signed [N-1:0] Y_in_r,
    input signed [N-1:0] Y_in_i,
    
    // --- OUTPUT  ---
    output wire signed [N-1:0] s_I_1,   // Real part of symbol 1
    output wire signed [N-1:0] s_Q_1,   // Imaginary part of symbol 1
    output wire signed [N-1:0] s_I_2,   // Real part of symbol 2
    output wire signed [N-1:0] s_Q_2,   // Imaginary part of symbol 2
    output wire [4:0]        Smin_index, // Index q_min representing the matrix S_qmin
    output wire              output_valid,
    output wire signed [11:0] signal_out_12bit
);

// Wires for determine_tx_signal outputs
wire signed [N-1:0] s_hat_I_1_out, s_hat_Q_1_out;
wire signed [N-1:0] s_hat_I_2_out, s_hat_Q_2_out;
wire [4:0]         S_hat_index_out;
wire               tx_signal_out_valid;

// Input handling module
wire start_hq_calc;
wire start_drive_y;
wire signed [0 :N*8-1] H_row0_r, H_row0_i, H_row1_r, H_row1_i;
wire signed [0 :N*8-1] H_row2_r, H_row2_i, H_row3_r, H_row3_i;
wire signed [N-1:0] y_r0_r, y_r0_i, y_r1_r, y_r1_i;

input_handle #(.Q(Q), .N(N)) input_handle_inst (
    .clk(clk),
    .rst(rst),
    .start(start),
    .H_in_valid(H_in_valid),
    .H_in_r(H_in_r),
    .H_in_i(H_in_i),
    .Y_in_valid(Y_in_valid),
    .Y_in_r(Y_in_r),
    .Y_in_i(Y_in_i),
    .g_valid(start_drive_y),
    .start_hq_calc(start_hq_calc),
    .H_row0_r(H_row0_r),
    .H_row0_i(H_row0_i),
    .H_row1_r(H_row1_r),
    .H_row1_i(H_row1_i),
    .H_row2_r(H_row2_r),
    .H_row2_i(H_row2_i),
    .H_row3_r(H_row3_r),
    .H_row3_i(H_row3_i),
    .y_r0_r(y_r0_r),
    .y_r0_i(y_r0_i),
    .y_r1_r(y_r1_r),
    .y_r1_i(y_r1_i)
);

wire signed [N-1:0] xI1_out, xQ1_out, xI2_out, xQ2_out;

wire [N-1:0] Dh_out;

x_calculate #(.Q(Q), .N(N)) x_calculate_inst (
    .clk(clk),
    .rst(rst),
    .start_hq_calc(start_hq_calc),
    .H_row0_r(H_row0_r),
    .H_row0_i(H_row0_i),
    .H_row1_r(H_row1_r),
    .H_row1_i(H_row1_i),
    .H_row2_r(H_row2_r),
    .H_row2_i(H_row2_i),
    .H_row3_r(H_row3_r),
    .H_row3_i(H_row3_i),
    .y_r0_r(y_r0_r),
    .y_r0_i(y_r0_i),
    .y_r1_r(y_r1_r),
    .y_r1_i(y_r1_i),
    .g_valid(start_drive_y),
    .Dh_out(Dh_out),
    .invDh_valid(invDh_valid),
    .xI1_out(xI1_out),
    .xQ1_out(xQ1_out),
    .xI2_out(xI2_out),
    .xQ2_out(xQ2_out)
);

wire signed [N-1:0] dI1, dI2,dQ1,dQ2;
wire signed [N-1:0] Rq;
wire signed [2:0] m_dI1, m_dI2, m_dQ1, m_dQ2;

di_q_calculate #(.N(N),.Q(Q)) di_dq_calculate_inst(
    //inputs
	.xI1(xI1_out), .xQ1(xQ1_out), .xI2(xI2_out), .xQ2(xQ2_out),
    //outputs
	.min_dI1(dI1), .min_dQ1(dQ1), .min_dI2(dI2), .min_dQ2(dQ2),
	.Rq(Rq),
	.min_idx_dI1(m_dI1), .min_idx_dQ1(m_dQ1), .min_idx_dI2(m_dI2), .min_idx_dQ2(m_dQ2)
);

wire signed [N-1:0] dq_min;

wire min_valid;
wire busy;
wire signed [2:0] min_dq_m_dI1, min_dq_m_dI2, min_dq_m_dQ1, min_dq_m_dQ2;

wire [4:0] q_min;

dq_min_calculate #(.N(N),.Q(Q)) dq_min_calculate_inst(
    .clk(clk),
    .rst(rst),
    .dI1(dI1),.dI2(dI2),.dQ1(dQ1),.dQ2(dQ2),
    .Rq(Rq),
    .Dh_in(Dh_out),
    .invDh_valid(invDh_valid),
    .in_m_dI1(m_dI1),
    .in_m_dI2(m_dI2),
    .in_m_dQ1(m_dQ1),
    .in_m_dQ2(m_dQ2),
    .out_dq_min(dq_min),
    .out_min_valid(min_valid),
    .busy(busy),
    .out_min_m_dI1(min_dq_m_dI1),
    .out_min_m_dI2(min_dq_m_dI2),
    .out_min_m_dQ1(min_dq_m_dQ1),
    .out_min_m_dQ2(min_dq_m_dQ2),
    .out_q_min(q_min)
);

determine_tx_signal #(
    .N(N), 
    .Q(Q)
)
determine_tx_signal_inst (
    .clk(clk),
    .rst(rst),
    .in_valid(min_valid),   
    .m_Imin_1(min_dq_m_dI1),   
    .m_Qmin_1(min_dq_m_dQ1),
    .m_Imin_2(min_dq_m_dI2),
    .m_Qmin_2(min_dq_m_dQ2),
    .q_min(q_min),              
    .s_hat_I_1(s_hat_I_1_out),
    .s_hat_Q_1(s_hat_Q_1_out),
    .s_hat_I_2(s_hat_I_2_out),
    .s_hat_Q_2(s_hat_Q_2_out),
    .S_hat_index(S_hat_index_out),
    .signal_out_12bit(signal_out_12bit),
    .out_valid(output_valid)

);

assign s_I_1 = s_hat_I_1_out;
assign s_Q_1 = s_hat_Q_1_out;
assign s_I_2 = s_hat_I_2_out;
assign s_Q_2 = s_hat_Q_2_out;
assign Smin_index = S_hat_index_out;


endmodule