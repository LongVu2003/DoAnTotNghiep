/**
 * @brief Module to map the minimum indices to the transmitted signal values.
 * @details Implements the v(m_min) and S(q_min) mapping based on the provided formulas.
 * The outputs are registered and valid for one clock cycle after the input is valid.
 * Assumes a fixed-point Q8.8 format for the output signals.
 */
module determine_tx_signal #(
    parameter N = 32, // Total bit-width for fixed-point numbers
    parameter Q = 22   // Number of fractional bits
) (
    // System Signals
    input wire              clk,
    input wire              rst_n,

    // Input Signals (from find_min module)
    input wire              in_valid,
    input wire signed [N-1:0] m_Imin_1,
    input wire signed [N-1:0] m_Qmin_1,
    input wire signed [N-1:0] m_Imin_2,
    input wire signed [N-1:0] m_Qmin_2,
    input wire [4:0]        q_min,

    // Output Transmitted Signals
    output reg signed [N-1:0] s_hat_I_1,   // Real part of symbol 1
    output reg signed [N-1:0] s_hat_Q_1,   // Imaginary part of symbol 1
    output reg signed [N-1:0] s_hat_I_2,   // Real part of symbol 2
    output reg signed [N-1:0] s_hat_Q_2,   // Imaginary part of symbol 2
    output reg [4:0]        S_hat_index, // Index q_min representing the matrix S_qmin
    output reg              out_valid
);

    // --- v Mapping Function ---
    // Converts an index (1, 2, 3, 4) to its corresponding Q(N-Q).Q fixed-point value.
    function signed [N-1:0] v_map;
        input signed [N-1:0] index;
        begin
            case (index)
                1:       v_map = 32'hff400000; // v(1) -> -3.0
                2:       v_map = 32'hffc00000; // v(2) -> -1.0
                3:       v_map = 32'h00400000; // v(3) ->  1.0
                4:       v_map = 32'h00c00000; // v(4) ->  3.0
                default: v_map = 0;             // Default case for safety
            endcase
        end
    endfunction

    // --- Combinational Logic for Mapping ---
    wire signed [N-1:0] s_hat_I_1_comb;
    wire signed [N-1:0] s_hat_Q_1_comb;
    wire signed [N-1:0] s_hat_I_2_comb;
    wire signed [N-1:0] s_hat_Q_2_comb;

    // Apply the v_map function to each m_min index
    assign s_hat_I_1_comb = v_map(m_Imin_1);
    assign s_hat_Q_1_comb = v_map(m_Qmin_1);
    assign s_hat_I_2_comb = v_map(m_Imin_2);
    assign s_hat_Q_2_comb = v_map(m_Qmin_2);
    
    // --- Registered Output Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_hat_I_1   <= 0;
            s_hat_Q_1   <= 0;
            s_hat_I_2   <= 0;
            s_hat_Q_2   <= 0;
            S_hat_index <= 0;
            out_valid   <= 1'b0;
        end else begin
            if (in_valid) begin
                s_hat_I_1   <= s_hat_I_1_comb;
                s_hat_Q_1   <= s_hat_Q_1_comb;
                s_hat_I_2   <= s_hat_I_2_comb;
                s_hat_Q_2   <= s_hat_Q_2_comb;
                S_hat_index <= q_min; // The selected S matrix is represented by its index
                out_valid   <= 1'b1;
            end else begin
                out_valid   <= 1'b0;
            end
        end
    end

endmodule