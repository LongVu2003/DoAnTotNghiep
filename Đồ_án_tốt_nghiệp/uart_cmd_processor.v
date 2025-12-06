module uart_cmd_processor #(
    parameter N = 32 // Độ rộng dữ liệu (32-bit)
) (
    // 1. Cổng hệ thống & UART
    input  wire         CLOCK_50,
    input  wire         sw_0,         // Reset (Active-low: 0=Reset, 1=Run)
    input  wire         GPIO_RX,      // Nhận từ PC
    output wire         GPIO_TX,      // Gửi lên PC

    // 2. Cổng Output Decoder (Kết nối vào Module xử lý thuật toán của bạn)
    output reg          sys_start,    // Lên 1 khi bắt đầu nhận gói tin mới
    
    output reg          H_valid,      
    output reg [N-1:0]  H_r,          
    output reg [N-1:0]  H_i,          
    
    output reg          Y_valid,      
    output reg [N-1:0]  Y_r,          
    output reg [N-1:0]  Y_i,        
	 
    // 3. Cổng Input TX (Gửi kết quả 12-bit về PC)
    input  wire [11:0]  message,      // Dữ liệu kết quả muốn gửi
    input  wire         message_ready // Xung kích hoạt gửi
);

    // =================================================================
    // 1. THIẾT LẬP UART DRIVER
    // =================================================================
    localparam CLK_FREQ  = 50000000;
    localparam BAUD_RATE = 9600; // Tốc độ truyền (khớp với code C/Python máy tính)

    wire       rst_n = sw_0;      // Reset tích cực thấp
    wire       rst_p = ~sw_0;     // Reset tích cực cao (nếu logic bên trong cần)

    // Dây nối nội bộ UART
    wire       rx_ready;          // Báo có 1 byte mới
    wire [7:0] rx_data;           // Byte vừa nhận
    
    reg        tx_start_signal;   // Lệnh gửi
    reg [7:0]  tx_byte;           // Byte cần gửi
    wire       tx_busy;           // Trạng thái bận của bộ phát

    // --- Module Nhận (Receiver) ---
    async_receiver #( .ClkFrequency(CLK_FREQ), .Baud(BAUD_RATE) ) 
    rx_inst (
        .clk(CLOCK_50),
        .RxD(GPIO_RX),
        .RxD_data_ready(rx_ready),
        .RxD_data(rx_data),
        .RxD_idle(), .RxD_endofpacket()
    );

    // --- Module Gửi (Transmitter) ---
    async_transmitter #( .ClkFrequency(CLK_FREQ), .Baud(BAUD_RATE) ) 
    tx_inst (
        .clk(CLOCK_50),
        .TxD_start(tx_start_signal),
        .TxD_data(tx_byte),
        .TxD(GPIO_TX),
        .TxD_busy(tx_busy)
    );

    // =================================================================
    // 2. RX DECODER FSM (Logic giải mã H và Y)
    // Nhiệm vụ: Nhận chuỗi byte -> Ghép thành số phức -> Đẩy ra cổng H hoặc Y
    // =================================================================
    
    // Bộ đếm byte: 0-3 (Thực), 4-7 (Ảo) => 1 phần tử phức tốn 8 bytes
    reg [2:0]  byte_cnt;
    
    // Bộ đếm phần tử: 0-15 (Ma trận H), 16-23 (Vector Y) => Tổng 24 phần tử
    reg [4:0]  element_cnt; 
    
    // Thanh ghi tạm để ghép byte
    reg [N-1:0] tmp_r;
    reg [N-1:0] tmp_i;

    always @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) begin
            // Reset toàn bộ
            sys_start   <= 0;
            H_valid     <= 0; H_r <= 0; H_i <= 0;
            Y_valid     <= 0; Y_r <= 0; Y_i <= 0;
            
            byte_cnt    <= 0;
            element_cnt <= 0;
            tmp_r       <= 0;
            tmp_i       <= 0;
        end else begin
            // Xóa cờ valid sau 1 chu kỳ (tạo xung đơn)
            H_valid   <= 0;
            Y_valid   <= 0;
            sys_start <= 0; // Mặc định sys_start xuống 0

            if (rx_ready) begin
                // --- Logic tạo sys_start ---
                // Khi nhận byte đầu tiên của phần tử đầu tiên
                if (element_cnt == 0 && byte_cnt == 0) begin
                    sys_start <= 1;
                end

                // --- FSM xử lý byte ---
                // Giả sử PC gửi Big Endian (Byte cao trước: [31:24] -> ... -> [7:0])
                case (byte_cnt)
                    // --- 4 Bytes cho Phần THỰC (Real) ---
                    3'd0: tmp_r[31:24] <= rx_data;
                    3'd1: tmp_r[23:16] <= rx_data;
                    3'd2: tmp_r[15:8]  <= rx_data;
                    3'd3: tmp_r[7:0]   <= rx_data; // Xong phần thực

                    // --- 4 Bytes cho Phần ẢO (Imaginary) ---
                    3'd4: tmp_i[31:24] <= rx_data;
                    3'd5: tmp_i[23:16] <= rx_data;
                    3'd6: tmp_i[15:8]  <= rx_data;
                    3'd7: begin
                        // Nhận byte cuối cùng của phần ảo -> Xong 1 số phức
                        
                        // Quyết định dữ liệu thuộc H hay Y dựa vào element_cnt
                        if (element_cnt < 16) begin
                            // 16 phần tử đầu là Ma trận H (4x4)
                            H_r     <= tmp_r;
                            H_i     <= {tmp_i[31:8], rx_data}; // Ghép byte cuối ngay tại đây
                            H_valid <= 1;
                        end 
                        else if (element_cnt < 24) begin
                            // 8 phần tử tiếp theo là Vector Y (4x2 hoặc 8x1 tùy cấu hình)
                            Y_r     <= tmp_r;
                            Y_i     <= {tmp_i[31:8], rx_data};
                            Y_valid <= 1;
                        end

                        // Tăng bộ đếm phần tử
                        if (element_cnt == 23) 
                            element_cnt <= 0; // Đã nhận đủ H và Y, reset để nhận gói mới
                        else 
                            element_cnt <= element_cnt + 1;
                    end
                endcase

                // Tăng bộ đếm byte (0->7 rồi quay về 0)
                byte_cnt <= byte_cnt + 1;
            end
        end
    end

    // =================================================================
    // 3. TX SENDER FSM (Gửi kết quả 12-bit)
    // Nhiệm vụ: Tách 12-bit message -> gửi 2 bytes (Cao trước, Thấp sau)
    // =================================================================
    localparam TX_IDLE    = 3'd0;
    localparam TX_SEND_HI = 3'd1;
    localparam TX_WAIT_HI = 3'd2;
    localparam TX_SEND_LO = 3'd3;
    localparam TX_WAIT_LO = 3'd4;

    reg [2:0]  tx_state;
    reg [11:0] saved_msg; // Lưu message để ổn định dữ liệu

    always @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) begin
            tx_state        <= TX_IDLE;
            tx_start_signal <= 0;
            tx_byte         <= 0;
            saved_msg       <= 0;
        end else begin
            case (tx_state)
                TX_IDLE: begin
                    tx_start_signal <= 0;
                    // Nếu có lệnh gửi và đường truyền rảnh
                    if (message_ready && !tx_busy) begin
                        saved_msg <= message;   // Chốt dữ liệu
                        tx_state  <= TX_SEND_HI;
                    end
                end

                // Gửi 4 bit cao (kèm 4 bit 0)
                TX_SEND_HI: begin
                    tx_byte         <= {4'b0000, saved_msg[11:8]};
                    tx_start_signal <= 1;
                    tx_state        <= TX_WAIT_HI;
                end

                // Đợi gửi xong byte cao
                TX_WAIT_HI: begin
                    tx_start_signal <= 0;
                    if (!tx_busy) tx_state <= TX_SEND_LO;
                end

                // Gửi 8 bit thấp
                TX_SEND_LO: begin
                    tx_byte         <= saved_msg[7:0];
                    tx_start_signal <= 1;
                    tx_state        <= TX_WAIT_LO;
                end

                // Đợi gửi xong byte thấp
                TX_WAIT_LO: begin
                    tx_start_signal <= 0;
                    if (!tx_busy) tx_state <= TX_IDLE; // Hoàn tất
                end
                
                default: tx_state <= TX_IDLE;
            endcase
        end
    end

endmodule
