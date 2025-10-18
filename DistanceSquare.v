module DistanceSquare #(
	parameter N = 16,
	parameter Q = 8
) (
    input signed [N-1:0] v_m,
    input signed [N-1:0] ref,
    output signed [N-1:0] dist
);
    wire signed [N-1:0] diff;
    wire ovr;
    assign diff = v_m - ref;
    qmult #(.Q(Q), .N(N)) qmult_common (
      .i_multiplicand(diff),
      .i_multiplier(diff),
      .o_result(dist),
      .ovr(ovr)
  );
endmodule

