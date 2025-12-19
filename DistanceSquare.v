module DistanceSquare #(
	parameter N = 16,
	parameter Q = 8
) (
    input signed [N-1:0] v_m,
    input signed [N-1:0] x_in,
    output signed [N-1:0] dx_out
);
    wire signed [N-1:0] diff;
    wire ovr;
    assign diff = v_m - x_in;
    qmult #(.Q(Q), .N(N)) qmult_common (
      .i_multiplicand(diff),
      .i_multiplier(diff),
      .o_result(dx_out),
      .ovr(ovr)
  );
endmodule

