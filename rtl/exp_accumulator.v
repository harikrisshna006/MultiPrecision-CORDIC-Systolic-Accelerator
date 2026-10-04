`timescale 1ns/1ps

// Pure combinational exp reconstruction from hyperbolic CORDIC outputs.
module exp_accumulator #(parameter WIDTH=32) (
    input  signed [WIDTH-1:0] cosh_in,
    input  signed [WIDTH-1:0] sinh_in,
    output signed [WIDTH-1:0] exp_out
);
    assign exp_out = cosh_in + sinh_in;
endmodule
