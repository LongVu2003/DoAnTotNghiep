// Đổi tên file thành .v, ví dụ: tb_matrix_multiplier.v
`timescale 1ns/1ps

module tb_matrix_multiplier;

    parameter Q = 8;
    parameter N = 16;
    parameter ACC_WIDTH = 32;
    parameter ROWS = 4;
    parameter COLS = 4;
    parameter CLK_PERIOD = 10;

    parameter H_REAL_FILE = "H_real_gold_Q8_8.hex";
    parameter H_IMAG_FILE = "H_imag_gold_Q8_8.hex";

    reg clk;
    reg rst;
    reg start;
    reg H_in_valid;
    reg signed [N-1:0] H_in_r;
    reg signed [N-1:0] H_in_i;
    reg [3:0] q_index;

    wire done;
    wire Hq_out_valid;
    wire signed [N-1:0] Hq_out_r;
    wire signed [N-1:0] Hq_out_i;

    reg signed [N-1:0] h_stim_r [0:ROWS-1][0:COLS-1];
    reg signed [N-1:0] h_stim_i [0:ROWS-1][0:COLS-1];
    reg signed [N-1:0] hq_result_r [0:ROWS-1][0:1];
    reg signed [N-1:0] hq_result_i [0:ROWS-1][0:1];
    reg signed [N-1:0] s_matrix_r [0:COLS-1][0:1];
    reg signed [N-1:0] s_matrix_i [0:COLS-1][0:1];

    matrix_multiplier #(.Q(Q), .N(N), .ACC_WIDTH(ACC_WIDTH)) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .H_in_valid(H_in_valid),
        .H_in_r(H_in_r),
        .H_in_i(H_in_i),
        .q_index(q_index),
        .done(done),
        .Hq_out_valid(Hq_out_valid),
        .Hq_out_r(Hq_out_r),
        .Hq_out_i(Hq_out_i)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
	$dumpfile("tb.vcd");
	$dumpvars();
        clk = 0;
        initialize_signals();
        reset_dut();
        
        read_h_matrix_from_file();
        
	// H x S0
        run_and_capture_hq(4'd1);  
        print_results(4'd1);
       @(posedge clk);
       @(posedge clk);
	// H x S1
	run_and_capture_hq(4'd0);
        print_results(4'd0);

        $finish;
    end

    task initialize_signals;
    begin
        start = 0;
        H_in_valid = 0;
        H_in_r = 0;
        H_in_i = 0;
        q_index = 0;
    end
    endtask

    task reset_dut;
    begin
        rst = 1;
        #(2 * CLK_PERIOD);
        rst = 0;
        #(2 * CLK_PERIOD);
    end
    endtask

    task read_h_matrix_from_file;
    integer h_real_fd, h_imag_fd;
    reg signed [N-1:0] temp_data;
    integer i, j;
    integer dummy; // SỬA LỖI: Khai báo biến tạm
    begin
        h_real_fd = $fopen(H_REAL_FILE, "r");
        h_imag_fd = $fopen(H_IMAG_FILE, "r");

        if (h_real_fd == 0 || h_imag_fd == 0) begin
            $display("Error: Could not open one or more input files.");
            $finish;
        end

        for (j = 0; j < COLS; j = j + 1) begin
            for (i = 0; i < ROWS; i = i + 1) begin
                dummy = $fscanf(h_real_fd, "%h", temp_data); // SỬA LỖI: Gán giá trị trả về
                h_stim_r[i][j] = temp_data;
                dummy = $fscanf(h_imag_fd, "%h", temp_data); // SỬA LỖI: Gán giá trị trả về
                h_stim_i[i][j] = temp_data;
            end
        end

        $fclose(h_real_fd);
        $fclose(h_imag_fd);
    end
    endtask

    task drive_h_matrix;
    integer i, j;
    begin
        @(posedge clk);
        for (i = 0; i < ROWS; i = i + 1) begin
            for (j = 0; j < COLS; j = j + 1) begin
                H_in_valid = 1;
                H_in_r = h_stim_r[i][j];
                H_in_i = h_stim_i[i][j];
                @(posedge clk);
            end
        end
        H_in_valid = 0;
    end
    endtask

    task run_and_capture_hq;
    input [3:0] q_idx;
    integer i, j;
    begin
        q_index = q_idx;
        start = 1;
        @(posedge clk);
        start = 0;
        
        drive_h_matrix();

        for (i = 0; i < ROWS; i = i + 1) begin
            for (j = 0; j < 2; j = j + 1) begin
                @(posedge clk);
		 while (!Hq_out_valid) begin
		    @(posedge clk);
		end
                hq_result_r[i][j] = Hq_out_r;
                hq_result_i[i][j] = Hq_out_i;
                @(posedge clk);
            end
        end
        wait(done);
    end
    endtask
    
    task get_s_matrix;
    input [3:0] q_idx;
    localparam signed [N-1:0] P_HALF = 16'sd128;
    localparam signed [N-1:0] N_HALF = -16'sd128;
    localparam signed [N-1:0] ZERO   = 16'sd0;
    integer i, j;
    begin
        case(q_idx)
            4'd0: begin
                {s_matrix_r[0][0], s_matrix_i[0][0]} = {P_HALF, ZERO};
                {s_matrix_r[0][1], s_matrix_i[0][1]} = {P_HALF, ZERO};
                {s_matrix_r[1][0], s_matrix_i[1][0]} = {N_HALF, ZERO};
                {s_matrix_r[1][1], s_matrix_i[1][1]} = {P_HALF, ZERO};
                {s_matrix_r[2][0], s_matrix_i[2][0]} = {P_HALF, ZERO};
                {s_matrix_r[2][1], s_matrix_i[2][1]} = {P_HALF, ZERO};
                {s_matrix_r[3][0], s_matrix_i[3][0]} = {N_HALF, ZERO};
                {s_matrix_r[3][1], s_matrix_i[3][1]} = {P_HALF, ZERO};
            end
            default: begin
                for(i=0; i<ROWS; i=i+1) begin
                  for(j=0; j<2; j=j+1) begin
                    {s_matrix_r[i][j], s_matrix_i[i][j]} = 32'b0;
                  end
                end
            end
        endcase
    end
    endtask
   task print_results;
    input [3:0] q_idx;
    integer i;
    begin
        get_s_matrix(q_idx);
        $display("\n[H] Matrix (Real | Imaginary) - Fixed-Point Q8.8 Format");
        for (i = 0; i < ROWS; i = i + 1) begin
            $display("  %7.4f | %7.4f   %7.4f | %7.4f   %7.4f | %7.4f   %7.4f | %7.4f",
                $signed(h_stim_r[i][0]) / 256.0, $signed(h_stim_i[i][0]) / 256.0,
                $signed(h_stim_r[i][1]) / 256.0, $signed(h_stim_i[i][1]) / 256.0,
                $signed(h_stim_r[i][2]) / 256.0, $signed(h_stim_i[i][2]) / 256.0,
                $signed(h_stim_r[i][3]) / 256.0, $signed(h_stim_i[i][3]) / 256.0);
        end

        $display("\n[S] Matrix for q_index = %0d (Real | Imaginary) - Fixed-Point Q8.8 Format", q_idx);
        for (i = 0; i < ROWS; i = i + 1) begin
            $display("  %7.4f | %7.4f   %7.4f | %7.4f",
                $signed(s_matrix_r[i][0]) / 256.0, $signed(s_matrix_i[i][0]) / 256.0,
                $signed(s_matrix_r[i][1]) / 256.0, $signed(s_matrix_i[i][1]) / 256.0);
        end

        $display("\n[Hq] = [H] x [S] (Real | Imaginary) - Fixed-Point Q8.8 Format");
        for (i = 0; i < ROWS; i = i + 1) begin
            $display("  %7.4f | %7.4f   %7.4f | %7.4f",
                $signed(hq_result_r[i][0]) / 256.0, $signed(hq_result_i[i][0]) / 256.0,
                $signed(hq_result_r[i][1]) / 256.0, $signed(hq_result_i[i][1]) / 256.0);
        end
        $display("--------------------------------------------------------------------------");
    end
    endtask

endmodule
