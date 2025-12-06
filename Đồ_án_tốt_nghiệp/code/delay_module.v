module delay_module #(
    parameter N = 16,          // Độ rộng dữ liệu
    parameter MAX_DELAY = 40  // Độ trễ tối đa có thể lưu được
)(
    input  wire              clk,
    input  wire              rst,
    input  wire signed [N-1:0]      in,
    input  wire [$clog2(MAX_DELAY)-1:0] number, // số chu kỳ trễ
    output reg signed [N-1:0]      out
);

    // Bộ nhớ lưu các giá trị input theo thời gian
    reg signed [N-1:0] shift_reg [0:MAX_DELAY-1];
    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset tất cả
            for (i = 0; i < MAX_DELAY; i = i + 1)
                shift_reg[i] <= {N{1'b0}};
            out <= {N{1'b0}};
        end else begin
            // Dịch dữ liệu
            shift_reg[0] <= in;
            for (i = 1; i < MAX_DELAY; i = i + 1)
                shift_reg[i] <= shift_reg[i-1];

            // Lấy giá trị trễ theo số chu kỳ
            out <= shift_reg[number];
        end
    end

endmodule

