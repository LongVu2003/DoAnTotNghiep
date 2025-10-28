//`include "c_mac.sv"
module matrix_multiplier #(
    parameter Q = 8,
    parameter N = 16,
    parameter ACC_WIDTH = 32
)
(
    input clk,
    input rst,

    input start,
    input signed [N-1:0] H_in_r,
    input signed [N-1:0] H_in_i, 
    output [1:0] i_counter,k_counter,
    output reg Hq_out_valid,
    output reg hq_one_matrix_done, // Tín hiệu done cho 1 ma trận
    output reg all_16_hq_done,      // Tín hiệu done cho cả 16 ma trận
    output reg signed [N-1:0] Hq_out_r,
    output reg signed [N-1:0] Hq_out_i
);

    reg [1:0] load_row_cnt;
    reg [1:0] load_col_cnt;
    reg [1:0] i_counter;
    reg       j_counter;
    reg [1:0] k_counter;
    reg [3:0] q_counter_reg;

    reg signed [N-1:0] s_data_r, s_data_i;
    wire signed [N-1:0] mac_result_r, mac_result_i;
    
    reg cal_en;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cal_en <= 0;
        end else if (start ) begin
            cal_en <= 1;
        end else if(all_16_hq_done) begin
            cal_en <= 0;
        end else begin
            cal_en <= cal_en;
        end
    end

    always @(*) begin : sq_block
        localparam P_HALF = 32'h00200000;
        localparam N_HALF = 32'hffe00000;
        localparam ZERO   = 32'h00000000;
        
        case ({q_counter_reg, k_counter, j_counter})
            {4'd0, 2'd0, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd0, 2'd0, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd0, 2'd1, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd0, 2'd1, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd0, 2'd2, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd0, 2'd2, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd0, 2'd3, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd0, 2'd3, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd1, 2'd0, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd1, 2'd0, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd1, 2'd1, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd1, 2'd1, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd1, 2'd2, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd1, 2'd2, 1'b1}: {s_data_r, s_data_i} = {ZERO, P_HALF};
            {4'd1, 2'd3, 1'b0}: {s_data_r, s_data_i} = {ZERO, P_HALF};
            {4'd1, 2'd3, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd2, 2'd0, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd2, 2'd0, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd2, 2'd1, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd2, 2'd1, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd2, 2'd2, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd2, 2'd2, 1'b1}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd2, 2'd3, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd2, 2'd3, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd3, 2'd0, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd3, 2'd0, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd3, 2'd1, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd3, 2'd1, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd3, 2'd2, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd3, 2'd2, 1'b1}: {s_data_r, s_data_i} = {ZERO, N_HALF};
            {4'd3, 2'd3, 1'b0}: {s_data_r, s_data_i} = {ZERO, N_HALF};
            {4'd3, 2'd3, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd4, 2'd0, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd4, 2'd0, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd4, 2'd1, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd4, 2'd1, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd4, 2'd2, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd4, 2'd2, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd4, 2'd3, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd4, 2'd3, 1'b1}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd5, 2'd0, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd5, 2'd0, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd5, 2'd1, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd5, 2'd1, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd5, 2'd2, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd5, 2'd2, 1'b1}: {s_data_r, s_data_i} = {ZERO, P_HALF};
            {4'd5, 2'd3, 1'b0}: {s_data_r, s_data_i} = {ZERO, P_HALF};
            {4'd5, 2'd3, 1'b1}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd6, 2'd0, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd6, 2'd0, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd6, 2'd1, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd6, 2'd1, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd6, 2'd2, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd6, 2'd2, 1'b1}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd6, 2'd3, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd6, 2'd3, 1'b1}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd7, 2'd0, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd7, 2'd0, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd7, 2'd1, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd7, 2'd1, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd7, 2'd2, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd7, 2'd2, 1'b1}: {s_data_r, s_data_i} = {ZERO, N_HALF};
            {4'd7, 2'd3, 1'b0}: {s_data_r, s_data_i} = {ZERO, N_HALF};
            {4'd7, 2'd3, 1'b1}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd8, 2'd0, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd8, 2'd0, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd8, 2'd1, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd8, 2'd1, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd8, 2'd2, 1'b0}: {s_data_r, s_data_i} = {ZERO, P_HALF};
            {4'd8, 2'd2, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd8, 2'd3, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd8, 2'd3, 1'b1}: {s_data_r, s_data_i} = {ZERO, P_HALF};
            {4'd9, 2'd0, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd9, 2'd0, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd9, 2'd1, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd9, 2'd1, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd9, 2'd2, 1'b0}: {s_data_r, s_data_i} = {ZERO, P_HALF};
            {4'd9, 2'd2, 1'b1}: {s_data_r, s_data_i} = {ZERO, P_HALF};
            {4'd9, 2'd3, 1'b0}: {s_data_r, s_data_i} = {ZERO, P_HALF};
            {4'd9, 2'd3, 1'b1}: {s_data_r, s_data_i} = {ZERO, P_HALF};
            {4'd10, 2'd0, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd10, 2'd0, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd10, 2'd1, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd10, 2'd1, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd10, 2'd2, 1'b0}: {s_data_r, s_data_i} = {ZERO, P_HALF};
            {4'd10, 2'd2, 1'b1}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd10, 2'd3, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd10, 2'd3, 1'b1}: {s_data_r, s_data_i} = {ZERO, P_HALF};
            {4'd11, 2'd0, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd11, 2'd0, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd11, 2'd1, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd11, 2'd1, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd11, 2'd2, 1'b0}: {s_data_r, s_data_i} = {ZERO, P_HALF};
            {4'd11, 2'd2, 1'b1}: {s_data_r, s_data_i} = {ZERO, N_HALF};
            {4'd11, 2'd3, 1'b0}: {s_data_r, s_data_i} = {ZERO, N_HALF};
            {4'd11, 2'd3, 1'b1}: {s_data_r, s_data_i} = {ZERO, P_HALF};
            {4'd12, 2'd0, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd12, 2'd0, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd12, 2'd1, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd12, 2'd1, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd12, 2'd2, 1'b0}: {s_data_r, s_data_i} = {ZERO, N_HALF};
            {4'd12, 2'd2, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd12, 2'd3, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd12, 2'd3, 1'b1}: {s_data_r, s_data_i} = {ZERO, N_HALF};
            {4'd13, 2'd0, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd13, 2'd0, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd13, 2'd1, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd13, 2'd1, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd13, 2'd2, 1'b0}: {s_data_r, s_data_i} = {ZERO, N_HALF};
            {4'd13, 2'd2, 1'b1}: {s_data_r, s_data_i} = {ZERO, P_HALF};
            {4'd13, 2'd3, 1'b0}: {s_data_r, s_data_i} = {ZERO, P_HALF};
            {4'd13, 2'd3, 1'b1}: {s_data_r, s_data_i} = {ZERO, N_HALF};
            {4'd14, 2'd0, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd14, 2'd0, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd14, 2'd1, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd14, 2'd1, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd14, 2'd2, 1'b0}: {s_data_r, s_data_i} = {ZERO, N_HALF};
            {4'd14, 2'd2, 1'b1}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd14, 2'd3, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd14, 2'd3, 1'b1}: {s_data_r, s_data_i} = {ZERO, N_HALF};
            {4'd15, 2'd0, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd15, 2'd0, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd15, 2'd1, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd15, 2'd1, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd15, 2'd2, 1'b0}: {s_data_r, s_data_i} = {ZERO, N_HALF};
            {4'd15, 2'd2, 1'b1}: {s_data_r, s_data_i} = {ZERO, N_HALF};
            {4'd15, 2'd3, 1'b0}: {s_data_r, s_data_i} = {ZERO, N_HALF};
            {4'd15, 2'd3, 1'b1}: {s_data_r, s_data_i} = {ZERO, N_HALF};
            default: {s_data_r, s_data_i} = {16'b0, 16'b0};
        endcase
    end


    wire [1:0] i_counter_delay;
    wire       j_counter_delay;
    wire [1:0] k_counter_delay;
    wire [3:0] q_counter_reg_delay;
    
    delay_module #(.N(N)) delay_kcount(
        .clk(clk),
        .rst(rst),
        .in(k_counter),
        .number(6'd4), 
        .out(k_counter_delay)
    );
    delay_module #(.N(N)) delay_icount(
        .clk(clk),
        .rst(rst),
        .in(i_counter),
        .number(6'd4), 
        .out(i_counter_delay)
    );
    delay_module #(.N(N)) delay_jcount(
        .clk(clk),
        .rst(rst),
        .in(j_counter),
        .number(6'd4), 
        .out(j_counter_delay)
    );
    delay_module #(.N(N)) delay_qcount(
        .clk(clk),
        .rst(rst),
        .in(q_counter_reg),
        .number(6'd4), 
        .out(q_counter_reg_delay)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            load_row_cnt <= 2'b0;
            load_col_cnt <= 2'b0;
            q_counter_reg <= 0;
            i_counter <= 2'b0;
            j_counter <= 1'b0;
            k_counter <= 2'b0;
            Hq_out_valid <= 1'b0;
        end else if(cal_en) begin
		    if(k_counter_delay == 2'b11) begin
                    Hq_out_r <= mac_result_r;
			        Hq_out_i <= mac_result_i;
                    Hq_out_valid <= 1'b1;
                    if (i_counter_delay == 3 && j_counter_delay == 1) begin //nhan xong hang 4 mt H va cot 2 ma tran S 
                        hq_one_matrix_done <= 1'b1;
                        if (q_counter_reg_delay == 15) begin
                            all_16_hq_done <= 1'b1;
                        end
                        else begin
                            all_16_hq_done <= 1'b0;
                        end
                    end else begin
                            hq_one_matrix_done <= 1'b0;
                        end   
		    end else begin
                    Hq_out_r <= Hq_out_r;
                    Hq_out_i <= Hq_out_i;   
                    Hq_out_valid <= 1'b0;
            end
                k_counter <= k_counter + 1;
                if (k_counter == 2'b11) begin // Neu nhan xong 1 hang H va 1 cot S
                    k_counter <= 0;
                    if (j_counter == 1'b1) begin // neu nhan xong 1 hang H va cot so 2 cua S
                        j_counter <= 1'b0;
                        if (i_counter == 2'b11) begin // neu nhan xong hang 4 cua H va cot 2 cua S
                            i_counter <= 2'b0;
                            q_counter_reg <= q_counter_reg + 1; // tang chi so ma tran S -> lay ma tran tiep theo
                    end else begin
                            i_counter <= i_counter + 1;
                    end
                    end else begin
                        j_counter <= j_counter + 1;
                    end
                end
	        
        end
    end

    c_pipe #(
        .Q(Q),
        .N(N)
    ) c_pipe_inst (
        .clk(clk),
        .rst(rst),
        .in_ar(H_in_r),
        .in_ai(H_in_i),
        .in_br(s_data_r),
        .in_bi(s_data_i),
        .r_out(mac_result_r),
        .i_out(mac_result_i)
    );

endmodule