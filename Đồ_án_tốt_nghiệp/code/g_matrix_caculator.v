/*
* Module: g_matrix_calculator_final
* Chức năng: Tự động kích hoạt, nạp đủ ma trận Hq vào RAM,
* sau đó xuất ra tuần tự 4 hàng của cả 4 ma trận G.
*/
module g_matrix_calculator #(
    parameter N = 16
)
(
    input clk,
    input rst,

    input Hq_in_valid,
    input signed [N-1:0] Hq_in_r,
    input signed [N-1:0] Hq_in_i,

    output reg G_valid, // Xung báo hiệu MỘT HÀNG của 4 ma trận G đã sẵn sàng
    
    output reg signed [N-1:0] Ga1_c0_r, Ga1_c0_i, Ga1_c1_r, Ga1_c1_i,
    output reg signed [N-1:0] Ga2_c0_r, Ga2_c0_i, Ga2_c1_r, Ga2_c1_i,
    output reg signed [N-1:0] Gb1_c0_r, Gb1_c0_i, Gb1_c1_r, Gb1_c1_i,
    output reg signed [N-1:0] Gb2_c0_r, Gb2_c0_i, Gb2_c1_r, Gb2_c1_i
);



// RAM nội bộ để lưu ma trận Hq (8 phần tử)
reg signed [N-1:0] Hq_RAM_r [0:7];
reg signed [N-1:0] Hq_RAM_i [0:7];

// Bộ đếm
reg [2:0] load_counter;   // Đếm 0-7 để nạp Hq
reg [1:0] stream_counter; // Đếm 0-3 để xuất 4 hàng G
reg stream_ena;

always @(posedge clk) begin
    if (Hq_in_valid) begin
        Hq_RAM_r[load_counter] <= Hq_in_r;
        Hq_RAM_i[load_counter] <= Hq_in_i;
    end
end

always @(posedge clk, posedge rst) begin
	if(rst) begin
		load_counter <= 1'b0;
	end
	else if(load_counter == 7'd7 && Hq_in_valid) begin
		load_counter <= 7'd0;
	end
	else if(Hq_in_valid)
		load_counter <= load_counter + 1'b1;
end

always @(posedge clk, posedge rst) begin
	if(rst) begin
		stream_ena <= 0;
	end 
	else if(load_counter == 7 && Hq_in_valid)
		stream_ena <= 1;
	else if(stream_counter == 2'b11)
		stream_ena <= 0;
end
always @(posedge clk,posedge rst) begin
	if(rst) 
		stream_counter <= 0;
	else if(stream_counter == 2'b11)
		stream_counter <= 0;
	else if(stream_ena)
		stream_counter <= stream_counter + 1;
end
		
// Đọc một hàng của Hq từ RAM dựa trên stream_counter
wire signed [N-1:0] hq_r0 = Hq_RAM_r[{stream_counter, 1'b0}]; // Hq[i][0]
wire signed [N-1:0] hq_i0 = Hq_RAM_i[{stream_counter, 1'b0}];
wire signed [N-1:0] hq_r1 = Hq_RAM_r[{stream_counter, 1'b1}]; // Hq[i][1]
wire signed [N-1:0] hq_i1 = Hq_RAM_i[{stream_counter, 1'b1}];

always @(posedge clk or posedge rst) begin
    if (rst) begin
        G_valid <= 1'b0;
        {Ga1_c0_r, Ga1_c0_i, Ga1_c1_r, Ga1_c1_i} <= 0;
        {Ga2_c0_r, Ga2_c0_i, Ga2_c1_r, Ga2_c1_i} <= 0;
        {Gb1_c0_r, Gb1_c0_i, Gb1_c1_r, Gb1_c1_i} <= 0;
        {Gb2_c0_r, Gb2_c0_i, Gb2_c1_r, Gb2_c1_i} <= 0;
    end else begin
        G_valid <= stream_ena;
        if (stream_ena) begin
            // 1. Ga,1 = [h_r0, h_r1]
            Ga1_c0_r <= hq_r0;    Ga1_c0_i <= hq_i0;
            Ga1_c1_r <= hq_r1;    Ga1_c1_i <= hq_i1;
            
            // 2. Ga,2 = [h_r1, -h_r0]
            Ga2_c0_r <= hq_r1;    Ga2_c0_i <= hq_i1;
            Ga2_c1_r <= -hq_r0;   Ga2_c1_i <= -hq_i0;
            
            // 3. Gb,1 = [h_r0, -h_r1]
            Gb1_c0_r <= hq_r0;    Gb1_c0_i <= hq_i0;
            Gb1_c1_r <= -hq_r1;   Gb1_c1_i <= -hq_i1;
            
            // 4. Gb,2 = [h_r1, h_r0]
            Gb2_c0_r <= hq_r1;    Gb2_c0_i <= hq_i1;
            Gb2_c1_r <= hq_r0;    Gb2_c1_i <= hq_i0;
        end
    end
end

endmodule
