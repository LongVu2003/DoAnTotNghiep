`timescale 1ns/1ps

module tb_top;

    // ============================================================
    // PARAMETERS
    // ============================================================
    parameter Q = 22;
    parameter N = 32;

    parameter ROWS = 4;
    parameter COLS = 4;
    parameter CLK_PERIOD = 10; 
    parameter ITER_NO  = 50; // Số lượng testcase muốn chạy

    parameter H_MATRIX_SIZE = 16; // 4x4 elements
    parameter Y_MATRIX_SIZE = 8;  // 4x2 elements

    // ============================================================
    // FILE PATHS
    // ============================================================
    parameter H_REAL_FILE = "/mnt/d/DoAnTotNghiep/GoldenTest/H_real_gold_Q8_8.hex";
    parameter H_IMAG_FILE = "/mnt/d/DoAnTotNghiep/GoldenTest/H_imag_gold_Q8_8.hex";
    parameter Y_REAL_FILE = "/mnt/d/DoAnTotNghiep/GoldenTest/Y_real_gold_Q8_8.hex";
    parameter Y_IMAG_FILE = "/mnt/d/DoAnTotNghiep/GoldenTest/Y_imag_gold_Q8_8.hex";
    parameter TX_BITS     = "/mnt/d/DoAnTotNghiep/GoldenTest/tx_bits.txt";
    // ============================================================
    // SIGNALS
    // ============================================================
    reg clk, rst, start;
    reg H_in_valid, Y_in_valid;
    reg signed [N-1:0] H_in_r, H_in_i;
    reg signed [N-1:0] Y_in_r, Y_in_i;

    wire output_valid;
    wire signed [11:0] signal_out_12bit;
    wire signed [N-1:0] s_I_1, s_Q_1, s_I_2, s_Q_2;
    wire [4:0] Smin_index;

    // ============================================================
    // MEMORY ARRAYS (Nơi lưu trữ toàn bộ dữ liệu file)
    // ============================================================
    // Kích thước mảng = Số lượng testcase * Kích thước 1 mẫu
    reg signed [N-1:0] H_real_mem [0 : ITER_NO * H_MATRIX_SIZE - 1];
    reg signed [N-1:0] H_imag_mem [0 : ITER_NO * H_MATRIX_SIZE - 1];
    reg signed [N-1:0] Y_real_mem [0 : ITER_NO * Y_MATRIX_SIZE - 1];
    reg signed [N-1:0] Y_imag_mem [0 : ITER_NO * Y_MATRIX_SIZE - 1];
    reg        [11:0]  tx_bits_mem[0 : ITER_NO - 1]; // Mỗi dòng là 12 bit

    // ============================================================
    // STATISTICS
    // ============================================================
    real total_bits_sent  = 0;
    real total_bit_errors = 0;

    // ============================================================
    // DUT INSTANTIATION
    // ============================================================
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

    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // ============================================================
    // MAIN PROCESS
    // ============================================================
    initial begin
        // 1. Setup ban đầu
        $dumpfile("tb.vcd");
        $dumpvars(0, tb_top); // Nếu file quá nặng thì comment dòng này lại
        
        initialize_signals();
        
        // 2. NẠP FILE VÀO RAM  
        $display("Loading data from files into Memory...");
        $readmemh(H_REAL_FILE, H_real_mem);
        $readmemh(H_IMAG_FILE, H_imag_mem);
        $readmemh(Y_REAL_FILE, Y_real_mem);
        $readmemh(Y_IMAG_FILE, Y_imag_mem);
        $readmemb(TX_BITS,     tx_bits_mem); // tx_bits là binary nên dùng readmemb
        $display("Data loaded successfully!");

        // 3. Reset hệ thống
        reset_dut();
        total_bits_sent  = 0;
        total_bit_errors = 0;

        // 4. CHẠY LOOP TESTCASE
        for (integer t = 0; t < ITER_NO; t = t + 1) begin
            // In tiến độ mỗi 1000 mẫu để theo dõi
            if (t % 1000 == 0) $display("Processing iteration: %0d / %0d", t, ITER_NO);
            
            run_testcase(t);
        end

        // 5. Báo cáo kết quả
        print_final_report();

        #100;
        $finish;
    end

    //time-out
    initial begin
        #500000;
        $display("TIMEOUT Reached. Ending Simulation.");
        $finish;
    end

    // ============================================================
    // TASK: RUN TESTCASE (Tối ưu hóa)
    // ============================================================
    // ============================================================
    // TASK: RUN TESTCASE (Đã sửa logic ánh xạ H)
    // ============================================================
    task run_testcase(input integer idx);
        integer h_base_addr;
        integer y_base_addr;
        integer r, c;     // Biến chạy hàng, cột
        integer h_offset; // Địa chỉ tính toán cho từng phần tử H
        integer i;
        
        reg [11:0] expected_bits;
        reg [11:0] diff_bits;
        integer current_errors;
    begin
        h_base_addr = idx * H_MATRIX_SIZE;
        y_base_addr = idx * Y_MATRIX_SIZE;

        // Pulse Start
        start = 1; 
        @(posedge clk); 
        start = 0;

        fork
            // --- DRIVE H MATRIX (Quan trọng: Đẩy theo Hàng, nhưng Đọc theo Cột) ---
            begin
                @(posedge clk);
                // DUT muốn nhận theo HÀNG -> Vòng lặp ngoài là ROWS
                for (r = 0; r < ROWS; r = r + 1) begin
                    for (c = 0; c < COLS; c = c + 1) begin
                        H_in_valid = 1;
                        
                        // TÍNH TOÁN ĐỊA CHỈ TRONG MEMORY (Lưu theo Cột)
                        // Công thức: Base + (Cột hiện tại * Số hàng) + Hàng hiện tại
                        h_offset = h_base_addr + (c * ROWS) + r;
                        
                        H_in_r = H_real_mem[h_offset];
                        H_in_i = H_imag_mem[h_offset];
                        
                        @(posedge clk);
                    end
                end
                H_in_valid = 0;
            end

            // --- DRIVE Y MATRIX (Giữ nguyên logic cũ nếu Y lưu đúng thứ tự) ---
            begin
                @(posedge clk);
                for (i = 0; i < Y_MATRIX_SIZE; i = i + 1) begin
                    Y_in_valid = 1;
                    Y_in_r = Y_real_mem[y_base_addr + i];
                    Y_in_i = Y_imag_mem[y_base_addr + i];
                    @(posedge clk);
                end
                Y_in_valid = 0;
            end
        join

        // ... (Phần kiểm tra kết quả giữ nguyên) ...
        wait(output_valid == 1);
        expected_bits = tx_bits_mem[idx];
        diff_bits = signal_out_12bit ^ expected_bits;
        current_errors = count_ones(diff_bits);

        total_bits_sent  = total_bits_sent + 12;
        total_bit_errors = total_bit_errors + current_errors;
        
        // Log lỗi nếu có
        if (current_errors > 0) 
             $display("Mismatch at Iter %0d", idx);

        @(posedge clk);
    end
    endtask

    // ============================================================
    // HELPER FUNCTIONS & TASKS
    // ============================================================

    function integer count_ones(input [11:0] data);
        integer k;
        begin
            count_ones = 0;
            for (k = 0; k < 12; k = k + 1) count_ones = count_ones + data[k];
        end
    endfunction

    task initialize_signals;
        begin
            clk = 0; start = 0; 
            H_in_valid = 0; H_in_r = 0; H_in_i = 0; 
            Y_in_valid = 0; Y_in_r = 0; Y_in_i = 0;
        end
    endtask

    task reset_dut;
        begin
            rst = 1; #(4 * CLK_PERIOD); 
            rst = 0; #(4 * CLK_PERIOD);
        end
    endtask

    task print_final_report;
    begin
        $display("\n##################################################");
        $display("### FINAL SIMULATION REPORT");
        $display("Total Iterations : %0d", ITER_NO);
        $display("Total Bits Sent  : %0.0f", total_bits_sent);
        $display("Total Bit Errors : %0.0f", total_bit_errors);
        
        if (total_bits_sent > 0)
            $display("Bit Error Rate   : %e", total_bit_errors/total_bits_sent);
        
        if (total_bit_errors == 0)
            $display("STATUS: PASSED (PERFECT MATCH)");
        else
            $display("STATUS: COMPLETED WITH ERRORS");
        $display("##################################################\n");
    end
    endtask

endmodule