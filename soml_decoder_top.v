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

assign s_I_1 = s_hat_I_1_out;
assign s_Q_1 = s_hat_Q_1_out;
assign s_I_2 = s_hat_I_2_out;
assign s_Q_2 = s_hat_Q_2_out;
assign Smin_index = S_hat_index_out;
assign output_valid = tx_signal_out_valid;
assign signal_out_12bit = {b2_out,b1_out};
//----------------------------------------------------------------
// 1. FSM State Definitions
//----------------------------------------------------------------
localparam S_IDLE = 2'd0;
localparam S_LOAD = 2'd1;
localparam S_CALC = 2'd2;

reg [1:0] state, next_state;

//----------------------------------------------------------------
// 2. Internal Signals and RAM
//----------------------------------------------------------------
// Tín hiệu điều khiển
reg start_hq_calc; // Điều khiển module tính toán

// RAM để lưu trữ ma trận H (4x4)
reg signed [N-1:0] h_mem_real [0:3][0:3];
reg signed [N-1:0] h_mem_imag [0:3][0:3];

reg signed [N-1:0] y_mem1_r [0:3];
reg signed [N-1:0] y_mem1_i [0:3];

reg signed [N-1:0] y_mem2_r [0:3];
reg signed [N-1:0] y_mem2_i [0:3];

// Bộ đếm để nạp dữ liệu vào RAM
reg [1:0] load_row_cnt;
reg [1:0] load_col_cnt;

reg [2:0] y_count;

// Dây nối cho module con
wire hq_done, hq_valid,all_16_hq_done;
wire signed [N-1:0] hq_r, hq_i;
wire [1:0] i_counter; 
wire [1:0] k_counter;


//----------------------------------------------------------------
// 3. Sub-module Instantiation
//----------------------------------------------------------------
// Module tính Hq
reg signed [0 :N*8-1] H_row0_r, H_row0_i, H_row1_r, H_row1_i;
reg signed [0 :N*8-1] H_row2_r, H_row2_i, H_row3_r, H_row3_i;

always @(posedge clk) begin  
    if(rst) begin
        H_row0_r <= 0;
        H_row0_i <= 0;
        H_row1_r <= 0;
        H_row1_i <= 0;
        H_row2_r <= 0;
        H_row2_i <= 0;
        H_row3_r <= 0;
        H_row3_i <= 0;
    end
    else if(start_hq_calc) begin
        H_row0_r <= {h_mem_real[0][0], h_mem_real[0][0], h_mem_real[1][0], h_mem_real[1][0],h_mem_real[2][0], h_mem_real[2][0], h_mem_real[3][0], h_mem_real[3][0]};
        H_row0_i <= {h_mem_imag[0][0], h_mem_imag[0][0], h_mem_imag[1][0], h_mem_imag[1][0],h_mem_imag[2][0], h_mem_imag[2][0], h_mem_imag[3][0], h_mem_imag[3][0]};
        H_row1_r <= {h_mem_real[0][1], h_mem_real[0][1], h_mem_real[1][1], h_mem_real[1][1],h_mem_real[2][1], h_mem_real[2][1], h_mem_real[3][1], h_mem_real[3][1]};
        H_row1_i <= {h_mem_imag[0][1], h_mem_imag[0][1], h_mem_imag[1][1], h_mem_imag[1][1],h_mem_imag[2][1], h_mem_imag[2][1], h_mem_imag[3][1], h_mem_imag[3][1]};
        H_row2_r <= {h_mem_real[0][2], h_mem_real[0][2], h_mem_real[1][2], h_mem_real[1][2],h_mem_real[2][2], h_mem_real[2][2], h_mem_real[3][2], h_mem_real[3][2]};
        H_row2_i <= {h_mem_imag[0][2], h_mem_imag[0][2], h_mem_imag[1][2], h_mem_imag[1][2],h_mem_imag[2][2], h_mem_imag[2][2], h_mem_imag[3][2], h_mem_imag[3][2]};
        H_row3_r <= {h_mem_real[0][3], h_mem_real[0][3], h_mem_real[1][3], h_mem_real[1][3],h_mem_real[2][3], h_mem_real[2][3], h_mem_real[3][3], h_mem_real[3][3]};
        H_row3_i <= {h_mem_imag[0][3], h_mem_imag[0][3], h_mem_imag[1][3], h_mem_imag[1][3],h_mem_imag[2][3], h_mem_imag[2][3], h_mem_imag[3][3], h_mem_imag[3][3]};
    end
