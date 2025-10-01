`timescale 1ns/1ps

module tb_Dh_cal;

    // --- Các tham số ---
    parameter Q = 8;
    parameter N = 16;
    parameter CLK_PERIOD = 10;
    
    // Kích thước ma trận Hq đầu vào là 4x32
    parameter HQ_ROWS = 4;
    parameter HQ_COLS = 32; 

    // Tên file stimulus
    parameter HQ_REAL_FILE = "Hq_real_gold_Q8_8.hex";
    parameter HQ_IMAG_FILE = "Hq_imag_gold_Q8_8.hex";

    // --- Tín hiệu Testbench ---
    reg clk;
    reg rst;
    reg Dh_en;
    reg signed [N-1:0] in_real;
    reg signed [N-1:0] in_im;

    wire signed [N-1:0] Dh_out;
    wire Dh_result_valid;

    // --- Bộ nhớ để lưu trữ toàn bộ dữ liệu Hq đọc từ file ---
    reg signed [N-1:0] hq_stim_r [0:HQ_ROWS-1][0:HQ_COLS-1];
    reg signed [N-1:0] hq_stim_i [0:HQ_ROWS-1][0:HQ_COLS-1];

    // --- Khởi tạo DUT (Device Under Test) ---
    // Đảm bảo bạn đang dùng phiên bản Dh_cal đã được sửa lỗi logic tích lũy
    Dh_cal #(.Q(Q), .N(N)) dut (
        .clk(clk),
        .rst(rst),
        .Dh_en(Dh_en),
        .in_real(in_real),
        .in_im(in_im),
        .Dh_out(Dh_out),
        .Dh_result_valid(Dh_result_valid)
    );

    // --- Logic Testbench ---

    // Tạo clock
    always #(CLK_PERIOD/2) clk = ~clk;

    // Luồng test chính (Test Sequencer)
    initial begin
        $dumpfile("tb_dh_cal.vcd");
        $dumpvars(0, tb_Dh_cal);
        
        // 1. Khởi tạo và Reset
        clk = 0;
        initialize_signals();
        reset_dut();

        // 2. Nạp toàn bộ dữ liệu Hq từ file vào bộ nhớ (chỉ một lần)
        read_hq_files();
        
        // 3. Chạy các test case tuần tự
        run_one_dh_calculation(0); // Test cho Dh_0

        @(posedge clk); // Chờ một chút giữa các lần test

        run_one_dh_calculation(1); // Test cho Dh_1

        @(posedge clk);

        run_one_dh_calculation(2); // Test cho Dh_2

        $display("\n--- Test Sequence Finished ---");
        $finish;
    end

    // --- Các Task Cho Testbench ---

    task initialize_signals;
    begin
        Dh_en = 0;
        in_real = 0;
        in_im = 0;
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

    // Task đọc toàn bộ 2 file Hq vào 2 mảng 2D
    task read_hq_files;
        integer fd_real, fd_imag, dummy;
        reg signed [N-1:0] temp_data;
        integer i, j;
    begin
        fd_real = $fopen(HQ_REAL_FILE, "r");
        fd_imag = $fopen(HQ_IMAG_FILE, "r");
        
        if (fd_real == 0 || fd_imag == 0) begin
            $display("ERROR: Could not open one or both Hq stimulus files.");
            $finish;
        end

        // Vòng lặp 1: Đọc toàn bộ file real
        $display("Reading REAL stimulus file...");
        for (j = 0; j < HQ_COLS; j = j + 1) begin
            for (i = 0; i < HQ_ROWS; i = i + 1) begin
                dummy = $fscanf(fd_real, "%h", temp_data);
                hq_stim_r[i][j] = temp_data;
            end
        end
        $fclose(fd_real);

        // Vòng lặp 2: Đọc toàn bộ file imag
        $display("Reading IMAGINARY stimulus file...");
        for (j = 0; j < HQ_COLS; j = j + 1) begin
            for (i = 0; i < HQ_ROWS; i = i + 1) begin
                dummy = $fscanf(fd_imag, "%h", temp_data);
                hq_stim_i[i][j] = temp_data;
            end
        end
        $fclose(fd_imag);
        
        $display("Finished reading all Hq stimulus files into memory.");
    end
    endtask

    // Task thực thi một phép tính Dh hoàn chỉnh cho một q_index
    // ĐÃ CẬP NHẬT LOGIC CHÍNH XÁC
    task run_one_dh_calculation;
        input [3:0] q_idx; // Chỉ số của Dh cần tính (0 đến 15)
        integer i;
        integer col1_idx, col2_idx;
    begin
        $display("\n--- Running Test for Dh_%0d ---", q_idx);

        // 2. Tính toán chỉ số các cột cần lấy dữ liệu theo đúng thuật toán
        col1_idx = q_idx * 2;
        col2_idx = q_idx * 2 + 1;

        // 3. Nạp 8 giá trị Hq cần thiết để tính Dh
        //    Gồm 4 giá trị từ cột 2*q và 4 giá trị từ cột 2*q + 1
        
        $display("Feeding Hq column %0d data...", col1_idx);
        for (i = 0; i < HQ_ROWS; i = i + 1) begin
            Dh_en = 1;
            in_real = hq_stim_r[i][col1_idx];
            in_im = hq_stim_i[i][col1_idx];
            @(posedge clk);
	    Dh_en = 0;
        end
        
        $display("Feeding Hq column %0d data...", col2_idx);
        for (i = 0; i < HQ_ROWS; i = i + 1) begin
            Dh_en = 1;
            in_real = hq_stim_r[i][col2_idx];
            in_im = hq_stim_i[i][col2_idx];
            @(posedge clk);
	    Dh_en = 0;
        end
        //Dh_en = 0;

        // 4. Chờ cho đến khi DUT báo kết quả hợp lệ
        $display("Waiting for DUT result...");
        wait(Dh_result_valid);
        
        // 5. In kết quả từ DUT ra màn hình để bạn quan sát
        $display(">>> DUT Result for Dh_%0d = %h (%f)", q_idx, Dh_out, $signed(Dh_out)/256.0);
        
        // Chờ một chu kỳ để các tín hiệu ổn định trước khi bắt đầu test case mới
        @(posedge clk);
    end
    endtask

endmodule
