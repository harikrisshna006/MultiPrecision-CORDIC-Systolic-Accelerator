`timescale 1ns/1ps

// Lane-wise signed two's-complement add/subtract.
// precision_sel: 00 = 8 lanes x 4 bits, 01 = 4 x 8, 10 = 2 x 16, 11 = 1 x 32.
// overflow[n] is signed arithmetic overflow for lane n; unused bits are zero.
module simd_add_sub (
    input  [31:0] A,
    input  [31:0] B,
    input  [1:0]  precision_sel,
    input         add_sub,       // 0: add, 1: subtract
    output reg [31:0] result,
    output reg [7:0]  overflow
);
    integer lane_width, lane_count;
    integer lane, bit_idx, base;
    reg carry;
    reg a_bit, b_bit, sum_bit;
    reg a_sign, b_sign, r_sign;

    always @* begin
        case (precision_sel)
            2'b00: begin lane_width = 4;  lane_count = 8; end
            2'b01: begin lane_width = 8;  lane_count = 4; end
            2'b10: begin lane_width = 16; lane_count = 2; end
            default: begin lane_width = 32; lane_count = 1; end
        endcase

        result   = 32'b0;
        overflow = 8'b0;

        for (lane = 0; lane < lane_count; lane = lane + 1) begin
            base  = lane * lane_width;
            carry = add_sub;

            // Ripple through this lane only. The carry is deliberately
            // reinitialized above, so adjacent packed lanes cannot interact.
            for (bit_idx = 0; bit_idx < lane_width; bit_idx = bit_idx + 1) begin
                a_bit   = A[base + bit_idx];
                b_bit   = B[base + bit_idx] ^ add_sub;
                sum_bit = a_bit ^ b_bit ^ carry;
                result[base + bit_idx] = sum_bit;
                carry = (a_bit & b_bit) | (a_bit & carry) | (b_bit & carry);
            end

            a_sign = A[base + lane_width - 1];
            b_sign = B[base + lane_width - 1];
            r_sign = result[base + lane_width - 1];
            if (!add_sub)
                overflow[lane] = (a_sign == b_sign) && (r_sign != a_sign);
            else
                overflow[lane] = (a_sign != b_sign) && (r_sign != a_sign);
        end
    end
endmodule
