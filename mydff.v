module mydff #(
    parameter N = 32
)(
    input  wire         clk,
    input  wire         rst,
    input  wire [N-1:0] d,
    output reg  [N-1:0] q
);
    always @(posedge clk) begin
        if (rst)
            q <= {N{1'b0}};
        else
            q <= d;
    end
endmodule
