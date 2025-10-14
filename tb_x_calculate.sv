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
    
    parameter Y_REAL_FILE = "Y_real_gold_Q8_8.hex";
    parameter Y_IMAG_FILE = "Y_imag_gold_Q8_8.hex";
 
    parameter MATRIX_ELEMENTS = 8;
    reg clk;
    reg rst;
    reg start;
    reg H_in_valid;
    reg Y_in_valid;

    reg signed [N-1:0] H_in_r,Y_in_r;
    reg signed [N-1:0] H_in_i,Y_in_i;
    reg [3:0] q_index;

    
    wire done;
    wire Hq_out_valid;
    wire signed [N-1:0] Hq_out_r;
    wire signed [N-1:0] Hq_out_i;

    reg signed [N-1:0] h_stim_r [0:ROWS-1][0:COLS-1];
    reg signed [N-1:0] h_stim_i [0:ROWS-1][0:COLS-1];
	
    wire signed [N-1:0]  xI1_out, xQ1_out, xI2_out, xQ2_out;
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
       	fork
		drive_h_matrix();
		read_and_drive_y_matrix_from_file();
	join
	
	wait(dut.all_16_hq_done);
	#10000;	
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
        Y_in_valid = 0;
        Y_in_r = 0;
        Y_in_i = 0;
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
    
task read_and_drive_y_matrix_from_file;
    integer y_real_fd, y_imag_fd;
    reg signed [N-1:0] temp_data;
    integer i, j;
    integer dummy; 
    begin
        y_real_fd = $fopen(Y_REAL_FILE, "r");
        y_imag_fd = $fopen(Y_IMAG_FILE, "r");

        if (y_real_fd == 0 || y_imag_fd == 0) begin
            $display("Error: Could not open one or more input files.");
            $finish;
        end
	@(posedge clk);
        for (j = 0; j < 8; j = j + 1) begin
	    Y_in_valid = 1;
            dummy = $fscanf(y_real_fd, "%h", temp_data); 
            Y_in_r= temp_data;
            dummy = $fscanf(y_imag_fd, "%h", temp_data);
	    Y_in_i = temp_data;
	    @(posedge clk);
        end
	Y_in_valid = 0;

        $fclose(y_real_fd);
        $fclose(y_imag_fd);
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
