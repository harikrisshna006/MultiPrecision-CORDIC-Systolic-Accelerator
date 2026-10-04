`timescale 1ns/1ps

// Five-stage logarithmic arithmetic right shifter.
// Each selected lane is shifted independently; stage shifts are 1, 2, 4, 8, 16.
module simd_barrel_shifter (
    input  [31:0] A,
    input  [4:0]  shift_amt,
    input  [1:0]  precision_sel,
    output reg [31:0] result
);
    integer lane_width, lane_count;
    integer lane, stage_num, base;
    reg signed [31:0] stages [0:5];
    reg signed [31:0] lane_value;

    function [31:0] shift_one_lane;
        input [31:0] value;
        input integer lane_base;
        input integer width;
        input integer amount;
        reg [31:0] mask;
        reg [31:0] extracted;
        reg signed [31:0] signed_value;
        reg signed [31:0] shifted_value;
        begin
            mask = (32'hFFFFFFFF >> (32 - width));
            extracted = (value >> lane_base) & mask;
            if (extracted[width-1])
                signed_value = extracted | ~mask;
            else
                signed_value = extracted;
            shifted_value = signed_value >>> amount;
            shift_one_lane = (value & ~(mask << lane_base)) |
                             ((shifted_value & mask) << lane_base);
        end
    endfunction

    always @* begin
        case (precision_sel)
            2'b00: begin lane_width = 4;  lane_count = 8; end
            2'b01: begin lane_width = 8;  lane_count = 4; end
            2'b10: begin lane_width = 16; lane_count = 2; end
            default: begin lane_width = 32; lane_count = 1; end
        endcase

        stages[0] = A;
        for (stage_num = 0; stage_num < 5; stage_num = stage_num + 1) begin
            stages[stage_num + 1] = stages[stage_num];
            if (shift_amt[stage_num]) begin
                for (lane = 0; lane < lane_count; lane = lane + 1) begin
                    base = lane * lane_width;
                    stages[stage_num + 1] = shift_one_lane(
                        stages[stage_num + 1], base, lane_width, (1 << stage_num));
                end
            end
        end
        result = stages[5];
    end
endmodule
