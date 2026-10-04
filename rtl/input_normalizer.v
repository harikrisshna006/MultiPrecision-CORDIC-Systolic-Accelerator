`timescale 1ns/1ps

// Saturating fixed-point input clamp. mode: 00 HR, 01 LV, 10 LR.

module input_normalizer #(parameter WIDTH=32, parameter FRAC=13) (
    input  signed [WIDTH-1:0] data_in,                      //to make zin to come under the range
    input  [1:0] mode,                                          //IT NORMALISE THE INPUT ACCORDING TO THE MODE
    output reg signed [WIDTH-1:0] data_out,             //i acc to each mode
    output reg overflow                            //0-> if inside the allowed range , 1-> if it is cliped to be inside the allowed range
);
    integer value_i, limit_i, max_i, min_i;

    always @* begin

        value_i = data_in;
        max_i = (1 << (WIDTH-1)) - 1;           //this is the max hadware signed +ve int
        min_i = -(1 << (WIDTH-1));              //this is the max hadware signed -ve int

        case (mode)
            2'b00: limit_i = (9160 >>> (13-FRAC));          // trunc(1.1182 * 8192)    ie; x<1.1182
            2'b01: limit_i = (8192 >>> (13-FRAC));          // 1.0        ie; x<1 (dividend)
            default: limit_i = (65273 >>> (13-FRAC));     // trunc(7.968 * 8192)    ie;-7.968 ≤ input ≤ +7.968    7 came due to we start i from -2 
        endcase

        if (limit_i > max_i) limit_i = max_i;                 //this is limited by hardware

        if (value_i > limit_i) begin 
            data_out = limit_i; 
            overflow = 1; 
        end
        else if (value_i < -limit_i) begin 
            data_out = -limit_i; 
            overflow = 1; 
        end
        else begin 
            data_out = data_in; 
            overflow = 0; 
        end

        if (data_in < min_i) begin                  //this is limited by hardware
            data_out=min_i; 
            overflow=1; 
        end
    end
endmodule
