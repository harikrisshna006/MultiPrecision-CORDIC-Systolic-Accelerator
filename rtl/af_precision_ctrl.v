`timescale 1ns/1ps

module af_precision_ctrl (
    input clk,
    input reset,
    input wr_en,
    input [1:0] addr,
    input [1:0] wdata,
    output reg [1:0] precision_sel,
    output reg [1:0] sel_af
);
    always @(posedge clk) begin
        if (reset) begin 
            precision_sel <= 0;                  //FPx4 mode is selected
            sel_af <= 0;                         //currently sigmod gets activated
        end
        else if (wr_en) begin
            case (addr)
                2'd0: precision_sel <= wdata;               //stores which precision to use 
                2'd1: sel_af <= wdata;                      //which activation function to run (activation function:)
                default: ;
            endcase
        end
    end
endmodule


/* 
precision select:
    00:FxP4 
    01:FxP8
    10:FxP16
    11:FxP32

sel_af (select activation):
    00:Sigmoid = e^x/1+e^x​
    01:Tanh = sinh/cosh
    10:ReLU    =  max(0,x)
    11:SoftMax = e^xi / ∑ e^xj 
*/ 