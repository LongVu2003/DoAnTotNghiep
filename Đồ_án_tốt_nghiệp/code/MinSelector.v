module MinSelector #(
	parameter N = 16,
	parameter Q = 8
) (
    input signed [N-1:0] d0, d1, d2, d3,
    output signed [N-1:0] min_dist,
    output  [2:0] min_idx
);
wire [N-1:0] tmp0,tmp1;
wire [2:0] tmpindex0, tmpindex1;

comparator #(N,Q) c0(
	.a(d0),
	.b(d1),
	.index0(3'b001),
	.index1(3'b010),
	.outmin(tmp0),
	.indexmin(tmpindex0)
);

comparator #(N,Q) c1(
	.a(d2),
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

