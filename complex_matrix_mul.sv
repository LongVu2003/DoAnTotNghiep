// mat_cmult.v
// Matrix complex multiply H[4x4] x S[4x2] -> Sq[4x2]
// Uses provided cmult module (parameter Q,N)
// Inputs/outputs packed as flat vectors of N-bit signed scalars:
//   H_in_flat  : 32 * N bits  (H[i][j][k], i=0..3, j=0..3, k=0(real)/1(imag))
//   S_in_flat  : 16 * N bits  (S[i][j][k], i=0..3, j=0..1, k=0/1)
//   Sq_out_flat: 16 * N bits  (result same layout as S_in_flat)

module complex_matrix_mul #(
    parameter Q = 8,
    parameter N = 16,
    // assumed latency of cmult in cycles (adjust to match your cmult impl)
    parameter CM_LATENCY = 5,
    // accumulator width (bits) to hold sum of 4 products safely
    parameter ACCW = N + 3
)(
    input  wire                     clk,
    input  wire                     rst,
    input  wire                     start,
    input  wire signed [32*N-1:0]   H_in_flat,
    input  wire signed [16*N-1:0]   S_in_flat,
    output reg  signed [16*N-1:0]   Sq_out_flat,
    output reg                      done
);

    // ------------------------------------------------------------
    // Unpack H_in_flat -> H[i][j][k]  where i=0..3, j=0..3, k=0..1 (real/imag)
    // Unpack S_in_flat -> S[i][j][k]  where i=0..3, j=0..1, k=0..1
    // Represent them as wires of width N.
    // ------------------------------------------------------------
    wire signed [N-1:0] H_val [0:3][0:3][0:1];
    wire signed [N-1:0] S_val [0:3][0:1][0:1];

    genvar i, j, k;
    generate
        for (i = 0; i < 4; i = i + 1) begin : GEN_UNPACK_H_I
            for (j = 0; j < 4; j = j + 1) begin : GEN_UNPACK_H_J
                for (k = 0; k < 2; k = k + 1) begin : GEN_UNPACK_H_K
                    // mapping same as you provided: ((i*4 + j)*2 + k)*N +: N
                    assign H_val[i][j][k] = H_in_flat[((i*4 + j)*2 + k)*N +: N];
                end
            end
        end

        for (i = 0; i < 4; i = i + 1) begin : GEN_UNPACK_S_I
            for (j = 0; j < 2; j = j + 1) begin : GEN_UNPACK_S_J
                for (k = 0; k < 2; k = k + 1) begin : GEN_UNPACK_S_K
                    assign S_val[i][j][k] = S_in_flat[((i*2 + j)*2 + k)*N +: N];
                end
            end
        end
    endgenerate

    // ------------------------------------------------------------
    // Instantiate 32 cmult modules: for each i(0..3), k(0..3), j(0..1)
    // Multiply H[i][k] with S[k][j] -> produce partial products
    // Partial product wires: pr_w[i][k][j], pi_w[i][k][j]
    // ------------------------------------------------------------
    wire signed [N-1:0] pr_w [0:3][0:3][0:1];
    wire signed [N-1:0] pi_w [0:3][0:3][0:1];

    // For clocked cmult we feed clk/rst and inputs directly; outputs are wires (registered inside cmult).
    generate
        for (i = 0; i < 4; i = i + 1) begin : GEN_CMULT_I
            for (k = 0; k < 4; k = k + 1) begin : GEN_CMULT_K
                for (j = 0; j < 2; j = j + 1) begin : GEN_CMULT_J
                    // instance name reflect indices
                    cmult #(.Q(Q), .N(N)) cmult_u (
                        .clk(clk),
                        .rst(rst),
                        .ar(H_val[i][k][0]), // H real
                        .ai(H_val[i][k][1]), // H imag
                        .br(S_val[k][j][0]), // S real
                        .bi(S_val[k][j][1]), // S imag
                        .pr(pr_w[i][k][j]),
                        .pi(pi_w[i][k][j])
                    );
                end
            end
        end
    endgenerate

    // ------------------------------------------------------------
    // Accumulate partial products for each output element (i,j)
    // sum_pr = sum_k pr_w[i][k][j]
    // sum_pi = sum_k pi_w[i][k][j]
    // Use ACCW bits for accumulator.
    // ------------------------------------------------------------
    wire signed [ACCW-1:0] sum_pr_w [0:3][0:1];
    wire signed [ACCW-1:0] sum_pi_w [0:3][0:1];

    generate
        for (i = 0; i < 4; i = i + 1) begin : GEN_SUM_I
            for (j = 0; j < 2; j = j + 1) begin : GEN_SUM_J
                // extend each product to ACCW bits then add
                wire signed [ACCW-1:0] a0 = {{(ACCW-N){pr_w[i][0][j][N-1]}}, pr_w[i][0][j]};
                wire signed [ACCW-1:0] a1 = {{(ACCW-N){pr_w[i][1][j][N-1]}}, pr_w[i][1][j]};
                wire signed [ACCW-1:0] a2 = {{(ACCW-N){pr_w[i][2][j][N-1]}}, pr_w[i][2][j]};
                wire signed [ACCW-1:0] a3 = {{(ACCW-N){pr_w[i][3][j][N-1]}}, pr_w[i][3][j]};

                assign sum_pr_w[i][j] = a0 + a1 + a2 + a3;

                wire signed [ACCW-1:0] b0 = {{(ACCW-N){pi_w[i][0][j][N-1]}}, pi_w[i][0][j]};
                wire signed [ACCW-1:0] b1 = {{(ACCW-N){pi_w[i][1][j][N-1]}}, pi_w[i][1][j]};
                wire signed [ACCW-1:0] b2 = {{(ACCW-N){pi_w[i][2][j][N-1]}}, pi_w[i][2][j]};
                wire signed [ACCW-1:0] b3 = {{(ACCW-N){pi_w[i][3][j][N-1]}}, pi_w[i][3][j]};

                assign sum_pi_w[i][j] = b0 + b1 + b2 + b3;
            end
        end
    endgenerate

    // ------------------------------------------------------------
    // FSM to manage operation and provide done
    // States: IDLE -> WAIT_CM (wait cmult latency) -> PACK -> DONE
    // - On start: capture inputs implicitly via wires (H_val,S_val are combinational from flat inputs)
    // - Wait CM_LATENCY cycles to allow cmult outputs to settle (since cmult has clk)
    // - Pack sums into Sq_out_flat, assert done for one cycle
    // ------------------------------------------------------------
    localparam IDLE     = 3'd0;
    localparam WAIT_CM  = 3'd1;
    localparam PACK     = 3'd2;
    localparam DONE_ST  = 3'd3;

    reg [2:0] state;
    reg [$clog2(CM_LATENCY+1)-1:0] wait_cnt;

    // registers to hold final sums (registered to respect timing)
    reg signed [ACCW-1:0] sum_pr_reg [0:3][0:1];
    reg signed [ACCW-1:0] sum_pi_reg [0:3][0:1];

    integer ii, jj;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            wait_cnt <= 0;
            done <= 1'b0;
            Sq_out_flat <= {16*N{1'b0}};
            // clear regs
            for (ii = 0; ii < 4; ii = ii + 1)
                for (jj = 0; jj < 2; jj = jj + 1) begin
                    sum_pr_reg[ii][jj] <= {ACCW{1'b0}};
                    sum_pi_reg[ii][jj] <= {ACCW{1'b0}};
                end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    wait_cnt <= 0;
                    if (start) begin
                        // begin operation
                        state <= WAIT_CM;
                        wait_cnt <= 0;
                    end
                end
                WAIT_CM: begin
                    // wait for cmult modules to produce valid outputs
                    if (wait_cnt == CM_LATENCY - 1) begin
                        // capture sums into registers
                        for (ii = 0; ii < 4; ii = ii + 1) begin
                            for (jj = 0; jj < 2; jj = jj + 1) begin
                                sum_pr_reg[ii][jj] <= sum_pr_w[ii][jj];
                                sum_pi_reg[ii][jj] <= sum_pi_w[ii][jj];
                            end
                        end
                        state <= PACK;
                    end else begin
                        wait_cnt <= wait_cnt + 1'b1;
                    end
                end
                PACK: begin
                    // pack sum_pr_reg / sum_pi_reg (ACCW) into output flat (truncate to N bits)
                    // mapping: ((i*2 + j)*2 + k)*N +: N
                    // k==0 -> real, k==1 -> imag
                    for (ii = 0; ii < 4; ii = ii + 1) begin
                        for (jj = 0; jj < 2; jj = jj + 1) begin
                            // simple truncation: take lower N bits of accumulator
                            // You may want to implement rounding or saturation here.
                            Sq_out_flat[((ii*2 + jj)*2 + 0)*N +: N] <= sum_pr_reg[ii][jj][N-1:0];
                            Sq_out_flat[((ii*2 + jj)*2 + 1)*N +: N] <= sum_pi_reg[ii][jj][N-1:0];
                        end
                    end
                    state <= DONE_ST;
                end
                DONE_ST: begin
                    done <= 1'b1;
                    // one-cycle pulse, then back to IDLE
                    state <= IDLE;
                    done <= 1'b0; // will be seen for 0 cycles? make it visible one cycle:
                    // To ensure a one-cycle 'done', better to set done=1 here and clear in next cycle:
                    done <= 1'b1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule

