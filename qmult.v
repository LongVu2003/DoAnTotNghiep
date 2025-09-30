
module qmult #(
	//Parameterized values
	parameter Q = 8,
	parameter N = 16
	)
	(
	 input	signed		[N-1:0]	i_multiplicand,
	 input	signed		[N-1:0]	i_multiplier,
	 output	signed		[N-1:0]	o_result,
	 output	reg				ovr
	 );
	 
	
	wire signed [2*N-1:0]	r_result;		//	Nhan 2 so cos gia tri N bit thi can 1 thanh ghi co do rong la N+N = 2N 
	reg signed [N-1:0]		r_RetVal;

	wire signed [N-1:0]     temp_multiplicand, temp_meltiplier;
	reg signed [N-1:0] temp_RetVal;
	reg is_signed;

	//--------------------------------------------------------------------------------
	assign o_result = r_RetVal;	//	Chi lay ket qua co cung so bit theo cau truc cua fixed point

	//---------------------------------------------------------------------------------
	//always @(i_multiplicand, i_multiplier)	begin						//	Thuc hien nhan bat cu khi nao input thay doi
		// Thuc hien kiem tra bit dau
	assign temp_multiplicand = i_multiplicand[N-1] ? -i_multiplicand : i_multiplicand;
	assign temp_meltiplier = i_multiplier[N-1] ? -i_multiplier : i_multiplier;
	assign r_result = temp_meltiplier * temp_multiplicand;
	//end

	always @(r_result) begin													//	Bat cu khi nao ket qua thay doi thi thuc hien
		is_signed = i_multiplicand[N-1] ^ i_multiplier[N-1];	// Kiem tra bit co dau
		temp_RetVal[N-2:0] = r_result[N-2+Q:Q];					// Bo N/2 bit dau vaf N/2 bit cuoi
		temp_RetVal[N-1] = 0;									// so khong cos dau
		r_RetVal = is_signed ? -temp_RetVal : temp_RetVal;
		
		ovr = |r_result[2*N-2:N-1+Q];		// Neu N/2 bit dau >0 thi phep toan tran
	end

endmodule
