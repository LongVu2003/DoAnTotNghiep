/*
* Module: Dh_cal (Corrected Version 2)
* Chức năng: Tự động tích lũy 8 giá trị |Hq|^2 và tự clear.
* - Xử lý Dh_en là xung đơn.
* - Dh_clear là tín hiệu nội bộ, tự động.
* - Tích lũy ngay lập tức vì qmult là tổ hợp.
*/

module Dh_cal #(
    parameter Q = 8,
    parameter N = 16
)
(
    input clk,
    input rst,
    // Dh_clear đã được loại bỏ, module sẽ tự động clear
    input Dh_en, // Tín hiệu xung đơn báo hiệu dữ liệu (in_real, in_im) hợp lệ
    input signed [N-1:0] in_real,
    input signed [N-1:0] in_im,

    output reg signed [N-1:0] Dh_out,
    output reg Dh_result_valid
);
    // Độ rộng thanh ghi tích lũy đủ lớn để tránh tràn số
    localparam ACC_WIDTH = 2*N + 3; // 32 + log2(8) = 35 bits

    // Các tín hiệu trung gian
    wire signed [N-1:0] product_r, product_i;
    wire ovr_multr, ovr_multi;
    wire signed [N:0] SoP; // Sum of Products (|Hq|^2 cho một phần tử)

    reg [2:0] dh_count; // Đếm từ 0 đến 7
    reg signed [ACC_WIDTH-1:0] dh_reg;
    
    // Tín hiệu nội bộ để tự động clear
    wire internal_clear;

    // --- Khối nhân tổ hợp ---
    qmult #(.Q(Q), .N(N)) qmult_real (
        .i_multiplicand(in_real),
        .i_multiplier(in_real),
        .o_result(product_r),
        .ovr(ovr_multr)
    );

    qmult #(.Q(Q), .N(N)) qmult_im (
        .i_multiplicand(in_im),
        .i_multiplier(in_im),
        .o_result(product_i),
        .ovr(ovr_multi)
    );

    // Tính |Hq|^2 = real^2 + imag^2
    assign SoP = product_r + product_i;
    
    // --- Logic Tích Lũy và Đếm ---
    // Tự động clear khi reset hoặc khi tính xong kết quả
    assign internal_clear = Dh_result_valid;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            dh_reg <= 0;
            dh_count <= 0;
        end else if (internal_clear) begin
            dh_reg <= 0;
            dh_count <= 0;
        end else if (Dh_en) begin
            // Tích lũy ngay khi có Dh_en, vì SoP là tổ hợp
            dh_reg <= dh_reg + {{ACC_WIDTH-N-1{SoP[N]}}, SoP};
            dh_count <= dh_count + 1;
        end
    end

    // --- Logic Xuất Kết Quả ---
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            Dh_result_valid <= 1'b0;
            Dh_out <= 0;
        end else begin
            // Báo valid khi nhận đủ 8 giá trị (đếm từ 0 đến 7)
            if ((dh_count == 3'd7)) begin
                Dh_result_valid <= 1'b1;
                // Kết quả cuối cùng là giá trị tích lũy hiện tại CỘNG với giá trị SoP cuối cùng
                Dh_out <= (dh_reg + {{ACC_WIDTH-N-1{SoP[N]}}, SoP});
            end else begin
                Dh_result_valid <= 1'b0;
            end
        end
    end

endmodule
