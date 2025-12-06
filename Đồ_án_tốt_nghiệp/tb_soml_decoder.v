`timescale 1ns / 1ps

module tb_soml_decoder;

    // ============================================================
    // 1. THAM SỐ & TÍN HIỆU (Khớp với Module Top)
    // ============================================================
    parameter N = 32;
    parameter Q = 22;
    localparam real SCALE_Q22 = 4194304.0;

    // Inputs
    reg clk;
    reg rst;      // Active High (dựa trên logic code của bạn)
    reg GPIO_RX;  // UART Input (Ta sẽ không dùng để nạp, treo mức 1)

    // Outputs
    wire GPIO_TX;
    wire output_valid;
    wire signed [11:0] signal_out_12bit;
    wire [4:0] Smin_index;
    wire signed [N-1:0] s_I_1, s_Q_1, s_I_2, s_Q_2;

    // ============================================================
    // 2. KẾT NỐI DUT (Device Under Test)
    // ============================================================
    soml_decoder_top #(
        .Q(Q),
        .N(N)
    ) uut (
        .clk(clk), 
        .rst(rst), 
        // start button không có trong port list mới của bạn,
        // nếu module top có input 'start' thì nối vào, 
        // nếu không có (tự chạy khi nhận đủ UART) thì bỏ qua.
        // Dựa trên code cũ có input start, nhưng nếu code mới bỏ thì bỏ dòng dưới:
        // .start(start_signal), 
        
        .GPIO_RX(GPIO_RX), 
        .GPIO_TX(GPIO_TX), 
        .output_valid(output_valid), 
        .signal_out_12bit(signal_out_12bit), 
        .Smin_index(Smin_index), 
        .s_I_1(s_I_1), 
        .s_Q_1(s_Q_1), 
        .s_I_2(s_I_2), 
        .s_Q_2(s_Q_2)
    );

    // ============================================================
    // 3. TẠO CLOCK (100MHz)
    // ============================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns
    end

    // ============================================================
    // 4. TASKS NẠP DỮ LIỆU "BACKDOOR" (Truy cập thẳng vào RAM DUT)
    // ============================================================
    
    // Task nạp H (Kênh lý tưởng: 0.5 * Identity)
    task load_H_Backdoor;
        integer r, c;
        begin
            $display("[TB] Dang nap truc tiep H vao uut.h_mem_real...");
            // H = 0.5 * I để tránh tràn số
            for (r = 0; r < 4; r = r + 1) begin
                for (c = 0; c < 4; c = c + 1) begin
                    if (r == c) begin
                        uut.h_mem_real[r][c] = $rtoi(0.5 * SCALE_Q22);
                        uut.h_mem_imag[r][c] = 0;
                    end else begin
                        uut.h_mem_real[r][c] = 0;
                        uut.h_mem_imag[r][c] = 0;
                    end
                end
            end
        end
    endtask

    // Task nạp Y (Target Input 0xCCC: 1100 1100 1100)
    // Dữ liệu này tương ứng với input 0xCCC qua kênh lý tưởng H=0.5*I
    task load_Y_Backdoor;
        begin
            $display("[TB] Dang nap truc tiep Y vao uut.y_mem...");
            
            // Cột 1 (4 phần tử đầu) -> Lưu vào y_mem1
            // Mapping: (0, -0.25), (0, -0.25), (0, 0.25), (0, 0.25)
            uut.y_mem1_r[0] = 0; uut.y_mem1_i[0] = $rtoi(-0.25 * SCALE_Q22);
            uut.y_mem1_r[1] = 0; uut.y_mem1_i[1] = $rtoi(-0.25 * SCALE_Q22);
            uut.y_mem1_r[2] = 0; uut.y_mem1_i[2] = $rtoi( 0.25 * SCALE_Q22);
            uut.y_mem1_r[3] = 0; uut.y_mem1_i[3] = $rtoi( 0.25 * SCALE_Q22);

            // Cột 2 (4 phần tử sau) -> Lưu vào y_mem2
            // Mapping: (0.25, 0), (0.25, 0), (0.25, 0), (0.25, 0)
            uut.y_mem2_r[0] = $rtoi(0.25 * SCALE_Q22); uut.y_mem2_i[0] = 0;
            uut.y_mem2_r[1] = $rtoi(0.25 * SCALE_Q22); uut.y_mem2_i[1] = 0;
            uut.y_mem2_r[2] = $rtoi(0.25 * SCALE_Q22); uut.y_mem2_i[2] = 0;
            uut.y_mem2_r[3] = $rtoi(0.25 * SCALE_Q22); uut.y_mem2_i[3] = 0;
        end
    endtask

    // ============================================================
    // 5. MAIN SCENARIO
    // ============================================================
    initial begin
        // Init
        rst = 1;
        GPIO_RX = 1; // Idle
        #100;
        
        // Reset
        rst = 0;
        #50;

        // 1. Nạp dữ liệu qua đường "Backdoor"
        load_H_Backdoor();
        load_Y_Backdoor();
        #20;

        // 2. Kích hoạt tính toán (Force tín hiệu nội bộ)
        // Vì ta không nạp qua UART nên FSM không tự nhảy. Ta phải ép nó.
        $display("[TB] Kich hoat tinh toan (Force Internal Signals)...");
        
        // Force tín hiệu start_hq_calc trong 1 chu kỳ để bắt đầu pipeline
        // (Lưu ý: Tên signal phải khớp chính xác với code module top của bạn)
        // Giả sử logic của bạn kích hoạt khi biến `start_hq_calc` lên 1
        force uut.start_hq_calc = 1'b1; 
        // Force state sang trạng thái tính toán (S_CALC = 2)
        force uut.state = 2'd2; 
        
        @(posedge clk);
        // Release force để logic tự chạy tiếp
        release uut.start_hq_calc;
        release uut.state;
        
        // Đặt start_hq_calc về 0 (như pulse) nếu logic yêu cầu
        // Trong code top của bạn: start_hq_calc được gán trong always block, 
        // nên force/release là đủ để kích một xung.

        // 3. Chờ kết quả
        $display("[TB] Dang cho Output Valid...");
        wait(output_valid);
        @(posedge clk);

        // 4. Kiểm tra
        $display("-------------------------------------------");
        $display("TIME: %t", $time);
        $display("RESULT: 0x%h (Binary: %b)", signal_out_12bit, signal_out_12bit);
        
        if (signal_out_12bit == 12'hCCC) begin
            $display("✅ TEST PASSED! Output matches 0xCCC.");
        end else begin
            $display("❌ TEST FAILED! Output mismatch.");
        end
        $display("-------------------------------------------");

        #500;
        $finish;
    end

endmodule