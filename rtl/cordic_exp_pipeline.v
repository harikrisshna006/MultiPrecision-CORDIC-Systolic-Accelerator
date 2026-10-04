`timescale 1ns/1ps
//Increasing the number of CORDIC iterations generally improves numerical accuracy
//for softmax only with e^Z harware

module cordic_exp_pipeline #(
    parameter WIDTH=32,
    parameter FRAC=13,
    parameter N_HV_STAGES=8,            //they made pipeline stages also dynamic
    parameter RANGE_EXT_BITS=3
) (
    input clk, reset, start,
    input signed [WIDTH-1:0] z_in,

    output signed [WIDTH-1:0] exp_out,        //exp_out = e^zin
    output busy, done, error_overflow
);

    wire signed [WIDTH-1:0] norm_z;

    wire signed [WIDTH-1:0] kh_value = (10000 * (1 <<< FRAC) + 4140) / 8281;          //REPRESENTS 0.8281 IN FIXED POINT
    wire signed [WIDTH-1:0] hr_x,hr_y,unused_z;

    input_normalizer #(WIDTH,FRAC) norm(z_in,2'b00,norm_z,error_overflow);                   //to make the inpt fall under the range of inputs
//                                                                                                          X_IN     Y_IN=0       Z_IN=THHIS MODULE INPUT
    cordic_stage_pipeline #(WIDTH,FRAC,N_HV_STAGES,RANGE_EXT_BITS) hr(clk,reset,start, 2'b00 /*HR mode*/ ,kh_value,{WIDTH{1'b0}},norm_z,  hr_x,hr_y,unused_z,  busy,done);
    
    assign exp_out=hr_x+hr_y;    //e^z = cosh(Z) + sinh(Z)
endmodule
