module di_q_calculate #(
	parameter N = 16,
	parameter Q = 8
) (
    input  signed [N-1:0] xI1, xQ1, xI2, xQ2,
    output signed [N-1:0] min_dI1, min_dQ1, min_dI2, min_dQ2,
    output signed [N-1:0] Rq,
    output [2:0] min_idx_dI1, min_idx_dQ1, min_idx_dI2, min_idx_dQ2
);

    // Vector V = {1, 4, 2, 5}
    wire signed [N-1:0] V [0:3];
    assign V[0] = 32'hff400000; // -3
    assign V[1] = 32'hffc00000; // -1
    assign V[2] = 32'h00400000; // 1
    assign V[3] = 32'h00c00000; // 3

    // Wires để lưu kết quả khoảng cách
    wire signed [N-1:0] dI1[0:3], dQ1[0:3], dI2[0:3], dQ2[0:3];

    // Generate các khối tính khoảng cách bình phương
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : gen_distance_calc
            DistanceSquare #(.N(N),.Q(Q)) calc_dI1 (.v_m(V[i]), .x_in(xI1), .dx_out(dI1[i]));
            DistanceSquare #(.N(N),.Q(Q)) calc_dQ1 (.v_m(V[i]), .x_in(xQ1), .dx_out(dQ1[i]));
            DistanceSquare #(.N(N),.Q(Q)) calc_dI2 (.v_m(V[i]), .x_in(xI2), .dx_out(dI2[i]));
            DistanceSquare #(.N(N),.Q(Q)) calc_dQ2 (.v_m(V[i]), .x_in(xQ2), .dx_out(dQ2[i]));
        end
    endgenerate

    // Module tìm min cho từng loại khoảng cách
    MinSelector #(.N(N),.Q(Q)) min_selector_I1 (.d0(dI1[0]), .d1(dI1[1]), .d2(dI1[2]), .d3(dI1[3]), .min_dist(min_dI1), .min_idx(min_idx_dI1));
    MinSelector #(.N(N),.Q(Q))min_selector_Q1 (.d0(dQ1[0]), .d1(dQ1[1]), .d2(dQ1[2]), .d3(dQ1[3]), .min_dist(min_dQ1), .min_idx(min_idx_dQ1));
    MinSelector #(.N(N),.Q(Q))min_selector_I2 (.d0(dI2[0]), .d1(dI2[1]), .d2(dI2[2]), .d3(dI2[3]), .min_dist(min_dI2), .min_idx(min_idx_dI2));
    MinSelector #(.N(N),.Q(Q))min_selector_Q2 (.d0(dQ2[0]), .d1(dQ2[1]), .d2(dQ2[2]), .d3(dQ2[3]), .min_dist(min_dQ2), .min_idx(min_idx_dQ2));
 	
	//RQcal
Rq_cal #(.N(N),.Q(Q)) Rqcaculate(
	.xi1_in(xI1),
	.xi2_in(xI2),
	.xq1_in(xQ1),
	.xq2_in(xQ2),
	.Rq_out(Rq)
);	
endmodule
