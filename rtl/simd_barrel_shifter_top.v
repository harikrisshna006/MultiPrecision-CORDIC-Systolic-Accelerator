`timescale 1ns/1ps

module simd_barrel_shifter_top (
    input  [31:0] data_in,
    input  [4:0]  shift_amt,
    input  [1:0]  precision_sel,
    output reg [31:0] data_out
);
    wire [31:0] out4, out8, out16, out32;
    genvar g;
    generate
        for (g=0; g<8; g=g+1) begin: S4
            wire [3:0] s1,s2,s3,s4,s5;
            barrel_shifter_stage #(4,1)  a(data_in[g*4 +: 4], shift_amt[0], s1);
            barrel_shifter_stage #(4,2)  b(s1, shift_amt[1], s2);
            barrel_shifter_stage #(4,4)  c(s2, shift_amt[2], s3);
            barrel_shifter_stage #(4,8)  d(s3, shift_amt[3], s4);
            barrel_shifter_stage #(4,16) e(s4, shift_amt[4], s5);
            assign out4[g*4 +: 4] = s5;
        end
        for (g=0; g<4; g=g+1) begin: S8
            wire [7:0] s1,s2,s3,s4,s5;
            barrel_shifter_stage #(8,1)  a(data_in[g*8 +: 8], shift_amt[0], s1);
            barrel_shifter_stage #(8,2)  b(s1, shift_amt[1], s2);
            barrel_shifter_stage #(8,4)  c(s2, shift_amt[2], s3);
            barrel_shifter_stage #(8,8)  d(s3, shift_amt[3], s4);
            barrel_shifter_stage #(8,16) e(s4, shift_amt[4], s5);
            assign out8[g*8 +: 8] = s5;
        end
        for (g=0; g<2; g=g+1) begin: S16
            wire [15:0] s1,s2,s3,s4,s5;
            barrel_shifter_stage #(16,1) a(data_in[g*16 +: 16], shift_amt[0], s1);
            barrel_shifter_stage #(16,2) b(s1, shift_amt[1], s2);
            barrel_shifter_stage #(16,4) c(s2, shift_amt[2], s3);
            barrel_shifter_stage #(16,8) d(s3, shift_amt[3], s4);
            barrel_shifter_stage #(16,16)e(s4, shift_amt[4], s5);
            assign out16[g*16 +: 16] = s5;
        end
    endgenerate
    barrel_shifter_stage #(32,1)  f0(data_in, shift_amt[0], out32);
    // Full-width stages are expressed separately below to retain the same
    // five-stage logarithmic structure.
    wire [31:0] f1,f2,f3,f4;
    barrel_shifter_stage #(32,2)  f_1(out32, shift_amt[1], f1);
    barrel_shifter_stage #(32,4)  f_2(f1, shift_amt[2], f2);
    barrel_shifter_stage #(32,8)  f_3(f2, shift_amt[3], f3);
    barrel_shifter_stage #(32,16) f_4(f3, shift_amt[4], f4);
    always @* case (precision_sel)
        2'b00: data_out=out4;
        2'b01: data_out=out8;
        2'b10: data_out=out16;
        default: data_out=f4;
    endcase
endmodule