end
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

wire signed [N-1:0] Dh_out;
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

wire invDh_valid;

delay_module #(.N(N)) invDh_Valid_inst(
    .clk(clk),
    .rst(rst),
    .in(Dh_result_valid),
    .number(N+1), 
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

wire g_valid;

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
wire signed [N-1:0] y_r0_r, y_r0_i, y_r1_r, y_r1_i;
reg [1:0] cnt_y;

always @(posedge clk) begin
	if(rst)
		cnt_y <= 0;
	else if (g_valid)
		cnt_y <= cnt_y + 1;
end

assign y_r0_r = (g_valid)? y_mem1_r[cnt_y] : 0;
assign y_r0_i = (g_valid)? y_mem1_i[cnt_y] : 0;
assign y_r1_r = (g_valid)? y_mem2_r[cnt_y] : 0;
assign y_r1_i = (g_valid)? y_mem2_i[cnt_y] : 0;


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
delay_module #(.N(N)) delay_ga1(
    .clk(clk),
    .rst(rst),
    .in(ga1_r),
    .number(6'd22), 
    .out(ga1_r_delay)
);
delay_module #(.N(N)) delay_ga2(
    .clk(clk),
    .rst(rst),
    .in(ga2_r),
    .number(6'd22), 
    .out(ga2_r_delay)
);
delay_module #(.N(N)) delay_gb1(
    .clk(clk),
    .rst(rst),
    .in(gb1_i),
    .number(6'd22), 
    .out(gb1_i_delay)
);
delay_module #(.N(N)) delay_gb2(
    .clk(clk),
    .rst(rst),
    .in(gb2_i),
    .number(6'd22), 
    .out(gb2_i_delay)
);

wire ovr_xi1,ovr_xi2,ovr_xq1,ovr_xq2;
wire signed [N-1:0] xI1_out_tmp,xI2_out_tmp,xQ1_out_tmp,xQ2_out_tmp;

wire  signed [N-1:0] xI1_out;
wire  signed [N-1:0] xQ1_out;
wire  signed [N-1:0] xI2_out;
wire  signed [N-1:0] xQ2_out;

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

wire signed [N-1:0] dI1, dI2,dQ1,dQ2;
wire signed [N-1:0] Rq;
wire signed [2:0] m_dI1, m_dI2, m_dQ1, m_dQ2;

MinFinder #(.N(N),.Q(Q)) dmin_inst(
	.xI1(xI1_out), .xQ1(xQ1_out), .xI2(xI2_out), .xQ2(xQ2_out),
	.min_dI1(dI1), .min_dQ1(dQ1), .min_dI2(dI2), .min_dQ2(dQ2),
	.Rq(Rq),
	.min_idx_dI1(m_dI1), .min_idx_dQ1(m_dQ1), .min_idx_dI2(m_dI2), .min_idx_dQ2(m_dQ2)
);

wire signed [N-1:0] Dh_delay;
delay_module #(.N(N)) delay_dh(
    .clk(clk),
    .rst(rst),
    .in(Dh_out),
    .number(6'd33), 
    .out(Dh_delay)
);

