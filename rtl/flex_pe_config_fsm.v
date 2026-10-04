`timescale 1ns/1ps

module flex_pe_config_fsm #(
    parameter WIDTH=32,
    parameter FRAC=13,
    parameter N_HV_STAGES=8,
    parameter N_LV_STAGES=9,
    parameter N_LR_STAGES=10,
    parameter USE_PIPELINE=1,
    parameter RANGE_EXT_BITS=3
) (
    input clk, reset, start,

    input [1:0] mode, ctrl_op, sel_af,                      //mode- just to normalise the  just to make the zin   ctrl_op-00 => LR(MAC)  sel_af (activation function)- 01= relu, 11= Z_IN, 00= HR + LV

    input signed [WIDTH-1:0] x_in, y_in, z_in,             //all are in fixed pt format 

    output reg signed [WIDTH-1:0] result,                      //in fixed pt    tanh,softmax,mac

    output reg busy, done, error_overflow,

    output reg [7:0] iteration_count                            //NO NEED FOR FIXED PIPELINE STRUCTURE                  
);
    localparam IDLE=0, HR_WAIT=1, LV_WAIT=2, LR_WAIT=3;

    reg [1:0] state;
    reg [1:0] af_reg;
    reg hr_start,lv_start,lr_start;

    reg signed [WIDTH-1:0] op_x,op_y,op_z;
    
    reg signed [WIDTH-1:0] div_x,div_y;
    
    wire signed [WIDTH-1:0] norm_z;
    
    wire norm_overflow;
    
    wire signed [WIDTH-1:0] relu_value;
    
    wire signed [WIDTH-1:0] hr_x,hr_y,hr_z,lv_x,lv_y,lv_z,lr_x,lr_y,lr_z;
    
    wire hr_busy,hr_done,lv_busy,lv_done,lr_busy,lr_done;

    wire signed [WIDTH-1:0] one_value = (1 <<< FRAC);


    wire signed [WIDTH-1:0] kh_value = (10000 * (1 <<< FRAC) + 4140) / 8281;


    input_normalizer #(WIDTH,FRAC) norm(z_in,(ctrl_op==2'b00)?mode:2'b00,norm_z,norm_overflow);       //limits the value according to the mode

    relu_mux #(WIDTH) relu(z_in,relu_value);         //if zin is -vee it provie it as 0 , +ve means z_in


    generate if(!USE_PIPELINE) begin: ITERATIVE
        cordic_stage_iterative #(WIDTH,FRAC,N_HV_STAGES,RANGE_EXT_BITS) hr(
            clk,reset,hr_start,2'b00,kh_value,{WIDTH{1'b0}},op_z,hr_x,hr_y,hr_z,hr_busy,hr_done);
        cordic_stage_iterative #(WIDTH,FRAC,N_LV_STAGES,RANGE_EXT_BITS) lv(
            clk,reset,lv_start,2'b01,div_x,div_y,{WIDTH{1'b0}},lv_x,lv_y,lv_z,lv_busy,lv_done);
        cordic_stage_iterative #(WIDTH,FRAC,N_LR_STAGES,RANGE_EXT_BITS) lr(
            clk,reset,lr_start,2'b10,op_x,op_y,op_z,lr_x,lr_y,lr_z,lr_busy,lr_done);

    end else begin: PIPELINED          //3 CORDIC ENGINES

        cordic_stage_pipeline #(WIDTH,FRAC,N_HV_STAGES,RANGE_EXT_BITS) hr(clk,reset,hr_start,2'b00,   kh_value,{WIDTH{1'b0}},op_z,    hr_x,hr_y,hr_z,hr_busy,hr_done);

        cordic_stage_pipeline #(WIDTH,FRAC,N_LV_STAGES,RANGE_EXT_BITS) lv(clk,reset,lv_start,2'b01,   div_x,div_y,{WIDTH{1'b0}},      lv_x,lv_y,lv_z,lv_busy,lv_done);
        
        cordic_stage_pipeline #(WIDTH,FRAC,N_LR_STAGES,RANGE_EXT_BITS) lr(clk,reset,lr_start,2'b10,   op_x,op_y,op_z /*z_norm*/,      lr_x,lr_y,lr_z,lr_busy,lr_done);
    
    end endgenerate

    always @(posedge clk) begin
        if(reset) begin
            state<=IDLE; 
            af_reg<=0; 

            hr_start<=0; 
            lv_start<=0; 
            lr_start<=0;

            op_x<=0; 
            op_y<=0; 
            op_z<=0; 

            div_x<=0; 
            div_y<=0; 

            result<=0; 
            busy<=0; 
            done<=0;
            error_overflow<=0; 
            iteration_count<=0;

        end else begin
            done<=0;
            hr_start<=0; 
            lv_start<=0; 
            lr_start<=0;

            case(state)
                IDLE: if(start) begin

                    error_overflow <=norm_overflow;

                    iteration_count<=0;
                    op_x<=x_in; 
                    op_y<=y_in; 
                    op_z<=norm_z;

                    if(ctrl_op==2'b00) begin          //lr(mac) alone
            
                        busy<=1; 
                        lr_start<=1;
                        state<=LR_WAIT;

//activation function
                    end else if(sel_af==2'b10) begin        //relu
                        result<=relu_value; 
                        busy<=0; 
                        done<=1;

                    end else if(sel_af==2'b11) begin       

                        result<=0; 
                        busy<=0; 
                        done<=1; 
                        error_overflow<=1;

                    end else begin    

                        af_reg<=sel_af; 
                        busy<=1; 

                        hr_start<=1; 
                        state<=HR_WAIT;
                    end
                end

                HR_WAIT: if(hr_done) begin
//-----------------tanh---------------------------------------
                            if(af_reg==2'b01) begin

                                div_x<=hr_x;        //putting the op of hr (hr_x=sinh, hr_y=cosh) into lv to divide (sinh/cosh = tanh) 
                                div_y<=hr_y;

//-----------------Sigmoid---------------------------------------
                            end else begin
                                div_x<=hr_x+hr_y+one_value;             //e+1
                                div_y<=hr_x+hr_y;                       //e                          to get e/(e+1)
                            end

                            lv_start<=1; 
                            state<=LV_WAIT;
                end

                LV_WAIT: if(lv_done) begin
                    result<=lv_z;                //the x/y comes in z this may be tanh or sigmod acc to what hr pushes 
                    busy<=0; 
                    done<=1;
                    iteration_count<=N_HV_STAGES+N_LV_STAGES;                            //because it gets the input from the 
                    state<=IDLE;

                end

                LR_WAIT: if(lr_done) begin
//-----------------MAC---------------------------------------
                    result<=lr_y;                    //in mac the result y = y+xz comes in y.
                    busy<=0;                           //it returns to idle so busy is deasserted
                    done<=1;
                    iteration_count<=N_LR_STAGES;                //gives total number of iteration done
                    state<=IDLE;

                end

                default: state<=IDLE;
            endcase
        end
    end
endmodule



/* THERE ARE 4 TYPES OF REQUEST:
1)Sigmoid:    e^x/(1+e^x)                     HR + LV
INPUT → HR → ADD → LV → OUTPUT

2)Tanh:   sinh/cosh                           LR + LV
INPUT → HR → LV → OUTPUT

3)MAC:                                        ONLY LR
INPUT → LR → OUTPUT

3)ReLU:                                       RELU
INPUT → ReLU MUX → OUTPUT
*/