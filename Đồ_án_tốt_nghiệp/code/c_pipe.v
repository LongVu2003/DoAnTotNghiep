
module c_pipe #(
    parameter Q = 8,  
    parameter N = 16 
)
(
    input clk,
    input rst,
    input signed [N-1:0] in_ar, in_ai,
    input signed [N-1:0] in_br, in_bi,

    output signed [N-1:0] r_out, i_out
);
    wire signed [N-1:0] pr,pi;
    reg signed  [N-1:0] pr_d,pr_dd,pr_ddd;
    reg signed  [N-1:0] pi_d,pi_dd,pi_ddd;
    cmult #( .Q(Q), .N(N) )
    cmult_inst ( // Khối nhân 2 số phức pipeline 5 chu kỳ
        .clk(clk),
        .rst(rst),
        .ar(in_ar),
        .ai(in_ai),
        .br(in_br),
        .bi(in_bi),
        .pr(pr),
        .pi(pi)
    );

    always @(posedge clk , posedge rst) begin
	if(rst) begin
		pr_d <= 0;
		pi_d <= 0;
	end else begin
		pr_d   <= pr;    pi_d   <= pi; 
		pr_dd  <= pr_d;  pi_dd  <= pi_d;
		pr_ddd <= pr_dd; pi_ddd <= pi_dd;
	end
    end
 
    assign i_out = pi + pi_d + pi_dd + pi_ddd;
    assign r_out = pr + pr_d + pr_dd + pr_ddd;

endmodule
