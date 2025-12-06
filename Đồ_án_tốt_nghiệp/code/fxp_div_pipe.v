module fxp_div_pipe #(
    parameter WIIA = 8,
    parameter WIFA = 8,
    parameter WIIB = 8,
    parameter WIFB = 8,
    parameter WOI  = 8,
    parameter WOF  = 8,
    parameter ROUND= 1
)(
    input  wire                 rstn,
    input  wire                 clk,
    input  wire [WIIA+WIFA-1:0] dividend,
    input  wire [WIIB+WIFB-1:0] divisor,
    output reg  [WOI +WOF -1:0] out,
    output reg                  overflow
);

initial {out, overflow} = 0;

localparam WRI = WOI+WIIB > WIIA ? WOI+WIIB : WIIA;
localparam WRF = WOF+WIFB > WIFA ? WOF+WIFB : WIFA;

wire [WRI+WRF-1:0]  divd, divr;
reg  [WOI+WOF-1:0] roundedres = 0;
reg                rsign = 1'b0;
reg                 sign [WOI+WOF:0];
reg  [WRI+WRF-1:0]  acc  [WOI+WOF:0];
reg  [WRI+WRF-1:0] divdp [WOI+WOF:0];
reg  [WRI+WRF-1:0] divrp [WOI+WOF:0];
reg  [WOI+WOF-1:0]  res  [WOI+WOF:0];
localparam  [WOI+WOF-1:0] ONEO = 1;

integer ii;

// initialize all regs (khoi tao cac reg banwgf 0)
initial for(ii=0; ii<=WOI+WOF; ii=ii+1) begin
            res  [ii] = 0;
            divrp[ii] = 0;
            divdp[ii] = 0;
            acc  [ii] = 0;
            sign [ii] = 1'b0;
        end

wire [WIIA+WIFA-1:0] ONEA = 1;
wire [WIIB+WIFB-1:0] ONEB = 1;

// convert dividend and divisor to positive number (chuyen 2 gias trij veef gias trij duongw)
wire [WIIA+WIFA-1:0] udividend = dividend[WIIA+WIFA-1] ? (~dividend)+ONEA : dividend;
wire [WIIB+WIFB-1:0]  udivisor =  divisor[WIIB+WIFB-1] ? (~ divisor)+ONEB : divisor ;

fxp_zoom # (
    .WII      ( WIIA      ),
    .WIF      ( WIFA      ),
    .WOI      ( WRI       ),
    .WOF      ( WRF       ),
    .ROUND    ( 0         )
) dividend_zoom (
    .in       ( udividend ),
    .out      ( divd      ),
    .overflow (           )
);

fxp_zoom # (
    .WII      ( WIIB      ),
    .WIF      ( WIFB      ),
    .WOI      ( WRI       ),
    .WOF      ( WRF       ),
    .ROUND    ( 0         )
)  divisor_zoom (
    .in       ( udivisor  ),
    .out      ( divr      ),
    .overflow (           )
);

// 1st pipeline stage: convert dividend and divisor to positive number
always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        res[0]   <= 0;
        acc[0]   <= 0;
        divdp[0] <= 0;
        divrp[0] <= 0;
        sign [0] <= 1'b0;
    end else begin
        res[0]   <= 0;
        acc[0]   <= 0;
        divdp[0] <= divd;
        divrp[0] <= divr;
        sign [0] <= dividend[WIIA+WIFA-1] ^ divisor[WIIB+WIFB-1];
    end

reg [WRI+ WRF-1:0] tmp;

// from 2nd to WOI+WOF+1 pipeline stages: calculate division
always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        for(ii=0; ii<WOI+WOF; ii=ii+1) begin
            res  [ii+1] <= 0;
            divrp[ii+1] <= 0;
            divdp[ii+1] <= 0;
            acc  [ii+1] <= 0;
            sign [ii+1] <= 1'b0;
        end
    end else begin
        for(ii=0; ii<WOI+WOF; ii=ii+1) begin
            
            res  [ii+1] <= res[ii];
            divdp[ii+1] <= divdp[ii];
            divrp[ii+1] <= divrp[ii];
            sign [ii+1] <= sign [ii];
            if(ii<WOI)
                tmp = acc[ii] + (divrp[ii]<<(WOI-1-ii));
            else
                tmp = acc[ii] + (divrp[ii]>>(1+ii-WOI));
            if( tmp < divdp[ii] ) begin
                acc[ii+1] <= tmp;
                res[ii+1][WOF+WOI-1-ii] <= 1'b1;
            end else begin
                acc[ii+1] <= acc[ii];
                res[ii+1][WOF+WOI-1-ii] <= 1'b0;
            end
        end
    end

// next pipeline stage: process round
always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        roundedres <= 0;
        rsign      <= 1'b0;
    end else begin
        if( ROUND && ~(&res[WOI+WOF]) && (acc[WOI+WOF]+(divrp[WOI+WOF]>>(WOF))-divdp[WOI+WOF]) < (divdp[WOI+WOF]-acc[WOI+WOF]) )
            roundedres <= res[WOI+WOF] + ONEO;
        else
            roundedres <= res[WOI+WOF];
        rsign      <= sign[WOI+WOF];
    end

// the last pipeline stage: process roof and output
always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        overflow <= 1'b0;
        out <= 0;
    end else begin
        overflow <= 1'b0;
        if(rsign) begin
            if(roundedres[WOI+WOF-1]) begin
                if(|roundedres[WOI+WOF-2:0]) overflow <= 1'b1;
                out[WOI+WOF-1] <= 1'b1;
                out[WOI+WOF-2:0] <= 0;
            end else
                out <= (~roundedres) + ONEO;
        end else begin
            if(roundedres[WOI+WOF-1]) begin
                overflow <= 1'b1;
                out[WOI+WOF-1] <= 1'b0;
                out[WOI+WOF-2:0] <= {(WOI+WOF){1'b1}};
            end else
                out <= roundedres;
        end
    end

endmodule 
