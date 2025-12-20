module input_handle #(
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

    //-- Driver tín hiệu tính toán ma trận H và vector Y ---
    input wire g_valid,

    output reg start_hq_calc,
    
    // --- OUTPUT  ---
    output reg signed [0 :N*8-1] H_row0_r,
    output reg signed [0 :N*8-1] H_row0_i,
    output reg signed [0 :N*8-1] H_row1_r,
    output reg signed [0 :N*8-1] H_row1_i,
    output reg signed [0 :N*8-1] H_row2_r,
    output reg signed [0 :N*8-1] H_row2_i,
    output reg signed [0 :N*8-1] H_row3_r,
    output reg signed [0 :N*8-1] H_row3_i,

    output wire [N-1:0] y_r0_r,
    output wire [N-1:0] y_r0_i,
    output wire [N-1:0] y_r1_r,
    output wire [N-1:0] y_r1_i

);

//----------------------------------------------------------------
// 1. FSM State Definitions
//----------------------------------------------------------------
localparam S_IDLE = 2'd0;
localparam S_LOAD = 2'd1;
localparam S_CALC = 2'd2;

reg [1:0] state, next_state;

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

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= S_IDLE;
        load_row_cnt <= 2'b0;
        load_col_cnt <= 2'b0;
	    y_count      <= 3'b0;
        start_hq_calc <= 1'b0; 
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