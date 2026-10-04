`timescale 1ns/1ps

// Paper-faithful SIMD wrapper around the existing CORDIC Flex-PE lane.
// A 64-bit packed word provides 16 FxP4, 8 FxP8, 4 FxP16, or 1 FxP32
// operations.  The active precision is configured at run time through the
// same two-register host interface used by the scalar implementation.
//
// Packed lane order is little-endian: lane 0 is in the least-significant
// bits.  Every active lane receives the same instruction (SIMD), but has
// independent x/y/z operands and result state.
module flex_pe_simd64_iterative (
    input clk, reset, start,
    input host_wr_en,
    input [1:0] host_addr, host_wdata,
    input [1:0] mode, ctrl_op,
    input [63:0] x_in, y_in, z_in,
    output [63:0] result,
    output done, busy, error_overflow,
    output [7:0] iteration_count,
    output [1:0] precision_sel, sel_af
);
    af_precision_ctrl cfg(
        clk,reset,host_wr_en,host_addr,host_wdata,precision_sel,sel_af);

    wire [63:0] r4,r8,r16,r32;
    wire [15:0] d4,b4,e4;
    wire [7:0] d8,b8,e8;
    wire [3:0] d16,b16,e16;
    wire d32,b32,e32;
    wire [7:0] i4 [0:15];
    wire [7:0] i8 [0:7];
    wire [7:0] i16[0:3];
    wire [7:0] i32;
    genvar lane;

    generate
        for (lane=0; lane<16; lane=lane+1) begin: FXP4
            wire [31:0] lane_result;
            wire lane_done,lane_busy,lane_error;
            wire [1:0] unused_precision,unused_af;
            flex_pe_iterative_top u(
                .clk(clk),.reset(reset),.start(start&&(precision_sel==2'b00)),
                .host_wr_en(host_wr_en),.host_addr(host_addr),.host_wdata(host_wdata),
                .mode(mode),.ctrl_op(ctrl_op),
                .x_in({{28{x_in[lane*4+3]}},x_in[lane*4 +: 4]}),
                .y_in({{28{y_in[lane*4+3]}},y_in[lane*4 +: 4]}),
                .z_in({{28{z_in[lane*4+3]}},z_in[lane*4 +: 4]}),
                .result(lane_result),.done(lane_done),.busy(lane_busy),
                .error_overflow(lane_error),.iteration_count(i4[lane]),
                .precision_sel(unused_precision),.sel_af(unused_af));
            assign r4[lane*4 +: 4] = lane_result[3:0];
            assign d4[lane] = lane_done;
            assign b4[lane] = lane_busy;
            assign e4[lane] = lane_error;
        end
        for (lane=0; lane<8; lane=lane+1) begin: FXP8
            wire [31:0] lane_result;
            wire lane_done,lane_busy,lane_error;
            wire [1:0] unused_precision,unused_af;
            flex_pe_iterative_top u(
                .clk(clk),.reset(reset),.start(start&&(precision_sel==2'b01)),
                .host_wr_en(host_wr_en),.host_addr(host_addr),.host_wdata(host_wdata),
                .mode(mode),.ctrl_op(ctrl_op),
                .x_in({{24{x_in[lane*8+7]}},x_in[lane*8 +: 8]}),
                .y_in({{24{y_in[lane*8+7]}},y_in[lane*8 +: 8]}),
                .z_in({{24{z_in[lane*8+7]}},z_in[lane*8 +: 8]}),
                .result(lane_result),.done(lane_done),.busy(lane_busy),
                .error_overflow(lane_error),.iteration_count(i8[lane]),
                .precision_sel(unused_precision),.sel_af(unused_af));
            assign r8[lane*8 +: 8] = lane_result[7:0];
            assign d8[lane] = lane_done;
            assign b8[lane] = lane_busy;
            assign e8[lane] = lane_error;
        end
        for (lane=0; lane<4; lane=lane+1) begin: FXP16
            wire [31:0] lane_result;
            wire lane_done,lane_busy,lane_error;
            wire [1:0] unused_precision,unused_af;
            flex_pe_iterative_top u(
                .clk(clk),.reset(reset),.start(start&&(precision_sel==2'b10)),
                .host_wr_en(host_wr_en),.host_addr(host_addr),.host_wdata(host_wdata),
                .mode(mode),.ctrl_op(ctrl_op),
                .x_in({{16{x_in[lane*16+15]}},x_in[lane*16 +: 16]}),
                .y_in({{16{y_in[lane*16+15]}},y_in[lane*16 +: 16]}),
                .z_in({{16{z_in[lane*16+15]}},z_in[lane*16 +: 16]}),
                .result(lane_result),.done(lane_done),.busy(lane_busy),
                .error_overflow(lane_error),.iteration_count(i16[lane]),
                .precision_sel(unused_precision),.sel_af(unused_af));
            assign r16[lane*16 +: 16] = lane_result[15:0];
            assign d16[lane] = lane_done;
            assign b16[lane] = lane_busy;
            assign e16[lane] = lane_error;
        end
    endgenerate

    // FxP32 is one scalar lane occupying the complete packed word.
    flex_pe_iterative_top FXP32(
        .clk(clk),.reset(reset),.start(start&&(precision_sel==2'b11)),
        .host_wr_en(host_wr_en),.host_addr(host_addr),.host_wdata(host_wdata),
        .mode(mode),.ctrl_op(ctrl_op),.x_in(x_in[31:0]),.y_in(y_in[31:0]),.z_in(z_in[31:0]),
        .result(r32[31:0]),.done(d32),.busy(b32),.error_overflow(e32),
        .iteration_count(i32),.precision_sel(),.sel_af());
    assign r32[63:32] = 32'b0;

    assign result = (precision_sel==2'b00) ? r4 :
                    (precision_sel==2'b01) ? r8 :
                    (precision_sel==2'b10) ? r16 : r32;
    assign done = (precision_sel==2'b00) ? (&d4) :
                  (precision_sel==2'b01) ? (&d8) :
                  (precision_sel==2'b10) ? (&d16) : d32;
    assign busy = (precision_sel==2'b00) ? (|b4) :
                  (precision_sel==2'b01) ? (|b8) :
                  (precision_sel==2'b10) ? (|b16) : b32;
    assign error_overflow = (precision_sel==2'b00) ? (|e4) :
                            (precision_sel==2'b01) ? (|e8) :
                            (precision_sel==2'b10) ? (|e16) : e32;
    assign iteration_count = (precision_sel==2'b00) ? i4[0] :
                             (precision_sel==2'b01) ? i8[0] :
                             (precision_sel==2'b10) ? i16[0] : i32;
endmodule
