module MinFinder #(
    parameter N = 16,
    parameter Q = 8
) (
    // Thêm Clock và Reset
    input wire                  clk,
    input wire                  rst_n,

    input  signed [N-1:0]       xI1, xQ1, xI2, xQ2,
    output signed [N-1:0]       min_dI1, min_dQ1, min_dI2, min_dQ2,
    output signed [N-1:0]       Rq,
    output [2:0]                min_idx_dI1, min_idx_dQ1, min_idx_dI2, min_idx_dQ2
);

    // Vector V = {-3, -1, 1, 3}
    wire signed [N-1:0] V [0:3];
    assign V[0] = 32'hff400000; // -3
    assign V[1] = 32'hffc00000; // -1
    assign V[2] = 32'h00400000; // 1
    assign V[3] = 32'h00c00000; // 3

    // --- Logic tuần tự ---

    reg [1:0] v_idx;

    wire signed [N-1:0] v_m_in;
    assign v_m_in = V[v_idx];

    wire signed [N-1:0] dist_I1, dist_Q1, dist_I2, dist_Q2;

    reg signed [N-1:0] dI1[0:3], dQ1[0:3], dI2[0:3], dQ2[0:3];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_idx <= 2'b00;
            dI1[0] <= 0; dI1[1] <= 0; dI1[2] <= 0; dI1[3] <= 0;
            dQ1[0] <= 0; dQ1[1] <= 0; dQ1[2] <= 0; dQ1[3] <= 0;
            dI2[0] <= 0; dI2[1] <= 0; dI2[2] <= 0; dI2[3] <= 0;
            dQ2[0] <= 0; dQ2[1] <= 0; dQ2[2] <= 0; dQ2[3] <= 0;
        end else begin
            v_idx <= v_idx + 1;
            dI1[v_idx] <= dist_I1;
            dQ1[v_idx] <= dist_Q1;
            dI2[v_idx] <= dist_I2;
            dQ2[v_idx] <= dist_Q2;
        end
    end

    
    
    DistanceSquare #(.N(N),.Q(Q)) calc_dI1 (.v_m(v_m_in), .in_ref(xI1), .out_dist(dist_I1));
    DistanceSquare #(.N(N),.Q(Q)) calc_dQ1 (.v_m(v_m_in), .in_ref(xQ1), .out_dist(dist_Q1));
    DistanceSquare #(.N(N),.Q(Q)) calc_dI2 (.v_m(v_m_in), .in_ref(xI2), .out_dist(dist_I2));
    DistanceSquare #(.N(N),.Q(Q)) calc_dQ2 (.v_m(v_m_in), .in_ref(xQ2), .out_dist(dist_Q2));


    // Module tìm min cho từng loại khoảng cách
    MinSelector #(.N(N),.Q(Q)) min_selector_I1 (.clk(clk), .rst(rst), .d0(dI1[0]), .d1(dI1[1]), .d2(dI1[2]), .d3(dI1[3]), .min_dist(min_dI1), .min_idx(min_idx_dI1));
    MinSelector #(.N(N),.Q(Q)) min_selector_Q1 (.clk(clk), .rst(rst), .d0(dQ1[0]), .d1(dQ1[1]), .d2(dQ1[2]), .d3(dQ1[3]), .min_dist(min_dQ1), .min_idx(min_idx_dQ1));
    MinSelector #(.N(N),.Q(Q)) min_selector_I2 (.clk(clk), .rst(rst), .d0(dI2[0]), .d1(dI2[1]), .d2(dI2[2]), .d3(dI2[3]), .min_dist(min_dI2), .min_idx(min_idx_dI2));
    MinSelector #(.N(N),.Q(Q)) min_selector_Q2 (.clk(clk), .rst(rst), .d0(dQ2[0]), .d1(dQ2[1]), .d2(dQ2[2]), .d3(dQ2[3]), .min_dist(min_dQ2), .min_idx(min_idx_dQ2));
    
    // RQcal (Không thay đổi)
    Rq_cal #(.N(N),.Q(Q)) Rqcaculate(
        .xi1_in(xI1),
        .xi2_in(xI2),
        .xq1_in(xQ1),
        .xq2_in(xQ2),
        .Rq_out(Rq)
    ); 
endmodule