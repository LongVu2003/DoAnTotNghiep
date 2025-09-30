// Testbench for c_mac module
`timescale 1ns/1ps

module tb_c_mac();

    // Parameters
    localparam Q = 8;
    localparam N = 16;
    
    // Testbench signals
    reg clk;
    reg rst;
    reg clear;
    reg mac_en;
    reg signed [N-1:0] in_ar, in_ai;
    reg signed [N-1:0] in_br, in_bi;
    wire signed [N-1:0] mac_r_out, mac_i_out;
    wire mac_result_valid;

    // Instantiate the Unit Under Test (UUT)
    c_mac #(
        .Q(Q),
        .N(N)
    ) dut (
        .clk(clk),
        .rst(rst),
        .mac_clear(clear),
        .mac_en(mac_en),
        .in_ar(in_ar),
        .in_ai(in_ai),
        .in_br(in_br),
        .in_bi(in_bi),
        .mac_r_out(mac_r_out),
        .mac_i_out(mac_i_out),
        .mac_result_valid(mac_result_valid)
    );

    // Clock Generation
    always #5 clk = ~clk;
always @(mac_result_valid)
   clear = mac_result_valid;

initial begin
      
  $dumpfile("tb.vcd");
      
  $dumpvars();
        
  // Initialize signals
        
  clk = 0;
  rst = 1;
  clear = 0;
  in_ar = 16'b0; in_ai = 16'b0;
  in_br = 16'b0; in_bi = 16'b0;
  // Reset the module
  #10 rst = 0;
  $display("-----------------------------------------");
  $display("   Starting testbench. Resetting...");
  $display("-----------------------------------------");

        
    // Test Case 1: Phép nhân đơn giản (1+2j) * (3+4j)
    run_test(1.0, 2.0, 3.0, 4.0);

    // Test Case 2: Số âm (1-2j) * (-3+4j)
    run_test(1.2, -2.0, -3.0, 2.0);

    // Test Case 3: Nhân với 0 (5-3j) * (0+0j)
    run_test(5.0, -3.0, 0.0, 0.0);

    // Test Case 4: Nhân với 1 (2.5+1.5j) * (1+0j)
    run_test(2.5, 1.5, 1.0, 1.0);
   // Test Case 5: Nhân với j (2.5+1.5j) * (0+1j)
    run_test(2.4, 2.5, 0.0, 2.0);

    // Test Case 6: Các giá trị lớn
    run_test(50.0, 25.0, -10.0, -20.5);

    // Test Case 7: Các giá trị phân số nhỏ
    run_test(0.125, -0.25, 0.5, -0.75);
    // Test Case 8  
    run_test(2.4, 2.5, 0.0, 2.0);

    // --- KẾT THÚC CÁC CA KIỂM THỬ ---
    // End of simulation
    #800 $display("Simulation finished successfully.");
    $finish;
end
  
//------------------------------------------------------------------------------
// Task để chạy một ca kiểm thử
//-------------------------------------------------------------------------------
task run_test;
    input real ar_real, ai_real, br_real, bi_real;
    begin
        // 1. Áp dụng các giá trị đầu vào (chuyển đổi từ số thực sang QN.Q)
	mac_en = 1;
        in_ar = ar_real * (2**Q);
        in_ai = ai_real * (2**Q);
        in_br = br_real * (2**Q);
        in_bi = bi_real * (2**Q);
     	 @(posedge clk);
	mac_en = 0;
    end
endtask

endmodule

