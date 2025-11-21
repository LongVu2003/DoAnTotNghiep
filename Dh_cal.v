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

    output signed [N-1:0] Dh_out,
    output reg Dh_result_valid
);

    // Các tín hiệu trung gian
    wire signed [N-1:0] product_r, product_i;
    wire ovr_multr, ovr_multi;
    wire signed [N:0] SoP; 

    reg [2:0] dh_count; 
    

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

    assign SoP = product_r + product_i;

    reg signed  [N:0] sop_d,sop_2d,sop_3d,sop_4d,sop_5d,sop_6d,sop_7d;

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            sop_d <= 0;
            sop_2d <= 0;
            sop_3d <= 0;
            sop_4d <= 0;
            sop_5d <= 0;
            sop_6d <= 0;
            sop_7d <= 0;
        end else if(Dh_en) begin
            sop_d <= SoP;
            sop_2d <= sop_d;
            sop_3d <= sop_2d;
            sop_4d <= sop_3d;
            sop_5d <= sop_4d;
            sop_6d <= sop_5d;
            sop_7d <= sop_6d;
        end
    end
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            dh_count <= 0;
        end else if (Dh_en) begin
            dh_count <= dh_count + 1;
        end
    end
    wire signed [N:0] Dh_out_tmp;
    assign Dh_out_tmp = SoP + sop_d + sop_2d + sop_3d + sop_4d + sop_5d + sop_6d + sop_7d;
    assign Dh_out =(dh_count == 3'd7)? Dh_out_tmp[N-1:0] :Dh_out ; 

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            Dh_result_valid <= 1'b0;
        end else begin
            if ((dh_count == 3'd6)&& Dh_en) begin
                Dh_result_valid <= 1'b1;
            end else begin
                Dh_result_valid <= 1'b0;
            end
        end
    end

endmodule
