/*
* Module: c_mac
* Chức năng: Tích lũy Nhân Phức (Complex Multiplier Accumulator)
* Sửa lỗi: Đồng bộ hóa pipeline 5 chu kỳ của khối nhân (cmult)
* Phương pháp: Sử dụng pipeline valid signal để điều khiển tích lũy.
*/

//`include "cmult.sv" // Giả định cmult có độ trễ 5 chu kỳ
module c_mac #(
    parameter Q = 8,  // Độ rộng bit phần thập phân (Fixed-point)
    parameter N = 16 // Tổng độ rộng bit
)
(
    input clk,
    input rst,
    input mac_clear,
    input mac_en, // Tín hiệu báo hiệu dữ liệu (in_ar, in_ai, in_br, in_bi) là hợp lệ
    input signed [N-1:0] in_ar, in_ai,
    input signed [N-1:0] in_br, in_bi,

    output reg signed [32-1:0] mac_r_out, mac_i_out,
    output reg mac_result_valid // Báo hiệu kết quả tích lũy mac_r_out/mac_i_out là hợp lệ
);
    wire mac_rs_valid;
    //wire product_valid_out;
    localparam LATENCY = 6; // Độ trễ của module cmult.sv
    // Dây nối để nhận kết quả từ khối nhân
    // Kích thước đầu ra của phép nhân là 2*N - 1, nhưng ta sẽ để N bit để tích lũy
    // Giả sử module cmult.sv đã xử lý việc giới hạn bit (truncation/saturation)
    wire signed [N-1:0] product_r, product_i;
    
    reg [1:0] mac_counter;
    // --- 1. Thanh ghi và Dây nối cho Tích lũy (Accumulator) ---
    // Thanh ghi tích lũy phải có độ rộng bit lớn hơn để tránh tràn số (overflow).
    // Phép nhân 16x16 cho ra 32 bit. Nếu tích lũy 8 lần, ta cần ít nhất 35 bit.
    // Dùng 2*N bit để đơn giản hóa logic (32 bit)
    localparam ACC_WIDTH = 2*N; 
    reg signed [ACC_WIDTH-1:0] mac_r_reg, mac_i_reg,mac_r_tmp,mac_i_tmp;
    
    // --- 2. Bộ tạo Tín hiệu Hợp lệ (Valid Signal Generator) ---
    // Tín hiệu valid cần được trễ 5 chu kỳ để đồng bộ với product_r/product_i
    reg [LATENCY-1:0] data_valid_pipe;
    wire product_valid = data_valid_pipe[LATENCY-1]; // Bit cuối cùng là valid output
   /// Internal Counter
    always @(posedge clk or posedge rst) begin
	if(rst) mac_counter <= 2'b0;
	else if(mac_clear) mac_counter <= 2'b0;
	else if (mac_counter == 2'b11) mac_counter <= 2'b0;
	else if (product_valid) mac_counter <= mac_counter+1'b1;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            data_valid_pipe <= {LATENCY{1'b0}}; // Reset tất cả về 0
        end else begin
	    mac_result_valid <= mac_rs_valid;
            // Trễ tín hiệu valid (5-stage pipeline)
            data_valid_pipe <= {data_valid_pipe[LATENCY-2:0], mac_en};
        end
    end
    
    // --- 3. Khối Nhân Phức (cmult instantiation) ---
    // Giả định cmult.sv là khối nhân 5-stage pipeline
    cmult #( .Q(Q), .N(N) )
    cmult_inst (
        .clk(clk),
        .rst(rst),
        .ar(in_ar),
        .ai(in_ai),
        .br(in_br),
        .bi(in_bi),
        .pr(product_r),
        .pi(product_i)
    );

    // --- 4. Logic cho Thanh ghi Tích lũy (Accumulation Logic) ---
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mac_r_reg <= {ACC_WIDTH{1'b0}};
            mac_i_reg <= {ACC_WIDTH{1'b0}};
        end else if (mac_clear) begin
            // Xóa ngay lập tức (Xóa đầu ra của phép tích lũy, không phải đầu ra của cmult)
            mac_r_reg <= {ACC_WIDTH{1'b0}};
            mac_i_reg <= {ACC_WIDTH{1'b0}};
	    mac_r_tmp <= mac_r_reg;
	    mac_i_tmp <= mac_i_reg;
        end else if (product_valid) begin
            // CHỈ THỰC HIỆN TÍCH LŨY KHI KẾT QUẢ NHÂN HỢP LỆ (product_valid = 1)
            // Lưu ý: Phép cộng này xảy ra trong chu kỳ thứ 6 sau khi dữ liệu vào được nạp
            mac_r_reg <= mac_r_reg + {{ACC_WIDTH-N{product_r[N-1]}}, product_r};
            mac_i_reg <= mac_i_reg + {{ACC_WIDTH-N{product_i[N-1]}}, product_i};
            // Ký hiệu mở rộng (Sign Extension) được sử dụng để cộng product_r/i (N bit) với
            // mac_r_reg/i (ACC_WIDTH bit)
        end
    end
    
    // --- 5. Gán Đầu ra (Output Assignment) ---
    // Giới hạn (Trừncate) kết quả tích lũy 2*N bit về N bit đầu ra. 
    // Trong một thiết kế thực tế, cần dùng logic làm tròn/giới hạn (Rounding/Saturation)
    always @(posedge clk or posedge rst) begin
	if(rst) begin
		mac_r_out <= 0;
		mac_i_out <= 0;
	end else if(mac_rs_valid) begin
    		mac_r_out <=  mac_r_reg + {{ACC_WIDTH-N{product_r[N-1]}}, product_r}; 
		mac_i_out <=  mac_i_reg + {{ACC_WIDTH-N{product_i[N-1]}}, product_i};
	end
    end
  //  assign mac_i_out = (mac_rs_valid)? mac_i_reg[N-1:0]: 0;
   // assign product_valid_out = product_valid;
    assign mac_rs_valid = (product_valid && mac_counter == 3)? 1:0;
endmodule
