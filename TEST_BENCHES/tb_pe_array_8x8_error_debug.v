`timescale 1ns/1ps

// Diagnostic-only bench for the two suspicious low-precision sweep cases.
// No RTL is modified and no tolerance is applied.
module tb_pe_array_8x8_error_debug;
    reg clk,reset,start,host_wr_en;
    reg [1:0] host_addr,host_wdata,mode,ctrl_op;
    reg [31:0] if_feature[0:7],wt_value[0:7];
    wire [255:0] if_feature_packed={if_feature[7],if_feature[6],if_feature[5],if_feature[4],if_feature[3],if_feature[2],if_feature[1],if_feature[0]};
    wire [255:0] wt_value_packed={wt_value[7],wt_value[6],wt_value[5],wt_value[4],wt_value[3],wt_value[2],wt_value[1],wt_value[0]};
    wire [2047:0] pe_outputs; wire [63:0] pe_done;
    wire busy,error_overflow;
    integer r,c,k,step,timeout,width,frac,base,max_code,lr_full;
    integer sign_case,density;
    reg signed [31:0] amat[0:3][0:3],bmat[0:3][0:3];
    reg signed [63:0] acc_ref,a64,b64,prod,ideal,actual,err;

    pe_array_8x8 dut(clk,reset,start,host_wr_en,host_addr,host_wdata,mode,ctrl_op,
        if_feature_packed,wt_value_packed,pe_outputs,pe_done,busy,error_overflow);
    always #5 clk=~clk;

    function automatic signed [63:0] wrap_width;
        input signed [63:0] value; input integer w;
        reg signed [63:0] mask,outv;
        begin
            mask=(64'sd1 <<< w)-1; outv=value & mask;
            if(outv & (64'sd1 <<< (w-1))) outv=outv-(64'sd1 <<< w);
            wrap_width=outv;
        end
    endfunction

    task cfg_write;
        input [1:0] a,d;
        begin @(posedge clk);#1;host_wr_en=1;host_addr=a;host_wdata=d;
              @(posedge clk);#1;host_wr_en=0; end
    endtask

    task reset_config;
        input integer precision;
        begin reset=1;start=0;host_wr_en=0;@(posedge clk);#1;reset=0;
              cfg_write(0,precision[1:0]);cfg_write(1,0);end
    endtask

    task build_case;
        input integer sc,den;
        integer sign_a,sign_b,mag;
        begin
            sign_a=sc & 1; sign_b=(sc >> 1) & 1;
            for(r=0;r<4;r=r+1) for(k=0;k<4;k=k+1) begin
                if(den==0) begin
                    mag=(r==k)?base:0;
                    if((r==0&&k==3)||(r==3&&k==0))mag=base/2;
                end else if(den==1) mag=base;
                else if(den==2) mag=(base/10)+(((r*7+k*2+3)%7)*(base/20));
                else mag=(r==k)?base:base/2;
                if(sign_a&&mag!=0)amat[r][k]=-mag;else amat[r][k]=mag;
                if(sign_b&&mag!=0)bmat[r][k]=-mag;else bmat[r][k]=mag;
            end
            // Match tb_pe_array_8x8_error_sweep.v exactly for mixed and
            // boundary cases, including its second deterministic pattern.
            if(den==2 || den==3) begin
                for(r=0;r<4;r=r+1) for(k=0;k<4;k=k+1) begin
                    mag=(den==3)?((r==k)?base:base/2):
                        (base/10)+(((r*7+k*2+3)%7)*(base/20));
                    if(sign_a&&mag!=0)amat[r][k]=-mag;else amat[r][k]=mag;
                    if(sign_b&&mag!=0)bmat[r][k]=-mag;else bmat[r][k]=mag;
                end
            end
        end
    endtask

    task print_matrix;
        begin
            $display("A matrix (Q code):");
            for(r=0;r<4;r=r+1)$display("  %0d %0d %0d %0d",amat[r][0],amat[r][1],amat[r][2],amat[r][3]);
            $display("B matrix (Q code):");
            for(r=0;r<4;r=r+1)$display("  %0d %0d %0d %0d",bmat[r][0],bmat[r][1],bmat[r][2],bmat[r][3]);
        end
    endtask

    task run_step;
        input integer st;
        begin
            for(r=0;r<8;r=r+1)begin if_feature[r]=0;if(r<4)if_feature[r]=amat[r][st];end
            for(c=0;c<8;c=c+1)begin wt_value[c]=0;if(c<4)wt_value[c]=bmat[st][c];end
            $display("STEP %0d raw x(features)=%h %h %h %h raw z(weights)=%h %h %h %h",
                st,if_feature[0],if_feature[1],if_feature[2],if_feature[3],
                wt_value[0],wt_value[1],wt_value[2],wt_value[3]);
            @(posedge clk);#1;start=1;@(posedge clk);#1;start=0;timeout=0;
            while(pe_done!==64'hFFFFFFFFFFFFFFFF&&timeout<100)begin @(posedge clk);#1;timeout=timeout+1;end
            // Allow the array's local accumulator registers to observe done.
            @(posedge clk);#1;
            $display("STEP %0d PE accumulators / ideal / output / delta:",st);
            for(r=0;r<4;r=r+1)begin
                for(c=0;c<4;c=c+1)begin
                    acc_ref=0;
                    for(k=0;k<=st;k=k+1)begin
                        a64=amat[r][k];b64=bmat[k][c];prod=a64*b64;
                        acc_ref=wrap_width(acc_ref+(prod >>> frac),width);
                    end
                    ideal=wrap_width(acc_ref,width);
                    actual=$signed(pe_outputs[(r*8+c)*32 +:32]);
                    err=actual-ideal;
                    $display("  PE[%0d][%0d] acc=%0d (0x%h) ideal=%0d (0x%h) out=%0d (0x%h) delta=%0d",
                        r,c,$signed(dut.local_acc[r*8+c]),dut.local_acc[r*8+c],ideal,ideal[31:0],actual,actual[31:0],err);
                end
            end
        end
    endtask

    task run_scenario;
        input integer precision,sc,den;
        begin
            width=(1 << (precision+2));
            case(width)4:frac=1;8:frac=3;16:frac=7;default:frac=13;endcase
            base=(65273 >>> (13-frac));max_code=(1 << (width-1))-1;
            if(base>max_code)base=max_code;
            lr_full=(65273 >>> (13-frac));
            $display("============================================================");
            $display("SCENARIO precision=FxP%0d width=%0d frac=%0d density=%0d sign_case=%0d LR_full=%0d",
                width,width,frac,den,sc,lr_full);
            build_case(sc,den);print_matrix;reset_config(precision);
            for(step=0;step<4;step=step+1)run_step(step);
        end
    endtask

    initial begin
        clk=0;reset=1;start=0;host_wr_en=0;host_addr=0;host_wdata=0;mode=2;ctrl_op=0;
        for(r=0;r<8;r=r+1)begin if_feature[r]=0;wt_value[r]=0;end
        // Sweep case 28: FxP8, mixed density, -- signs.
        run_scenario(1,3,2);
        // Sweep case 3: FxP4, sparse density, -+ signs.
        run_scenario(0,2,0);
        $finish;
    end
endmodule
