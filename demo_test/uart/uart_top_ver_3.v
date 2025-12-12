module uart_top_ver_3 (
    // 1. Cổng hệ thống
    input  wire       CLOCK_50,   // Clock 50MHz của kit
    input  wire       sw_0,       // Công tắc 0 - Dùng làm RESET (Active-low: 0=Reset)
    input  wire       sw_1,       // Công tắc 1 - Dùng để chọn hiển thị H (0) hay Y (1)
    
    // *** THÊM MỚI: 4 công tắc để chọn địa chỉ ***
    input  wire [5:2] sw,         // sw[3:2] = Hàng, sw[5:4] = Cột
    
    // 2. Cổng UART
    input  wire       GPIO_RX,    // Nối với TX của ESP32 (GPIO 17)
    output wire       GPIO_TX,    // Nối với RX của ESP32 (GPIO 16)
    
    // 3. Cổng LED 7-Thanh (đúng chuẩn 7-bit active-low)
    output wire [6:0] HEX0,
    output wire [6:0] HEX1,
    output wire [6:0] HEX2,
    output wire [6:0] HEX3,
    output wire [6:0] HEX4,
    output wire [6:0] HEX5
);

    // =================================================================
    // 1. ĐỊNH NGHĨA THAM SỐ VÀ DÂY NỐI
    // =================================================================

    localparam CLK_FREQ = 50000000; // Clock của DE10-Lite là 50MHz
    localparam BAUD_RATE = 9600;    // Tốc độ baud (phải khớp với ESP32)

    wire       rx_data_ready;
    wire [7:0] rx_data;
    wire       tx_busy;
    wire       reset_n = sw_0;

    // =================================================================
    // 2. GỌI CÁC MODULE UART (async_*)
    // (Phần này giữ nguyên như v4)
    // =================================================================

    async_receiver #(
        .ClkFrequency(CLK_FREQ),
        .Baud(BAUD_RATE)
    )
    rx_inst (
        .clk(CLOCK_50),
        .RxD(GPIO_RX),
        .RxD_data_ready(rx_data_ready),
        .RxD_data(rx_data),
        .RxD_idle(),
        .RxD_endofpacket()
    );

    async_transmitter #(
        .ClkFrequency(CLK_FREQ),
        .Baud(BAUD_RATE)
    )
    tx_inst (
        .clk(CLOCK_50),
        .TxD_start(rx_data_ready),  // ECHO
        .TxD_data(rx_data),
        .TxD(GPIO_TX),
        .TxD_busy(tx_busy)
    );

    // =================================================================
    // 3. LOGIC LẮP RÁP FLOAT 32-BIT (FSM v4 - Giữ nguyên)
    // (Phần này giữ nguyên như v4, nó nạp data vào RAM)
    // =================================================================

    localparam STATE_IDLE   = 2'b00;
    localparam STATE_RECV_H = 2'b01;
    localparam STATE_RECV_Y = 2'b10;
    
    reg [1:0] current_state = STATE_IDLE;
    reg [2:0] byte_cnt = 0;
    
    reg [31:0] tmp_data_re;
    reg [31:0] tmp_data_im;

    reg [31:0] matrix_H_re [0:3][0:3];
    reg [31:0] matrix_H_im [0:3][0:3];
    reg [31:0] matrix_Y_re [0:3][0:1];
    reg [31:0] matrix_Y_im [0:3][0:1];
    
    reg [1:0] row_h = 0, col_h = 0;
    reg [1:0] row_y = 0;
    reg       col_y = 0;
    
    // Logic FSM (giữ nguyên, đã đúng)
    always @(posedge CLOCK_50)
    begin
        if (!reset_n) begin
            current_state <= STATE_IDLE;
            byte_cnt <= 0;
            row_h <= 0; col_h <= 0;
            row_y <= 0; col_y <= 0;
            
        end else if (rx_data_ready) begin
        
            case (current_state)
                
                STATE_IDLE: begin
                    current_state <= STATE_RECV_H;
                    byte_cnt <= 1;
                    row_h <= 0; col_h <= 0;
                    row_y <= 0; col_y <= 0;
                    tmp_data_re <= {24'h000000, rx_data};
                end
                
                STATE_RECV_H: begin
                    if (byte_cnt < 4) begin
                        tmp_data_re <= {tmp_data_re[23:0], rx_data};
                        if (byte_cnt == 3) begin
                            matrix_H_re[row_h][col_h] <= {tmp_data_re[23:0], rx_data};
                        end
                    end 
                    else if (byte_cnt == 4) begin
                        tmp_data_im <= {24'h000000, rx_data};
                    end
                    else begin
                        tmp_data_im <= {tmp_data_im[23:0], rx_data};
                        if (byte_cnt == 7) begin
                            matrix_H_im[row_h][col_h] <= {tmp_data_im[23:0], rx_data};
                            
                            if (col_h == 3) begin
                                col_h <= 0;
                                row_h <= row_h + 1;
                                
                                if (row_h == 3) begin
                                    current_state <= STATE_RECV_Y;
                                end
                            end else begin
                                col_h <= col_h + 1;
                            end
                        end
                    end
                    
                    if (byte_cnt == 7) begin
                        byte_cnt <= 0;
                    end else begin
                        byte_cnt <= byte_cnt + 1;
                    end
                end

                STATE_RECV_Y: begin
                    if (byte_cnt < 4) begin
                        tmp_data_re <= {tmp_data_re[23:0], rx_data};
                        if (byte_cnt == 3) begin
                            matrix_Y_re[row_y][col_y] <= {tmp_data_re[23:0], rx_data};
                        end
                    end 
                    else if (byte_cnt == 4) begin
                        tmp_data_im <= {24'h000000, rx_data};
                    end
                    else begin
                        tmp_data_im <= {tmp_data_im[23:0], rx_data};
                        if (byte_cnt == 7) begin
                            matrix_Y_im[row_y][col_y] <= {tmp_data_im[23:0], rx_data};
                            
                            if (col_y == 1) begin
                                col_y <= 0;
                                row_y <= row_y + 1;
                                
                                if (row_y == 3) begin
                                    current_state <= STATE_IDLE;
                                end
                            end else begin
                                col_y <= col_y + 1;
                            end
                        end
                    end
                    
                    if (byte_cnt == 7) begin
                        byte_cnt <= 0;
                    end else begin
                        byte_cnt <= byte_cnt + 1;
                    end
                end
                
            endcase
        end
    end
    
    // =================================================================
    // 4. LOGIC HIỂN THỊ LED 7-THANH (ĐÃ NÂNG CẤP)
    // =================================================================

    // Tạo dây (wires) cho địa chỉ hàng/cột từ công tắc
    wire [1:0] sel_row = sw[3:2]; // sw_3, sw_2
    wire [1:0] sel_col = sw[5:4]; // sw_5, sw_4
    
    // Thanh ghi trung gian để giữ giá trị được chọn
    // (Đọc từ RAM là một hành vi tổ hợp)
    reg [31:0] display_data_re;
    reg [31:0] display_data_im;
    
    // Logic tổ hợp (combinational) để chọn dữ liệu từ RAM
    // dựa trên tất cả các công tắc (sw_1, sw[3:2], sw[5:4])
    always @(*) begin
        if (sw_1 == 1'b0) begin 
            // ----- Đang chọn Ma trận H (sw_1 = 0) -----
            display_data_re = matrix_H_re[sel_row][sel_col];
            display_data_im = matrix_H_im[sel_row][sel_col];
        end else begin
            // ----- Đang chọn Ma trận Y (sw_1 = 1) -----
            // (Ma trận Y chỉ có 2 cột (0, 1), nên ta bỏ qua sw_5)
            display_data_re = matrix_Y_re[sel_row][sel_col[0]];
            display_data_im = matrix_Y_im[sel_row][sel_col[0]];
        end
    end

    // Hiển thị 6 chữ số HEX (24 bit)
    // HEX5, HEX4, HEX3: Hiển thị 12 bit thấp [11:0] của Phần Thực
    // HEX2, HEX1, HEX0: Hiển thị 12 bit thấp [11:0] của Phần Ảo
    
    // Giải mã cho 6 đèn LED (giữ nguyên)
    hex_to_7seg dec0 ( .hex_digit(display_data_im[3:0]),  .seg_out(HEX0) ); // Ảo [3:0]
    hex_to_7seg dec1 ( .hex_digit(display_data_im[7:4]),  .seg_out(HEX1) ); // Ảo [7:4]
    hex_to_7seg dec2 ( .hex_digit(display_data_im[11:8]), .seg_out(HEX2) ); // Ảo [11:8]
    
    hex_to_7seg dec3 ( .hex_digit(display_data_re[3:0]),  .seg_out(HEX3) ); // Thực [3:0]
    hex_to_7seg dec4 ( .hex_digit(display_data_re[7:4]),  .seg_out(HEX4) ); // Thực [7:4]
    hex_to_7seg dec5 ( .hex_digit(display_data_re[11:8]), .seg_out(HEX5) ); // Thực [11:8]

endmodule
