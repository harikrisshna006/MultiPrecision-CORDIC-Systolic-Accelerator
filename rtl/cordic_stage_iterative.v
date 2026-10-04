`timescale 1ns/1ps
module cordic_stage_iterative #(
    parameter WIDTH=32, parameter FRAC=13, 
    parameter N_STAGES=10, 
    parameter RANGE_EXT_BITS=3                   // it affects iteration_i in lr mode,how many extra negative(*2^2) iterations the LR mode gets at the beginning
) (
    input clk, reset, start,                         //st????
    input [1:0] mode,                                      //????

    input signed [WIDTH-1:0] x_in, y_in, z_in,

    output reg signed [WIDTH-1:0] x_out, y_out, z_out,
    output reg busy, done                                 //???
);

    localparam IDLE=0, RUN=1, SETTLE=2, HOLD=3;
    reg [1:0] state;
    reg [7:0] count;

    reg [1:0] mode_reg;                                                          //mode dhan oru reg vachu varuthu
    reg signed [WIDTH-1:0] xr,yr,zr;                                                //all inputs
    wire signed [WIDTH-1:0] h_x,h_y,h_z, lx,ly,lz,rx,ry,rz;                                  //to get the op of all lr,lv,hr                      


//THIS I CALCULATION IS NOT ARBITARY
                                //lr                 init => 0-(3-1) = -2      so it makes the value c to be max +7.992 and -7.999------if we st from -100 we cant cover decimal with just 10 stages...and also due to overflow because x is already large mul with it will result higher value
    wire signed [7:0] iter_i = (mode_reg==2'b10) ? ($signed(count) - (RANGE_EXT_BITS-1)) :
                                //hr                
                                (mode_reg==2'b00) ? ((count>=4) ?$signed(count):($signed(count)+1))   //tanh(x=0)=0 , valid @-> -1<x<1 so if i=-1 means the x = 2^1=2(invalind) and for i=0 ie; x = 0 gives tanh(1) as infinite like wise i = -2,3 means the x becomes > 1 so invalid in tanh..
                                //lv
                                : ($signed(count) + 1);     //here for ai we just want small corrections so we div by small numbers

/*
18 bits are remaining for lr ie -131072 to +131071 y cant we start itteration_i from -100 ar something 
to cover 131072 but we cant because our pipeline is 10 stages if we go for i to start from -100 
it will not cover any decimall values--------->true
*/

    reg signed [WIDTH-1:0] xn,yn,zn;                    //according to the mode it assigns the output to this registers

//ip are sampe for all the blocks (hr,lr,lv)
    cordic_hr_stage #(WIDTH,FRAC) hs(xr,yr,zr,iter_i, h_x,h_y,h_z);
    cordic_lv_stage #(WIDTH,FRAC) ls(xr,yr,zr,iter_i, lx,ly,lz);
    cordic_lr_stage #(WIDTH,FRAC) rs(xr,yr,zr,iter_i, rx,ry,rz);


    always @(posedge clk) begin
        if (reset) begin                  //all outputs and internal states are 0

            state<=IDLE; 
            count<=0; 
            
            busy<=0; 
            done<=0; 
            x_out<=0;
            y_out<=0;
            z_out<=0; 
        
        end else begin

            done<=0;
            case(state)
              IDLE: if(start) begin                //start is triggered it samples the data and provide inputs to all the blocks and mode to the end case mux
                        xr<=x_in;
                        yr<=y_in;
                        zr<=z_in;
                        mode_reg<=mode;
                    
                        count<=0;
                        busy<=1;
                        state<=RUN; 
                    end
              RUN:  begin 
                        xr<=xn;
                        yr<=yn;
                        zr<=zn;

                        if(count == N_STAGES-1) state<= SETTLE ;         // 9 stages ie it can make i= 0 to 8   , for each clk count increases to calculate stages its completed and iteration_i
                        else count<=count+1;
                    end
              SETTLE: begin 
                        x_out<=xr; 
                        y_out<=yr; 
                        z_out<=zr; 

                        done<=1;               //till this busy = 1 and done = 0
                        busy<=0; 
                        state<=HOLD; 
                      end
              default: if(!start) state<=IDLE;

            endcase
        end
    end

    always @* begin        //this connects the output line according to the mode  
        case(mode_reg)
          2'b00: begin         //hr
                xn=h_x;
                yn=h_y;
                zn=h_z; 
            end

          2'b01: begin          //lv
                xn=lx;  
                yn=ly;
                zn=lz; 
            end

          default: begin       //ie; for mode 10,11 -> lr
                xn=rx;
                yn=ry;
                zn=rz; 
            end                                        
        endcase
    end
endmodule
