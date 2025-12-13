module MinSelector #(
	parameter N = 16,
	parameter Q = 8
) (
	input clk,
	input rst,
    input signed [N-1:0] d0, d1, d2, d3,
    output signed [N-1:0] min_dist,
    output  [2:0] min_idx
);
wire [N-1:0] tmp0,tmp1;
wire [2:0] tmpindex0, tmpindex1;

reg signed [N-1:0] d0_d, d0_2d, d0_3d;
reg signed [N-1:0] d1_d, d1_2d;
reg signed [N-1:0] d2_d;

always @(posedge clk or posedge rst) begin
	if (rst) begin
		d0_d <= 0; d0_2d <= 0; d0_3d <= 0;
		d1_d <= 0; d1_2d <= 0;
		d2_d <= 0;
	end else begin
		d0_d <= d0;
		d0_2d <= d0_d;
		d0_3d <= d0_2d;
		d1_d <= d1;
		d1_2d <= d1_d;
		d2_d <= d2;	
	end
end
comparator #(N,Q) c0(
	.a(d0_3d),
	.b(d1_2d),
	.index0(3'b001),
	.index1(3'b010),
	.outmin(tmp0),
	.indexmin(tmpindex0)
);

comparator #(N,Q) c1(
	.a(d2_d),
	.b(d3),
	.index0(3'b011),
	.index1(3'b100),
	.outmin(tmp1),
	.indexmin(tmpindex1)
);

comparator #(N,Q) c3(
	.a(tmp0),
	.b(tmp1),
	.index0(tmpindex0),
	.index1(tmpindex1),
	.outmin(min_dist),
	.indexmin(min_idx)
);
endmodule

