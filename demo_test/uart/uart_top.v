/*
module uart_top (
    // =================================================================
    // 1. CỔNG HỆ THỐNG & UART
    // =================================================================
    input  wire        CLOCK_50,   
    input  wire        sw_0,       // Reset (GẠT LÊN = CHẠY, GẠT XUỐNG = RESET)

    input  wire        GPIO_RX,    // Nối ESP32 TX
    output wire        GPIO_TX,    // Nối ESP32 RX

    // LED DEBUG
    output wire [9:0]  LEDR,

    // =================================================================
    // 2. CỔNG OUTPUT DỮ LIỆU (NỐI VỚI SOML_DECODER)
    // =================================================================
    
    // --- Output cho Ma trận H ---
    output reg [31:0] H_re_out,    
    output reg [31:0] H_im_out,    
    output reg        H_out,       // Valid Pulse (báo hiệu dữ liệu H hợp lệ)

    // --- Output cho Ma trận Y ---
    output reg [31:0] Y_re_out,    
    output reg [31:0] Y_im_out,    
    output reg        Y_out,        // Valid Pulse (báo hiệu dữ liệu Y hợp lệ)
	 
	 output reg start,

         //Inputs from Decoder
    input start_12bit,
    input [11:0]val_12bit_to_send
);

    // =================================================================
    // 3. THAM SỐ VÀ KHAI BÁO
    // =================================================================

    localparam CLK_FREQ  = 50000000;
    localparam BAUD_RATE = 9600;

    wire reset = sw_0; 

    // UART Signals
    wire        rx_data_ready;
    wire [7:0]  rx_data;
    reg         tx_start_reg = 0;
    reg  [7:0]  tx_data_reg  = 0;
    wire        tx_busy;

    // metastability
    reg [11:0] val_12bit_tmp_1;
	 reg [11:0] val_12bit_tmp_2;
	 
	 reg start_12bit_1;
	 reg start_12bit_2;
	 
	 always @(posedge CLOCK_50 or posedge reset) begin
		if(reset) begin
			val_12bit_tmp_1<=0;
			val_12bit_tmp_2 <=0;
			start_12bit_1<=0;
			start_12bit_2<=0;
		end else begin
			val_12bit_tmp_1<=val_12bit_to_send;
			val_12bit_tmp_2 <=val_12bit_tmp_1;
			start_12bit_1<=start_12bit;
			start_12bit_2<=start_12bit_1;
		end
	 end

    // =================================================================
    // 4. KHỐI RAM LƯU TRỮ MA TRẬN
    // =================================================================
    
    // Khai báo mảng nhớ (Distributed RAM / Registers)
    
    reg [31:0] ram_H_re [0:15];
    reg [31:0] ram_H_im [0:15];
    
    
    reg [31:0] ram_Y_re [0:7];
    reg [31:0] ram_Y_im [0:7];

    // =================================================================
    // 5. MÁY TRẠNG THÁI (FSM)
    // =================================================================

    localparam S_IDLE       = 4'd0;
    localparam S_RECV_H     = 4'd1;
    localparam S_RECV_Y     = 4'd2;
    localparam S_SEND_H_PRE = 4'd3; // Chuẩn bị Echo H
    localparam S_SEND_H     = 4'd4; // Đang Echo H
    localparam S_WAIT_TX    = 4'd5; // Chờ Echo xong 1 byte
    localparam S_STREAM     = 4'd6; // Bắn dữ liệu sang Decoder
    
    // --- TRẠNG THÁI MỚI CHO 12-BIT ---
    localparam S_PRE_12BIT  = 4'd7; // Chuẩn bị gửi 12 bit
    localparam S_SEND_12BIT = 4'd8; // Gửi từng byte của 12 bit
    localparam S_WAIT_12BIT = 4'd9; // Chờ gửi xong

    reg [3:0] state = S_IDLE; // Tăng độ rộng bit state lên 4 bit để chứa đủ trạng thái
    reg [2:0] byte_cnt = 0;
    reg [31:0] tmp_re, tmp_im; // Thanh ghi lắp ráp số 32-bit
    
    reg [4:0] h_index = 0;     // Đếm nhận H (0-15)
    reg [3:0] y_index = 0;     // Đếm nhận Y (0-7)
    
    reg [4:0] tx_elem_idx = 0; // Đếm phần tử gửi Echo
    reg [31:0] tx_temp_val;    // Giá trị tạm gửi Echo

    // Biến đếm cho quá trình Stream sang Decoder
    reg [4:0] stream_h_idx;
    reg [3:0] stream_y_idx;

    // =================================================================
    // 6. MODULES CON
    // =================================================================

    async_receiver #( .ClkFrequency(CLK_FREQ), .Baud(BAUD_RATE) ) 
    rx_inst (
        .clk(CLOCK_50), .RxD(GPIO_RX), .RxD_data_ready(rx_data_ready),
        .RxD_data(rx_data), .RxD_idle(), .RxD_endofpacket()
    );

    async_transmitter #( .ClkFrequency(CLK_FREQ), .Baud(BAUD_RATE) ) 
    tx_inst (
        .clk(CLOCK_50), .TxD_start(tx_start_reg), .TxD_data(tx_data_reg),   
        .TxD(GPIO_TX), .TxD_busy(tx_busy)
    );

    // Debug LED
    assign LEDR[3:0] = state;     // Hiển thị state 4 bit
    assign LEDR[9]   = rx_data_ready;
    assign LEDR[8]   = H_out | Y_out; // Sáng khi đang bắn dữ liệu sang decoder

    // =================================================================
    // 7. LOGIC CHÍNH
    // =================================================================
    always @(posedge CLOCK_50 or posedge reset) begin
        if (reset) begin
            state <= S_IDLE;
            byte_cnt <= 0;
            h_index <= 0;
            y_index <= 0;
            tx_start_reg <= 0;
            tx_data_reg <= 0;
            tmp_re <= 0;
            tmp_im <= 0;
            
            // Reset Streaming counters
            stream_h_idx <= 0;
            stream_y_idx <= 0;
            
            // Reset Output ports
            H_re_out <= 0; H_im_out <= 0; H_out <= 0;
            Y_re_out <= 0; Y_im_out <= 0; Y_out <= 0;
            
        end else begin
            // --- DEFAULT ASSIGNMENTS (QUAN TRỌNG) ---
            // Tự động tắt tín hiệu Valid và Start sau 1 xung clock
            // Nếu logic bên dưới không set lại thành 1, nó sẽ về 0.
            if (tx_start_reg) tx_start_reg <= 0;
            H_out <= 0; 
            Y_out <= 0;

            case (state)
                // --- TRẠNG THÁI CHỜ ---
                S_IDLE: begin
                    if (rx_data_ready) begin
                        if (rx_data == 8'hAA) begin        
                            state <= S_RECV_H;
                            byte_cnt <= 0; h_index <= 0;
                        end else if (rx_data == 8'hBB) begin 
                            state <= S_RECV_Y;
                            byte_cnt <= 0; y_index <= 0;
                        end
                    end
                end

                // --- NHẬN MA TRẬN H ---
                S_RECV_H: begin
                    if (rx_data_ready) begin
                        // Lắp ráp byte (Little Endian: LSB First)
                        if (byte_cnt < 4) tmp_re <= { tmp_re[23:0],rx_data};
                        else tmp_im <= {tmp_re[23:0],rx_data};

                        byte_cnt <= byte_cnt + 1;

                        if (byte_cnt == 7) begin
                            // Ghi vào RAM H
                            ram_H_re[h_index] <= tmp_re;
                            ram_H_im[h_index] <= {tmp_re[23:0],rx_data};
                            
                            byte_cnt <= 0;
                            h_index <= h_index + 1;

                            if (h_index == 15) state <= S_RECV_Y; //S_SEND_H_PRE; // Nhận đủ -> Echo
                        end
                    end
                end

                // --- NHẬN MA TRẬN Y ---
                S_RECV_Y: begin
                    if (rx_data_ready) begin
                        if (byte_cnt < 4) tmp_re <= {tmp_re[23:0],rx_data};
                        else tmp_im <= {tmp_re[23:0],rx_data};

                        byte_cnt <= byte_cnt + 1;

                        if (byte_cnt == 7) begin
                            // Ghi vào RAM Y
                            ram_Y_re[y_index] <= tmp_re;
                            ram_Y_im[y_index] <= {tmp_re[23:0],rx_data};
                            
                            byte_cnt <= 0;
                            y_index <= y_index + 1;

                            if (y_index == 7) begin
                                // SAU KHI NHẬN ĐỦ Y -> CHUYỂN SANG BẮN DỮ LIỆU
                                state <= S_STREAM;
                                stream_h_idx <= 0;
                                stream_y_idx <= 0;
                            end
                        end
                    end
                end

                // --- GỬI LẠI H (ECHO) ĐỂ DEBUG ---
                S_SEND_H_PRE: begin
                    tx_elem_idx <= 0; 
                    byte_cnt <= 0;
                    state <= S_SEND_H;
                end

                S_SEND_H: begin
                    if (!tx_busy) begin
                        // Đọc từ RAM để gửi UART
                        if (byte_cnt < 4) tx_temp_val = ram_H_re[tx_elem_idx]; 
                        else tx_temp_val = ram_H_im[tx_elem_idx];
                        
                        case (byte_cnt[1:0]) 
                            2'b00: tx_data_reg <= tx_temp_val[7:0];
                            2'b01: tx_data_reg <= tx_temp_val[15:8];
                            2'b10: tx_data_reg <= tx_temp_val[23:16];
                            2'b11: tx_data_reg <= tx_temp_val[31:24];
                        endcase
                        tx_start_reg <= 1;
                        state <= S_WAIT_TX; 
							
                    end
                end

                S_WAIT_TX: begin
                    byte_cnt <= byte_cnt + 1;
                    if (byte_cnt == 7) begin
                        byte_cnt <= 0;
                        tx_elem_idx <= tx_elem_idx + 1;
                        
                        if (tx_elem_idx == 15) state <= S_IDLE; // Xong Echo -> Về IDLE chờ Y
                        else state <= S_SEND_H;
                    end else state <= S_SEND_H;
                end

                // --- TRẠNG THÁI: BẮN DỮ LIỆU SANG SOML_DECODER ---
                S_STREAM: begin
                    // 1. Quét RAM H (16 phần tử)
                    if (stream_h_idx < 16) begin
	
                        H_re_out <= ram_H_re[stream_h_idx];
                        H_im_out <= ram_H_im[stream_h_idx];
                        H_out    <= 1; // Pulse Valid
                        stream_h_idx <= stream_h_idx + 1;
                    end

                    // 2. Quét RAM Y (8 phần tử) - chạy song song
                    if (stream_y_idx < 8) begin
                        Y_re_out <= ram_Y_re[stream_y_idx];
                        Y_im_out <= ram_Y_im[stream_y_idx];
                        Y_out    <= 1; // Pulse Valid
                        stream_y_idx <= stream_y_idx + 1;
                    end
							
                    // 3. Kiểm tra hoàn tất
                    if (stream_h_idx == 16 && stream_y_idx == 8) begin
                        // Thay vì về IDLE ngay, ta chuyển sang gửi kết quả 12-bit
                        state <= S_PRE_12BIT; 
                    end
                end

                // =================================================================
                // 8. LOGIC GỬI 12-BIT MỚI THÊM VÀO
                // =================================================================
                
                // Chuẩn bị biến đếm
                S_PRE_12BIT: begin
                    byte_cnt <= 0; 
						  if(start_12bit_2) begin
								state <= S_PRE_12BIT;
							end else state <= S_SEND_12BIT;
                end

                // Thực hiện gửi 2 byte
                S_SEND_12BIT: begin
                    if (!tx_busy) begin
                        if (byte_cnt == 0) begin
                            // Gửi Byte cao: 4 bit 0 + 4 bit cao của dữ liệu
                            tx_data_reg <= {4'b0000, val_12bit_tmp_2[11:8]};
                        end else begin
                            // Gửi Byte thấp: 8 bit thấp của dữ liệu
                            tx_data_reg <= val_12bit_tmp_2[7:0];
                        end
                        
                        tx_start_reg <= 1; // Kích hoạt module transmitter
                        state <= S_WAIT_12BIT;
                    end
                end

                // Chờ TX gửi xong byte hiện tại
                S_WAIT_12BIT: begin
                    
                    if (byte_cnt == 0) begin
                        byte_cnt <= 1;        // Chuyển sang byte tiếp theo
                        state <= S_SEND_12BIT; // Quay lại gửi byte thấp
                    end else begin
                        // Đã gửi xong cả 2 byte (byte_cnt == 1)
                        state <= S_IDLE;      
                    end
                end

            endcase
        end
    end

endmodule
*/
module uart_top (
    input  wire        CLOCK_50,   
    input  wire        sw_0,      

    input  wire        GPIO_RX,    // Nối ESP32 TX
    output wire        GPIO_TX,    // Nối ESP32 RX

    // LED DEBUG
    output wire [9:0]  LEDR,
    
    // --- Output cho Ma trận H ---
    output reg [31:0] H_re_out,    
    output reg [31:0] H_im_out,    
    output reg        H_value_ready,       

    // --- Output cho Ma trận Y ---
    output reg [31:0] Y_re_out,    
    output reg [31:0] Y_im_out,    
    output reg        Y_value_ready,       
	 


         //Inputs from Decoder
    input start_12bit,
    input [11:0]val_12bit_to_send
);

    localparam CLK_FREQ  = 50000000;
    localparam BAUD_RATE = 9600;

    wire reset = sw_0; 

    wire        rx_data_ready;
    wire [7:0]  rx_data;
    reg         tx_start_reg = 0;
    reg  [7:0]  tx_data_reg  = 0;
    wire        tx_busy;

    // metastability
    reg [11:0] val_12bit_tmp_1;
	 reg [11:0] val_12bit_tmp_2;
	 
	 reg start_12bit_1;
	 reg start_12bit_2;
	 
	 always @(posedge CLOCK_50 or posedge reset) begin
		if(reset) begin
			val_12bit_tmp_1<=0;
			val_12bit_tmp_2 <=0;
			start_12bit_1<=0;
			start_12bit_2<=0;
		end else begin
			val_12bit_tmp_1<=val_12bit_to_send;
			val_12bit_tmp_2 <=val_12bit_tmp_1;
			start_12bit_1<=start_12bit;
			start_12bit_2<=start_12bit_1;
		end
	 end
    
    reg [31:0] ram_H_re [0:15];
    reg [31:0] ram_H_im [0:15];
    
    
    reg [31:0] ram_Y_re [0:7];
    reg [31:0] ram_Y_im [0:7];

    localparam S_IDLE       = 4'd0;
    localparam S_RECV_H     = 4'd1;
    localparam S_RECV_Y     = 4'd2;
    localparam S_SEND_H_PRE = 4'd3; // Chuẩn bị Echo H
    localparam S_SEND_H     = 4'd4; // Đang Echo H
    localparam S_WAIT_TX    = 4'd5; // Chờ Echo xong 1 byte
    localparam S_STREAM     = 4'd6; // Bắn dữ liệu sang Decoder
    
    // --- TRẠNG THÁI CHO 12-BIT ---
    localparam S_PRE_12BIT  = 4'd7; // Chuẩn bị gửi 12 bit
    localparam S_SEND_12BIT = 4'd8; // Gửi từng byte của 12 bit
    localparam S_WAIT_12BIT = 4'd9; // Chờ gửi xong

    reg [3:0] state = S_IDLE; // Tăng độ rộng bit state lên 4 bit để chứa đủ trạng thái
    reg [2:0] byte_cnt = 0;
    reg [31:0] tmp_re, tmp_im; // Thanh ghi lắp ráp số 32-bit
    
    reg [4:0] h_index = 0;     // Đếm nhận H (0-15)
    reg [3:0] y_index = 0;     // Đếm nhận Y (0-7)
    
    reg [4:0] tx_elem_idx = 0; // Đếm phần tử gửi Echo
    reg [31:0] tx_temp_val;    // Giá trị tạm gửi Echo

    // Biến đếm cho quá trình gui sang Decoder
    reg [4:0] stream_h_idx;
    reg [3:0] stream_y_idx;

    async_receiver #( .ClkFrequency(CLK_FREQ), .Baud(BAUD_RATE) ) 
    rx_inst (
        .clk(CLOCK_50), .RxD(GPIO_RX), .RxD_data_ready(rx_data_ready),
        .RxD_data(rx_data), .RxD_idle(), .RxD_endofpacket()
    );

    async_transmitter #( .ClkFrequency(CLK_FREQ), .Baud(BAUD_RATE) ) 
    tx_inst (
        .clk(CLOCK_50), .TxD_start(tx_start_reg), .TxD_data(tx_data_reg),   
        .TxD(GPIO_TX), .TxD_busy(tx_busy)
    );

	 reg [31:0] H_re_tmp;    
    reg [31:0] H_im_tmp;    
    reg        H_value_tmp;       

    reg [31:0] Y_re_tmp;    
    reg [31:0] Y_im_tmp;    
    reg        Y_value_tmp;
	 
    always @(posedge CLOCK_50 or posedge reset) begin
        if (reset) begin
            state <= S_IDLE;
            byte_cnt <= 0;
            h_index <= 0;
            y_index <= 0;
            tx_start_reg <= 0;
            tx_data_reg <= 0;
            tmp_re <= 0;
            tmp_im <= 0;
            
            // Reset Streaming counters
            stream_h_idx <= 0;
            stream_y_idx <= 0;
            
            // Reset Output ports
            H_re_out <= 0; H_im_out <= 0; H_value_ready <= 0;
            Y_re_out <= 0; Y_im_out <= 0; Y_value_ready <= 0;
            
        end else begin
            if (tx_start_reg) tx_start_reg <= 0;
            H_value_ready <= 0; 
            Y_value_ready <= 0;

            case (state)
                S_IDLE: begin
                    if (rx_data_ready) begin
                        if (rx_data == 8'hAA) begin        
                            state <= S_RECV_H;
                            byte_cnt <= 0; h_index <= 0;
                        end else if (rx_data == 8'hBB) begin 
                            state <= S_RECV_Y;
                            byte_cnt <= 0; y_index <= 0;
                        end
                    end
                end

                // --- NHẬN MA TRẬN H ---
                S_RECV_H: begin
                    if (rx_data_ready) begin     
                        if (byte_cnt < 4) tmp_re <= {rx_data, tmp_re[31:8]};
                        else tmp_im <= {rx_data, tmp_im[31:8]};

                        byte_cnt <= byte_cnt + 1;

                        if (byte_cnt == 7) begin
                            H_value_ready <= 1'b1;
                            H_re_out <= tmp_re;
                            H_im_out <= {rx_data, tmp_im[31:8]};
                        
                            byte_cnt <= 0;

                            h_index <= h_index + 1;

                            if (h_index == 15) state <= S_IDLE;
                        end
                    end
                end

                S_RECV_Y: begin
                    if (rx_data_ready) begin
                        if (byte_cnt < 4) tmp_re <= {rx_data, tmp_re[31:8]};
                        else tmp_im <= {rx_data, tmp_im[31:8]};

                        byte_cnt <= byte_cnt + 1;

                        if (byte_cnt == 7) begin
     
                            Y_value_ready <= 1'b1;
                            Y_re_out<= tmp_re;
                            Y_im_out <= {rx_data, tmp_im[31:8]};
                            byte_cnt <= 0;
									 
									 y_index <= y_index+1;
									 if (y_index == 7) begin
                                
                                state <= S_PRE_12BIT;
                              
                            end
                        end
                    end
                end
                S_PRE_12BIT: begin
                    byte_cnt <= 0; 
					if(start_12bit_2) begin
						state <= S_PRE_12BIT;
					end else state <= S_SEND_12BIT;
                end

                S_SEND_12BIT: begin
                    if (!tx_busy) begin
                        if (byte_cnt == 0) begin
                            tx_data_reg <= {4'b0000, val_12bit_tmp_2[11:8]};
                        end else begin
                            tx_data_reg <= val_12bit_tmp_2[7:0];
                        end
                        
                        tx_start_reg <= 1; 
                        state <= S_WAIT_12BIT;
                    end
                end

                S_WAIT_12BIT: begin
                    
                    if (byte_cnt == 0) begin
                        byte_cnt <= 1;        
                        state <= S_SEND_12BIT; 
                    end else begin
                        state <= S_IDLE;      
                    end
                end

            endcase
        end
    end
	 /*
	 always @(posedge CLOCK_50 or posedge reset) begin
		if(reset) begin
			H_re_out <= 0;  
			H_im_out <= 0;   
			H_value_ready <= 0;      
			Y_re_out <= 0;    
			Y_im_out <= 0;
			Y_value_ready <= 0;   
	 
		end else begin
			H_re_out <= H_re_tmp;  
			H_im_out <= H_im_tmp;   
			H_value_ready <= H_value_tmp;      
			Y_re_out <= Y_re_tmp;    
			Y_im_out <= Y_im_tmp;
			Y_value_ready <=Y_value_tmp;   
		end
	 end
	 */
endmodule

