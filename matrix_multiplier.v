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
    input H_in_valid,
    input signed [N-1:0] H_in_r,
    input signed [N-1:0] H_in_i, 
    output [1:0] i_counter,k_counter,
    input [3:0] q_index,
    output reg Hq_out_valid,
    output reg hq_one_matrix_done, // Tín hiệu done cho 1 ma trận
    output reg all_16_hq_done,      // Tín hiệu done cho cả 16 ma trận
    output reg signed [N-1:0] Hq_out_r,
    output reg signed [N-1:0] Hq_out_i
);

    localparam S_IDLE        = 4'd0;
    localparam S_LOAD_H      = 4'd1;
    localparam S_CLEAR_MAC   = 4'd2;
    localparam S_CALC_ELEMENT   = 4'd3;
    localparam S_WAIT_RESULT = 4'd4;
    localparam S_OUTPUT_DATA = 4'd5;
    localparam S_DONE        = 4'd6;

    reg [3:0] state, next_state;

    reg [1:0] load_row_cnt;
    reg [1:0] load_col_cnt;
    reg [1:0] i_counter;
    reg       j_counter;
    reg [1:0] k_counter;
    reg [3:0] q_counter_reg;
    //reg signed [N-1:0] h_mem_real [0:3][0:3];
    //reg signed [N-1:0] h_mem_imag [0:3][0:3];

    //wire signed [N-1:0] h_data_r, h_data_i;
    reg signed [N-1:0] s_data_r, s_data_i;
    wire signed [N-1:0] mac_result_r, mac_result_i;
    wire mac_result_valid;
    reg mac_en;
    wire mac_clear;
    assign mac_clear = mac_result_valid;
    
    //assign h_data_r = h_mem_real[i_counter][k_counter];
    //assign h_data_i = h_mem_imag[i_counter][k_counter];
   // assign Hq_out_r = mac_result_r;
   // assign Hq_out_i = mac_result_i;
 
    always @(*) begin : sq_block
        localparam P_HALF = 16'sd128;
        localparam N_HALF = -16'sd128;
        localparam ZERO   = 16'sd0;
        
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
            {4'd3, 2'd3, 1'b0}: {s_data_r, s_data_i} = {ZERO, P_HALF};
            {4'd3, 2'd3, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd4, 2'd0, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd4, 2'd0, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd4, 2'd1, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd4, 2'd1, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd4, 2'd2, 1'b0}: {s_data_r, s_data_i} = {ZERO, P_HALF};
            {4'd4, 2'd2, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd4, 2'd3, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd4, 2'd3, 1'b1}: {s_data_r, s_data_i} = {ZERO, P_HALF};
            {4'd5, 2'd0, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd5, 2'd0, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd5, 2'd1, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd5, 2'd1, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd5, 2'd2, 1'b0}: {s_data_r, s_data_i} = {ZERO, P_HALF};
            {4'd5, 2'd2, 1'b1}: {s_data_r, s_data_i} = {ZERO, P_HALF};
            {4'd5, 2'd3, 1'b0}: {s_data_r, s_data_i} = {ZERO, N_HALF};
            {4'd5, 2'd3, 1'b1}: {s_data_r, s_data_i} = {ZERO, P_HALF};
            {4'd6, 2'd0, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd6, 2'd0, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd6, 2'd1, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd6, 2'd1, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd6, 2'd2, 1'b0}: {s_data_r, s_data_i} = {ZERO, P_HALF};
            {4'd6, 2'd2, 1'b1}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd6, 2'd3, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd6, 2'd3, 1'b1}: {s_data_r, s_data_i} = {ZERO, P_HALF};
            {4'd7, 2'd0, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd7, 2'd0, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd7, 2'd1, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd7, 2'd1, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd7, 2'd2, 1'b0}: {s_data_r, s_data_i} = {ZERO, P_HALF};
            {4'd7, 2'd2, 1'b1}: {s_data_r, s_data_i} = {ZERO, N_HALF};
            {4'd7, 2'd3, 1'b0}: {s_data_r, s_data_i} = {ZERO, P_HALF};
            {4'd7, 2'd3, 1'b1}: {s_data_r, s_data_i} = {ZERO, P_HALF};
            {4'd8, 2'd0, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd8, 2'd0, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd8, 2'd1, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd8, 2'd1, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd8, 2'd2, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd8, 2'd2, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd8, 2'd3, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd8, 2'd3, 1'b1}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd9, 2'd0, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd9, 2'd0, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd9, 2'd1, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd9, 2'd1, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd9, 2'd2, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd9, 2'd2, 1'b1}: {s_data_r, s_data_i} = {ZERO, P_HALF};
            {4'd9, 2'd3, 1'b0}: {s_data_r, s_data_i} = {ZERO, N_HALF};
            {4'd9, 2'd3, 1'b1}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd10, 2'd0, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd10, 2'd0, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd10, 2'd1, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd10, 2'd1, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd10, 2'd2, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd10, 2'd2, 1'b1}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd10, 2'd3, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd10, 2'd3, 1'b1}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd11, 2'd0, 1'b0}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd11, 2'd0, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd11, 2'd1, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd11, 2'd1, 1'b1}: {s_data_r, s_data_i} = {P_HALF, ZERO};
            {4'd11, 2'd2, 1'b0}: {s_data_r, s_data_i} = {N_HALF, ZERO};
            {4'd11, 2'd2, 1'b1}: {s_data_r, s_data_i} = {ZERO, N_HALF};
            {4'd11, 2'd3, 1'b0}: {s_data_r, s_data_i} = {ZERO, P_HALF};
            {4'd11, 2'd3, 1'b1}: {s_data_r, s_data_i} = {N_HALF, ZERO};
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
            {4'd13, 2'd3, 1'b0}: {s_data_r, s_data_i} = {ZERO, N_HALF};
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
            {4'd15, 2'd3, 1'b0}: {s_data_r, s_data_i} = {ZERO, P_HALF};
            {4'd15, 2'd3, 1'b1}: {s_data_r, s_data_i} = {ZERO, N_HALF};
            default: {s_data_r, s_data_i} = {16'b0, 16'b0};
        endcase
    end

    always @(*) begin
        next_state = state;
        mac_en = 1'b0;
       // mac_clear = 1'b0;
        Hq_out_valid = 1'b0;
        hq_one_matrix_done = 1'b0;
        all_16_hq_done = 1'b0;
	case (state)
            S_IDLE: begin
                if (start) begin
                    next_state = S_CALC_ELEMENT;
                end
            end
            S_LOAD_H: begin
                if (H_in_valid && load_row_cnt == 2'b11 && load_col_cnt == 2'b11) begin
                    next_state = S_CALC_ELEMENT;
                end
            end
            //S_CLEAR_MAC: begin
               // mac_clear = 1'b1;
              //  next_state = S_CALC_ELEMENT;
           // end
            S_CALC_ELEMENT: begin
		//mac_clear = (k_counter==0);
                mac_en = 1'b1;
                if (k_counter == 2'b11) begin
                    next_state = S_WAIT_RESULT;
                end
            end
            S_WAIT_RESULT: begin
                if (mac_result_valid) begin
                    Hq_out_valid = 1'b1;
		    Hq_out_r = mac_result_r;
		    Hq_out_i = mac_result_i;
                    if (i_counter == 3 && j_counter == 1) begin
                        hq_one_matrix_done = 1'b1;
                        if (q_counter_reg == 15) begin
                            next_state = S_DONE;
                        end else begin
                            next_state = S_CALC_ELEMENT;
                        end
                    end else begin
                        next_state = S_CALC_ELEMENT;
                    end
                end
            end
            S_DONE: begin
		all_16_hq_done = 1'b1;
                if (!start) begin
                    next_state = S_IDLE;
                end
            end
            default: next_state = S_IDLE;
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
            load_row_cnt <= 2'b0;
            load_col_cnt <= 2'b0;
            q_counter_reg <= 0;
            i_counter <= 2'b0;
            j_counter <= 1'b0;
            k_counter <= 2'b0;
            Hq_out_r <= 16'b0;
            Hq_out_i <= 16'b0;
        end else begin
            state <= next_state;

            if (state == S_IDLE && start) begin
                load_row_cnt <= 2'b0;
                load_col_cnt <= 2'b0;
		q_counter_reg <= 0;
                i_counter <= 2'b0;
                j_counter <= 1'b0;
                k_counter <= 2'b0;
            end
/*
            if (state == S_LOAD_H) begin
                if (H_in_valid) begin
                    h_mem_real[load_row_cnt][load_col_cnt] <= H_in_r;
                    h_mem_imag[load_row_cnt][load_col_cnt] <= H_in_i;
                    if (load_col_cnt == 2'b11) begin
                        load_col_cnt <= 2'b0;
                        load_row_cnt <= load_row_cnt + 1;
                    end else begin
                        load_col_cnt <= load_col_cnt + 1;
                    end
                end
            end
*/
            if (state == S_CALC_ELEMENT) begin
                k_counter <= k_counter + 1;
            end
            if (state == S_WAIT_RESULT && mac_result_valid) begin
                k_counter <= 0;
                if (j_counter == 1'b1) begin
                    j_counter <= 1'b0;
                    if (i_counter == 2'b11) begin
                        i_counter <= 2'b0;
                        q_counter_reg <= q_counter_reg + 1;
                    end else begin
                        i_counter <= i_counter + 1;
                    end
                end else begin
                    j_counter <= j_counter + 1;
                end
            end
        end
    end

    c_mac #(
        .Q(Q),
        .N(N)
    ) c_mac_inst (
        .clk(clk),
        .rst(rst),
        .mac_clear(mac_clear),
        .mac_en(mac_en),
        .in_ar(H_in_r),
        .in_ai(H_in_i),
        .in_br(s_data_r),
        .in_bi(s_data_i),
        .mac_r_out(mac_result_r),
        .mac_i_out(mac_result_i),
        .mac_result_valid(mac_result_valid)
    );

endmodule
