module reset_synchronizer (
    input wire clk,
    input wire rst_n_async, 
    output reg rst_n_sync   
);
    reg rst_n_meta;
    always @(posedge clk or negedge rst_n_async) begin
        if (!rst_n_async) begin
            rst_n_meta <= 1'b0;
            rst_n_sync <= 1'b0;
        end else begin
            rst_n_meta <= 1'b1;
            rst_n_sync <= rst_n_meta;
        end
    end
endmodule