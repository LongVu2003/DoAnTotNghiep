
module matrix_multiplier #(
    parameter Q = 22,
    parameter N = 32,
    parameter CHUNK_WIDTH = 32,
    parameter NUM_CHUNKS  = 8
) (
    input clk,
    input rst,
    input start,
    
    input [ 0 : (NUM_CHUNKS * CHUNK_WIDTH) - 1  ] H_row0_r,
    input [ 0 : (NUM_CHUNKS * CHUNK_WIDTH) - 1  ] H_row0_i,
    input [ 0 : (NUM_CHUNKS * CHUNK_WIDTH) - 1  ] H_row1_r,
    input [ 0 : (NUM_CHUNKS * CHUNK_WIDTH) - 1  ] H_row1_i,
    input [ 0 : (NUM_CHUNKS * CHUNK_WIDTH) - 1  ] H_row2_r,
    input [ 0 : (NUM_CHUNKS * CHUNK_WIDTH) - 1  ] H_row2_i,
    input [ 0 : (NUM_CHUNKS * CHUNK_WIDTH) - 1  ] H_row3_r,
    input [ 0 : (NUM_CHUNKS * CHUNK_WIDTH) - 1  ] H_row3_i,


    output reg hq_one_matrix_done,
    output reg all_16_hq_done,
    output reg Hq_valid,

    output  signed [N-1:0] Hq_out_r, Hq_out_i
    
);
    localparam COUNT_WIDTH = $clog2(NUM_CHUNKS);
	 wire signed [N-1:0] Hq_r, Hq_i;
	 wire [COUNT_WIDTH - 1 : 0] count_delay;
    wire [3:0] q_count_delay;
    wire calc_en_delay;
	 
    assign Hq_out_r = Hq_r;
    assign Hq_out_i = Hq_i;

    //localparam COUNT_WIDTH = $clog2(NUM_CHUNKS); 
    reg [COUNT_WIDTH - 1 : 0] count;
    reg [3:0] q_counter_reg;
    reg cal_en;



    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count <= 0;
            q_counter_reg <= 0;
            cal_en <= 1'b0;
            hq_one_matrix_done <= 1'b0;
            all_16_hq_done <= 1'b0;
        end else begin
            hq_one_matrix_done <= 1'b0;
            all_16_hq_done <= 1'b0;
            
            if (start) begin
                cal_en <= 1'b1;
                count <= 0;
                q_counter_reg <= 0;
            end else if (cal_en) begin
                count <= count + 1;
        
                
                if (count == NUM_CHUNKS - 1) begin
                    if (q_counter_reg == 15) begin
                        q_counter_reg <= 0;
                        cal_en <= 1'b0;
                    end else begin
                        q_counter_reg <= q_counter_reg + 1;
                    end
                end
                if (count_delay == NUM_CHUNKS - 1) begin
                    hq_one_matrix_done <= 1'b1;
                    if (q_count_delay == 15) begin
                        all_16_hq_done <= 1'b1;
                    end 
                end
            end
        end
    end
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            Hq_valid <= 1'b0;
        end else begin
            Hq_valid <= calc_en_delay;
        end
    end
	 /*
    wire [COUNT_WIDTH - 1 : 0] count_delay;
    wire [3:0] q_count_delay;
    wire calc_en_delay;
	 */
    delay_module #(.N(1)) delay_calc_en(
        .clk(clk),
        .rst(rst),
        .in(cal_en),
        .number(6'd3), 
        .out(calc_en_delay)
    );
    delay_module #(.N(N)) delay_count(
        .clk(clk),
        .rst(rst),
        .in(count),
        .number(6'd4), 
        .out(count_delay)
    );
    delay_module #(.N(N)) delay_q_count(
        .clk(clk),
        .rst(rst),
        .in(q_counter_reg),
        .number(6'd4), 
        .out(q_count_delay)
    );

    localparam P_HALF = 32'h00200000;
    localparam N_HALF = 32'hffe00000;
    localparam ZERO   = 32'h00000000;
    
    reg [0 : (NUM_CHUNKS * CHUNK_WIDTH) - 1] S_ROM_R_k0 [0:15];
    reg [0 : (NUM_CHUNKS * CHUNK_WIDTH) - 1] S_ROM_I_k0 [0:15];
    reg [0 : (NUM_CHUNKS * CHUNK_WIDTH) - 1] S_ROM_R_k1 [0:15];
    reg [0 : (NUM_CHUNKS * CHUNK_WIDTH) - 1] S_ROM_I_k1 [0:15];
    reg [0 : (NUM_CHUNKS * CHUNK_WIDTH) - 1] S_ROM_R_k2 [0:15];
    reg [0 : (NUM_CHUNKS * CHUNK_WIDTH) - 1] S_ROM_I_k2 [0:15];
    reg [0 : (NUM_CHUNKS * CHUNK_WIDTH) - 1] S_ROM_R_k3 [0:15];
    reg [ (NUM_CHUNKS * CHUNK_WIDTH) - 1 : 0 ] S_ROM_I_k3 [0:15];
    
    function signed [N-1:0] get_s_r;
        input [3:0] q; input [1:0] k; input j;
        begin
            case ({q, k, j})
                {4'd0, 2'd0, 1'b0}: get_s_r = P_HALF;
                {4'd0, 2'd0, 1'b1}: get_s_r = P_HALF;
                {4'd0, 2'd1, 1'b0}: get_s_r = N_HALF;
                {4'd0, 2'd1, 1'b1}: get_s_r = P_HALF;
                {4'd0, 2'd2, 1'b0}: get_s_r = P_HALF;
                {4'd0, 2'd2, 1'b1}: get_s_r = P_HALF;
                {4'd0, 2'd3, 1'b0}: get_s_r = N_HALF;
                {4'd0, 2'd3, 1'b1}: get_s_r = P_HALF;
                {4'd1, 2'd0, 1'b0}: get_s_r = P_HALF;
                {4'd1, 2'd0, 1'b1}: get_s_r = P_HALF;
                {4'd1, 2'd1, 1'b0}: get_s_r = N_HALF;
                {4'd1, 2'd1, 1'b1}: get_s_r = P_HALF;
                {4'd1, 2'd2, 1'b0}: get_s_r = P_HALF;
                {4'd1, 2'd2, 1'b1}: get_s_r = ZERO;
                {4'd1, 2'd3, 1'b0}: get_s_r = ZERO;
                {4'd1, 2'd3, 1'b1}: get_s_r = P_HALF;
                {4'd2, 2'd0, 1'b0}: get_s_r = P_HALF;
                {4'd2, 2'd0, 1'b1}: get_s_r = P_HALF;
                {4'd2, 2'd1, 1'b0}: get_s_r = N_HALF;
                {4'd2, 2'd1, 1'b1}: get_s_r = P_HALF;
                {4'd2, 2'd2, 1'b0}: get_s_r = P_HALF;
                {4'd2, 2'd2, 1'b1}: get_s_r = N_HALF;
                {4'd2, 2'd3, 1'b0}: get_s_r = P_HALF;
                {4'd2, 2'd3, 1'b1}: get_s_r = P_HALF;
                {4'd3, 2'd0, 1'b0}: get_s_r = P_HALF;
                {4'd3, 2'd0, 1'b1}: get_s_r = P_HALF;
                {4'd3, 2'd1, 1'b0}: get_s_r = N_HALF;
                {4'd3, 2'd1, 1'b1}: get_s_r = P_HALF;
                {4'd3, 2'd2, 1'b0}: get_s_r = P_HALF;
                {4'd3, 2'd2, 1'b1}: get_s_r = ZERO;
                {4'd3, 2'd3, 1'b0}: get_s_r = ZERO;
                {4'd3, 2'd3, 1'b1}: get_s_r = P_HALF;
                {4'd4, 2'd0, 1'b0}: get_s_r = P_HALF;
                {4'd4, 2'd0, 1'b1}: get_s_r = P_HALF;
                {4'd4, 2'd1, 1'b0}: get_s_r = N_HALF;
                {4'd4, 2'd1, 1'b1}: get_s_r = P_HALF;
                {4'd4, 2'd2, 1'b0}: get_s_r = N_HALF;
                {4'd4, 2'd2, 1'b1}: get_s_r = P_HALF;
                {4'd4, 2'd3, 1'b0}: get_s_r = N_HALF;
                {4'd4, 2'd3, 1'b1}: get_s_r = N_HALF;
                {4'd5, 2'd0, 1'b0}: get_s_r = P_HALF;
                {4'd5, 2'd0, 1'b1}: get_s_r = P_HALF;
                {4'd5, 2'd1, 1'b0}: get_s_r = N_HALF;
                {4'd5, 2'd1, 1'b1}: get_s_r = P_HALF;
                {4'd5, 2'd2, 1'b0}: get_s_r = N_HALF;
                {4'd5, 2'd2, 1'b1}: get_s_r = ZERO;
                {4'd5, 2'd3, 1'b0}: get_s_r = ZERO;
                {4'd5, 2'd3, 1'b1}: get_s_r = N_HALF;
                {4'd6, 2'd0, 1'b0}: get_s_r = P_HALF;
                {4'd6, 2'd0, 1'b1}: get_s_r = P_HALF;
                {4'd6, 2'd1, 1'b0}: get_s_r = N_HALF;
                {4'd6, 2'd1, 1'b1}: get_s_r = P_HALF;
                {4'd6, 2'd2, 1'b0}: get_s_r = N_HALF;
                {4'd6, 2'd2, 1'b1}: get_s_r = N_HALF;
                {4'd6, 2'd3, 1'b0}: get_s_r = P_HALF;
                {4'd6, 2'd3, 1'b1}: get_s_r = N_HALF;
                {4'd7, 2'd0, 1'b0}: get_s_r = P_HALF;
                {4'd7, 2'd0, 1'b1}: get_s_r = P_HALF;
                {4'd7, 2'd1, 1'b0}: get_s_r = N_HALF;
                {4'd7, 2'd1, 1'b1}: get_s_r = P_HALF;
                {4'd7, 2'd2, 1'b0}: get_s_r = N_HALF;
                {4'd7, 2'd2, 1'b1}: get_s_r = ZERO;
                {4'd7, 2'd3, 1'b0}: get_s_r = ZERO;
                {4'd7, 2'd3, 1'b1}: get_s_r = N_HALF;
                {4'd8, 2'd0, 1'b0}: get_s_r = P_HALF;
                {4'd8, 2'd0, 1'b1}: get_s_r = P_HALF;
                {4'd8, 2'd1, 1'b0}: get_s_r = N_HALF;
                {4'd8, 2'd1, 1'b1}: get_s_r = P_HALF;
                {4'd8, 2'd2, 1'b0}: get_s_r = ZERO;
                {4'd8, 2'd2, 1'b1}: get_s_r = P_HALF;
                {4'd8, 2'd3, 1'b0}: get_s_r = N_HALF;
                {4'd8, 2'd3, 1'b1}: get_s_r = ZERO;
                {4'd9, 2'd0, 1'b0}: get_s_r = P_HALF;
                {4'd9, 2'd0, 1'b1}: get_s_r = P_HALF;
                {4'd9, 2'd1, 1'b0}: get_s_r = N_HALF;
                {4'd9, 2'd1, 1'b1}: get_s_r = P_HALF;
                {4'd9, 2'd2, 1'b0}: get_s_r = ZERO;
                {4'd9, 2'd2, 1'b1}: get_s_r = ZERO;
                {4'd9, 2'd3, 1'b0}: get_s_r = ZERO;
                {4'd9, 2'd3, 1'b1}: get_s_r = ZERO;
                {4'd10, 2'd0, 1'b0}: get_s_r = P_HALF;
                {4'd10, 2'd0, 1'b1}: get_s_r = P_HALF;
                {4'd10, 2'd1, 1'b0}: get_s_r = N_HALF;
                {4'd10, 2'd1, 1'b1}: get_s_r = P_HALF;
                {4'd10, 2'd2, 1'b0}: get_s_r = ZERO;
                {4'd10, 2'd2, 1'b1}: get_s_r = N_HALF;
                {4'd10, 2'd3, 1'b0}: get_s_r = P_HALF;
                {4'd10, 2'd3, 1'b1}: get_s_r = ZERO;
                {4'd11, 2'd0, 1'b0}: get_s_r = P_HALF;
                {4'd11, 2'd0, 1'b1}: get_s_r = P_HALF;
                {4'd11, 2'd1, 1'b0}: get_s_r = N_HALF;
                {4'd11, 2'd1, 1'b1}: get_s_r = P_HALF;
                {4'd11, 2'd2, 1'b0}: get_s_r = ZERO;
                {4'd11, 2'd2, 1'b1}: get_s_r = ZERO;
                {4'd11, 2'd3, 1'b0}: get_s_r = ZERO;
                {4'd11, 2'd3, 1'b1}: get_s_r = ZERO;
                {4'd12, 2'd0, 1'b0}: get_s_r = P_HALF;
                {4'd12, 2'd0, 1'b1}: get_s_r = P_HALF;
                {4'd12, 2'd1, 1'b0}: get_s_r = N_HALF;
                {4'd12, 2'd1, 1'b1}: get_s_r = P_HALF;
                {4'd12, 2'd2, 1'b0}: get_s_r = ZERO;
                {4'd12, 2'd2, 1'b1}: get_s_r = P_HALF;
                {4'd12, 2'd3, 1'b0}: get_s_r = N_HALF;
                {4'd12, 2'd3, 1'b1}: get_s_r = ZERO;
                {4'd13, 2'd0, 1'b0}: get_s_r = P_HALF;
                {4'd13, 2'd0, 1'b1}: get_s_r = P_HALF;
                {4'd13, 2'd1, 1'b0}: get_s_r = N_HALF;
                {4'd13, 2'd1, 1'b1}: get_s_r = P_HALF;
                {4'd13, 2'd2, 1'b0}: get_s_r = ZERO;
                {4'd13, 2'd2, 1'b1}: get_s_r = ZERO;
                {4'd13, 2'd3, 1'b0}: get_s_r = ZERO;
                {4'd13, 2'd3, 1'b1}: get_s_r = ZERO;
                {4'd14, 2'd0, 1'b0}: get_s_r = P_HALF;
                {4'd14, 2'd0, 1'b1}: get_s_r = P_HALF;
                {4'd14, 2'd1, 1'b0}: get_s_r = N_HALF;
                {4'd14, 2'd1, 1'b1}: get_s_r = P_HALF;
                {4'd14, 2'd2, 1'b0}: get_s_r = ZERO;
                {4'd14, 2'd2, 1'b1}: get_s_r = N_HALF;
                {4'd14, 2'd3, 1'b0}: get_s_r = P_HALF;
                {4'd14, 2'd3, 1'b1}: get_s_r = ZERO;
                {4'd15, 2'd0, 1'b0}: get_s_r = P_HALF;
                {4'd15, 2'd0, 1'b1}: get_s_r = P_HALF;
                {4'd15, 2'd1, 1'b0}: get_s_r = N_HALF;
                {4'd15, 2'd1, 1'b1}: get_s_r = P_HALF;
                {4'd15, 2'd2, 1'b0}: get_s_r = ZERO;
                {4'd15, 2'd2, 1'b1}: get_s_r = ZERO;
                {4'd15, 2'd3, 1'b0}: get_s_r = ZERO;
                {4'd15, 2'd3, 1'b1}: get_s_r = ZERO;
                default: get_s_r = ZERO;
            endcase
        end
    endfunction
    
    function signed [N-1:0] get_s_i;
        input [3:0] q; input [1:0] k; input j;
        begin
            case ({q, k, j})
                {4'd0, 2'd0, 1'b0}: get_s_i = ZERO;
                {4'd0, 2'd0, 1'b1}: get_s_i = ZERO;
                {4'd0, 2'd1, 1'b0}: get_s_i = ZERO;
                {4'd0, 2'd1, 1'b1}: get_s_i = ZERO;
                {4'd0, 2'd2, 1'b0}: get_s_i = ZERO;
                {4'd0, 2'd2, 1'b1}: get_s_i = ZERO;
                {4'd0, 2'd3, 1'b0}: get_s_i = ZERO;
                {4'd0, 2'd3, 1'b1}: get_s_i = ZERO;
                {4'd1, 2'd0, 1'b0}: get_s_i = ZERO;
                {4'd1, 2'd0, 1'b1}: get_s_i = ZERO;
                {4'd1, 2'd1, 1'b0}: get_s_i = ZERO;
                {4'd1, 2'd1, 1'b1}: get_s_i = ZERO;
                {4'd1, 2'd2, 1'b0}: get_s_i = ZERO;
                {4'd1, 2'd2, 1'b1}: get_s_i = P_HALF;
                {4'd1, 2'd3, 1'b0}: get_s_i = P_HALF;
                {4'd1, 2'd3, 1'b1}: get_s_i = ZERO;
                {4'd2, 2'd0, 1'b0}: get_s_i = ZERO;
                {4'd2, 2'd0, 1'b1}: get_s_i = ZERO;
                {4'd2, 2'd1, 1'b0}: get_s_i = ZERO;
                {4'd2, 2'd1, 1'b1}: get_s_i = ZERO;
                {4'd2, 2'd2, 1'b0}: get_s_i = ZERO;
                {4'd2, 2'd2, 1'b1}: get_s_i = ZERO;
                {4'd2, 2'd3, 1'b0}: get_s_i = ZERO;
                {4'd2, 2'd3, 1'b1}: get_s_i = ZERO;
                {4'd3, 2'd0, 1'b0}: get_s_i = ZERO;
                {4'd3, 2'd0, 1'b1}: get_s_i = ZERO;
                {4'd3, 2'd1, 1'b0}: get_s_i = ZERO;
                {4'd3, 2'd1, 1'b1}: get_s_i = ZERO;
                {4'd3, 2'd2, 1'b0}: get_s_i = ZERO;
                {4'd3, 2'd2, 1'b1}: get_s_i = N_HALF;
                {4'd3, 2'd3, 1'b0}: get_s_i = N_HALF;
                {4'd3, 2'd3, 1'b1}: get_s_i = ZERO;
                {4'd4, 2'd0, 1'b0}: get_s_i = ZERO;
                {4'd4, 2'd0, 1'b1}: get_s_i = ZERO;
                {4'd4, 2'd1, 1'b0}: get_s_i = ZERO;
                {4'd4, 2'd1, 1'b1}: get_s_i = ZERO;
                {4'd4, 2'd2, 1'b0}: get_s_i = ZERO;
                {4'd4, 2'd2, 1'b1}: get_s_i = ZERO;
                {4'd4, 2'd3, 1'b0}: get_s_i = ZERO;
                {4'd4, 2'd3, 1'b1}: get_s_i = ZERO;
                {4'd5, 2'd0, 1'b0}: get_s_i = ZERO;
                {4'd5, 2'd0, 1'b1}: get_s_i = ZERO;
                {4'd5, 2'd1, 1'b0}: get_s_i = ZERO;
                {4'd5, 2'd1, 1'b1}: get_s_i = ZERO;
                {4'd5, 2'd2, 1'b0}: get_s_i = ZERO;
                {4'd5, 2'd2, 1'b1}: get_s_i = P_HALF;
                {4'd5, 2'd3, 1'b0}: get_s_i = P_HALF;
                {4'd5, 2'd3, 1'b1}: get_s_i = ZERO;
                {4'd6, 2'd0, 1'b0}: get_s_i = ZERO;
                {4'd6, 2'd0, 1'b1}: get_s_i = ZERO;
                {4'd6, 2'd1, 1'b0}: get_s_i = ZERO;
                {4'd6, 2'd1, 1'b1}: get_s_i = ZERO;
                {4'd6, 2'd2, 1'b0}: get_s_i = ZERO;
                {4'd6, 2'd2, 1'b1}: get_s_i = ZERO;
                {4'd6, 2'd3, 1'b0}: get_s_i = ZERO;
                {4'd6, 2'd3, 1'b1}: get_s_i = ZERO;
                {4'd7, 2'd0, 1'b0}: get_s_i = ZERO;
                {4'd7, 2'd0, 1'b1}: get_s_i = ZERO;
                {4'd7, 2'd1, 1'b0}: get_s_i = ZERO;
                {4'd7, 2'd1, 1'b1}: get_s_i = ZERO;
                {4'd7, 2'd2, 1'b0}: get_s_i = ZERO;
                {4'd7, 2'd2, 1'b1}: get_s_i = N_HALF;
                {4'd7, 2'd3, 1'b0}: get_s_i = N_HALF;
                {4'd7, 2'd3, 1'b1}: get_s_i = ZERO;
                {4'd8, 2'd0, 1'b0}: get_s_i = ZERO;
                {4'd8, 2'd0, 1'b1}: get_s_i = ZERO;
                {4'd8, 2'd1, 1'b0}: get_s_i = ZERO;
                {4'd8, 2'd1, 1'b1}: get_s_i = ZERO;
                {4'd8, 2'd2, 1'b0}: get_s_i = P_HALF;
                {4'd8, 2'd2, 1'b1}: get_s_i = ZERO;
                {4'd8, 2'd3, 1'b0}: get_s_i = ZERO;
                {4'd8, 2'd3, 1'b1}: get_s_i = P_HALF;
                {4'd9, 2'd0, 1'b0}: get_s_i = ZERO;
                {4'd9, 2'd0, 1'b1}: get_s_i = ZERO;
                {4'd9, 2'd1, 1'b0}: get_s_i = ZERO;
                {4'd9, 2'd1, 1'b1}: get_s_i = ZERO;
                {4'd9, 2'd2, 1'b0}: get_s_i = P_HALF;
                {4'd9, 2'd2, 1'b1}: get_s_i = P_HALF;
                {4'd9, 2'd3, 1'b0}: get_s_i = P_HALF;
                {4'd9, 2'd3, 1'b1}: get_s_i = P_HALF;
                {4'd10, 2'd0, 1'b0}: get_s_i = ZERO;
                {4'd10, 2'd0, 1'b1}: get_s_i = ZERO;
                {4'd10, 2'd1, 1'b0}: get_s_i = ZERO;
                {4'd10, 2'd1, 1'b1}: get_s_i = ZERO;
                {4'd10, 2'd2, 1'b0}: get_s_i = P_HALF;
                {4'd10, 2'd2, 1'b1}: get_s_i = ZERO;
                {4'd10, 2'd3, 1'b0}: get_s_i = ZERO;
                {4'd10, 2'd3, 1'b1}: get_s_i = P_HALF;
                {4'd11, 2'd0, 1'b0}: get_s_i = ZERO;
                {4'd11, 2'd0, 1'b1}: get_s_i = ZERO;
                {4'd11, 2'd1, 1'b0}: get_s_i = ZERO;
                {4'd11, 2'd1, 1'b1}: get_s_i = ZERO;
                {4'd11, 2'd2, 1'b0}: get_s_i = P_HALF;
                {4'd11, 2'd2, 1'b1}: get_s_i = N_HALF;
                {4'd11, 2'd3, 1'b0}: get_s_i = N_HALF;
                {4'd11, 2'd3, 1'b1}: get_s_i = P_HALF;
                {4'd12, 2'd0, 1'b0}: get_s_i = ZERO;
                {4'd12, 2'd0, 1'b1}: get_s_i = ZERO;
                {4'd12, 2'd1, 1'b0}: get_s_i = ZERO;
                {4'd12, 2'd1, 1'b1}: get_s_i = ZERO;
                {4'd12, 2'd2, 1'b0}: get_s_i = N_HALF;
                {4'd12, 2'd2, 1'b1}: get_s_i = ZERO;
                {4'd12, 2'd3, 1'b0}: get_s_i = ZERO;
                {4'd12, 2'd3, 1'b1}: get_s_i = N_HALF;
                {4'd13, 2'd0, 1'b0}: get_s_i = ZERO;
                {4'd13, 2'd0, 1'b1}: get_s_i = ZERO;
                {4'd13, 2'd1, 1'b0}: get_s_i = ZERO;
                {4'd13, 2'd1, 1'b1}: get_s_i = ZERO;
                {4'd13, 2'd2, 1'b0}: get_s_i = N_HALF;
                {4'd13, 2'd2, 1'b1}: get_s_i = P_HALF;
                {4'd13, 2'd3, 1'b0}: get_s_i = P_HALF;
                {4'd13, 2'd3, 1'b1}: get_s_i = N_HALF;
                {4'd14, 2'd0, 1'b0}: get_s_i = ZERO;
                {4'd14, 2'd0, 1'b1}: get_s_i = ZERO;
                {4'd14, 2'd1, 1'b0}: get_s_i = ZERO;
                {4'd14, 2'd1, 1'b1}: get_s_i = ZERO;
                {4'd14, 2'd2, 1'b0}: get_s_i = N_HALF;
                {4'd14, 2'd2, 1'b1}: get_s_i = ZERO;
                {4'd14, 2'd3, 1'b0}: get_s_i = ZERO;
                {4'd14, 2'd3, 1'b1}: get_s_i = N_HALF;
                {4'd15, 2'd0, 1'b0}: get_s_i = ZERO;
                {4'd15, 2'd0, 1'b1}: get_s_i = ZERO;
                {4'd15, 2'd1, 1'b0}: get_s_i = ZERO;
                {4'd15, 2'd1, 1'b1}: get_s_i = ZERO;
                {4'd15, 2'd2, 1'b0}: get_s_i = N_HALF;
                {4'd15, 2'd2, 1'b1}: get_s_i = N_HALF;
                {4'd15, 2'd3, 1'b0}: get_s_i = N_HALF;
                {4'd15, 2'd3, 1'b1}: get_s_i = N_HALF;
                default: get_s_i = ZERO;
            endcase
        end
    endfunction
    
    integer q_idx;
    initial begin
        for (q_idx = 0; q_idx < 16; q_idx = q_idx + 1) begin
            S_ROM_R_k0[q_idx] = { {4{get_s_r(q_idx, 0, 0), get_s_r(q_idx, 0, 1)}} };
            S_ROM_I_k0[q_idx] = { {4{get_s_i(q_idx, 0, 0), get_s_i(q_idx, 0, 1)}} };
            
            S_ROM_R_k1[q_idx] = { {4{get_s_r(q_idx, 1, 0), get_s_r(q_idx, 1, 1)}} };
            S_ROM_I_k1[q_idx] = { {4{get_s_i(q_idx, 1, 0), get_s_i(q_idx, 1, 1)}} };
            
            S_ROM_R_k2[q_idx] = { {4{get_s_r(q_idx, 2, 0), get_s_r(q_idx, 2, 1)}} };
            S_ROM_I_k2[q_idx] = { {4{get_s_i(q_idx, 2, 0), get_s_i(q_idx, 2, 1)}} };
            
            S_ROM_R_k3[q_idx] = { {4{get_s_r(q_idx, 3, 0), get_s_r(q_idx, 3, 1)}} };
            S_ROM_I_k3[q_idx] = { {4{get_s_i(q_idx, 3, 0), get_s_i(q_idx, 3, 1)}} };
        end
    end
    

    wire [$clog2(NUM_CHUNKS * CHUNK_WIDTH) - 1 : 0] start_bit;

    assign start_bit = count * (CHUNK_WIDTH ); 

    wire signed [N-1:0] h0_r, h0_i, h1_r, h1_i, h2_r, h2_i, h3_r, h3_i;
    
    assign h0_r = H_row0_r[ start_bit +: CHUNK_WIDTH ];
    assign h0_i = H_row0_i[ start_bit +: CHUNK_WIDTH ];
    assign h1_r = H_row1_r[ start_bit +: CHUNK_WIDTH ];
    assign h1_i = H_row1_i[ start_bit +: CHUNK_WIDTH ];
    assign h2_r = H_row2_r[ start_bit +: CHUNK_WIDTH ];
    assign h2_i = H_row2_i[ start_bit +: CHUNK_WIDTH ];
    assign h3_r = H_row3_r[ start_bit +: CHUNK_WIDTH ];
    assign h3_i = H_row3_i[ start_bit +: CHUNK_WIDTH ];
    
    
    
    wire signed [N-1:0] s0_r, s0_i, s1_r, s1_i, s2_r, s2_i, s3_r, s3_i;
    

    wire [0 : (NUM_CHUNKS * CHUNK_WIDTH) - 1] s_bus_r_k0, s_bus_i_k0;
    wire [0 : (NUM_CHUNKS * CHUNK_WIDTH) - 1] s_bus_r_k1, s_bus_i_k1;
    wire [0 : (NUM_CHUNKS * CHUNK_WIDTH) - 1] s_bus_r_k2, s_bus_i_k2;
    wire [0 : (NUM_CHUNKS * CHUNK_WIDTH) - 1] s_bus_r_k3, s_bus_i_k3;

    assign s_bus_r_k0 = S_ROM_R_k0[q_counter_reg];
    assign s_bus_i_k0 = S_ROM_I_k0[q_counter_reg];
    assign s_bus_r_k1 = S_ROM_R_k1[q_counter_reg];
    assign s_bus_i_k1 = S_ROM_I_k1[q_counter_reg];
    assign s_bus_r_k2 = S_ROM_R_k2[q_counter_reg];
    assign s_bus_i_k2 = S_ROM_I_k2[q_counter_reg];
    assign s_bus_r_k3 = S_ROM_R_k3[q_counter_reg];
    assign s_bus_i_k3 = S_ROM_I_k3[q_counter_reg];

    assign s0_r = s_bus_r_k0[ start_bit +: CHUNK_WIDTH ];
    assign s0_i = s_bus_i_k0[ start_bit +: CHUNK_WIDTH ];
    assign s1_r = s_bus_r_k1[ start_bit +: CHUNK_WIDTH ];
    assign s1_i = s_bus_i_k1[ start_bit +: CHUNK_WIDTH ];
    assign s2_r = s_bus_r_k2[ start_bit +: CHUNK_WIDTH ];
    assign s2_i = s_bus_i_k2[ start_bit +: CHUNK_WIDTH ];
    assign s3_r = s_bus_r_k3[ start_bit +: CHUNK_WIDTH ];
    assign s3_i = s_bus_i_k3[ start_bit +: CHUNK_WIDTH ];
    
    wire signed [N-1:0] pr0, pi0, pr1, pi1, pr2, pi2, pr3, pi3;

    cmult #(.Q(Q), .N(N)) cmult_i0 (
        .clk(clk), .rst(rst), 
        .ar(h0_r), .ai(h0_i), .br(s0_r), .bi(s0_i), 
        .pr(pr0), .pi(pi0)
    );
    cmult #(.Q(Q), .N(N)) cmult_i1 (
        .clk(clk), .rst(rst), 
        .ar(h1_r), .ai(h1_i), .br(s1_r), .bi(s1_i), 
        .pr(pr1), .pi(pi1)
    );
    cmult #(.Q(Q), .N(N)) cmult_i2 (
        .clk(clk), .rst(rst), 
        .ar(h2_r), .ai(h2_i), .br(s2_r), .bi(s2_i), 
        .pr(pr2), .pi(pi2)
    );
    cmult #(.Q(Q), .N(N)) cmult_i3 (
        .clk(clk), .rst(rst), 
        .ar(h3_r), .ai(h3_i), .br(s3_r), .bi(s3_i), 
        .pr(pr3), .pi(pi3)
    );
    //wire signed [N-1:0] Hq_r, Hq_i;
    assign Hq_r = pr0 + pr1 + pr2 + pr3;
    assign Hq_i = pi0 + pi1 + pi2 + pi3;

endmodule

