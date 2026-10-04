`timescale 1ns/1ps

// SIMD-wide pipelined SoftMax for the paper baseline.  All lanes first
// calculate exp(x) with hyperbolic CORDIC, then share one denominator and
// divide concurrently using the linear-vectoring CORDIC.  The sum and every
// numerator are shifted by log2(lane_count) before division so the active
// fixed-point lane width does not overflow; the quotient is unchanged.
module flex_pe_simd64_softmax (
    input clk, reset, start,
    input [1:0] precision_sel,
    input [63:0] x_in,
    output [63:0] result,
    output reg done, busy, error_overflow,
    output reg [7:0] iteration_count
);
    localparam IDLE=0, EXP_WAIT=1, DIV_WAIT=2;
    reg [1:0] state;
    reg exp_start,div_start;
    wire [63:0] exp8,exp16,exp32,div8,div16,div32;
    wire [7:0] exp_done8,exp_busy8,exp_err8,div_done8,div_busy8;
    wire [3:0] exp_done16,exp_busy16,exp_err16,div_done16,div_busy16;
    wire exp_done32,exp_busy32,exp_err32,div_done32,div_busy32;
    reg signed [10:0] sum8;
    reg signed [17:0] sum16;
    wire signed [7:0] denom8 = sum8 >>> 3;
    wire signed [15:0] denom16 = sum16 >>> 2;
    integer k;
    genvar lane;

    always @* begin
        sum8=0;
        for(k=0;k<8;k=k+1) sum8=sum8+$signed(exp8[k*8 +: 8]);
        sum16=0;
        for(k=0;k<4;k=k+1) sum16=sum16+$signed(exp16[k*16 +: 16]);
    end

    generate
        for(lane=0;lane<8;lane=lane+1) begin: FXP8
            wire signed [7:0] ex;
            wire signed [7:0] dz,unused_x,unused_y;
            cordic_exp_pipeline #(.WIDTH(8),.FRAC(3),.N_HV_STAGES(4)) exp_lane(
                clk,reset,exp_start&&(precision_sel==2'b01),x_in[lane*8 +: 8],
                ex,exp_busy8[lane],exp_done8[lane],exp_err8[lane]);
            cordic_stage_pipeline #(.WIDTH(8),.FRAC(3),.N_STAGES(5)) div_lane(
                clk,reset,div_start&&(precision_sel==2'b01),2'b01,
                denom8,ex >>> 3,{8{1'b0}},unused_x,unused_y,dz,div_busy8[lane],div_done8[lane]);
            assign exp8[lane*8 +: 8]=ex;
            assign div8[lane*8 +: 8]=dz;
        end
        for(lane=0;lane<4;lane=lane+1) begin: FXP16
            wire signed [15:0] ex;
            wire signed [15:0] dz,unused_x,unused_y;
            cordic_exp_pipeline #(.WIDTH(16),.FRAC(7),.N_HV_STAGES(4)) exp_lane(
                clk,reset,exp_start&&(precision_sel==2'b10),x_in[lane*16 +: 16],
                ex,exp_busy16[lane],exp_done16[lane],exp_err16[lane]);
            cordic_stage_pipeline #(.WIDTH(16),.FRAC(7),.N_STAGES(5)) div_lane(
                clk,reset,div_start&&(precision_sel==2'b10),2'b01,
                denom16,ex >>> 2,{16{1'b0}},unused_x,unused_y,dz,div_busy16[lane],div_done16[lane]);
            assign exp16[lane*16 +: 16]=ex;
            assign div16[lane*16 +: 16]=dz;
        end
    endgenerate

    wire signed [31:0] ex32;
    wire signed [31:0] dz32,unused_x32,unused_y32;
    cordic_exp_pipeline #(.WIDTH(32),.FRAC(13),.N_HV_STAGES(8)) FXP32_EXP(
        clk,reset,exp_start&&(precision_sel==2'b11),x_in[31:0],
        ex32,exp_busy32,exp_done32,exp_err32);
    cordic_stage_pipeline #(.WIDTH(32),.FRAC(13),.N_STAGES(9)) FXP32_DIV(
        clk,reset,div_start&&(precision_sel==2'b11),2'b01,
        ex32,ex32,{32{1'b0}},unused_x32,unused_y32,dz32,div_busy32,div_done32);
    assign exp32[31:0]=ex32;
    assign exp32[63:32]=32'b0;
    assign div32[31:0]=dz32;
    assign div32[63:32]=32'b0;

    assign result=(precision_sel==2'b01) ? div8 :
                  (precision_sel==2'b10) ? div16 : div32;
    assign busy=(precision_sel==2'b01) ? (|exp_busy8 || |div_busy8) :
                (precision_sel==2'b10) ? (|exp_busy16 || |div_busy16) :
                (precision_sel==2'b11) ? (exp_busy32 || div_busy32) : 1'b0;

    always @(posedge clk) begin
        if(reset) begin
            state<=IDLE; exp_start<=0; div_start<=0; done<=0;
            error_overflow<=0; iteration_count<=0;
        end else begin
            done<=0; exp_start<=0; div_start<=0;
            case(state)
                IDLE: if(start) begin
                    if(precision_sel==2'b00) begin
                        done<=1; error_overflow<=1; iteration_count<=0;
                    end else begin
                        exp_start<=1; error_overflow<=0; state<=EXP_WAIT;
                    end
                end
                EXP_WAIT: if((precision_sel==2'b01 && (&exp_done8)) ||
                             (precision_sel==2'b10 && (&exp_done16)) ||
                             (precision_sel==2'b11 && exp_done32)) begin
                    div_start<=1; state<=DIV_WAIT;
                end
                DIV_WAIT: if((precision_sel==2'b01 && (&div_done8)) ||
                             (precision_sel==2'b10 && (&div_done16)) ||
                             (precision_sel==2'b11 && div_done32)) begin
                    done<=1; iteration_count<=(precision_sel==2'b11) ? 17 : 9;
                    error_overflow<=(precision_sel==2'b01) ? (|exp_err8) :
                                    (precision_sel==2'b10) ? (|exp_err16) : exp_err32;
                    state<=IDLE;
                end
                default: state<=IDLE;
            endcase
        end
    end
endmodule
