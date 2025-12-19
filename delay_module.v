module delay_module #(
    parameter N = 32,
    parameter NUM_DELAY = 5   // giới hạn tối đa
)(
    input  wire         clk,
    input  wire         rst,
    input  wire [N-1:0] in,
    output wire [N-1:0] out
);

    // chain lưu các giá trị trễ
    wire [N-1:0] delay_chain [0:NUM_DELAY];

    assign delay_chain[0] = in;

    genvar i;
    generate
        for (i = 0; i < NUM_DELAY; i = i + 1) begin : gen_delay
            mydff #(.N(N)) u_dff (
                .clk (clk),
                .rst (rst),
                .d   (delay_chain[i]),
                .q   (delay_chain[i+1])
            );
        end
    endgenerate

    // chọn tap theo number
    assign out = delay_chain[NUM_DELAY];

endmodule
