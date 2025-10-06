`timescale 1ns/1ps

module tb_trace_calculator;

    // --- Các tham số ---
    parameter Q = 8;
    parameter N = 16;
    parameter ACC_WIDTH = 32;
    parameter CLK_PERIOD = 10;

    // Kích thước ma trận Y và G là 4x2 = 8 phần tử
    parameter MATRIX_ELEMENTS = 8;


    // --- Tín hiệu Testbench ---
    reg clk;
    reg rst;
    reg start_calc;

    // Giao tiếp với DUT
    wire [2:0] y_rd_addr;
    wire signed [N-1:0] y_rd_data_r; // Sửa thành wire
    wire signed [N-1:0] y_rd_data_i; // Sửa thành wire

    wire [2:0] g_rd_addr;
    wire signed [N-1:0] g_rd_data_r; // Sửa thành wire
    wire signed [N-1:0] g_rd_data_i; // Sửa thành wire

    wire done_calc;
    wire signed [ACC_WIDTH-1:0] trace_result_r;
    wire signed [ACC_WIDTH-1:0] trace_result_i;

    // --- Bộ nhớ để lưu trữ dữ liệu Y và G ---
    reg signed [N-1:0] y_stim_r [0:MATRIX_ELEMENTS-1];
    reg signed [N-1:0] y_stim_i [0:MATRIX_ELEMENTS-1];
    reg signed [N-1:0] g_stim_r [0:MATRIX_ELEMENTS-1];
    reg signed [N-1:0] g_stim_i [0:MATRIX_ELEMENTS-1];

    // --- Khởi tạo DUT (Device Under Test) ---
    trace_calculator #(
        .N(N),
        .ACC_WIDTH(ACC_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start_calc(start_calc),
        .y_rd_addr(y_rd_addr),
        .y_rd_data_r(y_rd_data_r),
        .y_rd_data_i(y_rd_data_i),
        .g_rd_addr(g_rd_addr),
        .g_rd_data_r(g_rd_data_r),
        .g_rd_data_i(g_rd_data_i),
        .done_calc(done_calc),
        .trace_result_r(trace_result_r),
        .trace_result_i(trace_result_i)
    );

    // --- Logic Testbench ---

    // Tạo clock
    always #(CLK_PERIOD/2) clk = ~clk;

    // **ĐÃ SỬA LỖI: Mô phỏng RAM tổ hợp (không có độ trễ đọc)**
    assign y_rd_data_r = y_stim_r[y_rd_addr];
    assign y_rd_data_i = y_stim_i[y_rd_addr];
    assign g_rd_data_r = g_stim_r[g_rd_addr];
    assign g_rd_data_i = g_stim_i[g_rd_addr];

    // Luồng test chính
    initial begin
        $dumpfile("tb_trace_calculator.vcd");
        $dumpvars(0, tb_trace_calculator);

        initialize_signals();
        reset_dut();

        // Nạp dữ liệu vào các bộ nhớ của testbench
        generate_y_matrix();
        generate_g_matrix(); // Tạo ma trận G mẫu

        // Chạy 1 test case
        run_one_trace_calculation();
        
        $display("\n--- Test Sequence Finished ---");
        $finish;
    end

    // --- Các Task Cho Testbench ---
    task initialize_signals;
    begin
	clk = 0;
        start_calc = 0;
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
    // Task tự tạo ma trận G mẫu
    task generate_g_matrix;
    begin
        $display("Generating a sample G matrix...");
        // G[0,0] = 1+j1
        g_stim_r[0] = 1 << Q; g_stim_i[0] = 1 << Q;
        // G[0,1] = 2+j2
        g_stim_r[1] = 2 << Q; g_stim_i[1] = 2 << Q;
        // G[1,0] = 3+j3
        g_stim_r[2] = 2 << Q; g_stim_i[2] = 3 << Q;
        // G[1,1] = 4+j4
        g_stim_r[3] = 2 << Q; g_stim_i[3] = 4 << Q;
        // G[2,0] = 5+j1
        g_stim_r[4] = 5 << Q; g_stim_i[4] = 1 << Q;
        // G[2,1] = 6+j2
        g_stim_r[5] = 6 << Q; g_stim_i[5] = 2 << Q;
        // G[3,0] = 7+j3
        g_stim_r[6] = 7 << Q; g_stim_i[6] = 3 << Q;
        // G[3,1] = 8+j4
        g_stim_r[7] = 8 << Q; g_stim_i[7] = 4 << Q;
    end
    endtask

    // Task thực thi một phép tính trace
    task run_one_trace_calculation;
    begin
        $display("\n--- Running Trace Calculation Test ---");
        
        // Kích hoạt DUT
        @(posedge clk);
        start_calc = 1;
        @(posedge clk);
        start_calc = 0;

        // Chờ DUT tính xong
        $display("Waiting for DUT to complete...");
        wait(done_calc);

        // In kết quả
        $display(">>> DUT Trace Result (Real) = %h (%f)", trace_result_r, $signed(trace_result_r)/(2.0**Q));
        $display(">>> DUT Trace Result (Imag) = %h (%f)", trace_result_i, $signed(trace_result_i)/(2.0**Q));
        
        @(posedge clk);
    end
    endtask

endmodule
