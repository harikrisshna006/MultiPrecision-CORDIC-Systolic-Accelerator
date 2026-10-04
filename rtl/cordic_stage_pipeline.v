//race to sleep is pipelins compared to itterative

//no need of hazard unit bcs all are independent operation (no reg are involved the exact data is given)

/*
in the pipeline the mode also travel along side so that each stage can work in diff mode 
there will be a mux con at each stage end with all 3 op and mode as selection line which decides which  block(hr,lr,lv) x,y,z gonna reach 
next itteration in next stage.
*/

/*
think about valid: here it samples all the values and satges starts to operate but only if the start is asserted 
the stage needs to operate and the output of that stage is valid =1, if the start is not asserted the valid = 0 
the output at the end will not be considered or taken axi or some stuff...
*/
`timescale 1ns/1ps
module cordic_stage_pipeline #(
    parameter WIDTH=32, parameter FRAC=13, parameter N_STAGES=10,
    parameter RANGE_EXT_BITS=3
) (
    input clk, reset, start,
    input [1:0] mode,
    input signed [WIDTH-1:0] x_in, y_in, z_in,

    output reg signed [WIDTH-1:0] x_out, y_out, z_out,          //these are the final mac@y/exp@y/div@z as the output
    output reg busy, done
);

    reg signed [WIDTH-1:0] xp[0:N_STAGES], yp[0:N_STAGES], zp[0:N_STAGES];
    reg signed [WIDTH-1:0] xc[0:N_STAGES], yc[0:N_STAGES], zc[0:N_STAGES];

    reg [1:0] mode_pipe[0:N_STAGES];
    reg [N_STAGES:0] valid;
    integer k;
    genvar g;

    generate for(g=0; g<N_STAGES; g=g+1) begin: STAGES
        wire signed [WIDTH-1:0] hx,hy,hz,lx,ly,lz,rx,ry,rz;
       
        wire signed [7:0] ii = (mode_pipe[g]==2'b10) ?                                           //g-> number of stages 
                              (g-(RANGE_EXT_BITS-1)) :
                              (mode_pipe[g]==2'b00) ? ((g>=4) ? g : (g+1)) : (g+1);             //

/*
lr:
g:   0   1   2   3   4   5   6   7
i:  -2  -1   0   1   2   3   4   5         -ve is to extend the LR CORDIC's range
    x*4 x*2  x*1 x*1/2................................

lv:
g:   0   1   2   3   4   5   6   7
i:   1   2   3   4   5   6   7   8
y(i+1) = yi +- x*2^-i                                @i=0 y=yi+x*1 = x    our qual is to minimise the y to 0 not to 1 or x    so we start from 1 not from 0 or -ve
z(i+1) = zi -+ 2^-i                                 it has the output


hr:
g:   0   1   2   3   4   5   6   7
i:   1   2   3   4   4   5   6   7
repeated 4 is due to property: hyperbolic CORDIC convergence, this repeat 4 is to include the hr convergence behaviour

*/
                                 
        cordic_hr_stage #(WIDTH,FRAC) h(xp[g],yp[g],zp[g],ii,hx,hy,hz);
        cordic_lv_stage #(WIDTH,FRAC) l(xp[g],yp[g],zp[g],ii,lx,ly,lz);
        cordic_lr_stage #(WIDTH,FRAC) r(xp[g],yp[g],zp[g],ii,rx,ry,rz);

        always @* begin
            case(mode_pipe[g])
              2'b00: begin xc[g+1]=hx;yc[g+1]=hy;zc[g+1]=hz; end
              2'b01: begin xc[g+1]=lx;yc[g+1]=ly;zc[g+1]=lz; end
              default: begin xc[g+1]=rx;yc[g+1]=ry;zc[g+1]=rz; end
            endcase
        end
    end endgenerate


    always @* begin
        xc[0]=xp[0]; yc[0]=yp[0]; zc[0]=zp[0];
    end
    always @(posedge clk) begin
        if(reset) begin
            valid<=0;
            busy<=0;
            done<=0;
            x_out<=0;
            y_out<=0;
            z_out<=0;

            for(k=0;k<=N_STAGES;k=k+1) mode_pipe[k]<=0;
        end
        else begin
            done<=valid[N_STAGES];

            if(valid[N_STAGES]) begin
                x_out<=xp[N_STAGES];
                y_out<=yp[N_STAGES];
                z_out<=zp[N_STAGES]; 
            end
            valid[0]<=start;

            if(start) begin 
                xp[0]<=x_in;
                yp[0]<=y_in;
                zp[0]<=z_in;
                mode_pipe[0]<=mode; 
            end

            for(k=1;k<=N_STAGES;k=k+1) begin
                valid[k]<=valid[k-1];
                xp[k]<=xc[k]; 
                yp[k]<=yc[k]; 
                zp[k]<=zc[k];
                mode_pipe[k]<=mode_pipe[k-1];
            end

            busy<=|valid;
        end
    end
endmodule
