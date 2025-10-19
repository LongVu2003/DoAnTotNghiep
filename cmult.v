
//---------------------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------------------
module cmult # (
    parameter Q = 22, 
    parameter N = 32
)
(
    input clk,
    input rst,
    input signed  [N-1:0] ar, ai,
    input signed  [N-1:0] br, bi,
    output signed [N-1:0] pr, pi
);

reg signed [N-1:0] ar_d, ar_dd, ar_ddd, ar_dddd;
reg signed [N-1:0] ai_d, ai_dd, ai_ddd, ai_dddd;
reg signed [N-1:0] br_d, br_dd, br_ddd, bi_d, bi_dd, bi_ddd;
reg signed [N-1:0] addcommon ;
reg signed [N-1:0] addr, addi ;
reg signed [N-1:0] mult0, multr, multi;
reg signed  [N-1:0] common, commonr1, commonr2;
reg signed  [N-1:0] pr_int, pi_int;

wire signed [N-1:0] tmp_mult0, tmp_multr, tmp_multi;
wire ovr_mult0, ovr_multr, ovr_multi; // Overflow flags for multipliers
/*
always @(ar,ai,br,bi)  begin //      Thuc hien nhan bat cu khi     nao input thay doi
                  // Thuc hien kiem tra bit dau
	temp_ar = ar[N-1] ? -ar : ar;
	temp_ai = ai[N-1] ? -ai : ai;
	temp_br = br[N-1] ? -br : br;
	temp_bi = bi[N-1] ? -bi : bi;
end
always @(r_result) begin
 	//Bat cu khi nao ket qua thay doi thi thuc hien
	is_signed = i_multiplicand[N-1] ^ i_multiplier[N-1];    // Kiem tra bit co dau
	temp_RetVal[N-2:0] = r_result[N-2+Q:Q];                 // Bo N/2 bit dau vaf N/2 bit cuoi
	temp_RetVal[N-1] = 0;                                   // so khong cos dau
	r_RetVal = is_signed ? -temp_RetVal : temp_RetVal;

	ovr = |r_result[2*N-2:N-1+Q];           // Neu N/2 bit dau >0 thi phep toan tran
end
*/
// Pipeline stage 1: Input register
always @(posedge clk) begin
  	if(rst) begin
		ar_d <= 0;
		ai_d <= 0;	
		br_d <= 0;
		bi_d <= 0;
	end
	else begin
    		ar_d <= ar;
    		ar_dd <= ar_d;
    		ai_d <= ai;
    		ai_dd <= ai_d;
    		br_d <= br;
    		br_dd <= br_d;
    		br_ddd <= br_dd;
    		bi_d <= bi;
    		bi_dd <= bi_d;
    		bi_ddd <= bi_dd;
	end
end

// Pipeline stage 2: Common factor multiplication
always @(posedge clk) begin
	addcommon <= ar_d - ai_d;
	mult0 <= tmp_mult0;//addcommon * bi_dd;
	common <= mult0;
end

qmult #(.Q(Q), .N(N)) qmult_common (
    .i_multiplicand(addcommon), 
    .i_multiplier(bi_dd), 
    .o_result(tmp_mult0),
    .ovr(ovr_mult0)
);
/*
always @(posedge clk) begin
    common <= mult0;
end
*/
// Pipeline stage 3: Real product calculation
always @(posedge clk) begin
	ar_ddd <= ar_dd;
	ar_dddd <= ar_ddd;
	addr <= br_ddd - bi_ddd;
	multr <=  tmp_multr;//addr * ar_dddd;
	commonr1 <= common;
	pr_int <= multr + commonr1;
end

/*
always @(posedge clk) begin
	addr <= br_ddd - bi_ddd;
	
end
*/
qmult #(.Q(Q), .N(N)) qmult_real (
    .i_multiplicand(addr), 
    .i_multiplier(ar_dddd), 
    .o_result(tmp_multr),
    .ovr(ovr_multr)
);
/*
always @(posedge clk) begin
    commonr1 <= common;
    pr_int <= multr + commonr1; 
end
*/
// Pipeline stage 4: Imaginary product calculation

always @(posedge clk)
begin
	ai_ddd <= ai_dd;
	ai_dddd <= ai_ddd;
	addi <= br_ddd + bi_ddd;
	multi <= tmp_multi;//addi * ai_dddd;
	commonr2 <= common;
	pi_int <= multi + commonr2;
end
/*
always @(posedge clk) begin
	addi <= br_ddd + bi_ddd;
end
*/
qmult #(.Q(Q), .N(N)) qmult_imag (
    .i_multiplicand(addi), 
    .i_multiplier(ai_dddd), 
    .o_result(tmp_multi),
    .ovr(ovr_multi)
);
/*
always @(posedge clk) begin
    commonr2 <= common;
    pi_int <= multi + commonr2; 
end
*/
// Output assignment
/*
assign pr[N-2:0] = pr_int[N-2+Q:Q];
assign pr[N-1] = 0;
assign pi[N-2:0] = pi_int[N-2+Q:Q];
assign pi[N-1] = 0;
*/
assign pr = pr_int;
assign pi = pi_int;

endmodule // cmult
