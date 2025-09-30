//==============================================================================
// Module: pe_unit (Processing Engine) - RESTRUCTURED WITH FSM & SUB-MODULES
// Description: Implements the full calculation flow for a single 'q' value,
//              controlled by a central FSM.
//==============================================================================
module pe_unit #(
    parameter Q = 8,
    parameter N = 16,
    parameter ACC_WIDTH = 48
) (
    input clk,
    input rst,
    input start_process,

    // Inputs from main module (Flattened)
    input signed [32*N-1:0] H_in_flat,
    input signed [16*N-1:0] Y_in_flat,
    input signed [16*N-1:0] Sq_in_flat,
    input signed [4*N-1:0]  Vm_in_flat,

    // Outputs to comparator tree
    output reg signed [ACC_WIDTH-1:0] d_q_out,
    output reg [1:0] mImin1_out, mQmin1_out,
    output reg [1:0] mImin2_out, mQmin2_out,
    output reg valid_out
);
    //--------------------------------------------------------------------------
    // --- Các tín hiệu điều khiển và trạng thái ---
    //--------------------------------------------------------------------------
    reg matrix_mult_start, calc_dh_g_start, reciprocal_start, calc_x_start, calc_dx_rq_start, find_mins_start;
    wire matrix_mult_done, calc_dh_g_done, reciprocal_done, calc_x_done, calc_dx_rq_done, find_mins_done;
    
    //--------------------------------------------------------------------------
    // --- Gọi instance các module tính toán con ---
    //--------------------------------------------------------------------------
    wire signed [16*N-1:0] Hq_from_mult_flat;
    complex_matrix_mult matrix_mult_inst (
        .clk(clk), .rst(rst), .start(matrix_mult_start),
        .H_in_flat(H_in_flat), .S_in_flat(Sq_in_flat),
        .Hq_out_flat(Hq_from_mult_flat), .done(matrix_mult_done)
    );
    
    wire signed [ACC_WIDTH-1:0] dh_wire;
    wire signed [64*N-1:0] g_all_wire;
    calc_dh_g calc_dh_g_inst (
        .clk(clk), .rst(rst), .start(calc_dh_g_start),
        .hq_in_flat(Hq_reg_flat), .dh_out(dh_wire),
        .g_all_out_flat(g_all_wire), .done(calc_dh_g_done)
    );
    
    wire signed [N-1:0] dh_inv_wire;
    reciprocal_lut recip_inst (
        .clk(clk), .rst(rst), .start(reciprocal_start),
        .dh_in(Dh_reg), .dh_inv_out(dh_inv_wire), .done(reciprocal_done)
    );

    wire signed [4*N-1:0] x_wire;
    calc_x_values calc_x_inst (
        .clk(clk), .rst(rst), .start(calc_x_start),
        .y_in_flat(Y_in_flat), .g_all_in_flat(g_all_reg), .dh_inv_in(dh_inv_reg),
        .x_out_flat(x_wire), .done(calc_x_done)
    );
    
    wire signed [ACC_WIDTH-1:0] rq_wire;
    wire signed [4*ACC_WIDTH-1:0] dxI1_wire, dxQ1_wire, dxI2_wire, dxQ2_wire;
    calc_dx_and_rq calc_dx_rq_inst(
        .clk(clk), .rst(rst), .start(calc_dx_rq_start),
        .x_in_flat(x_reg_flat), .vm_in_flat(Vm_in_flat),
        .rq_out(rq_wire),
        .dxI1_out_flat(dxI1_wire), .dxQ1_out_flat(dxQ1_wire),
        .dxI2_out_flat(dxI2_wire), .dxQ2_out_flat(dxQ2_wire),
        .done(calc_dx_rq_done)
    );
    
    wire signed [ACC_WIDTH-1:0] dI1q_wire, dQ1q_wire, dI2q_wire, dQ2q_wire;
    wire [1:0] mImin1_wire, mQmin1_wire, mImin2_wire, mQmin2_wire;
    find_4_mins find_mins_inst(
        .clk(clk), .rst(rst), .start(find_mins_start),
        .dxI1_in_flat(dxI1_reg), .dxQ1_in_flat(dxQ1_reg),
        .dxI2_in_flat(dxI2_reg), .dxQ2_in_flat(dxQ2_reg),
        .dI1q_out(dI1q_wire), .dQ1q_out(dQ1q_wire),
        .dI2q_out(dI2q_wire), .dQ2q_out(dQ2q_wire),
        .mImin1_out(mImin1_wire), .mQmin1_out(mQmin1_wire),
        .mImin2_out(mImin2_wire), .mQmin2_out(mQmin2_wire),
        .done(find_mins_done)
    );
    
    //--------------------------------------------------------------------------
    // --- Các thanh ghi trung gian để lưu kết quả ---
    //--------------------------------------------------------------------------
    reg signed [16*N-1:0] Hq_reg_flat;
    reg signed [ACC_WIDTH-1:0] Dh_reg;
    reg signed [64*N-1:0] g_all_reg;
    reg signed [N-1:0] dh_inv_reg;
    reg signed [4*N-1:0] x_reg_flat;
    reg signed [ACC_WIDTH-1:0] Rq_reg;
    reg signed [4*ACC_WIDTH-1:0] dxI1_reg, dxQ1_reg, dxI2_reg, dxQ2_reg;
    reg signed [ACC_WIDTH-1:0] dI1q_reg, dQ1q_reg, dI2q_reg, dQ2q_reg;
    
    //--------------------------------------------------------------------------
    // --- FSM điều khiển PE Unit ---
    //--------------------------------------------------------------------------
    reg [3:0] state;
    localparam S_IDLE              = 4'd0, S_START_Hq = 4'd1, S_WAIT_Hq = 4'd2,
               S_START_Dh_G        = 4'd3, S_WAIT_Dh_G = 4'd4,
               S_START_RECIPROCAL  = 4'd5, S_WAIT_RECIPROCAL   = 4'd6,
               S_START_X_CALC      = 4'd7, S_WAIT_X_CALC       = 4'd8,
               S_START_DX_RQ       = 4'd9, S_WAIT_DX_RQ        = 4'd10,
               S_START_FIND_MINS   = 4'd11, S_WAIT_FIND_MINS    = 4'd12,
               S_CALC_DQ           = 4'd13, S_OUTPUT            = 4'd14;

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE; valid_out <= 1'b0;
            matrix_mult_start <= 1'b0; calc_dh_g_start <= 1'b0; reciprocal_start <= 1'b0; 
            calc_x_start <= 1'b0; calc_dx_rq_start <= 1'b0; find_mins_start <= 1'b0;
        end else begin
            valid_out <= 1'b0; matrix_mult_start <= 1'b0; calc_dh_g_start <= 1'b0; reciprocal_start <= 1'b0; 
            calc_x_start <= 1'b0; calc_dx_rq_start <= 1'b0; find_mins_start <= 1'b0;

            case(state)
                S_IDLE: if (start_process) state <= S_START_Hq;
                
                S_START_Hq: begin matrix_mult_start <= 1'b1; state <= S_WAIT_Hq; end
                S_WAIT_Hq: if (matrix_mult_done) begin Hq_reg_flat <= Hq_from_mult_flat; state <= S_START_Dh_G; end

                S_START_Dh_G: begin calc_dh_g_start <= 1'b1; state <= S_WAIT_Dh_G; end
                S_WAIT_Dh_G: if (calc_dh_g_done) begin Dh_reg <= dh_wire; g_all_reg <= g_all_wire; state <= S_START_RECIPROCAL; end

                S_START_RECIPROCAL: begin reciprocal_start <= 1'b1; state <= S_WAIT_RECIPROCAL; end
                S_WAIT_RECIPROCAL: if (reciprocal_done) begin dh_inv_reg <= dh_inv_wire; state <= S_START_X_CALC; end

                S_START_X_CALC: begin calc_x_start <= 1'b1; state <= S_WAIT_X_CALC; end
                S_WAIT_X_CALC: if (calc_x_done) begin x_reg_flat <= x_wire; state <= S_START_DX_RQ; end

                S_START_DX_RQ: begin calc_dx_rq_start <= 1'b1; state <= S_WAIT_DX_RQ; end
                S_WAIT_DX_RQ: if (calc_dx_rq_done) begin 
                                  Rq_reg <= rq_wire; 
                                  dxI1_reg <= dxI1_wire; dxQ1_reg <= dxQ1_wire;
                                  dxI2_reg <= dxI2_wire; dxQ2_reg <= dxQ2_wire;
                                  state <= S_START_FIND_MINS; 
                              end

                S_START_FIND_MINS: begin find_mins_start <= 1'b1; state <= S_WAIT_FIND_MINS; end
                S_WAIT_FIND_MINS: if (find_mins_done) begin 
                                      dI1q_reg <= dI1q_wire; dQ1q_reg <= dQ1q_wire;
                                      dI2q_reg <= dI2q_wire; dQ2q_reg <= dQ2q_wire;
                                      mImin1_out <= mImin1_wire; mQmin1_out <= mQmin1_wire;
                                      mImin2_out <= mImin2_wire; mQmin2_out <= mQmin2_wire;
                                      state <= S_CALC_DQ; 
                                  end

                S_CALC_DQ: begin 
                               d_q_out <= (dI1q_reg + dQ1q_reg + dI2q_reg + dQ2q_reg) - (Rq_reg * Dh_reg); // Placeholder
                               state <= S_OUTPUT; 
                           end
                S_OUTPUT: begin valid_out <= 1'b1; state <= S_IDLE; end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
