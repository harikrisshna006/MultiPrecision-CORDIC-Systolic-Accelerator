`timescale 1ns/1ps
// Verification status: no dedicated unit testbench exists; coverage is
// transitive only, via tb_simd_lane_mux.v testing simd_lane_mux.v (which
// instantiates these modules). Accepted scope decision.
module simd_add_sub_32b (
    input  [31:0] A, B,
    input         add_sub,
    output [31:0] result,
    output        overflow
);
    wire [32:0] sum = {1'b0,A} + {1'b0,B ^ {32{add_sub}}} + add_sub;
    assign result = sum[31:0];
    assign overflow = (!add_sub && (A[31] == B[31]) && (result[31] != A[31])) ||
                       ( add_sub && (A[31] != B[31]) && (result[31] != A[31]));
endmodule
