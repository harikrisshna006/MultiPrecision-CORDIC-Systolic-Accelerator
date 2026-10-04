//FOR DIVISION  

`timescale 1ns/1ps
module cordic_lv_stage #(parameter WIDTH=32, parameter FRAC=13) (
    input signed [WIDTH-1:0] x_in, y_in, z_in,                                  //all in fixed point form = real value*2^frac.
    input signed [7:0] iteration_i,
    output reg signed [WIDTH-1:0] x_next, y_next, z_next                        //all in fixed point form = real value*2^frac.
);


    wire signed [WIDTH-1:0] angle;
    reg signed [WIDTH-1:0] xterm;

    angle_lut_rom #(WIDTH,FRAC) lut(iteration_i,2'b01,angle);                //THE ANGLE IS 2^-I IN FIXED  POINT FORM IE; 2^13 * 2^-I

    always @* begin
        xterm = x_in >>> iteration_i;                                       
//irrespective of anything u need to do div by assuming itt_i is always +ve..so only right shift but in "lr" u need to mul so if itt_i is +ve u do right shift and if itt_i is -ve do left shift 

        x_next = x_in;                                                       //IN LINEAR MODE x_in IS UNCHANGED
        
        if (y_in >= 0) begin 

            y_next = y_in - xterm; 
            z_next = z_in + angle; 
        
        end else begin 
        
            y_next = y_in + xterm; 
            z_next = z_in - angle; 
        
        end
    end

endmodule

/*   x/y    x-> dividend and y-> divisor 
repeated subtract shifted versions of the divisor until the remainder approaches zero.
*/
