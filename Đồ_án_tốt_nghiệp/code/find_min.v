module find_min #(
    parameter N = 32,
    parameter NUM_VALUES = 16
) (
    input wire                  clk,
    input wire                  rst_n,
    input wire signed [N-1:0]   dq_out,
    input wire                  in_valid,
    input wire signed [N-1:0]   m_dI1,
    input wire signed [N-1:0]   m_dI2,
    input wire signed [N-1:0]   m_dQ1,
    input wire signed [N-1:0]   m_dQ2,

    output reg signed [N-1:0]   min_value,
    output reg                  min_valid,
    output reg                  busy,
    output reg signed [N-1:0]   min_m_dI1,
    output reg signed [N-1:0]   min_m_dI2,
    output reg signed [N-1:0]   min_m_dQ1,
    output reg signed [N-1:0]   min_m_dQ2,
    output reg [4:0]            q_min
);

    parameter COUNT_WIDTH = $clog2(NUM_VALUES);

    reg [COUNT_WIDTH-1:0]         count_reg;
    reg signed [N-1:0]            min_value_reg;
    reg signed [N-1:0]            min_m_dI1_reg;
    reg signed [N-1:0]            min_m_dI2_reg;
    reg signed [N-1:0]            min_m_dQ1_reg;
    reg signed [N-1:0]            min_m_dQ2_reg;
    reg [COUNT_WIDTH-1:0]         q_min_idx_reg;


    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count_reg     <= 0;
            min_value_reg <= 0;
            min_value     <= 0;
            min_valid     <= 1'b0;
            busy          <= 1'b0;
            min_m_dI1_reg <= 0;
            min_m_dI2_reg <= 0;
            min_m_dQ1_reg <= 0;
            min_m_dQ2_reg <= 0;
            min_m_dI1     <= 0;
            min_m_dI2     <= 0;
            min_m_dQ1     <= 0;
            min_m_dQ2     <= 0;
            q_min_idx_reg <= 0;
            q_min         <= 0;
        end else begin
            min_valid <= 1'b0;

            if (in_valid) begin
                if (!busy) begin
                    busy          <= 1'b1;
                    min_value_reg <= dq_out;
                    count_reg     <= 1;
                    min_m_dI1_reg <= m_dI1;
                    min_m_dI2_reg <= m_dI2;
                    min_m_dQ1_reg <= m_dQ1;
                    min_m_dQ2_reg <= m_dQ2;
                    q_min_idx_reg <= 0;
                end
                else begin
                    if (dq_out < min_value_reg) begin
                        min_value_reg <= dq_out;
                        min_m_dI1_reg <= m_dI1;
                        min_m_dI2_reg <= m_dI2;
                        min_m_dQ1_reg <= m_dQ1;
                        min_m_dQ2_reg <= m_dQ2;
                        q_min_idx_reg <= count_reg;
                    end

                    if (count_reg == NUM_VALUES - 1) begin
                        busy      <= 1'b0;
                        min_valid <= 1'b1;
                        count_reg <= 0;
                        
                        if (dq_out < min_value_reg) begin
                            min_value <= dq_out;
                            min_m_dI1 <= m_dI1;
                            min_m_dI2 <= m_dI2;
                            min_m_dQ1 <= m_dQ1;
                            min_m_dQ2 <= m_dQ2;
                            q_min     <= count_reg + 1;
                        end else begin
                            min_value <= min_value_reg;
                            min_m_dI1 <= min_m_dI1_reg;
                            min_m_dI2 <= min_m_dI2_reg;
                            min_m_dQ1 <= min_m_dQ1_reg;
                            min_m_dQ2 <= min_m_dQ2_reg;
                            q_min     <= q_min_idx_reg + 1;
                        end

                    end else begin
                        count_reg <= count_reg + 1;
                    end
                end
            end
        end
    end

endmodule


