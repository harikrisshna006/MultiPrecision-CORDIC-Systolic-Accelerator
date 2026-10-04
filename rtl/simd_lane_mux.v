`timescale 1ns/1ps

// Runtime precision mux around single-lane arithmetic primitives.
module simd_lane_mux (
    input  [31:0] A, B,
    input         add_sub,
    input  [1:0]  precision_sel,
    output reg [31:0] result,
    output reg [7:0]  overflow
);
    wire [3:0]  r4 [0:7];  wire o4 [0:7];
    wire [7:0]  r8 [0:3];  wire o8 [0:3];
    wire [15:0] r16[0:1];  wire o16[0:1];
    wire [31:0] r32;       wire o32;
    genvar g;
    generate
        for (g=0; g<8; g=g+1) begin: G4
            simd_add_sub_4b u(A[g*4 +: 4], B[g*4 +: 4], add_sub, r4[g], o4[g]);
        end
        for (g=0; g<4; g=g+1) begin: G8
            simd_add_sub_8b u(A[g*8 +: 8], B[g*8 +: 8], add_sub, r8[g], o8[g]);
        end
        for (g=0; g<2; g=g+1) begin: G16
            simd_add_sub_16b u(A[g*16 +: 16], B[g*16 +: 16], add_sub, r16[g], o16[g]);
        end
    endgenerate
    simd_add_sub_32b u32(A, B, add_sub, r32, o32);

    integer i;
    always @* begin
        result = 0; overflow = 0;
        case (precision_sel)
            2'b00: for (i=0; i<8; i=i+1) begin result[i*4 +: 4]=r4[i]; overflow[i]=o4[i]; end
            2'b01: for (i=0; i<4; i=i+1) begin result[i*8 +: 8]=r8[i]; overflow[i]=o8[i]; end
            2'b10: for (i=0; i<2; i=i+1) begin result[i*16 +: 16]=r16[i]; overflow[i]=o16[i]; end
            default: begin result=r32; overflow[0]=o32; end
        endcase
    end
endmodule
