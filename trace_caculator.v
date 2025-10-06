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
    input start_calc, // Bắt đầu tính

    // Giao diện đọc Y_RAM (giả định có sẵn bên ngoài)
    output reg [2:0] y_rd_addr,
    input signed [N-1:0] y_rd_data_r,
    input signed [N-1:0] y_rd_data_i,

    // Giao diện đọc G_RAM (giả định có sẵn bên ngoài)
    output reg [2:0] g_rd_addr,
    input signed [N-1:0] g_rd_data_r,
    input signed [N-1:0] g_rd_data_i,

    // Đầu ra
    output reg done_calc,
    output reg signed [ACC_WIDTH-1:0] trace_result_r,
    output reg signed [ACC_WIDTH-1:0] trace_result_i
);

// --- 1. FSM, MAC và Counters ---
localparam S_IDLE            = 4'd0;
localparam S_CALC_P00_CLEAR  = 4'd1;
localparam S_CALC_P00_FEED   = 4'd2;
localparam S_CALC_P00_WAIT   = 4'd3;
localparam S_CALC_P11_CLEAR  = 4'd4;
localparam S_CALC_P11_FEED   = 4'd5;
localparam S_CALC_P11_WAIT   = 4'd6;
localparam S_ADD_TRACE       = 4'd7;
localparam S_DONE            = 4'd8;

reg [3:0] state, next_state;
reg [1:0] k_counter; // Đếm 0-3 cho dot product

// Tín hiệu điều khiển MAC
reg mac_en, mac_clear;
wire mac_result_valid;
wire signed [ACC_WIDTH-1:0] mac_result_r, mac_result_i;

// Thanh ghi lưu kết quả trung gian P[0][0]
reg signed [ACC_WIDTH-1:0] p00_reg_r, p00_reg_i;

// --- 2. Logic tính YH on-the-fly ---
// YH[i][k] = Y[k][i]*
wire signed [N-1:0] yh_data_r;
wire signed [N-1:0] yh_data_i;

assign yh_data_r = y_rd_data_r;
assign yh_data_i = -y_rd_data_i; // Liên hợp phức

// --- 3. Thể hiện c_mac ---
c_mac #( .N(N), .Q(Q) )
mac_engine (
    .clk(clk), .rst(rst),
    .mac_clear(mac_clear),
    .mac_en(mac_en),
    .in_ar(yh_data_r), .in_ai(yh_data_i), // YH
    .in_br(g_rd_data_r), .in_bi(g_rd_data_i), // G
    .mac_r_out(mac_result_r),
    .mac_i_out(mac_result_i),
    .mac_result_valid(mac_result_valid)
);

// --- 4. Logic FSM và Counters ---
always @(posedge clk or rst) begin
    if (rst) begin
        state <= S_IDLE;
        k_counter <= 0;
    end else begin
        state <= next_state;
        // Cập nhật k_counter
        if (next_state == S_IDLE || next_state == S_CALC_P00_CLEAR || next_state == S_CALC_P11_CLEAR) begin
            k_counter <= 0;
        end else if (state == S_CALC_P00_FEED || state == S_CALC_P11_FEED) begin
            k_counter <= k_counter + 1;
        end
    end
end

always @(*) begin
    next_state = state;
    mac_clear = 1'b0;
    mac_en = 1'b0;
    done_calc = 1'b0;
    y_rd_addr = 0;
    g_rd_addr = 0;

    case (state)
        S_IDLE: if (start_calc) next_state = S_CALC_P00_CLEAR;
        
        // --- Tính P[0][0] = dot(YH[0,:], G[:,0]) ---
        S_CALC_P00_CLEAR: begin
            mac_clear = 1'b1;
            next_state = S_CALC_P00_FEED;
        end
        S_CALC_P00_FEED: begin
            mac_en = 1'b1;
            y_rd_addr = {k_counter, 1'b0}; // Đọc Y[k][0] để tính YH[0][k]
            g_rd_addr = {k_counter, 1'b0}; // Đọc G[k][0]
            if (k_counter == 2'b11) next_state = S_CALC_P00_WAIT;
        end
        S_CALC_P00_WAIT: if (mac_result_valid) next_state = S_CALC_P11_CLEAR;
        
        // --- Tính P[1][1] = dot(YH[1,:], G[:,1]) ---
        S_CALC_P11_CLEAR: begin
            mac_clear = 1'b1;
            next_state = S_CALC_P11_FEED;
        end
        S_CALC_P11_FEED: begin
            mac_en = 1'b1;
            y_rd_addr = {k_counter, 1'b1}; // Đọc Y[k][1] để tính YH[1][k]
            g_rd_addr = {k_counter, 1'b1}; // Đọc G[k][1]
            if (k_counter == 2'b11) next_state = S_CALC_P11_WAIT;
        end
        S_CALC_P11_WAIT: if (mac_result_valid) next_state = S_ADD_TRACE;

        // --- Cộng và Hoàn tất ---
        S_ADD_TRACE: next_state = S_DONE;
        S_DONE: begin
            done_calc = 1'b1;
            next_state = S_IDLE;

        end
        default: next_state = S_IDLE;
    endcase
end

// --- 5. Logic lưu trữ và tính toán cuối cùng ---
always @(posedge clk or rst) begin
    if (rst) begin
        p00_reg_r <= 0;
        p00_reg_i <= 0;
        trace_result_r <= 0;
        trace_result_i <= 0;
    end else begin
        // Lưu P[0][0]
        if (state == S_CALC_P00_WAIT && mac_result_valid) begin
            p00_reg_r <= mac_result_r;
            p00_reg_i <= mac_result_i;
        end
        
        // Tính trace = P[0][0] + P[1][1]
        if (state == S_ADD_TRACE) begin
            trace_result_r <= p00_reg_r + mac_result_r; // mac_result lúc này là của P[1][1]
            trace_result_i <= p00_reg_i + mac_result_i;
        end
    end
end

endmodule
