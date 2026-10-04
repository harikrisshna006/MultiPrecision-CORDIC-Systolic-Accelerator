`timescale 1ns/1ps

//One single scalar 32-bit PE that can switch between FxP4, FxP8, FxP16, FxP32   (4 precisions)


// ERROR OVERFLOW IS USED FOR???????????????????????


module flex_pe_pipelined_top (
    input clk, reset, start,
    input host_wr_en, input [1:0] host_addr, input [1:0] host_wdata,
    input [1:0] mode, ctrl_op,
    input [31:0] x_in, y_in, z_in,
    output [31:0] result, 
    output done, busy, error_overflow,
    output [7:0] iteration_count, 
    output [1:0] precision_sel, sel_af
);
    af_precision_ctrl cfg(clk,reset,host_wr_en,host_addr,host_wdata,precision_sel,sel_af);

    wire [31:0] r4,r8,r16,r32;        //RESULT
    wire d4,d8,d16,d32,b4,b8,b16,b32,e4,e8,e16,e32;   //B-BUSY -> NOT NEEDED BCS ITS AN PIPELINE ~HK      D-DONE IS NEEDED TO KNOW ITS AN VALID RES FOR THE AXI TO SEND TO MEM      E-error_overflow     I-ITTERATION COUNT    
    wire [7:0] i4,i8,i16,i32;



//CALL THE PE PIPELINE FOR FP4,FP8,FP16,FP32                                                                     ST&&WHAT PRECISION IS SELECTED THAT PIPELINE WILL GET ST AS 1                       RESULT = r4
    flex_pe_config_fsm #(.WIDTH(4),.FRAC(1),.USE_PIPELINE(1),.N_HV_STAGES(4),.N_LV_STAGES(4),.N_LR_STAGES(4)) c4(clk,reset,start&&(precision_sel==0),mode,ctrl_op,sel_af,x_in[3:0],y_in[3:0],z_in[3:0],r4[3:0],b4,d4,e4,i4);
    flex_pe_config_fsm #(.WIDTH(8),.FRAC(3),.USE_PIPELINE(1),.N_HV_STAGES(4),.N_LV_STAGES(5),.N_LR_STAGES(5)) c8(clk,reset,start&&(precision_sel==1),mode,ctrl_op,sel_af,x_in[7:0],y_in[7:0],z_in[7:0],r8[7:0],b8,d8,e8,i8);
    flex_pe_config_fsm #(.WIDTH(16),.FRAC(7),.USE_PIPELINE(1),.N_HV_STAGES(4),.N_LV_STAGES(5),.N_LR_STAGES(5)) c16(clk,reset,start&&(precision_sel==2),mode,ctrl_op,sel_af,x_in[15:0],y_in[15:0],z_in[15:0],r16[15:0],b16,d16,e16,i16);
    flex_pe_config_fsm #(.WIDTH(32),.FRAC(13),.USE_PIPELINE(1),.N_HV_STAGES(8),.N_LV_STAGES(9),.N_LR_STAGES(10)) c32(clk,reset,start&&(precision_sel==3),mode,ctrl_op,sel_af,x_in,y_in,z_in,r32,b32,d32,e32,i32);

//                                       4 BIT RESULT SO SIGN EXTENSION NEEDS TO BE DONE FOR 28 BITS TO GET 32BIT OUTPUT
    assign result = (precision_sel==0)?{{28{r4[3]}},r4[3:0]}:(precision_sel==1)?{{24{r8[7]}},r8[7:0]}:(precision_sel==2)?{{16{r16[15]}},r16[15:0]}:r32;  //RESULT


    assign done=(precision_sel==0)?d4:(precision_sel==1)?d8:(precision_sel==2)?d16:d32;


    assign busy=(precision_sel==0)?b4:(precision_sel==1)?b8:(precision_sel==2)?b16:b32;
    assign error_overflow=(precision_sel==0)?e4:(precision_sel==1)?e8:(precision_sel==2)?e16:e32;
    assign iteration_count=(precision_sel==0)?i4:(precision_sel==1)?i8:(precision_sel==2)?i16:i32;

endmodule

/*
 combines     af_precision_ctrl.v + flex_pe_config_fsm.v 

flex_pe_config_fsm.v COMBINES input_normalizer.v + relu_mux.v + cordic_stage_pipeline.v 

cordic_stage_pipeline.v COMBINES ALL CORDIC ENGINES HR,LR,LV,LUT_ROM

*/

