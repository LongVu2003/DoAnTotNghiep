module hex_to_7seg (
    input  wire [3:0] hex_digit, // 4-bit hex input (0-F)
    output reg  [6:0] seg_out    // 7-bit segment output (active-low)
);
    // Active-low (0 = sáng)
    // {g, f, e, d, c, b, a} (Chân 0 là 'a', 6 là 'g')
    always @(*) begin
        case (hex_digit)
            //              {g,f,e,d,c,b,a}
            4'h0:    seg_out = 7'b1000000; // 0
            4'h1:    seg_out = 7'b1111001; // 1
            4'h2:    seg_out = 7'b0100100; // 2
            4'h3:    seg_out = 7'b0110000; // 3
            4'h4:    seg_out = 7'b0011001; // 4
            4'h5:    seg_out = 7'b0010010; // 5
            4'h6:    seg_out = 7'b0000010; // 6
            4'h7:    seg_out = 7'b1111000; // 7
            4'h8:    seg_out = 7'b0000000; // 8
            4'h9:    seg_out = 7'b0010000; // 9
            4'hA:    seg_out = 7'b0001000; // A
            4'hB:    seg_out = 7'b0000011; // b
            4'hC:    seg_out = 7'b1000110; // C
            4'hD:    seg_out = 7'b0100001; // d
            4'hE:    seg_out = 7'b0000110; // E
            4'hF:    seg_out = 7'b0001110; // F
            default: seg_out = 7'b1111111; // blank
        endcase
    end
endmodule