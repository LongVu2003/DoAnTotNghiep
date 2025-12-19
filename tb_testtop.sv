
`timescale 1ns/1ps

module tb_testtop;

    parameter Q = 22 ;
    parameter N = 32;

    parameter ROWS = 4;
    parameter COLS = 4;
    parameter CLK_PERIOD = 10;

    // --- ĐỊNH NGHĨA TÊN FILE GOLDEN VECTOR ---
    // Các file này chứa TẤT CẢ các ma trận H và Y
    parameter H_REAL_FILE = "H_real_gold_Q8_8.hex";
    parameter H_IMAG_FILE = "H_imag_gold_Q8_8.hex";
    parameter Y_REAL_FILE = "Y_real_gold_Q8_8.hex";
    parameter Y_IMAG_FILE = "Y_imag_gold_Q8_8.hex";
    
    // --- KÍCH THƯỚC MA TRẬN ---
    parameter H_MATRIX_SIZE = 16; // 4x4
    parameter Y_MATRIX_SIZE = 8;  // 4x2

    reg clk;
    reg rst;
    reg start;
    reg H_in_valid;
    reg Y_in_valid;

    reg signed [N-1:0] H_in_r,Y_in_r;
    reg signed [N-1:0] H_in_i,Y_in_i;

    // --- Wires   ---
    wire signed [N-1:0] s_I_1, s_Q_1, s_I_2, s_Q_2;
    wire [4:0]        Smin_index;
    wire              output_valid;
    wire signed [11:0] signal_out_12bit;

    // --- Mảng lưu trữ 1 ma trận H  ---
    reg signed [N-1:0] h_stim_r [0:ROWS-1][0:COLS-1];
    reg signed [N-1:0] h_stim_i [0:ROWS-1][0:COLS-1];
    
 
    system_top #(.Q(Q), .N(N)) dut (
        .CLOCK_50(clk),
        .sys_rst(rst),
        
        .w_H_in_valid(H_in_valid),
        .w_H_in_r(H_in_r),
        .w_H_in_i(H_in_i),
	    .w_Y_in_valid(Y_in_valid),
	    .w_Y_in_r(Y_in_r),
	    .w_Y_in_i(Y_in_i),
        .w_decoder_done(output_valid),
        .w_signal_out_12bit(signal_out_12bit)
    );

    always #(CLK_PERIOD/2) clk = ~clk;
    
initial begin
    $dumpfile("tb.vcd");
    $dumpvars();
    initialize_signals();
    reset_dut();
    // --- CHẠY CÁC TEST CASE ---
    testcase(1, 1); // Đọc H1 và Y1 từ file
    testcase(1, 2); // Đọc H1 và Y2 từ file
    testcase(1, 3); // Đọc H1 và Y3 từ file
    testcase(1, 4); // Đọc H1 và Y4 từ file
    testcase(1, 5); // Đọc H1 và Y5 từ file
    testcase(1, 6); // Đọc H1 và Y6 từ file
    testcase(1, 7); // Đọc H1 và Y7 từ file
    testcase(1, 8); // Đọc H1 và Y8 từ file 
    testcase(1, 9); // Đọc H1 và Y9 từ file
    testcase(1, 10); // Đọc H1 và Y10 từ file
    $display("ALL TESTCASES COMPLETED at %t", $time);

    #6000;  
    $finish;  
end

initial begin
    #500000;
    $display("TIMEOUT at %t", $time);
    $finish;
end

//----------------------------------------------------------------
// TASK: TESTCASE
//----------------------------------------------------------------
task testcase(input integer h_index, input integer y_index);
begin
    $display("=======================================");
    $display("=== STARTING TESTCASE (H%0d, Y%0d) @ %0t ===", h_index, y_index, $time);
    $display("=======================================");

    // 1. Reset DUT
    //reset_dut();
    
    // 2. Đọc ma trận H thứ 'h_index' từ file vào RAM 'h_stim_r/i'
    read_h_matrix_from_file(h_index);

    // 3. Kích hoạt FSM
    start = 1;
    @(posedge clk);
    start = 0;
    
    // 4. Nạp H (từ RAM) và Y (từ file) song song
    drive_h_matrix(); // Drive H từ h_stim_r/i
    // Đọc ma trận Y thứ 'y_index' từ file và drive
    read_and_drive_y_matrix_from_file(y_index);
    
    // 5. Chờ kết quả
    wait(output_valid == 1);
    $display("Testcase (H%0d, Y%0d) VALID output received @ %t", h_index, y_index, $time);
    @(posedge clk);
    output_print();
    
    #(CLK_PERIOD * 10);
end
endtask

//----------------------------------------------------------------
// CÁC TASK
//----------------------------------------------------------------
    
task initialize_signals;
//  
    begin
	    clk = 0; start = 0; H_in_valid = 0; H_in_r = 0;
        H_in_i = 0; Y_in_valid = 0; Y_in_r = 0; Y_in_i = 0;
    end
endtask

task reset_dut;
//  
    begin
        rst = 1; #(2 * CLK_PERIOD); rst = 0; #(2 * CLK_PERIOD);
    end
endtask
    
task read_and_drive_y_matrix_from_file(
    input integer y_index
);
    integer y_real_fd, y_imag_fd;
    reg signed [N-1:0] temp_data;
    integer i, j, dummy; 
    integer offset;
    
    begin
        y_real_fd = $fopen(Y_REAL_FILE, "r");
        y_imag_fd = $fopen(Y_IMAG_FILE, "r");

        if (y_real_fd == 0 || y_imag_fd == 0) begin
            $display("Error: Could not open Y input files."); $finish;
        end
        
        // --- BỎ QUA (SKIP) CÁC MA TRẬN Y TRƯỚC ĐÓ ---
        offset = (y_index - 1) * Y_MATRIX_SIZE; // Y_MATRIX_SIZE = 8
        $display("TB_Y: Skipping %0d lines in Y file...", offset);
        for (i = 0; i < offset; i = i + 1) begin
            dummy = $fscanf(y_real_fd, "%h", temp_data);
            dummy = $fscanf(y_imag_fd, "%h", temp_data);
        end

        // --- ĐỌC VÀ DRIVE MA TRẬN Y MONG MUỐN ---
        $display("TB_Y: Reading and driving Y_index %0d", y_index);
	    @(posedge clk);
        for (j = 0; j < Y_MATRIX_SIZE; j = j + 1) begin // Nạp 8 giá trị Y
	        Y_in_valid = 1;
            dummy = $fscanf(y_real_fd, "%h", temp_data); Y_in_r = temp_data;
            dummy = $fscanf(y_imag_fd, "%h", temp_data); Y_in_i = temp_data;
	        @(posedge clk);
        end
	    Y_in_valid = 0;

        $fclose(y_real_fd);
        $fclose(y_imag_fd);
    end
endtask


task read_h_matrix_from_file(
    input integer h_index
);
    integer h_real_fd, h_imag_fd;
    reg signed [N-1:0] temp_data;
    integer i, j, dummy;
    integer offset;
    
    begin
        h_real_fd = $fopen(H_REAL_FILE, "r");
        h_imag_fd = $fopen(H_IMAG_FILE, "r");

        if (h_real_fd == 0 || h_imag_fd == 0) begin
            $display("Error: Could not open H input files."); $finish;
        end

        // --- BỎ QUA (SKIP) CÁC MA TRẬN H TRƯỚC ĐÓ ---
        offset = (h_index - 1) * H_MATRIX_SIZE; // H_MATRIX_SIZE = 16
        $display("TB_H: Skipping %0d lines in H file...", offset);
        for (i = 0; i < offset; i = i + 1) begin
            dummy = $fscanf(h_real_fd, "%h", temp_data);
            dummy = $fscanf(h_imag_fd, "%h", temp_data);
        end

        // --- ĐỌC MA TRẬN H MONG MUỐN VÀO RAM ---
        // Đọc theo cột (j là cột, i là hàng)
        $display("TB_H: Reading H_index %0d into RAM", h_index);
        for (j = 0; j < COLS; j = j + 1) begin
            for (i = 0; i < ROWS; i = i + 1) begin
                dummy = $fscanf(h_real_fd, "%h", temp_data);
                h_stim_r[i][j] = temp_data; // Nạp [0][0], [1][0], [2][0], [3][0], ...
                dummy = $fscanf(h_imag_fd, "%h", temp_data); 
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

task output_print;
//  
    real r_s_I_1, r_s_Q_1, r_s_I_2, r_s_Q_2;
    begin
        r_s_I_1 = $itor(s_I_1) / (1 << Q); r_s_Q_1 = $itor(s_Q_1) / (1 << Q);
        r_s_I_2 = $itor(s_I_2) / (1 << Q); r_s_Q_2 = $itor(s_Q_2) / (1 << Q);
        $display("======================");
        $display("=== Output Results ===");
        $display("======================");
        $display("Symbol QAM 1 : %+.4f %+.4fj", r_s_I_1, r_s_Q_1);
        $display("Symbol QAM 2 : %+.4f %+.4fj", r_s_I_2, r_s_Q_2);
        $display("Index matrix S_qmin : %0d", Smin_index);
        $display("Output signal 12 bit : %12b", signal_out_12bit);
        $display("======================");
    end
endtask

endmodule