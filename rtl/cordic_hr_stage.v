//non linear calculations

`timescale 1ns/1ps
module cordic_hr_stage #(parameter WIDTH=32, parameter FRAC=13) (
    input signed [WIDTH-1:0] x_in, y_in, z_in,
    input signed [7:0] iteration_i,                             //IT WILL BE ALWAYS +VE 
    output reg signed [WIDTH-1:0] x_next, y_next, z_next
);
    wire signed [WIDTH-1:0] angle;
    reg signed [WIDTH-1:0] xs, ys;
    reg signed [WIDTH-1:0] dx, dy;

    angle_lut_rom #(WIDTH,FRAC) lut(iteration_i,2'b00,angle);   //gets Atanh(2^-I) value as angle

    always @* begin
        xs = x_in >>> iteration_i;
        ys = y_in >>> iteration_i;      //y_in/2^-I

        if (z_in >= 0) begin                       //z tells +ve or -ve
            x_next = x_in + ys; 
            y_next = y_in + xs; 
            z_next = z_in - angle;

        end else begin
            x_next = x_in - ys; 
            y_next = y_in - xs; 
            z_next = z_in + angle;
        end
    end
endmodule


/*
x_next = x_in + y_in*2^-i
y_next = y_in + x_in*2^-i
z_next = z_in - angle;

@z->0
x≈cosh(z)
y≈sinh(z)
from this we can obtain e^z = sinh(z) + cosh(z)

*/