wire signed [N-1:0] dq_out;
wire dq_valid;
delay_module #(.N(N)) delay_valid(
    .clk(clk),
    .rst(rst),
    .in(invDh_valid),
    .number(6'd2), 
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

wire signed [N-1:0] dq_min;
wire busy, min_valid;

wire  [2:0] min_dq_m_dI1;
wire  [2:0] min_dq_m_dI2;
wire  [2:0] min_dq_m_dQ1;
wire  [2:0] min_dq_m_dQ2;

wire [4:0] q_min;

find_min #(
    .N(32),
    .NUM_VALUES(16)
)
find_min_inst (
    .clk(clk),
    .rst_n(!rst),
    .dq_out(dq_out),
    .in_valid(dq_valid),
    .m_dI1(m_dI1),
    .m_dI2(m_dI2),
    .m_dQ1(m_dQ1),
    .m_dQ2(m_dQ2),
    .min_value(dq_min),
    .min_valid(min_valid),
    .busy(busy),
    .min_m_dI1(min_dq_m_dI1),
    .min_m_dI2(min_dq_m_dI2),
    .min_m_dQ1(min_dq_m_dQ1),
    .min_m_dQ2(min_dq_m_dQ2),
    .q_min(q_min)
);
// Wires for determine_tx_signal outputs
wire signed [N-1:0] s_hat_I_1_out, s_hat_Q_1_out;
wire signed [N-1:0] s_hat_I_2_out, s_hat_Q_2_out;
wire [4:0]         S_hat_index_out;
wire               tx_signal_out_valid;
determine_tx_signal #(
    .N(N), 
    .Q(Q)
)
determine_tx_signal_inst (
    .clk(clk),
    .rst_n(~rst),
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
    .out_valid(tx_signal_out_valid)
);
wire [7:0]         b1_out;
wire [3:0]         b2_out;
wire               final_out_valid;
output_signal #(
    .N(32)
)
output_signal_inst (
    .clk(clk),
    .rst_n(~rst),
    .in_valid(min_valid),
    .m_Imin_1(min_dq_m_dI1),
    .m_Qmin_1(min_dq_m_dQ1),
    .m_Imin_2(min_dq_m_dI2),
    .m_Qmin_2(min_dq_m_dQ2),
    .q_min(q_min),
    .b1(b1_out),
    .b2(b2_out),
    .out_valid(final_out_valid)
);

wire load_H_done = (load_row_cnt == 2'b11 && load_col_cnt == 2'b11);
wire load_Y_done = y_count == 3'b111;

always @(*) begin
    next_state = state; 
    case(state)
        S_IDLE: begin
            if (start || load_H_done) begin
                next_state = S_LOAD;
            end
        end
        S_LOAD: begin
            if (H_in_valid && load_H_done) begin
                next_state = S_IDLE;
            end
        end
        default: begin
            next_state = S_IDLE;
        end
    endcase
end

always @(posedge clk or rst) begin
    if (rst) begin
        state <= S_IDLE;
        load_row_cnt <= 2'b0;
        load_col_cnt <= 2'b0;
	    y_count      <= 3'b0;
        start_hq_calc = 1'b0; 
    end else begin
        state <= next_state;
        if (state == S_IDLE) begin
            start_hq_calc <= 1'b0;
            if (start) begin
                load_row_cnt <= 2'b0;
                load_col_cnt <= 2'b0;
		        y_count      <= 3'b0;
            end
        end
        if (state == S_LOAD) begin
            if (H_in_valid) begin
                if (load_H_done) begin
                    start_hq_calc <= 1'b1;
                end else begin
                    start_hq_calc <= 1'b0;
                end
                // Ghi dữ liệu vào RAM
                h_mem_real[load_row_cnt][load_col_cnt] <= H_in_r;
                h_mem_imag[load_row_cnt][load_col_cnt] <= H_in_i;
                // Cập nhật bộ đếm
                if (load_col_cnt == 2'b11) begin
                    load_col_cnt <= 2'b0;
                    load_row_cnt <= load_row_cnt + 1;
                end else begin
                    load_col_cnt <= load_col_cnt + 1;
                end
            end
	        if(Y_in_valid == 1) begin
		        y_count <= y_count + 1;
                if(y_count < 4) begin
                    y_mem1_r[y_count] <= Y_in_r;
                    y_mem1_i[y_count] <= -Y_in_i;
                end else if(y_count > 3 && y_count < 8) begin
                    y_mem2_r[y_count-3'd4] <= Y_in_r;
                    y_mem2_i[y_count-3'd4] <= -Y_in_i;
                end
                if(y_count == 3'b111) y_count <= 3'b000;
	        end	
        end
    end
end
endmodule