`timescale 1ns/1ps
// Verification status: no dedicated unit testbench exists; coverage is
// transitive only, via tb_simd_lane_mux.v testing simd_lane_mux.v (which
// instantiates these modules). Accepted scope decision.
module simd_add_sub_4b (
    input  [3:0] A, B,
    input        add_sub,
    output [3:0] result,
    output       overflow
);
    wire [4:0] sum = {1'b0,A} + {1'b0,B ^ {4{add_sub}}} + add_sub;
    assign result = sum[3:0];
    assign overflow = (!add_sub && (A[3] == B[3]) && (result[3] != A[3])) ||
                       ( add_sub && (A[3] != B[3]) && (result[3] != A[3]));
endmodule
