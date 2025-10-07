// Đổi tên file thành .v, ví dụ: tb_matrix_multiplier.v
`timescale 1ns/1ps

module tb_x_calculate;

    parameter Q = 8;
    parameter N = 16;
    parameter ACC_WIDTH = 32;
    parameter ROWS = 4;
    parameter COLS = 4;
    parameter CLK_PERIOD = 10;

    parameter H_REAL_FILE = "H_real_gold_Q8_8.hex";
    parameter H_IMAG_FILE = "H_imag_gold_Q8_8.hex";
    
 
    parameter MATRIX_ELEMENTS = 8;
    reg clk;
    reg rst;
    reg start;
    reg H_in_valid;
    reg Y_in_valid;

    reg signed [N-1:0] H_in_r,Y_in_r;
    reg signed [N-1:0] H_in_i,Y_in_i;
    reg [3:0] q_index;

    // --- Bộ nhớ để lưu trữ dữ liệu Y và G ---
    reg signed [N-1:0] y_stim_r [0:MATRIX_ELEMENTS-1];
    reg signed [N-1:0] y_stim_i [0:MATRIX_ELEMENTS-1];
    
    wire done;
    wire Hq_out_valid;
    wire signed [N-1:0] Hq_out_r;
    wire signed [N-1:0] Hq_out_i;

    reg signed [N-1:0] h_stim_r [0:ROWS-1][0:COLS-1];
    reg signed [N-1:0] h_stim_i [0:ROWS-1][0:COLS-1];
	
    wire signed [15:0]  xI1_out, xQ1_out, xI2_out, xQ2_out;
    x_calculate #(.Q(Q), .N(N), .ACC_WIDTH(ACC_WIDTH)) dut (
        .clk(clk),
        .rst(rst),
        .start_new_q(start),
        .q_index(q_index),
        .H_in_valid(H_in_valid),
        .H_in_r(H_in_r),
        .H_in_i(H_in_i),
	.Y_in_valid(Y_in_valid),
	.Y_in_r(Y_in_r),
	.Y_in_i(Y_in_i),
        .q_done(done),
        .xI1_out(xI1_out), 
	.xQ1_out(xQ1_out), 
	.xI2_out(xI2_out), 
	.xQ2_out(xQ2_out)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    
initial begin
	$dumpfile("tb.vcd");
	$dumpvars();
        initialize_signals();
        reset_dut();
        start = 1;
	@(posedge clk);
	start = 0;
        read_h_matrix_from_file();
        generate_y_matrix();
       	fork
		drive_h_matrix();
		drive_y_matrix();
	join
	
	wait(dut.all_16_hq_done);	
        $finish;

    
end
initial begin
    #500000; // 5000 ns, hoặc 500 chu kỳ
    $display("TIMEOUT at %t", $time);
    $finish;
end


    
task initialize_signals;
    begin
	clk = 0;
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
    task generate_y_matrix;
    begin
        $display("Generating a sample Y matrix...");
        // Y[0,0] = 1+j1
        y_stim_r[0] = 1 << Q; y_stim_i[0] = 1 << Q;
        // G[0,1] = 2+j2
        y_stim_r[1] = 2 << Q; y_stim_i[1] = 2 << Q;
        // G[1,0] = 3+j3
        y_stim_r[2] = 3 << Q; y_stim_i[2] = 3 << Q;
        // G[1,1] = 1+j1
        y_stim_r[3] = 1 << Q; y_stim_i[3] = 1 << Q;
        // G[2,0] = 1+j1
        y_stim_r[4] = 1 << Q; y_stim_i[4] = 1 << Q;
        // G[2,1] = 1+j2
        y_stim_r[5] = 1 << Q; y_stim_i[5] = 2 << Q;
        // G[3,0] = 1+j3
        y_stim_r[6] = 1 << Q; y_stim_i[6] = 3 << Q;
        // G[3,1] = 1+j4
        y_stim_r[7] = 1 << Q; y_stim_i[7] = 4 << Q;
    end
endtask
    
task drive_y_matrix;
    integer i;
    begin
        @(posedge clk);
        for (i = 0; i < 8; i = i + 1) begin
                Y_in_valid = 1;
                Y_in_r = y_stim_r[i];
                Y_in_i = y_stim_i[i];
                @(posedge clk);
        end
        Y_in_valid = 0;
	$display("LOAD Y MATRIX DONE");
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
	$display("LOAD H MATRIX DONE");
    end
endtask
    
endmodule
