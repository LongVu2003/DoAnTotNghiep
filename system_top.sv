module system_top (
    input  wire       CLOCK_50,
    input  wire       sys_rst,    
	 
    // Data H
    input [31:0] w_H_in_r,
    input [31:0] w_H_in_i,
    input        w_H_in_valid,

    // Data Y
    input [31:0] w_Y_in_r,
    input [31:0] w_Y_in_i,
    input        w_Y_in_valid,
	 
    output        w_decoder_done,
    output [11:0] w_signal_out_12bit
);

/*
    uart_top uart_inst (
        .CLOCK_50(CLOCK_50),
        .sw_0(sys_rst),
        
        .GPIO_RX(GPIO_RX),
        .GPIO_TX(GPIO_TX),
        .LEDR(LEDR),

        // Outputs to Decoder
        .H_re_out(w_H_in_r),
        .H_im_out(w_H_in_i),
        .H_value_ready(w_H_in_valid),
        
        .Y_re_out(w_Y_in_r),
        .Y_im_out(w_Y_in_i),
        .Y_value_ready(w_Y_in_valid),

        //Inputs from Decoder
        .start_12bit(w_decoder_done),
        .val_12bit_to_send(w_signal_out_12bit)
    );
*/

    // Internal signals from buffer controller to decoder
    wire        w_start_decoder;
    wire [31:0] w_H_r, w_H_i;
    wire        H_valid;
    wire [31:0] w_Y_r, w_Y_i;
    wire        Y_valid;
    
    // Unused decoder outputs
    wire signed [31:0] s_I_1, s_Q_1, s_I_2, s_Q_2;
    wire [4:0] Smin_index;

    // ========================================================================
    // Data Buffer Controller Instance
    // ========================================================================
    data_buffer_controller buffer_ctrl_inst (
        .clk(CLOCK_50),
        .sys_rst(sys_rst),
        
        // Input from UART (or external source)
        .w_H_in_r(w_H_in_r),
        .w_H_in_i(w_H_in_i),
        .w_H_in_valid(w_H_in_valid),
        
        .w_Y_in_r(w_Y_in_r),
        .w_Y_in_i(w_Y_in_i),
        .w_Y_in_valid(w_Y_in_valid),
        
        // Output to Decoder
        .w_start_decoder(w_start_decoder),
        .H_out_r(w_H_r),
        .H_out_i(w_H_i),
        .H_out_valid(H_valid),
        .Y_out_r(w_Y_r),
        .Y_out_i(w_Y_i),
        .Y_out_valid(Y_valid)
    );

    // ========================================================================
    // SOML Decoder Instance
    // ========================================================================
    soml_decoder_top #(
        .Q(22),
        .N(32)
    ) decoder_inst (
        .clk(CLOCK_50),
        .rst(sys_rst),
        .start(w_start_decoder),

        // Nạp H từ buffer controller
        .H_in_valid(H_valid),
        .H_in_r(w_H_r),
        .H_in_i(w_H_i),

        // Nạp Y từ buffer controller
        .Y_in_valid(Y_valid),
        .Y_in_r(w_Y_r),
        .Y_in_i(w_Y_i),

        // Outputs
        .s_I_1(s_I_1), 
        .s_Q_1(s_Q_1), 
        .s_I_2(s_I_2), 
        .s_Q_2(s_Q_2),
        .Smin_index(Smin_index),
        
        .output_valid(w_decoder_done),   
        .signal_out_12bit(w_signal_out_12bit) 
    );

endmodule