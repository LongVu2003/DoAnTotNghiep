/*
** Author     : Doan Long Vu
** Date       : 18/8/2025
** Module     : so_ml_decoder_top - CÓ KHỞI TẠO LUT:
** Description: Top-level module for the SO-ML decoder.
*/
module so_ml_decoder_top #(
    parameter Q = 8,
    parameter N = 16,
    parameter ACC_WIDTH = 48
) (
    input clk,
    input rst,
    input start,
    input data_valid,
    input signed [N-1:0] H_serial_in,
    input signed [N-1:0] Y_serial_in,

    output reg [11:0] decoded_bits,
    output reg output_valid
);
    // Main FSM states
    localparam FSM_IDLE = 3'b000, FSM_LOAD_HY = 3'b001, FSM_PROCESS = 3'b010,
               FSM_FIND_MIN = 3'b011, FSM_OUTPUT = 3'b100;
    reg [2:0] state;

    // Internal Storage (BRAMs)
    reg signed [N-1:0] H_bram [0:3][0:3][0:1];
    reg signed [N-1:0] Y_bram [0:3][0:1][0:1];
    reg [5:0] load_counter;

    // LUTs (ROMs) - Khai báo bộ nhớ cho các bảng tra cứu
    reg signed [N-1:0] Sq_lut [0:15][0:3][0:1][0:1]; // [q_idx][row][col][re/im]
    reg signed [N-1:0] Vm_lut [0:3];
    reg [1:0] Bv_lut [0:3];
    reg [3:0] Bs_lut [0:15];

    // Flattened wires to connect to PE array
    wire signed [32*N-1:0] H_bram_flat;
    wire signed [16*N-1:0] Y_bram_flat; // Corrected size for 4x2 complex
    wire signed [16*N-1:0] Sq_lut_flat [0:15];
    wire signed [4*N-1:0]  Vm_lut_flat; 
    // Separate counters for parallel loading
    reg [4:0] h_load_counter; // Counts 0 to 31
    reg [3:0] y_load_counter; // Counts 0 to 15
    // Logic để "làm phẳng" các mảng 2D/3D/4D thành vector 1D để truyền qua cổng module
    genvar i, j, k, p;
    generate
        for (i = 0; i < 4; i = i + 1) begin
            assign Vm_lut_flat[i*N +: N] = Vm_lut[i];
            for (j = 0; j < 4; j = j + 1) begin
                for (k = 0; k < 2; k = k + 1) begin
                    assign H_bram_flat[((i*4+j)*2+k)*N +: N] = H_bram[i][j][k];
                end
            end
        end
        for (i = 0; i < 4; i = i + 1) 
	    for (j = 0; j < 2; j = j + 1) 
                for (k = 0; k < 2; k = k + 1)
                    assign Y_bram_flat[((i*2+j)*2+k)*N +: N] = Y_bram[i][j][k];
        for (p = 0; p < 16; p = p + 1)
            for (i = 0; i < 4; i = i + 1) 
		for (j = 0; j < 2; j = j + 1) 
		     for (k = 0; k < 2; k = k + 1)
                         assign Sq_lut_flat[p][((i*2+j)*2+k)*N +: N] = Sq_lut[p][i][j][k];
    endgenerate

    // Wires for PE array
    wire signed [ACC_WIDTH-1:0] d_q_all [0:15];
    wire signed [16*ACC_WIDTH-1:0] d_q_all_flat;
    wire [1:0] mImin1_all[0:15], mQmin1_all[0:15], mImin2_all[0:15], mQmin2_all[0:15];
    wire pe_valid_all [0:15];

    // Flatten d_q_all for find_min_16
    genvar i_dq;
    generate
        for(i_dq = 0; i_dq < 16; i_dq = i_dq + 1) begin
            assign d_q_all_flat[i_dq*ACC_WIDTH +: ACC_WIDTH] = d_q_all[i_dq];
        end
    endgenerate
    
    // Wires for Comparator Tree
    wire signed [ACC_WIDTH-1:0] d_min_val;
    wire [3:0] q_min_idx;
    wire find_min_valid;

    // Control signals
    reg start_pe_processing;
    reg start_find_min;

    // --- KHỞI TẠO GIÁ TRỊ CHO CÁC BẢNG TRA CỨU (LUT) ---
    initial begin : INITAL
        // Khai báo các hằng số ở định dạng Q8.8
        localparam P_HALF = 16'sd128;  // 0.5 * 2^8
        localparam N_HALF = -16'sd128; // -0.5 * 2^8
        localparam ZERO   = 16'sd0;

        // Bảng Vm_lut: {-3, -1, 1, 3}
        Vm_lut[0] = -768; // -3 * 2^8
        Vm_lut[1] = -256; // -1 * 2^8
        Vm_lut[2] =  256; //  1 * 2^8
        Vm_lut[3] =  768; //  3 * 2^8

        // Bảng Bv_lut: Ánh xạ chỉ số m sang 2 bit
        Bv_lut[0] = 2'b00; 
        Bv_lut[1] = 2'b01; 
        Bv_lut[2] = 2'b11; 
        Bv_lut[3] = 2'b10;

        // Bảng Bs_lut: Ánh xạ chỉ số q sang 4 bit
        Bs_lut[0]  = 4'b0000; Bs_lut[1]  = 4'b0001; Bs_lut[2]  = 4'b0010; Bs_lut[3]  = 4'b0011;
        Bs_lut[4]  = 4'b0100; Bs_lut[5]  = 4'b0101; Bs_lut[6]  = 4'b0110; Bs_lut[7]  = 4'b0111;
        Bs_lut[8]  = 4'b1000; Bs_lut[9]  = 4'b1001; Bs_lut[10] = 4'b1010; Bs_lut[11] = 4'b1011;
        Bs_lut[12] = 4'b1100; Bs_lut[13] = 4'b1101; Bs_lut[14] = 4'b1110; Bs_lut[15] = 4'b1111;

        // Bảng Sq_lut: 16 ma trận S_q
        // Mỗi phần tử Sq[q][hàng][cột] = {phần thực, phần ảo}
        // Công thức: G(s) = (1/2) * [s1, s2; -s2*, s1*; s3, s4; -s4*, s3*]
        
        // s_0 = [1, 1, 1, 1]
        Sq_lut[0][0][0][0] = P_HALF; Sq_lut[0][0][0][1] = ZERO;   Sq_lut[0][0][1][0] = P_HALF; Sq_lut[0][0][1][1] = ZERO;
        Sq_lut[0][1][0][0] = N_HALF; Sq_lut[0][1][0][1] = ZERO;   Sq_lut[0][1][1][0] = P_HALF; Sq_lut[0][1][1][1] = ZERO;
        Sq_lut[0][2][0][0] = P_HALF; Sq_lut[0][2][0][1] = ZERO;   Sq_lut[0][2][1][0] = P_HALF; Sq_lut[0][2][1][1] = ZERO;
        Sq_lut[0][3][0][0] = N_HALF; Sq_lut[0][3][0][1] = ZERO;   Sq_lut[0][3][1][0] = P_HALF; Sq_lut[0][3][1][1] = ZERO;
        
        // s_1 = [1, 1, 1, j]
        Sq_lut[1][0][0][0] = P_HALF; Sq_lut[1][0][0][1] = ZERO;   Sq_lut[1][0][1][0] = P_HALF; Sq_lut[1][0][1][1] = ZERO;
        Sq_lut[1][1][0][0] = N_HALF; Sq_lut[1][1][0][1] = ZERO;   Sq_lut[1][1][1][0] = P_HALF; Sq_lut[1][1][1][1] = ZERO;
        Sq_lut[1][2][0][0] = P_HALF; Sq_lut[1][2][0][1] = ZERO;   Sq_lut[1][2][1][0] = ZERO;   Sq_lut[1][2][1][1] = P_HALF;
        Sq_lut[1][3][0][0] = ZERO;   Sq_lut[1][3][0][1] = N_HALF; Sq_lut[1][3][1][0] = P_HALF; Sq_lut[1][3][1][1] = ZERO;

        // s_2 = [1, 1, 1, -1]
        Sq_lut[2][0][0][0] = P_HALF; Sq_lut[2][0][0][1] = ZERO;   Sq_lut[2][0][1][0] = P_HALF; Sq_lut[2][0][1][1] = ZERO;
        Sq_lut[2][1][0][0] = N_HALF; Sq_lut[2][1][0][1] = ZERO;   Sq_lut[2][1][1][0] = P_HALF; Sq_lut[2][1][1][1] = ZERO;
        Sq_lut[2][2][0][0] = P_HALF; Sq_lut[2][2][0][1] = ZERO;   Sq_lut[2][2][1][0] = N_HALF; Sq_lut[2][2][1][1] = ZERO;
        Sq_lut[2][3][0][0] = P_HALF; Sq_lut[2][3][0][1] = ZERO;   Sq_lut[2][3][1][0] = P_HALF; Sq_lut[2][3][1][1] = ZERO;

        // s_3 = [1, 1, 1, -j]
        Sq_lut[3][0][0][0] = P_HALF; Sq_lut[3][0][0][1] = ZERO;   Sq_lut[3][0][1][0] = P_HALF; Sq_lut[3][0][1][1] = ZERO;
        Sq_lut[3][1][0][0] = N_HALF; Sq_lut[3][1][0][1] = ZERO;   Sq_lut[3][1][1][0] = P_HALF; Sq_lut[3][1][1][1] = ZERO;
        Sq_lut[3][2][0][0] = P_HALF; Sq_lut[3][2][0][1] = ZERO;   Sq_lut[3][2][1][0] = ZERO;   Sq_lut[3][2][1][1] = N_HALF;
        Sq_lut[3][3][0][0] = ZERO;   Sq_lut[3][3][0][1] = P_HALF; Sq_lut[3][3][1][0] = P_HALF; Sq_lut[3][3][1][1] = ZERO;

        // s_4 = [1, 1, j, 1]
        Sq_lut[4][0][0][0] = P_HALF; Sq_lut[4][0][0][1] = ZERO;   Sq_lut[4][0][1][0] = P_HALF; Sq_lut[4][0][1][1] = ZERO;
        Sq_lut[4][1][0][0] = N_HALF; Sq_lut[4][1][0][1] = ZERO;   Sq_lut[4][1][1][0] = P_HALF; Sq_lut[4][1][1][1] = ZERO;
        Sq_lut[4][2][0][0] = ZERO;   Sq_lut[4][2][0][1] = P_HALF; Sq_lut[4][2][1][0] = P_HALF; Sq_lut[4][2][1][1] = ZERO;
        Sq_lut[4][3][0][0] = N_HALF; Sq_lut[4][3][0][1] = ZERO;   Sq_lut[4][3][1][0] = ZERO;   Sq_lut[4][3][1][1] = P_HALF;

        // s_5 = [1, 1, j, j]
        Sq_lut[5][0][0][0] = P_HALF; Sq_lut[5][0][0][1] = ZERO;   Sq_lut[5][0][1][0] = P_HALF; Sq_lut[5][0][1][1] = ZERO;
        Sq_lut[5][1][0][0] = N_HALF; Sq_lut[5][1][0][1] = ZERO;   Sq_lut[5][1][1][0] = P_HALF; Sq_lut[5][1][1][1] = ZERO;
        Sq_lut[5][2][0][0] = ZERO;   Sq_lut[5][2][0][1] = P_HALF; Sq_lut[5][2][1][0] = ZERO;   Sq_lut[5][2][1][1] = P_HALF;
        Sq_lut[5][3][0][0] = ZERO;   Sq_lut[5][3][0][1] = N_HALF; Sq_lut[5][3][1][0] = ZERO;   Sq_lut[5][3][1][1] = P_HALF;

        // s_6 = [1, 1, j, -1]
        Sq_lut[6][0][0][0] = P_HALF; Sq_lut[6][0][0][1] = ZERO;   Sq_lut[6][0][1][0] = P_HALF; Sq_lut[6][0][1][1] = ZERO;
        Sq_lut[6][1][0][0] = N_HALF; Sq_lut[6][1][0][1] = ZERO;   Sq_lut[6][1][1][0] = P_HALF; Sq_lut[6][1][1][1] = ZERO;
        Sq_lut[6][2][0][0] = ZERO;   Sq_lut[6][2][0][1] = P_HALF; Sq_lut[6][2][1][0] = N_HALF; Sq_lut[6][2][1][1] = ZERO;
        Sq_lut[6][3][0][0] = P_HALF; Sq_lut[6][3][0][1] = ZERO;   Sq_lut[6][3][1][0] = ZERO;   Sq_lut[6][3][1][1] = P_HALF;

        // s_7 = [1, 1, j, -j]
        Sq_lut[7][0][0][0] = P_HALF; Sq_lut[7][0][0][1] = ZERO;   Sq_lut[7][0][1][0] = P_HALF; Sq_lut[7][0][1][1] = ZERO;
        Sq_lut[7][1][0][0] = N_HALF; Sq_lut[7][1][0][1] = ZERO;   Sq_lut[7][1][1][0] = P_HALF; Sq_lut[7][1][1][1] = ZERO;
        Sq_lut[7][2][0][0] = ZERO;   Sq_lut[7][2][0][1] = P_HALF; Sq_lut[7][2][1][0] = ZERO;   Sq_lut[7][2][1][1] = N_HALF;
        Sq_lut[7][3][0][0] = ZERO;   Sq_lut[7][3][0][1] = P_HALF; Sq_lut[7][3][1][0] = ZERO;   Sq_lut[7][3][1][1] = P_HALF;

        // s_8 = [1, 1, -1, 1]
        Sq_lut[8][0][0][0] = P_HALF; Sq_lut[8][0][0][1] = ZERO;   Sq_lut[8][0][1][0] = P_HALF; Sq_lut[8][0][1][1] = ZERO;
        Sq_lut[8][1][0][0] = N_HALF; Sq_lut[8][1][0][1] = ZERO;   Sq_lut[8][1][1][0] = P_HALF; Sq_lut[8][1][1][1] = ZERO;
        Sq_lut[8][2][0][0] = N_HALF; Sq_lut[8][2][0][1] = ZERO;   Sq_lut[8][2][1][0] = P_HALF; Sq_lut[8][2][1][1] = ZERO;
        Sq_lut[8][3][0][0] = N_HALF; Sq_lut[8][3][0][1] = ZERO;   Sq_lut[8][3][1][0] = N_HALF; Sq_lut[8][3][1][1] = ZERO;

        // s_9 = [1, 1, -1, j]
        Sq_lut[9][0][0][0] = P_HALF; Sq_lut[9][0][0][1] = ZERO;   Sq_lut[9][0][1][0] = P_HALF; Sq_lut[9][0][1][1] = ZERO;
        Sq_lut[9][1][0][0] = N_HALF; Sq_lut[9][1][0][1] = ZERO;   Sq_lut[9][1][1][0] = P_HALF; Sq_lut[9][1][1][1] = ZERO;
        Sq_lut[9][2][0][0] = N_HALF; Sq_lut[9][2][0][1] = ZERO;   Sq_lut[9][2][1][0] = ZERO;   Sq_lut[9][2][1][1] = P_HALF;
        Sq_lut[9][3][0][0] = ZERO;   Sq_lut[9][3][0][1] = N_HALF; Sq_lut[9][3][1][0] = N_HALF; Sq_lut[9][3][1][1] = ZERO;

        // s_10 = [1, 1, -1, -1]
        Sq_lut[10][0][0][0] = P_HALF; Sq_lut[10][0][0][1] = ZERO;   Sq_lut[10][0][1][0] = P_HALF; Sq_lut[10][0][1][1] = ZERO;
        Sq_lut[10][1][0][0] = N_HALF; Sq_lut[10][1][0][1] = ZERO;   Sq_lut[10][1][1][0] = P_HALF; Sq_lut[10][1][1][1] = ZERO;
        Sq_lut[10][2][0][0] = N_HALF; Sq_lut[10][2][0][1] = ZERO;   Sq_lut[10][2][1][0] = N_HALF; Sq_lut[10][2][1][1] = ZERO;
        Sq_lut[10][3][0][0] = P_HALF; Sq_lut[10][3][0][1] = ZERO;   Sq_lut[10][3][1][0] = N_HALF; Sq_lut[10][3][1][1] = ZERO;

        // s_11 = [1, 1, -1, -j]
        Sq_lut[11][0][0][0] = P_HALF; Sq_lut[11][0][0][1] = ZERO;   Sq_lut[11][0][1][0] = P_HALF; Sq_lut[11][0][1][1] = ZERO;
        Sq_lut[11][1][0][0] = N_HALF; Sq_lut[11][1][0][1] = ZERO;   Sq_lut[11][1][1][0] = P_HALF; Sq_lut[11][1][1][1] = ZERO;
        Sq_lut[11][2][0][0] = N_HALF; Sq_lut[11][2][0][1] = ZERO;   Sq_lut[11][2][1][0] = ZERO;   Sq_lut[11][2][1][1] = N_HALF;
        Sq_lut[11][3][0][0] = ZERO;   Sq_lut[11][3][0][1] = P_HALF; Sq_lut[11][3][1][0] = N_HALF; Sq_lut[11][3][1][1] = ZERO;

        // s_12 = [1, 1, -j, 1]
        Sq_lut[12][0][0][0] = P_HALF; Sq_lut[12][0][0][1] = ZERO;   Sq_lut[12][0][1][0] = P_HALF; Sq_lut[12][0][1][1] = ZERO;
        Sq_lut[12][1][0][0] = N_HALF; Sq_lut[12][1][0][1] = ZERO;   Sq_lut[12][1][1][0] = P_HALF; Sq_lut[12][1][1][1] = ZERO;
        Sq_lut[12][2][0][0] = ZERO;   Sq_lut[12][2][0][1] = N_HALF; Sq_lut[12][2][1][0] = P_HALF; Sq_lut[12][2][1][1] = ZERO;
        Sq_lut[12][3][0][0] = N_HALF; Sq_lut[12][3][0][1] = ZERO;   Sq_lut[12][3][1][0] = ZERO;   Sq_lut[12][3][1][1] = N_HALF;

        // s_13 = [1, 1, -j, j]
        Sq_lut[13][0][0][0] = P_HALF; Sq_lut[13][0][0][1] = ZERO;   Sq_lut[13][0][1][0] = P_HALF; Sq_lut[13][0][1][1] = ZERO;
        Sq_lut[13][1][0][0] = N_HALF; Sq_lut[13][1][0][1] = ZERO;   Sq_lut[13][1][1][0] = P_HALF; Sq_lut[13][1][1][1] = ZERO;
        Sq_lut[13][2][0][0] = ZERO;   Sq_lut[13][2][0][1] = N_HALF; Sq_lut[13][2][1][0] = ZERO;   Sq_lut[13][2][1][1] = P_HALF;
        Sq_lut[13][3][0][0] = ZERO;   Sq_lut[13][3][0][1] = N_HALF; Sq_lut[13][3][1][0] = ZERO;   Sq_lut[13][3][1][1] = N_HALF;

        // s_14 = [1, 1, -j, -1]
        Sq_lut[14][0][0][0] = P_HALF; Sq_lut[14][0][0][1] = ZERO;   Sq_lut[14][0][1][0] = P_HALF; Sq_lut[14][0][1][1] = ZERO;
        Sq_lut[14][1][0][0] = N_HALF; Sq_lut[14][1][0][1] = ZERO;   Sq_lut[14][1][1][0] = P_HALF; Sq_lut[14][1][1][1] = ZERO;
        Sq_lut[14][2][0][0] = ZERO;   Sq_lut[14][2][0][1] = N_HALF; Sq_lut[14][2][1][0] = N_HALF; Sq_lut[14][2][1][1] = ZERO;
        Sq_lut[14][3][0][0] = P_HALF; Sq_lut[14][3][0][1] = ZERO;   Sq_lut[14][3][1][0] = ZERO;   Sq_lut[14][3][1][1] = N_HALF;

        // s_15 = [1, 1, -j, -j]
        Sq_lut[15][0][0][0] = P_HALF; Sq_lut[15][0][0][1] = ZERO;   Sq_lut[15][0][1][0] = P_HALF; Sq_lut[15][0][1][1] = ZERO;
        Sq_lut[15][1][0][0] = N_HALF; Sq_lut[15][1][0][1] = ZERO;   Sq_lut[15][1][1][0] = P_HALF; Sq_lut[15][1][1][1] = ZERO;
        Sq_lut[15][2][0][0] = ZERO;   Sq_lut[15][2][0][1] = N_HALF; Sq_lut[15][2][1][0] = ZERO;   Sq_lut[15][2][1][1] = N_HALF;
        Sq_lut[15][3][0][0] = ZERO;   Sq_lut[15][3][0][1] = P_HALF; Sq_lut[15][3][1][0] = ZERO;   Sq_lut[15][3][1][1] = N_HALF;

    end

    // Processing Engine Array
    generate
        for (i = 0; i < 16; i = i + 1) begin : pe_array
            pe_unit #(
                .Q(Q), .N(N), .ACC_WIDTH(ACC_WIDTH)
            ) pe_inst (
                .clk(clk), .rst(rst),
                .start_process(start_pe_processing),
                .H_in_flat(H_bram_flat),
                .Y_in_flat(Y_bram_flat),
                // Truy cập vào LUT và cung cấp ma trận Sq tương ứng cho mỗi PE
                .Sq_in_flat(Sq_lut_flat[i]),
                .Vm_in_flat(Vm_lut_flat),
                .d_q_out(d_q_all[i]),
                .mImin1_out(mImin1_all[i]), .mQmin1_out(mQmin1_all[i]),
                .mImin2_out(mImin2_all[i]), .mQmin2_out(mQmin2_all[i]),
                .valid_out(pe_valid_all[i])
            );
        end
    endgenerate

    // Comparator Tree Instance
    find_min_16 #(.DATA_WIDTH(ACC_WIDTH)) find_min_inst (
        .clk(clk), .rst(rst), .start_find(start_find_min), .data_in_flat(d_q_all_flat),
        .min_val(d_min_val), .min_idx(q_min_idx), .valid_out(find_min_valid)
    );

    // Main FSM Logic
    always @(posedge clk) begin
        if (rst) begin
            state <= FSM_IDLE;
            output_valid <= 1'b0;
            start_pe_processing <= 1'b0;
            start_find_min <= 1'b0;
            load_counter <= 0;
        end else begin
            output_valid <= 1'b0;
            start_pe_processing <= 1'b0;
            start_find_min <= 1'b0;

            case (state)
                FSM_IDLE: if (start) begin 
		   state <= FSM_LOAD_HY; 
		   load_counter <= 0; 
		   h_load_counter <= 0;
		   y_load_counter <= 0;
		end
                FSM_LOAD_HY: begin
                    if (data_valid) begin
                        // Nạp song song H và Y
                        if (h_load_counter < 32) begin
                            H_bram[h_load_counter / 8][(h_load_counter % 8) / 2][h_load_counter % 2] <= H_serial_in;
                            h_load_counter <= h_load_counter + 1;
                        end
                        
                        if (y_load_counter < 16) begin
                            Y_bram[y_load_counter / 4][(y_load_counter % 4) / 2][y_load_counter % 2] <= Y_serial_in;
                            y_load_counter <= y_load_counter + 1;
                        end

                        // Chuyển trạng thái khi việc nạp H (lâu hơn) hoàn tất
                        if (h_load_counter == 31) begin
                            state <= FSM_PROCESS;
                        end
                    end
                end
		FSM_PROCESS: begin
                    start_pe_processing <= 1'b1;
                    if (pe_valid_all[0]) state <= FSM_FIND_MIN;
                end
                FSM_FIND_MIN: begin
                    start_find_min <= 1'b1;
                    if (find_min_valid) state <= FSM_OUTPUT;
                end
                FSM_OUTPUT: begin
                    // Truy cập LUT để lấy ra chuỗi bit cuối cùng
                    decoded_bits[11:8] <= Bs_lut[q_min_idx];
                    decoded_bits[7:6]  <= Bv_lut[mImin1_all[q_min_idx]];
                    decoded_bits[5:4]  <= Bv_lut[mQmin1_all[q_min_idx]];
                    decoded_bits[3:2]  <= Bv_lut[mImin2_all[q_min_idx]];
                    decoded_bits[1:0]  <= Bv_lut[mQmin2_all[q_min_idx]];
                    
                    output_valid <= 1'b1;
                    state <= FSM_IDLE;
                end
                default: state <= FSM_IDLE;
            endcase
        end
    end
endmodule
