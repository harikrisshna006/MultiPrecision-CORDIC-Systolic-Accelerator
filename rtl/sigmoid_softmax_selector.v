`timescale 1ns/1ps

// af_mode=0: sigmoid divisor 1+exp; af_mode=1: SoftMax FIFO sum.
module sigmoid_softmax_selector #(
    parameter WIDTH=32,
    parameter FRAC=13,
    parameter FIFO_SUM_WIDTH=WIDTH+$clog2(9)
) (
    input  [WIDTH-1:0] exp_out,
    input  [FIFO_SUM_WIDTH-1:0] fifo_running_sum,
    input  af_mode,
    output reg [FIFO_SUM_WIDTH-1:0] divisor
);
    localparam [FIFO_SUM_WIDTH-1:0] ONE = (1 << FRAC);
    always @* begin
        if (af_mode) divisor = fifo_running_sum;
        else divisor = {{(FIFO_SUM_WIDTH-WIDTH){1'b0}},exp_out} + ONE;
    end
endmodule
