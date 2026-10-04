`timescale 1ns/1ps
// Verification status: no dedicated unit testbench exists; coverage is
// transitive only, via tb_simd_lane_mux.v testing simd_lane_mux.v (which
// instantiates these modules). Accepted scope decision.
module simd_add_sub_16b (
    input  [15:0] A, B,
    input         add_sub,
    output [15:0] result,
    output        overflow
);
    wire [16:0] sum = {1'b0,A} + {1'b0,B ^ {16{add_sub}}} + add_sub;
    assign result = sum[15:0];
    assign overflow = (!add_sub && (A[15] == B[15]) && (result[15] != A[15])) ||
                       ( add_sub && (A[15] != B[15]) && (result[15] != A[15]));
endmodule
