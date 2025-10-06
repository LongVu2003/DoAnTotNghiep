/*
* Module: g_matrix_calculator_final
* Chức năng: Tự động kích hoạt, nạp đủ ma trận Hq vào RAM,
* sau đó xuất ra tuần tự 4 hàng của cả 4 ma trận G.
*/
module g_matrix_calculator_final #(
    parameter N = 16
)
(
    // Tín hiệu hệ thống
    input clk,
    input rst,

    // Giao diện đầu vào từ khối tính Hq
    input Hq_in_valid,
    input signed [N-1:0] Hq_in_r,
    input signed [N-1:0] Hq_in_i,

    // Giao diện đầu ra
    output reg G_row_valid, // Xung báo hiệu MỘT HÀNG của 4 ma trận G đã sẵn sàng
    output reg done,        // Xung báo hiệu đã xuất xong TẤT CẢ
    
    // 16 Port đầu ra cho 8 giá trị phức của MỘT HÀNG
    output reg signed [N-1:0] Ga1_c0_r, Ga1_c0_i, Ga1_c1_r, Ga1_c1_i,
    output reg signed [N-1:0] Ga2_c0_r, Ga2_c0_i, Ga2_c1_r, Ga2_c1_i,
    output reg signed [N-1:0] Gb1_c0_r, Gb1_c0_i, Gb1_c1_r, Gb1_c1_i,
    output reg signed [N-1:0] Gb2_c0_r, Gb2_c0_i, Gb2_c1_r, Gb2_c1_i
);

// --- 1. FSM, RAM, và Counters ---
localparam S_IDLE       = 2'd0;
localparam S_LOADING    = 2'd1;
localparam S_STREAMING  = 2'd2;
localparam S_DONE       = 2'd3;

reg [1:0] state, next_state;

// RAM nội bộ để lưu ma trận Hq (8 phần tử)
reg signed [N-1:0] Hq_RAM_r [0:7];
reg signed [N-1:0] Hq_RAM_i [0:7];

// Bộ đếm
reg [2:0] load_counter;   // Đếm 0-7 để nạp Hq
reg [1:0] stream_counter; // Đếm 0-3 để xuất 4 hàng G

// --- 2. Logic FSM và Counters ---
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= S_IDLE;
        load_counter <= 0;
        stream_counter <= 0;
    end else begin
        state <= next_state;
        // Cập nhật bộ đếm
        if (next_state == S_IDLE) begin
            load_counter <= 0;
            stream_counter <= 0;
        end else if (state == S_LOADING && Hq_in_valid) begin
            load_counter <= load_counter + 1;
        end else if (state == S_STREAMING) begin
            stream_counter <= stream_counter + 1;
        end
    end
end

// Ghi vào Hq_RAM
always @(posedge clk) begin
    if (state == S_LOADING && Hq_in_valid) begin
        Hq_RAM_r[load_counter] <= Hq_in_r;
        Hq_RAM_i[load_counter] <= Hq_in_i;
    end
end

// Logic tổ hợp của FSM
always @(*) begin
    next_state = state;
    done = 1'b0;
    
    case(state)
        S_IDLE: if (Hq_in_valid) begin
            next_state = S_LOADING;
        end
        S_LOADING: if (load_counter == 3'd7 && Hq_in_valid) begin
            next_state = S_STREAMING;
        end
        S_STREAMING: if (stream_counter == 2'b11) begin // Đã xuất xong hàng cuối
            next_state = S_DONE;
        end
        S_DONE: begin
            done = 1'b1;
            next_state = S_IDLE;
        end
    endcase
end

// --- 3. Logic Tính toán và Xuất Dữ liệu ---
// Đọc một hàng của Hq từ RAM dựa trên stream_counter
wire signed [N-1:0] hq_r0 = Hq_RAM_r[{stream_counter, 1'b0}]; // Hq[i][0]
wire signed [N-1:0] hq_i0 = Hq_RAM_i[{stream_counter, 1'b0}];
wire signed [N-1:0] hq_r1 = Hq_RAM_r[{stream_counter, 1'b1}]; // Hq[i][1]
wire signed [N-1:0] hq_i1 = Hq_RAM_i[{stream_counter, 1'b1}];

always @(posedge clk or posedge rst) begin
    if (rst) begin
        G_row_valid <= 1'b0;
        {Ga1_c0_r, Ga1_c0_i, Ga1_c1_r, Ga1_c1_i} <= 0;
        {Ga2_c0_r, Ga2_c0_i, Ga2_c1_r, Ga2_c1_i} <= 0;
        {Gb1_c0_r, Gb1_c0_i, Gb1_c1_r, Gb1_c1_i} <= 0;
        {Gb2_c0_r, Gb2_c0_i, Gb2_c1_r, Gb2_c1_i} <= 0;
    end else begin
        // Tín hiệu valid bật lên trong suốt quá trình streaming
        G_row_valid <= (state == S_STREAMING);

        if (state == S_STREAMING) begin
            // --- Tính toán và gán cho 16 port đầu ra ---

            // 1. Ga,1 = [h_r0, h_r1]
            Ga1_c0_r <= hq_r0;    Ga1_c0_i <= hq_i0;
            Ga1_c1_r <= hq_r1;    Ga1_c1_i <= hq_i1;
            
            // 2. Ga,2 = [h_r1, -h_r0]
            Ga2_c0_r <= hq_r1;    Ga2_c0_i <= hq_i1;
            Ga2_c1_r <= -hq_r0;   Ga2_c1_i <= -hq_i0;
            
            // 3. Gb,1 = [h_r0, -h_r1]
            Gb1_c0_r <= hq_r0;    Gb1_c0_i <= hq_i0;
            Gb1_c1_r <= -hq_r1;   Gb1_c1_i <= -hq_i1;
            
            // 4. Gb,2 = [h_r1, h_r0]
            Gb2_c0_r <= hq_r1;    Gb2_c0_i <= hq_i1;
            Gb2_c1_r <= hq_r0;    Gb2_c1_i <= hq_i0;
        end
    end
end

endmodule
