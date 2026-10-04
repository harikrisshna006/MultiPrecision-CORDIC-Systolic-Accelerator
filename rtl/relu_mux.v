`timescale 1ns/1ps
//it give max of 0,x
module relu_mux #(parameter WIDTH=32) (
    input  signed [WIDTH-1:0] x_in,
    output signed [WIDTH-1:0] x_out
);

    assign x_out = x_in[WIDTH-1]/*sign bit*/ ? {WIDTH{1'b0}} : x_in;

endmodule

/*
if sign bit is -ve -> x_out = 0 
if sign bit is +ve -> x_out = x_in 
*/