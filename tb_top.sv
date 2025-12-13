`timescale 1ns/1ps

module tb_top;

    parameter Q = 22 ;
    parameter N = 32;

    parameter ROWS = 4;
    parameter COLS = 4;
    parameter CLK_PERIOD = 10;
    parameter ITER_NO   = 1000;

    // --- ĐỊNH NGHĨA TÊN FILE ---
    // Lưu ý: Đảm bảo đường dẫn file tx_bits chính xác
    parameter H_REAL_FILE = "/mnt/d/DoAnTotNghiep/GoldenTest/H_real_gold_Q8_8.hex";
    parameter H_IMAG_FILE = "/mnt/d/DoAnTotNghiep/GoldenTest/H_imag_gold_Q8_8.hex";
    parameter Y_REAL_FILE = "/mnt/d/DoAnTotNghiep/GoldenTest/Y_real_gold_Q8_8.hex";
    parameter Y_IMAG_FILE = "/mnt/d/DoAnTotNghiep/GoldenTest/Y_imag_gold_Q8_8.hex";
    parameter TX_BITS     = "/mnt/d/DoAnTotNghiep/GoldenTest/tx_bits.txt"; 
    
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
    
    // --- BIẾN THỐNG KÊ LỖI ---
    real total_bits_sent   = 0;
    real total_bit_errors  = 0;
    
    soml_decoder_top #(.Q(Q), .N(N)) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .H_in_valid(H_in_valid),
        .H_in_r(H_in_r),
        .H_in_i(H_in_i),
        .Y_in_valid(Y_in_valid),
        .Y_in_r(Y_in_r),
        .Y_in_i(Y_in_i),
        .output_valid(output_valid),
        .s_I_1(s_I_1), .s_Q_1(s_Q_1),
        .s_I_2(s_I_2), .s_Q_2(s_Q_2),
        .Smin_index(Smin_index),
        .signal_out_12bit(signal_out_12bit)
    );

    always #(CLK_PERIOD/2) clk = ~clk;
    
initial begin
    $dumpfile("tb.vcd");
    $dumpvars();
    initialize_signals();
    reset_dut();
    
    // Reset bộ đếm lỗi
    total_bits_sent  = 0;
    total_bit_errors = 0;

    // --- CHẠY CÁC TEST CASE ---
    for (integer i = 0; i < ITER_NO; i = i + 1) begin
       testcase(i+1, i+1, i); 
    end
    
    // --- BÁO CÁO KẾT QUẢ CUỐI CÙNG ---
    $display("\n##################################################");
    $display("### FINAL SIMULATION REPORT");
    $display("##################################################");
    $display("Total Iterations : %0d", ITER_NO);
    $display("Total Bits Sent  : %0d", total_bits_sent);
    $display("Total Bit Errors : %0d", total_bit_errors);
    
    if (total_bits_sent > 0)
        $display("Bit Error Rate   : %e", total_bit_errors/total_bits_sent);
    
    if (total_bit_errors == 0)
        $display("STATUS: PASSED (PERFECT MATCH)");
    else
        $display("STATUS: COMPLETED WITH ERRORS");
        
    $display("##################################################\n");

    #100;  
    $finish;  
end


//----------------------------------------------------------------
// TASK: TESTCASE
//----------------------------------------------------------------
task testcase(
    input integer h_index, 
    input integer y_index,
    input integer bit_file_index // Index dòng trong file text (bắt đầu từ 0)
);
begin
    $display("=======================================");
    $display("=== TESTCASE (H%0d, Y%0d) @ %0t ===", h_index, y_index, $time);

    // 2. Đọc ma trận H từ file vào RAM
    read_h_matrix_from_file(h_index);

    // 3. Kích hoạt FSM
    start = 1;
    @(posedge clk);
    start = 0;
    
    // 4. Nạp H và Y song song
    fork
        drive_h_matrix(); 
        read_and_drive_y_matrix_from_file(y_index);
    join
    
    // 5. Chờ kết quả
    wait(output_valid == 1);
    
    // 6. KIỂM TRA LỖI BIT
    check_bit_error(bit_file_index);

    // output_print(); 
    
    @(posedge clk);
    #(CLK_PERIOD * 5); // Nghỉ một chút giữa các testcase
end
endtask

//----------------------------------------------------------------
// CÁC TASK HỖ TRỢ
//----------------------------------------------------------------

// --- HÀM ĐẾM SỐ BIT 1 (Đếm số lỗi) ---
function integer count_ones;
    input [11:0] data;
    integer k;
    begin
        count_ones = 0;
        for (k = 0; k < 12; k = k + 1) begin
            count_ones = count_ones + data[k];
        end
    end
endfunction

// --- ĐỌC FILE BIT, SO SÁNH VÀ CỘNG DỒN LỖI ---
task check_bit_error(input integer line_index);
    integer fd, i, dummy;
    reg [11:0] expected_bits;
    reg [11:0] diff_bits;
    integer current_errors;
begin
    fd = $fopen(TX_BITS, "r");
    if (fd == 0) begin
        $display("Error: Could not open TX_BITS file: %s", TX_BITS);
        $finish;
    end

    // Bỏ qua các dòng trước đó (Skip lines)
    for (i = 0; i < line_index; i = i + 1) begin
        dummy = $fscanf(fd, "%b", expected_bits); 
    end

    // Đọc dòng hiện tại
    dummy = $fscanf(fd, "%b", expected_bits);
    $fclose(fd);

    // So sánh (XOR để tìm các bit khác nhau)
    diff_bits = signal_out_12bit ^ expected_bits;
    
    // Đếm số bit lỗi
    current_errors = count_ones(diff_bits);

    // Cộng dồn thống kê
    total_bits_sent  = total_bits_sent + 12;
    total_bit_errors = total_bit_errors + current_errors;

    // In thông tin kiểm tra
    $display("   --> CHECK BER: Exp=%12b | Got=%12b | Errs=%0d", expected_bits, signal_out_12bit, current_errors);
    
    if (current_errors > 0)
        $display("   --> MISMATCH DETECTED!");
end
endtask

// --- Các Task cũ giữ nguyên ---

task initialize_signals;
    begin
        clk = 0; start = 0; H_in_valid = 0; H_in_r = 0;
        H_in_i = 0; Y_in_valid = 0; Y_in_r = 0; Y_in_i = 0;
    end
endtask

task reset_dut;
    begin
        rst = 1; #(2 * CLK_PERIOD); rst = 0; #(2 * CLK_PERIOD);
    end
endtask
    
task read_and_drive_y_matrix_from_file(input integer y_index);
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
        
        offset = (y_index - 1) * Y_MATRIX_SIZE; 
        for (i = 0; i < offset; i = i + 1) begin
            dummy = $fscanf(y_real_fd, "%h", temp_data);
            dummy = $fscanf(y_imag_fd, "%h", temp_data);
        end

        @(posedge clk);
        for (j = 0; j < Y_MATRIX_SIZE; j = j + 1) begin 
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


task read_h_matrix_from_file(input integer h_index);
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

        offset = (h_index - 1) * H_MATRIX_SIZE;
        for (i = 0; i < offset; i = i + 1) begin
            dummy = $fscanf(h_real_fd, "%h", temp_data);
            dummy = $fscanf(h_imag_fd, "%h", temp_data);
        end

        for (j = 0; j < COLS; j = j + 1) begin
            for (i = 0; i < ROWS; i = i + 1) begin
                dummy = $fscanf(h_real_fd, "%h", temp_data);
                h_stim_r[i][j] = temp_data; 
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
    end
endtask

task output_print;
    real r_s_I_1, r_s_Q_1, r_s_I_2, r_s_Q_2;
    begin
        r_s_I_1 = $itor(s_I_1) / (1 << Q); r_s_Q_1 = $itor(s_Q_1) / (1 << Q);
        r_s_I_2 = $itor(s_I_2) / (1 << Q); r_s_Q_2 = $itor(s_Q_2) / (1 << Q);
        $display("Symbol 1: %+.4f %+.4fj | Symbol 2: %+.4f %+.4fj", r_s_I_1, r_s_Q_1, r_s_I_2, r_s_Q_2);
        $display("Output 12b: %12b", signal_out_12bit);
    end
endtask

endmodule