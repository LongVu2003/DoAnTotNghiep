module comparator #(
	parameter N = 16,
	parameter Q = 8
)(
	input signed [N-1:0] a,
	input signed [N-1:0] b,
	input [2:0] index0,
	input [2:0] index1,
	output reg signed [N-1:0] outmin,
	output reg [2:0] indexmin

);

always @(*) begin
	if(a>b) begin
		outmin = b;
		indexmin = index1;
	end
	else if(a == b) begin
		outmin = b;
		indexmin = index1;
	end
	else begin
		outmin = a;
		indexmin = index0;
	end
end

endmodule

		
