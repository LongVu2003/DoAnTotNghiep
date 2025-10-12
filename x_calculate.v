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
    output reg signed [N-1:0] xI1_out,
    output reg signed [N-1:0] xQ1_out,
    output reg signed [N-1:0] xI2_out,
    output reg signed [N-1:0] xQ2_out
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

reg signed [N-1:0] y_mem_real [0:7];
reg signed [N-1:0] y_mem_imag [0:7];

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
fxp_div_pipe invDh_inst (
 .rstn(!rst),
 .clk(clk),
 .dividend(16'd1<<Q),
 .divisor(Dh_out),
 .out(inversDh),
 .overflow(div_ovr)
);

wire g_row_valid;
wire g_done;

wire signed [N-1:0] Ga1_c0_r, Ga1_c0_i, Ga1_c1_r, Ga1_c1_i;
wire signed [N-1:0] Ga2_c0_r, Ga2_c0_i, Ga2_c1_r, Ga2_c1_i;
wire signed [N-1:0] Gb1_c0_r, Gb1_c0_i, Gb1_c1_r, Gb1_c1_i;
wire signed [N-1:0] Gb2_c0_r, Gb2_c0_i, Gb2_c1_r, Gb2_c1_i;
g_matrix_calculator g_matrix_inst(
	.clk(clk),
	.rst(rst),
	.Hq_in_valid(hq_valid),
	.Hq_in_r(dh_in_r),
	.Hq_in_i(dh_in_i),
	.G_row_valid(g_row_valid), // Xung báo hiệu MỘT HÀNG của 4 ma trận G đã sẵn sàng
	.done(g_done),        // Xung báo hiệu đã xuất xong TẤT CẢ
	.Ga1_c0_r(Ga1_c0_r), .Ga1_c0_i(Ga1_c0_i), .Ga1_c1_r(Ga1_c1_r), .Ga1_c1_i(Ga1_c1_i),
	.Ga2_c0_r(Ga2_c0_r), .Ga2_c0_i(Ga2_c0_i), .Ga2_c1_r(Ga2_c1_r), .Ga2_c1_i(Ga2_c1_i),
	.Gb1_c0_r(Gb1_c0_r), .Gb1_c0_i(Gb1_c0_i), .Gb1_c1_r(Gb1_c1_r), .Gb1_c1_i(Gb1_c1_i),
	.Gb2_c0_r(Gb2_c0_r), .Gb2_c0_i(Gb2_c0_i), .Gb2_c1_r(Gb2_c1_r), .Gb2_c1_i(Gb2_c1_i)
);
reg signed [N-1:0] ga1ram_r [0:7];
reg signed [N-1:0] ga1ram_i [0:7];

wire signed [N-1:0] GA1_r,GA1_i;

wire signed [N-1:0] y_rd_data_r,y_rd_data_i;

wire signed [N-1:0] GA1_rd_data_r,GA1_rd_data_i;


wire GA1_done_calc;
reg [2:0] g_count;

wire [2:0] g_rd_addr,y_rd_addr;

always @(posedge clk, posedge rst) begin
	if(rst) g_count <= 1'b0;
	else if(g_row_valid) begin
		ga1ram_r[g_count] <= Ga1_c0_r;
		ga1ram_i[g_count] <= Ga1_c0_i;
		ga1ram_r[g_count+1] <= Ga1_c1_r;
		ga1ram_i[g_count+1] <= Ga1_c1_i;
		g_count <= g_count + 1'b1;
	end else g_count <= g_count;
end
trace_calculator #(
  .N(N)
) traceGa1 (
  .clk(clk),
  .rst(rst),
  .start_calc(g_done),
  .y_rd_addr(y_rd_addr),
  .y_rd_data_r(y_rd_data_r),
  .y_rd_data_i(y_rd_data_i),
  .g_rd_addr(g_rd_addr),
  .g_rd_data_r(GA1_rd_data_r),
  .g_rd_data_i(GA1_rd_data_i),
  .done_calc(GA1_done_calc),
  .trace_result_r(GA1_r),
  .trace_result_i(GA1_i)
);
assign GA1_rd_data_r = ga1ram_r[g_rd_addr];
assign GA1_rd_data_i = ga1ram_i[g_rd_addr];

assign y_rd_data_r = y_mem_real[y_rd_addr];
assign y_rd_data_i = y_mem_imag[y_rd_addr];

wire signed [N-1:0] Xi1;
cmult #(
    .Q(Q),
    .N(N)
) xI1_calc_inst (
    .clk(clk),
    .rst(rst),
    .ar(GA1_r),
    .ai(16'b0),
    .br(inversDh),
    .bi(16'b0),
    .pr(Xi1),
    .pi()
);
//----------------------------------------------------------------
//----------------------------------------------------------------
// 4. FSM Logic
//----------------------------------------------------------------

// --- Logic tổ hợp (Combinational): Xác định trạng thái kế tiếp ---
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
            // Khi H_in_valid và bộ đếm đã ở vị trí cuối cùng (3,3),
            // việc ghi sẽ hoàn tất ở cạnh clock tiếp theo, nên ta chuyển trạng thái.
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

// --- Logic tuần tự (Sequential): Cập nhật trạng thái và các thanh ghi ---
always @(posedge clk or rst) begin
    if (rst) begin
        state <= S_IDLE;
        load_row_cnt <= 2'b0;
        load_col_cnt <= 2'b0;
	y_count      <= 3'b0;
           start_hq_calc = 1'b1; // Kích hoạt module tính toán
        // Reset các đầu ra
        q_done <= 1'b0;
        xI1_out <= 0;
        xQ1_out <= 0;
        xI2_out <= 0;
        xQ2_out <= 0;
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
		y_mem_real[y_count] <= Y_in_r;
		y_mem_imag[y_count] <= Y_in_i;
		if(y_count == 3'b111) y_count = 3'b000;
		else y_count <= y_count + 1;
	    end	
        end
    end
end

endmodule
