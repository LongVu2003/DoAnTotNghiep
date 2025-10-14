/*
 * Module: calculation_controller
 * Chức năng: Module điều khiển chính, quản lý việc nạp ma trận H
 * và khởi động quá trình tính toán Hq.
 * Ghi chú: Tên module đã được đổi từ "matrix_multiplier" để tránh
 * lỗi tự gọi lại chính nó (recursive instantiation).
 */
module x_calculate #(
    parameter Q = 16,
    parameter N = 32,
    parameter ACC_WIDTH = 32
)
(
    // --- Interface ---
    input clk,
    input rst,
    input start_new_q,          // Xung bắt đầu một phiên tính toán mới

    input [3:0] q_index,

    // --- Giao diện nạp ma trận H ---
    input H_in_valid,
    input signed [N-1:0] H_in_r,
    input signed [N-1:0] H_in_i,

    // --- Giao diện nạp vector Y (chưa sử dụng) ---
    input Y_in_valid,
    input signed [N-1:0] Y_in_r,
    input signed [N-1:0] Y_in_i,
    
    // --- Đầu ra cuối cùng (chưa sử dụng) ---
    output reg q_done,
    output  signed [N-1:0] xI1_out,
    output  signed [N-1:0] xQ1_out,
    output  signed [N-1:0] xI2_out,
    output  signed [N-1:0] xQ2_out
);

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
wire [1:0] i_counter; // Địa chỉ đọc từ module con
wire [1:0] k_counter;


//----------------------------------------------------------------
// 3. Sub-module Instantiation
//----------------------------------------------------------------
// Module tính Hq (giả định tên là "matrix_multiplier_inst")
// Dữ liệu đầu vào H được đọc từ RAM nội bộ
matrix_multiplier  #(.N(N), .Q(Q)) hq_calc_inst(
    .clk(clk),
    .rst(rst),
    .start(start_hq_calc),
    .q_index(q_index),
    .H_in_valid(1'b1), // Luôn hợp lệ khi đọc từ RAM
    .i_counter(i_counter),
    .k_counter(k_counter),
    .H_in_r(h_mem_real[i_counter][k_counter]),
    .H_in_i(h_mem_imag[i_counter][k_counter]),
    .hq_one_matrix_done(hq_done),
    .all_16_hq_done(all_16_hq_done),
    .Hq_out_valid(hq_valid),
    .Hq_out_r(hq_r),
    .Hq_out_i(hq_i)
);
wire Dh_en;
wire signed [N-1:0] dh_in_r,dh_in_i;
wire signed [N-1:0] Dh_out;
assign dh_in_r = (hq_valid)? hq_r : dh_in_r;
assign dh_in_i = (hq_valid)? hq_i : dh_in_i;

Dh_cal #(.N(N), .Q(Q)) dh_calc_inst(
      .clk(clk),
      .rst(rst),
      .Dh_en(hq_valid), 
      .in_real(dh_in_r),
      .in_im(dh_in_i),
      .Dh_out(Dh_out),
      .Dh_result_valid(Dh_result_valid)
);
wire div_ovr;
wire [N-1:0]  inversDh;

reg invDh_valid;
reg invDh_count_ena;
reg [4:0] inv_count;
always @(posedge clk,posedge rst) begin
	if(rst) begin
		 invDh_count_ena <= 1'b0;
	end
	else if(inv_count == 7'd17)
		invDh_count_ena <= 1'b0;
	else if(Dh_result_valid == 1'b1)
		invDh_count_ena <= 1'b1;
end
always @(posedge clk,posedge rst) begin
	if(rst) begin
		inv_count <= 1'd0;
		invDh_valid <= 5'b0;
	end
	else if(inv_count == 5'd17) begin
		inv_count <= 5'd0;
		invDh_valid <= 1'd1;
	end
	else if(invDh_count_ena)
		inv_count <= inv_count + 1'b1;
	else invDh_valid <= 1'd0;
end
		
fxp_div_pipe invDh_inst (
 .rstn(!rst),
 .clk(clk),
 .dividend(16'd1<<Q),
 .divisor(Dh_out),
 .out(inversDh),
 .overflow(div_ovr)
);

wire g_valid;

wire signed [N-1:0] Ga1_c0_r, Ga1_c0_i, Ga1_c1_r, Ga1_c1_i;
wire signed [N-1:0] Ga2_c0_r, Ga2_c0_i, Ga2_c1_r, Ga2_c1_i;
wire signed [N-1:0] Gb1_c0_r, Gb1_c0_i, Gb1_c1_r, Gb1_c1_i;
wire signed [N-1:0] Gb2_c0_r, Gb2_c0_i, Gb2_c1_r, Gb2_c1_i;

g_matrix_calculator g_matrix_inst(
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
wire ga1_done,ga2_done,gb1_done,gb2_done;
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
  .done_calc(ga1_done),
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
  .done_calc(ga2_done),
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
  .done_calc(gb1_done),
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
  .done_calc(gb2_done),
  .trace_result_r(gb2_r),
  .trace_result_i(gb2_i)
);

wire signed [N-1:0] ga1_r_delay, ga2_r_delay,gb1_i_delay,gb2_i_delay;
delay_module delay_ga1(
    .clk(clk),
    .rst(rst),
    .in(ga1_r),
    .number(5'd6), 
    .out(ga1_r_delay)
);
delay_module delay_ga2(
    .clk(clk),
    .rst(rst),
    .in(ga2_r),
    .number(5'd6), 
    .out(ga2_r_delay)
);
delay_module delay_gb1(
    .clk(clk),
    .rst(rst),
    .in(gb1_i),
    .number(5'd6), 
    .out(gb1_i_delay)
);
delay_module delay_gb2(
    .clk(clk),
    .rst(rst),
    .in(gb2_i),
    .number(5'd6), 
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

wire load_H_done = (load_row_cnt == 2'b11 && load_col_cnt == 2'b11);
wire load_Y_done = y_count == 3'b111;
always @(*) begin
    next_state = state; // Mặc định giữ nguyên trạng thái
    case(state)
        S_IDLE: begin
            if (start_new_q) begin
                next_state = S_LOAD;
            end
		$display("IDLE");
        end
        S_LOAD: begin
            if (H_in_valid && load_H_done) begin
                next_state = S_CALC;
            end
        end
        S_CALC: begin
            if (hq_done) begin
                next_state = S_IDLE; // Tính xong, quay về chờ
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
           start_hq_calc = 1'b1; // Kích hoạt module tính toán
        // Reset các đầu ra
        q_done <= 1'b0;
    end else begin
        state <= next_state;

        // Logic hoạt động trong từng trạng thái
        if (state == S_IDLE) begin
            // Reset bộ đếm khi chuẩn bị vào S_LOAD
            if (start_new_q) begin
                load_row_cnt <= 2'b0;
                load_col_cnt <= 2'b0;
		y_count      <= 3'b0;
            end
        end
	if (state == S_LOAD && next_state == S_CALC) begin
            start_hq_calc <= 1'b1; // assert 1 cycle
        end else begin
            start_hq_calc <= 1'b0;
        end
        if (state == S_LOAD) begin
            if (H_in_valid) begin
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
		if(y_count == 3'b111) y_count = 3'b000;
	    end	
        end
    end
end

endmodule
