
module output_signal #(
    parameter N = 32
) (
    // System Signals
    input wire                  clk,
    input wire                  rst,

    // Input Signals (from find_min module)
    input wire                  in_valid,      // Connect to min_valid
    input wire [2:0]   m_Imin_1,      // Index for Bv (1-4)
    input wire [2:0]   m_Qmin_1,      // Index for Bv (1-4)
    input wire [2:0]   m_Imin_2,      // Index for Bv (1-4)
    input wire [2:0]   m_Qmin_2,      // Index for Bv (1-4)
    input wire [4:0]   q_min,         // Connect to q_min

    // Output Bitstreams
    output reg [7:0]            b1,
    output reg [3:0]            b2,
    output reg                  out_valid
);

    // --- Bv Mapping Function ---
    // Converts an index (1, 2, 3, 4) to its corresponding 2-bit Gray code from the Bv table.
    function [1:0] Bv_map;
        input signed [N-1:0] index;
        begin
            case (index)
                1:       Bv_map = 2'b00; // Bv(1) -> 00
                2:       Bv_map = 2'b01; // Bv(2) -> 01
                3:       Bv_map = 2'b11; // Bv(3) -> 11
                4:       Bv_map = 2'b10; // Bv(4) -> 10
                default: 
                     Bv_map = 2'b00; // Default case for safety
            endcase
        end
    endfunction

    // --- Combinational Logic for Mapping ---
    wire [7:0] b1_comb;
    wire [3:0] b2_comb;

    // Map each input index using the Bv function and concatenate them for b1
    assign b1_comb = { Bv_map(m_Imin_1), Bv_map(m_Qmin_1), Bv_map(m_Imin_2), Bv_map(m_Qmin_2) };

    // Map q_min (1-16) to b2 (0-15) by subtracting 1
    assign b2_comb = q_min - 1;


    // --- Registered Output Logic ---
    // This creates a pipeline stage, making timing easier to manage.
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            b1        <= 8'b0;
            b2        <= 4'b0;
            out_valid <= 1'b0;
        end else begin
            if (in_valid) begin
                b1        <= b1_comb;
                b2        <= b2_comb;
                out_valid <= 1'b1;
            end else begin
                // out_valid is a single-cycle pulse
                out_valid <= 1'b0;
            end
        end
    end

endmodule


