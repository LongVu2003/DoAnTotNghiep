module system_top_upgrade (
    input  wire        CLOCK_50,
    input  wire        sw_0,    // System Reset (Active High)
	 
	 input  wire        GPIO_RX,
    output wire        GPIO_TX,
 
    // Output Result
    output [11:0]      w_signal_out_12bit
);

    wire sys_rst_n;
    assign sys_rst_n = ~sw_0; // Chuyển sang Active Low cho giống logic FIFO cũ

	 // Data H Input (Real + Imag + Valid)
    wire [31:0]       w_H_in_r;
    wire [31:0]       w_H_in_i;
    wire              w_H_in_valid;

    // Data Y Input (Real + Imag + Valid)
    wire [31:0]       w_Y_in_r;
    wire [31:0]       w_Y_in_i;
    wire              w_Y_in_valid;

	 
	 // --- UART ---
    uart_top uart_inst (
        .CLOCK_50(CLOCK_50), .sw_0(sys_rst),
        .GPIO_RX(GPIO_RX), .GPIO_TX(GPIO_TX), .LEDR(LEDR),
        .H_re_out(w_H_in_r), .H_im_out(w_H_in_i), .H_value_ready(w_H_in_valid),
        .Y_re_out(w_Y_in_r), .Y_im_out(w_Y_in_i), .Y_value_ready(w_Y_in_valid),
        .start_12bit(w_decoder_done), .val_12bit_to_send(w_signal_out_12bit)
    );
	 
    localparam H_DEPTH = 32;               // Đủ chứa 16 mẫu
    reg [63:0] H_mem [H_DEPTH-1:0];        // Bộ nhớ: 64-bit (32R + 32I)
    reg [4:0]  H_wptr;                     // 5 bits cho depth 32
    reg [4:0]  H_rptr;
    reg [63:0] H_dout;

    wire H_full  = ((H_wptr + 1'b1) == H_rptr);
    wire H_empty = (H_wptr == H_rptr);

    // Tín hiệu điều khiển đọc (sẽ được lái bởi logic ở phần 4)
    reg  H_rd_en_ctrl;

    // --- H FIFO: WRITE LOGIC ---
    always @(posedge CLOCK_50 or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            H_wptr <= 0;
        end else begin
            // Chỉ ghi khi Valid Input bật và FIFO chưa đầy
            if (w_H_in_valid && !H_full) begin
                H_mem[H_wptr] <= {w_H_in_r, w_H_in_i}; // Ghép 2 số 32bit thành 64bit
                H_wptr <= H_wptr + 1'b1;
            end
        end
    end

    // --- H FIFO: READ LOGIC ---
    always @(posedge CLOCK_50 or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            H_rptr <= 0;
            H_dout <= 0;
        end else begin
            // Chỉ đọc khi Enable bật và FIFO có dữ liệu
            if (H_rd_en_ctrl && !H_empty) begin
                H_dout <= H_mem[H_rptr];
                H_rptr <= H_rptr + 1'b1;
            end
        end
    end

    
    localparam Y_DEPTH = 16;               // Đủ chứa 8 mẫu
    reg [63:0] Y_mem [Y_DEPTH-1:0];
    reg [3:0]  Y_wptr;                     // 4 bits cho depth 16
    reg [3:0]  Y_rptr;
    reg [63:0] Y_dout;

    wire Y_full  = ((Y_wptr + 1'b1) == Y_rptr);
    wire Y_empty = (Y_wptr == Y_rptr);

    // Tín hiệu điều khiển đọc
    reg  Y_rd_en_ctrl;

    // --- Y FIFO: WRITE LOGIC ---
    always @(posedge CLOCK_50 or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            Y_wptr <= 0;
        end else begin
            if (w_Y_in_valid && !Y_full) begin
                Y_mem[Y_wptr] <= {w_Y_in_r, w_Y_in_i};
                Y_wptr <= Y_wptr + 1'b1;
            end
        end
    end

    // --- Y FIFO: READ LOGIC ---
    always @(posedge CLOCK_50 or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            Y_rptr <= 0;
            Y_dout <= 0;
        end else begin
            if (Y_rd_en_ctrl && !Y_empty) begin
                Y_dout <= Y_mem[Y_rptr];
                Y_rptr <= Y_rptr + 1'b1;
            end
        end
    end


    // --- A. Đếm số lượng Y đã nạp để kích hoạt ---
    reg [4:0] cnt_loaded_Y;
    always @(posedge CLOCK_50 or negedge sys_rst_n) begin
        if (!sys_rst_n)
            cnt_loaded_Y <= 0;
        else if (w_Y_in_valid && cnt_loaded_Y < 16)
            cnt_loaded_Y <= cnt_loaded_Y + 1;
    end

    // Trigger Start: Khi nạp đủ 8 mẫu
    wire w_start_trigger = (cnt_loaded_Y >= 8);

    // --- B. Delay Start ---
    reg [3:0] wait_reset_cnt;
    reg       stream_active_flag;

    always @(posedge CLOCK_50 or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            wait_reset_cnt     <= 0;
            stream_active_flag <= 0;
        end else begin
            if (w_start_trigger) stream_active_flag <= 1;

            if (stream_active_flag && wait_reset_cnt < 8)
                wait_reset_cnt <= wait_reset_cnt + 1;
        end
    end

    // --- C. Read Controller (Điều khiển H_rd_en_ctrl và Y_rd_en_ctrl) ---
    reg [4:0] read_cnt_H;
    reg [3:0] read_cnt_Y;

    always @(posedge CLOCK_50 or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            H_rd_en_ctrl <= 0; read_cnt_H <= 0;
            Y_rd_en_ctrl <= 0; read_cnt_Y <= 0;
        end else begin
            // Kích hoạt đồng thời tại thời điểm delay == 5
            if (stream_active_flag && wait_reset_cnt == 5) begin
                if (!H_empty) begin H_rd_en_ctrl <= 1; read_cnt_H <= 0; end
                if (!Y_empty) begin Y_rd_en_ctrl <= 1; read_cnt_Y <= 0; end
            end

            // Đếm đủ 16 mẫu H thì dừng
            if (H_rd_en_ctrl) begin
                if (read_cnt_H == 15) H_rd_en_ctrl <= 0;
                else                  read_cnt_H   <= read_cnt_H + 1;
            end

            // Đếm đủ 8 mẫu Y thì dừng
            if (Y_rd_en_ctrl) begin
                if (read_cnt_Y == 7)  Y_rd_en_ctrl <= 0;
                else                  read_cnt_Y   <= read_cnt_Y + 1;
            end
        end
    end

    reg valid_H_d1;
    reg valid_Y_d1;

    always @(posedge CLOCK_50 or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            valid_H_d1 <= 0;
            valid_Y_d1 <= 0;
        end else begin
            valid_H_d1 <= H_rd_en_ctrl;
            valid_Y_d1 <= Y_rd_en_ctrl;
        end
    end

    // ============================================================
    // 6. DECODER CONNECTION
    // ============================================================
    wire w_decoder_done;

    // Tách 64-bit FIFO Out thành Real/Imag 32-bit
    wire [31:0] dec_H_r = H_dout[63:32];
    wire [31:0] dec_H_i = H_dout[31:0];
    wire [31:0] dec_Y_r = Y_dout[63:32];
    wire [31:0] dec_Y_i = Y_dout[31:0];

    soml_decoder_top #( .Q(22), .N(32) ) decoder_inst (
        .clk(CLOCK_50),
        .rst(sw_0), // Decoder dùng Active High Reset như cũ
        .start(w_start_trigger),

        // H Channel
        .H_in_valid (valid_H_d1),
        .H_in_r     (dec_H_r),
        .H_in_i     (dec_H_i),

        // Y Channel
        .Y_in_valid (valid_Y_d1),
        .Y_in_r     (dec_Y_r),
        .Y_in_i     (dec_Y_i),

        .output_valid(w_decoder_done),
        .signal_out_12bit(w_signal_out_12bit)
    );

endmodule
