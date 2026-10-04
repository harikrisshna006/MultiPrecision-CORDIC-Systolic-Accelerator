`timescale 1ns/1ps

//EACH PE HAS MULTIPLE CHANNELS (PARALLEL CORE)
/*
"Our design is a "2D Systolic Array composed of SIMD Vector Processing Elements". 
while each PE contains an 8-lane SIMD datapath (in FxP8 mode) to process 8 feature channels in parallel. 
This allows the 3×3 array to achieve 72 MAC operations per clock cycle!"


In Deep Neural Networks, as an image passes deeper into the network (e.g., Layer 3), 
the network stops looking at simple colors and starts looking at 8 learned features (channels)


precision select:
    00:FxP4 
    01:FxP8
    10:FxP16
    11:FxP32

*/

module flex_pe_simd64_pipelined (
    input clk, reset, start,
    input host_wr_en,

//GIVEN BY AXI DRIVEN BY CPU
    input [1:0] host_addr, host_wdata,            //its notr the memory address it tells wether the data is for choosing the function or precision
    input [1:0] mode, ctrl_op,                       //mode , ctrlop

// SRAM Memory Bank THE CPU DOESNT GIVE THE DATA 
    input [63:0] x_in, y_in, z_in,    

// SRAM Memory Bank TAKES THE DATA 
    output [63:0] result,

    output done, busy, error_overflow,
    output [7:0] iteration_count,
    output [1:0] precision_sel, sel_af
);

    af_precision_ctrl cfg(clk,reset,host_wr_en,host_addr,host_wdata ,precision_sel,sel_af);      //SEL_AF CTRLS THE FUNCTION WE NEED TO PROCEED TANH,SIGMOD ETC

    wire [63:0] r8,r16,r32;
    wire [7:0] d8,b8,e8;
    wire [3:0] d16,b16,e16;
    wire d32,b32,e32;
    wire [7:0] i8 [0:7];
    wire [7:0] i16[0:3];
    wire [7:0] i32;
    wire softmax_mode = (ctrl_op==2'b01) && (sel_af==2'b11);
    wire [63:0] softmax_result;
    wire softmax_done,softmax_busy,softmax_error;
    wire [7:0] softmax_iterations;
    genvar lane;


//LANE CREATION
    generate
        for (lane=0; lane<8; lane=lane+1) begin: FXP8
            wire [31:0] lane_result;
            wire lane_done,lane_busy,lane_error;
            flex_pe_pipelined_top u(
                .clk(clk),.reset(reset),.start(start&&!softmax_mode&&(precision_sel==2'b01)),
                .host_wr_en(host_wr_en),.host_addr(host_addr),.host_wdata(host_wdata),
                .mode(mode),.ctrl_op(ctrl_op),
                .x_in({{24{x_in[lane*8+7]}},x_in[lane*8 +: 8]}),
                .y_in({{24{y_in[lane*8+7]}},y_in[lane*8 +: 8]}),
                .z_in({{24{z_in[lane*8+7]}},z_in[lane*8 +: 8]}),
                .result(lane_result),.done(lane_done),.busy(lane_busy),
                .error_overflow(lane_error),.iteration_count(i8[lane]),
                .precision_sel(),.sel_af());
            assign r8[lane*8 +: 8] = lane_result[7:0];
            assign d8[lane] = lane_done;
            assign b8[lane] = lane_busy;
            assign e8[lane] = lane_error;
        end
        for (lane=0; lane<4; lane=lane+1) begin: FXP16
            wire [31:0] lane_result;
            wire lane_done,lane_busy,lane_error;
            flex_pe_pipelined_top u(
                .clk(clk),.reset(reset),.start(start&&!softmax_mode&&(precision_sel==2'b10)),
                .host_wr_en(host_wr_en),.host_addr(host_addr),.host_wdata(host_wdata),
                .mode(mode),.ctrl_op(ctrl_op),
                .x_in({{16{x_in[lane*16+15]}},x_in[lane*16 +: 16]}),
                .y_in({{16{y_in[lane*16+15]}},y_in[lane*16 +: 16]}),
                .z_in({{16{z_in[lane*16+15]}},z_in[lane*16 +: 16]}),
                .result(lane_result),.done(lane_done),.busy(lane_busy),
                .error_overflow(lane_error),.iteration_count(i16[lane]),
                .precision_sel(),.sel_af());
            assign r16[lane*16 +: 16] = lane_result[15:0];
            assign d16[lane] = lane_done;
            assign b16[lane] = lane_busy;
            assign e16[lane] = lane_error;
        end
    endgenerate
    flex_pe_pipelined_top FXP32(
        .clk(clk),.reset(reset),.start(start&&!softmax_mode&&(precision_sel==2'b11)),
        .host_wr_en(host_wr_en),.host_addr(host_addr),.host_wdata(host_wdata),
        .mode(mode),.ctrl_op(ctrl_op),.x_in(x_in[31:0]),.y_in(y_in[31:0]),.z_in(z_in[31:0]),
        .result(r32[31:0]),.done(d32),.busy(b32),.error_overflow(e32),
        .iteration_count(i32),.precision_sel(),.sel_af());
    assign r32[63:32] = 32'b0;
    flex_pe_simd64_softmax softmax(
        .clk(clk),.reset(reset),.start(start&&softmax_mode),
        .precision_sel(precision_sel),.x_in(x_in),.result(softmax_result),
        .done(softmax_done),.busy(softmax_busy),.error_overflow(softmax_error),
        .iteration_count(softmax_iterations));




    assign result = softmax_mode ? softmax_result :
                    (precision_sel==2'b01) ? r8 :
                    (precision_sel==2'b10) ? r16 :
                    (precision_sel==2'b11) ? r32 : 64'b0;


    assign done = softmax_mode ? softmax_done :
                  (precision_sel==2'b00) ? start :
                  (precision_sel==2'b01) ? (&d8) :
                  (precision_sel==2'b10) ? (&d16) : d32;
    assign busy = softmax_mode ? softmax_busy :
                  (precision_sel==2'b01) ? (|b8) :
                  (precision_sel==2'b10) ? (|b16) :
                  (precision_sel==2'b11) ? b32 : 1'b0;
    assign error_overflow = softmax_mode ? softmax_error :
                            (precision_sel==2'b00) ? start :
                            (precision_sel==2'b01) ? (|e8) :
                            (precision_sel==2'b10) ? (|e16) : e32;
    assign iteration_count = softmax_mode ? softmax_iterations :
                             (precision_sel==2'b01) ? i8[0] :
                             (precision_sel==2'b10) ? i16[0] : i32;
endmodule


/*
72 operations per cycle no not per cycle - the systolic array inputs geets filled each 3 cycle once 
and that inputs output we get it after 10 systolic array clk's ie; axi clk 1 ipx1,y1 , axi clk 2 ipx2,y2 , 
axi clk 3 ipx3,y3 so after 10 systolic clk PE-11 outputs 64bits (ie; 10th clk) and @ 11 th clk PE-12,21,22 gives output like wise 
it takes 12 clk to give 1 matrix output but after 12 clk ie 13th clk it gives new matrix ouput of PE11 like wise

Think of a 10-stage assembly line factory:

It takes 14 minutes for one car to travel from the entrance to the exit door (that's Latency = 14 cycles).
BUT once the factory is running, there are cars inside every single workstation at the exact same moment.
*/