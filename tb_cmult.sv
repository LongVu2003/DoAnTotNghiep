`timescale 1ns / 1ps

module tb_cmult;

//--------------------------------------------------------------------------------
// Tham số (Parameters)
//--------------------------------------------------------------------------------
// Các tham số này phải khớp với module cmult đang được kiểm thử
parameter Q = 8;
parameter N = 16;
// Tham số của Testbench
parameter CLK_PERIOD = 10; // Chu kỳ clock là 10ns

//--------------------------------------------------------------------------------
// Khai báo tín hiệu (Signal Declarations)
//--------------------------------------------------------------------------------
// Tín hiệu kết nối tới DUT (Device Under Test)
reg clk;
reg rst;
reg signed [N-1:0] ar_tb, ai_tb;
reg signed [N-1:0] br_tb, bi_tb;
wire signed [N-1:0] pr_tb, pi_tb;

// Tín hiệu nội bộ của Testbench
reg signed [2*N-1:0] expected_pr_full, expected_pi_full;
reg signed [N-1:0]   expected_pr, expected_pi;
integer test_case_num;
integer error_count;

//--------------------------------------------------------------------------------
// Khởi tạo DUT (Instantiate the DUT)
//--------------------------------------------------------------------------------
cmult #(
    .Q(Q),
    .N(N)
) uut (
    .clk(clk),
    .rst(rst),
    .ar(ar_tb),
    .ai(ai_tb),
    .br(br_tb),
    .bi(bi_tb),
    .pr(pr_tb),
    .pi(pi_tb)
);

//--------------------------------------------------------------------------------
// Tạo Clock (Clock Generation)
//--------------------------------------------------------------------------------
always #(CLK_PERIOD / 2) clk = ~clk;

//--------------------------------------------------------------------------------
// Luồng Test chính (Main Test Sequence)
//--------------------------------------------------------------------------------
initial begin
    // Khởi tạo ban đầu
    $display("------------------------------------------------------------");
    $display("--- Bắt đầu kiểm thử module cmult ---");
    $display("--- Tham số: N=%0d, Q=%0d", N, Q);
    $display("------------------------------------------------------------");
    clk = 0;
    rst = 1; // Bắt đầu với reset
    ar_tb = 0;
    ai_tb = 0;
    br_tb = 0;
    bi_tb = 0;
    test_case_num = 0;
    error_count = 0;

    // Thiết lập VCD dump để xem dạng sóng
    $dumpfile("tb_cmult.vcd");
    $dumpvars(0, tb_cmult);

    // Giữ reset trong vài chu kỳ clock
    #(CLK_PERIOD * 3);
    rst = 0; // Nhả reset
    #(CLK_PERIOD);

    // --- BẮT ĐẦU CÁC CA KIỂM THỬ ---

    // Test Case 1: Phép nhân đơn giản (1+2j) * (3+4j)
    run_test(1.0, 2.0, 3.0, 4.0); #(CLK_PERIOD * 1); 

    // Test Case 2: Số âm (1-2j) * (-3+4j)
    run_test(1.2, -2.0, -3.0, 2.0);#(CLK_PERIOD * 1);

    // Test Case 3: Nhân với 0 (5-3j) * (0+0j)
    run_test(5.0, -3.0, 0.0, 0.0);#(CLK_PERIOD * 1);
    
    // Test Case 4: Nhân với 1 (2.5+1.5j) * (1+0j)
    run_test(2.5, 1.5, 1.0, 1.0);#(CLK_PERIOD * 1);

    // Test Case 5: Nhân với j (2.5+1.5j) * (0+1j)
    run_test(2.4, 2.5, 0.0, 2.0);#(CLK_PERIOD * 1);

    // Test Case 6: Các giá trị lớn
    run_test(50.0, 25.0, -10.0, -20.5);#(CLK_PERIOD * 1);

    // Test Case 7: Các giá trị phân số nhỏ
    run_test(0.125, -0.25, 0.5, -0.75);#(CLK_PERIOD * 1);

    // --- KẾT THÚC CÁC CA KIỂM THỬ ---

    #(CLK_PERIOD * 10); // Chờ cho pipeline cuối cùng hoàn tất

    // Báo cáo tổng kết
    $display("------------------------------------------------------------");
    if (error_count == 0) begin
        $display("--- TẤT CẢ CÁC TEST CASE ĐỀU PASS ---");
    end else begin
        $display("--- KIỂM THỬ THẤT BẠI: Tìm thấy %0d lỗi ---", error_count);
    end
    $display("------------------------------------------------------------");

    $finish; // Kết thúc mô phỏng
end

//--------------------------------------------------------------------------------
// Task để chạy một ca kiểm thử
//--------------------------------------------------------------------------------
task run_test;
    input real ar_real, ai_real, br_real, bi_real;
    begin
        test_case_num = test_case_num + 1;
        $display("\n--- Test Case #%0d ---", test_case_num);
        
        // 1. Áp dụng các giá trị đầu vào (chuyển đổi từ số thực sang QN.Q)
        ar_tb = ar_real * (2**Q);
        ai_tb = ai_real * (2**Q);
        br_tb = br_real * (2**Q);
        bi_tb = bi_real * (2**Q);

        $display("Đầu vào (dạng số thực): a = %f + %fj, b = %f + %fj", ar_real, ai_real, br_real, bi_real);
        $display("Đầu vào (dạng fixed-point): ar=%d, ai=%d, br=%d, bi=%d", ar_tb, ai_tb, br_tb, bi_tb);

        // 2. Tính toán kết quả dự kiến
        // (a+jb)*(c+jd) = (ac-bd) + j(ad+bc)
        // Kết quả nhân sẽ có 2*N bit và 2*Q bit phần thập phân
        expected_pr_full = ar_tb * br_tb - ai_tb * bi_tb;
        expected_pi_full = ar_tb * bi_tb + ai_tb * br_tb;

        // Dịch phải Q bit để quay về định dạng N.Q, tương đương với module qmult
        // Sử dụng dịch phải số học (>>>) để bảo toàn dấu
        expected_pr = (expected_pr_full >>> Q);
        expected_pi = (expected_pi_full >>> Q);
        
        // 3. Chờ cho pipeline của DUT xử lý xong
        // Dựa trên phân tích module cmult, có khoảng 4-5 stage
        // Chờ 6 chu kỳ clock để đảm bảo an toàn
        #(CLK_PERIOD * 6);

        // 4. So sánh kết quả và báo cáo
        $display("Kết quả dự kiến: pr = %f, pi = %f", expected_pr, expected_pi);
        $display("Kết quả thực tế: pr = %f, pi = %f", pr_tb, pi_tb);

        if (pr_tb === expected_pr && pi_tb === expected_pi) begin
            $display(">>> KẾT QUẢ: PASS <<<");
        end else begin
            $display(">>> KẾT QUẢ: FAIL <<<");
            error_count = error_count + 1;
        end
    end
endtask

endmodule

