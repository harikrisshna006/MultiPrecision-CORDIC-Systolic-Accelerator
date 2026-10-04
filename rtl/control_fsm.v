`timescale 1ns/1ps

// CTRL_MAC=0, CTRL_NAF=1. NAF sel_af: 00 sigmoid, 01 tanh, 10 ReLU, 11 SoftMax.
module control_fsm #(
    parameter WIDTH=32, parameter FRAC=13, parameter N_STAGES=10,
    // N_STAGES is retained for compatibility with existing benches.  The
    // three parameters below allow the paper's distinct Pareto points for
    // hyperbolic rotation (HV), linear vectoring (LV), and linear rotation
    // (LR) to be represented in one configurable controller.
    parameter N_HV_STAGES=N_STAGES,
    parameter N_LV_STAGES=N_STAGES,
    parameter N_LR_STAGES=N_STAGES,
    parameter USE_PIPELINE=0, parameter RANGE_EXT_BITS=3
) (
    input clk, reset, start,
    input [1:0] mode, ctrl_op, sel_af,
    input signed [WIDTH-1:0] x_in, y_in, z_in,
    output reg signed [WIDTH-1:0] result,
    output reg busy, done, error_overflow,
    output reg [7:0] iteration_count
);
    localparam IDLE=0, RUN=1, STORE=2, FINISH=3;
    reg [1:0] state;
    reg engine_start;
    reg [1:0] mode_reg, op_reg, af_reg;
    reg signed [WIDTH-1:0] exp_reg;
    wire signed [WIDTH-1:0] norm_z;
    wire norm_overflow;
    wire signed [WIDTH-1:0] hr_x,hr_y,hr_z,lv_x,lv_y,lv_z,lr_x,lr_y,lr_z;
    wire hr_busy,hr_done,lv_busy,lv_done,lr_busy,lr_done;
    wire [1:0] engine_mode = (op_reg==2'b01) ? 2'b00 : mode_reg;
    wire signed [WIDTH-1:0] cx = (engine_mode==2'b00) ? hr_x :
                                  (engine_mode==2'b01) ? lv_x : lr_x;
    wire signed [WIDTH-1:0] cy = (engine_mode==2'b00) ? hr_y :
                                  (engine_mode==2'b01) ? lv_y : lr_y;
    wire signed [WIDTH-1:0] cz = (engine_mode==2'b00) ? hr_z :
                                  (engine_mode==2'b01) ? lv_z : lr_z;
    wire engine_busy = (engine_mode==2'b00) ? hr_busy :
                       (engine_mode==2'b01) ? lv_busy : lr_busy;
    wire engine_done = (engine_mode==2'b00) ? hr_done :
                       (engine_mode==2'b01) ? lv_done : lr_done;
    wire [7:0] selected_stages = (engine_mode==2'b00) ? N_HV_STAGES :
                                 (engine_mode==2'b01) ? N_LV_STAGES : N_LR_STAGES;
    wire signed [WIDTH-1:0] relu_value;
    wire [WIDTH-1:0] exp_value;
    wire [WIDTH+$clog2(9)-1:0] fifo_sum;
    wire [WIDTH+$clog2(9)-1:0] divisor;
    wire fifo_full,fifo_empty;
    wire [3:0] fifo_count;
    wire fifo_wr = (state==STORE) && (af_reg==2'b11) && !fifo_full;
    input_normalizer #(WIDTH,FRAC) norm(z_in,(op_reg==2'b01)?2'b00:mode_reg,norm_z,norm_overflow);
    generate if (!USE_PIPELINE) begin: GI
        cordic_stage_iterative #(WIDTH,FRAC,N_HV_STAGES,RANGE_EXT_BITS) hr(
            clk,reset,engine_start&&(engine_mode==2'b00),2'b00,x_in,y_in,norm_z,hr_x,hr_y,hr_z,hr_busy,hr_done);
        cordic_stage_iterative #(WIDTH,FRAC,N_LV_STAGES,RANGE_EXT_BITS) lv(
            clk,reset,engine_start&&(engine_mode==2'b01),2'b01,x_in,y_in,norm_z,lv_x,lv_y,lv_z,lv_busy,lv_done);
        cordic_stage_iterative #(WIDTH,FRAC,N_LR_STAGES,RANGE_EXT_BITS) lr(
            clk,reset,engine_start&&(engine_mode==2'b10),2'b10,x_in,y_in,norm_z,lr_x,lr_y,lr_z,lr_busy,lr_done);
    end else begin: GP
        cordic_stage_pipeline #(WIDTH,FRAC,N_HV_STAGES,RANGE_EXT_BITS) hr(
            clk,reset,engine_start&&(engine_mode==2'b00),2'b00,x_in,y_in,norm_z,hr_x,hr_y,hr_z,hr_busy,hr_done);
        cordic_stage_pipeline #(WIDTH,FRAC,N_LV_STAGES,RANGE_EXT_BITS) lv(
            clk,reset,engine_start&&(engine_mode==2'b01),2'b01,x_in,y_in,norm_z,lv_x,lv_y,lv_z,lv_busy,lv_done);
        cordic_stage_pipeline #(WIDTH,FRAC,N_LR_STAGES,RANGE_EXT_BITS) lr(
            clk,reset,engine_start&&(engine_mode==2'b10),2'b10,x_in,y_in,norm_z,lr_x,lr_y,lr_z,lr_busy,lr_done);
    end endgenerate
    relu_mux #(WIDTH) relu(z_in,relu_value);
    exp_accumulator #(WIDTH) ea(cx,cy,exp_value);
    fifo_exp_store #(WIDTH,8,3,WIDTH+$clog2(9)) fifo(clk,reset,fifo_wr,1'b0,exp_value,,fifo_sum,fifo_full,fifo_empty,fifo_count);
    sigmoid_softmax_selector #(WIDTH,FRAC,WIDTH+$clog2(9)) sel(exp_value,fifo_sum,1'b0,divisor);

    always @(posedge clk) begin
        if(reset) begin state<=IDLE;engine_start<=0;busy<=0;done<=0;result<=0;error_overflow<=0;iteration_count<=0; mode_reg<=0;op_reg<=0;af_reg<=0;exp_reg<=0; end
        else begin
            done<=0; engine_start<=0;
            case(state)
                IDLE: if(start) begin
                    mode_reg<=mode; op_reg<=ctrl_op; af_reg<=sel_af; error_overflow<=norm_overflow;
                    iteration_count<=0;
                    if(ctrl_op==2'b01 && sel_af==2'b10) begin result<=relu_value; done<=1; end
                    else begin engine_start<=1; busy<=1; state<=RUN; end
                end
                RUN: if(engine_done) begin exp_reg<=exp_value; iteration_count<=selected_stages; state<=STORE; end
                STORE: begin busy<=0; state<=FINISH; end
                FINISH: begin
                    if(op_reg==2'b00) result<=cy;
                    else case(af_reg)
                        2'b00: result<=divisor[WIDTH-1:0];
                        2'b01: result<=cy;
                        2'b11: result<=fifo_sum[WIDTH-1:0];
                        default: result<=relu_value;
                    endcase
                    done<=1; state<=IDLE;
                end
            endcase
        end
    end
endmodule
