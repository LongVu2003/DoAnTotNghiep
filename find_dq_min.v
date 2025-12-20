module find_dq_min #(
    parameter N = 32,
    parameter NUM_VALUES = 16
) (
    input wire                  clk,
    input wire                  rst,
    input wire signed [N-1:0]   dq_out,
    input wire                  in_valid,
    input wire signed [2:0]   in_m_dI1,
    input wire signed [2:0]   in_m_dI2,
    input wire signed [2:0]   in_m_dQ1,
    input wire signed [2:0]   in_m_dQ2,

    output reg signed [N-1:0]   out_dq_min,
    output reg                  out_min_valid,
    output reg                  busy,
    output reg signed [2:0]   out_min_m_dI1,
    output reg signed [2:0]   out_min_m_dI2,
    output reg signed [2:0]   out_min_m_dQ1,
    output reg signed [2:0]   out_min_m_dQ2,
    output reg [4:0]            out_q_min
);

    parameter COUNT_WIDTH = $clog2(NUM_VALUES);

    reg [COUNT_WIDTH-1:0]         count_reg;
    reg signed [N-1:0]            min_value_reg;
    reg signed [N-1:0]            min_m_dI1_reg;
    reg signed [N-1:0]            min_m_dI2_reg;
    reg signed [N-1:0]            min_m_dQ1_reg;
    reg signed [N-1:0]            min_m_dQ2_reg;
    reg [COUNT_WIDTH-1:0]         q_min_idx_reg;


    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count_reg     <= 0;
            min_value_reg <= 0;
            out_dq_min     <= 0;
            out_min_valid     <= 1'b0;
            busy          <= 1'b0;
            min_m_dI1_reg <= 0;
            min_m_dI2_reg <= 0;
            min_m_dQ1_reg <= 0;
            min_m_dQ2_reg <= 0;
            out_min_m_dI1     <= 0;
            out_min_m_dI2     <= 0;
            out_min_m_dQ1     <= 0;
            out_min_m_dQ2     <= 0;
            q_min_idx_reg <= 0;
            out_q_min         <= 0;
        end else begin
            out_min_valid <= 1'b0;

            if (in_valid) begin
                if (!busy) begin
                    busy          <= 1'b1;
                    min_value_reg <= dq_out;
                    count_reg     <= 1;
                    min_m_dI1_reg <= in_m_dI1;
                    min_m_dI2_reg <= in_m_dI2;
                    min_m_dQ1_reg <= in_m_dQ1;
                    min_m_dQ2_reg <= in_m_dQ2;
                    q_min_idx_reg <= 0;
                end
                else begin
                    if (dq_out < min_value_reg) begin
                        min_value_reg <= dq_out;
                        min_m_dI1_reg <= in_m_dI1;
                        min_m_dI2_reg <= in_m_dI2;
                        min_m_dQ1_reg <= in_m_dQ1;
                        min_m_dQ2_reg <= in_m_dQ2;
                        q_min_idx_reg <= count_reg;
                    end

                    if (count_reg == NUM_VALUES - 1) begin
                        busy      <= 1'b0;
                        out_min_valid <= 1'b1;
                        count_reg <= 0;
                        
                        if (dq_out < min_value_reg) begin
                            out_dq_min <= dq_out;
                            out_min_m_dI1 <= in_m_dI1;
                            out_min_m_dI2 <= in_m_dI2;
                            out_min_m_dQ1 <= in_m_dQ1;
                            out_min_m_dQ2 <= in_m_dQ2;
                            out_q_min     <= count_reg + 1;
                        end else begin
                            out_dq_min <= min_value_reg;
                            out_min_m_dI1 <= min_m_dI1_reg;
                            out_min_m_dI2 <= min_m_dI2_reg;
                            out_min_m_dQ1 <= min_m_dQ1_reg;
                            out_min_m_dQ2 <= min_m_dQ2_reg;
                            out_q_min     <= q_min_idx_reg + 1;
                        end

                    end else begin
                        count_reg <= count_reg + 1;
                    end
                end
            end
        end
    end

endmodule


