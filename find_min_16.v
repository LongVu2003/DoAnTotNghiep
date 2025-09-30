//==============================================================================
// Module: find_min_16
// Description: 4-stage pipelined comparator tree.
//==============================================================================
module find_min_16 #(
    parameter DATA_WIDTH = 48
) (
    input clk,
    input rst,
    input start_find,
    input signed [16*DATA_WIDTH-1:0] data_in_flat,
    
    output reg signed [DATA_WIDTH-1:0] min_val,
    output reg [3:0] min_idx,
    output reg valid_out
);


endmodule
