`timescale 1ns/1ps

// Verification status: no dedicated unit testbench exists; coverage is
// transitive only, via tb_simd_barrel_shifter_top.v testing
// simd_barrel_shifter_top.v (which instantiates this module as a sub-block).
// This is an accepted scope decision, not an oversight.
// Pure combinational stage. No clock port: shift_en selects a fixed 1,2,4,8,
// or 16-bit arithmetic right shift, depending on SHIFT_AMOUNT.
module barrel_shifter_stage #(parameter WIDTH=4, parameter SHIFT_AMOUNT=1) (
    input  [WIDTH-1:0] data_in,
    input              shift_en,
    output [WIDTH-1:0] data_out
);
    function [WIDTH-1:0] arithmetic_shift;
        input [WIDTH-1:0] value;
        reg [WIDTH-1:0] logical_value;
        begin
            if (SHIFT_AMOUNT >= WIDTH)
                arithmetic_shift = {WIDTH{value[WIDTH-1]}};
            else begin
                logical_value = value >> SHIFT_AMOUNT;
                if (value[WIDTH-1])
                    arithmetic_shift = logical_value | ({WIDTH{1'b1}} << (WIDTH-SHIFT_AMOUNT));
                else
                    arithmetic_shift = logical_value;
            end
        end
    endfunction
    assign data_out = shift_en ? arithmetic_shift(data_in) : data_in;
endmodule
