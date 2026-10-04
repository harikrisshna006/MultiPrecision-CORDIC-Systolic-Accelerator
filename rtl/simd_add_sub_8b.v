`timescale 1ns/1ps
// Verification status: no dedicated unit testbench exists; coverage is
// transitive only, via tb_simd_lane_mux.v testing simd_lane_mux.v (which
// instantiates these modules). Accepted scope decision.
module simd_add_sub_8b (
    input  [7:0] A, B,
    input        add_sub,
    output [7:0] result,
    output       overflow
);
    wire [8:0] sum = {1'b0,A} + {1'b0,B ^ {8{add_sub}}} + add_sub;
    assign result = sum[7:0];
    assign overflow = (!add_sub && (A[7] == B[7]) && (result[7] != A[7])) ||
                       ( add_sub && (A[7] != B[7]) && (result[7] != A[7]));
endmodule
