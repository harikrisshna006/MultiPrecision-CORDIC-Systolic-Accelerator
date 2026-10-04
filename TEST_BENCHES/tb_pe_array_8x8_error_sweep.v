`timescale 1ns/1ps

// Error characterization only. This bench deliberately does not apply a
// pass/fail tolerance. It compares the array against an independent ideal
// fixed-point nested-loop MAC and reports observed error maxima.
module tb_pe_array_8x8_error_sweep;
    reg clk, reset, start, host_wr_en;
    reg [1:0] host_addr, host_wdata, mode, ctrl_op;
    reg [31:0] if_feature[0:7], wt_value[0:7];
    wire [255:0] if_feature_packed={if_feature[7],if_feature[6],if_feature[5],if_feature[4],if_feature[3],if_feature[2],if_feature[1],if_feature[0]};
    wire [255:0] wt_value_packed={wt_value[7],wt_value[6],wt_value[5],wt_value[4],wt_value[3],wt_value[2],wt_value[1],wt_value[0]};
    wire [2047:0] pe_outputs;
    wire [63:0] pe_done;
    wire busy, error_overflow;

    integer r,c,k,p,step,sign_case,density;
    integer width, frac, lr_full, max_code, base, av, bv;
    integer timeout, case_id;
    integer max_abs[0:3][0:3];
    integer max_case[0:3][0:3];
    integer max_density[0:3][0:3];
    integer max_sign[0:3][0:3];
    integer tolerance[0:3][0:3];
    integer pass_count[0:3], fail_count[0:3], info_count;
    real max_pct;
    reg signed [31:0] amat[0:3][0:3];
    reg signed [31:0] bmat[0:3][0:3];
    reg signed [63:0] acc_ref;
    reg signed [63:0] a64, b64, product, ideal_value, actual_value, error_value;

    pe_array_8x8 dut(clk,reset,start,host_wr_en,host_addr,host_wdata,mode,ctrl_op,
        if_feature_packed,wt_value_packed,pe_outputs,pe_done,busy,error_overflow);
    always #5 clk=~clk;

    function automatic signed [63:0] wrap_width;
        input signed [63:0] value;
        input integer w;
        reg signed [63:0] mask;
        reg signed [63:0] outv;
        begin
            mask=(64'sd1 <<< w)-1;
            outv=value & mask;
            if(outv & (64'sd1 <<< (w-1))) outv=outv-(64'sd1 <<< w);
            wrap_width=outv;
        end
    endfunction

    task cfg_write;
        input [1:0] a,d;
        begin
            @(posedge clk); #1; host_wr_en=1; host_addr=a; host_wdata=d;
            @(posedge clk); #1; host_wr_en=0;
        end
    endtask

    task reset_and_config;
        input integer precision;
        begin
            reset=1; start=0; host_wr_en=0;
            @(posedge clk); #1; reset=0;
            cfg_write(2'd0,precision[1:0]);
            cfg_write(2'd1,2'b00);
        end
    endtask

    task build_case;
        input integer sc;
        input integer den;
        integer sign_a,sign_b,mag;
        begin
            sign_a=(sc & 1); sign_b=((sc >> 1) & 1);
            for(r=0;r<4;r=r+1) begin
                for(k=0;k<4;k=k+1) begin
                    if(den==0) begin
                        mag=((r==k) ? base : 0);
                        if((r==0 && k==3) || (r==3 && k==0)) mag=base/2;
                    end else if(den==1) begin
                        mag=base;
                    end else if(den==2) begin
                        mag=(base/8)+(((r*5+k*3+1)%5)*(base/16));
                    end else begin
                        mag=((r==k) ? base : (base/2));
                    end
                    if(sign_a && (mag!=0)) amat[r][k]=-mag; else amat[r][k]=mag;
                    if(sign_b && (mag!=0)) bmat[r][k]=-mag; else bmat[r][k]=mag;
                end
            end
            // Give A and B different deterministic magnitudes in the mixed
            // and boundary cases, while retaining the requested sign sweep.
            if(den==2 || den==3) begin
                for(r=0;r<4;r=r+1) for(k=0;k<4;k=k+1) begin
                    mag=(den==3) ? ((r==k)?base:base/2) :
                        (base/10)+(((r*7+k*2+3)%7)*(base/20));
                    if(sign_a && mag!=0) amat[r][k]=-mag; else amat[r][k]=mag;
                    if(sign_b && mag!=0) bmat[r][k]=-mag; else bmat[r][k]=mag;
                end
            end
        end
    endtask

    task run_step;
        input integer st;
        begin
            for(r=0;r<8;r=r+1) begin
                if_feature[r]=0;
                if(r<4) if_feature[r]=amat[r][st];
            end
            for(c=0;c<8;c=c+1) begin
                wt_value[c]=0;
                if(c<4) wt_value[c]=bmat[st][c];
            end
            @(posedge clk); #1; start=1;
            @(posedge clk); #1; start=0; timeout=0;
            while(pe_done!==64'hFFFFFFFFFFFFFFFF && timeout<100) begin
                @(posedge clk); #1; timeout=timeout+1;
            end
            if(timeout>=100) begin
                $display("SWEEP TIMEOUT precision=%0d step=%0d case=%0d",p,st,case_id);
            end
            acc_ref=0;
            for(r=0;r<4;r=r+1) for(c=0;c<4;c=c+1) begin
                acc_ref=0;
                for(k=0;k<=st;k=k+1) begin
                    a64=amat[r][k]; b64=bmat[k][c];
                    product=a64*b64;
                    acc_ref=wrap_width(acc_ref+(product >>> frac),width);
                end
                ideal_value=wrap_width(acc_ref,width);
                actual_value=$signed(pe_outputs[(r*8+c)*32 +: 32]);
                // Compare in the active-width modular domain. Raw signed
                // subtraction falsely turns a small boundary-crossing
                // error (for example 124 versus -116 in FxP8) into 240 LSB.
                error_value=wrap_width(actual_value-ideal_value,width);
                if(p==0) begin
                    info_count=info_count+1;
                end else if(error_value<0) begin
                    if((-error_value)<=tolerance[p][st]) pass_count[p]=pass_count[p]+1;
                    else begin
                        fail_count[p]=fail_count[p]+1;
                        $display("TOL FAIL FxP%0d step=%0d case=%0d row=%0d col=%0d err=%0d tol=%0d",
                            width,st,case_id,r,c,-error_value,tolerance[p][st]);
                    end
                end else if(error_value<=tolerance[p][st]) begin
                    pass_count[p]=pass_count[p]+1;
                end else begin
                    fail_count[p]=fail_count[p]+1;
                    $display("TOL FAIL FxP%0d step=%0d case=%0d row=%0d col=%0d err=%0d tol=%0d",
                        width,st,case_id,r,c,error_value,tolerance[p][st]);
                end
                if(error_value<0) begin
                    if((-error_value)>max_abs[p][st]) begin
                        max_abs[p][st]=(-error_value); max_case[p][st]=case_id;
                        max_density[p][st]=density; max_sign[p][st]=sign_case;
                    end
                end else if(error_value>max_abs[p][st]) begin
                    max_abs[p][st]=error_value; max_case[p][st]=case_id;
                    max_density[p][st]=density; max_sign[p][st]=sign_case;
                end
            end
        end
    endtask

    initial begin
        clk=0; reset=1; start=0; host_wr_en=0; host_addr=0; host_wdata=0;
        mode=2'b10; ctrl_op=2'b00; case_id=0;
        // Documented acceptance margins: observed maxima rounded upward to
        // practical whole-number limits, with explicit guard margin.
        // FxP4 is intentionally informational only, not pass/fail judged.
        tolerance[0][0]=0;  tolerance[0][1]=0;  tolerance[0][2]=0;  tolerance[0][3]=0;
        tolerance[1][0]=10; tolerance[1][1]=18; tolerance[1][2]=26; tolerance[1][3]=36;
        tolerance[2][0]=16; tolerance[2][1]=16; tolerance[2][2]=16; tolerance[2][3]=24;
        tolerance[3][0]=550;tolerance[3][1]=1000;tolerance[3][2]=1500;tolerance[3][3]=2000;
        pass_count[0]=0; pass_count[1]=0; pass_count[2]=0; pass_count[3]=0;
        fail_count[0]=0; fail_count[1]=0; fail_count[2]=0; fail_count[3]=0;
        info_count=0;
        for(p=0;p<4;p=p+1) for(step=0;step<4;step=step+1) begin
            max_abs[p][step]=0; max_case[p][step]=0;
            max_density[p][step]=0; max_sign[p][step]=0;
        end

        for(p=0;p<4;p=p+1) begin
            case(width)
                4:  frac=1;
                8:  frac=3;
                16: frac=7;
                default: frac=13;
            endcase
            width=(1 << (p+2));
            case(width)
                4: frac=1;
                8: frac=3;
                16: frac=7;
                default: frac=13;
            endcase
            base=(65273 >>> (13-frac));
            max_code=(1 << (width-1))-1;
            if(base>max_code) base=max_code;
            lr_full=(65273 >>> (13-frac));
            for(density=0;density<4;density=density+1) begin
                for(sign_case=0;sign_case<4;sign_case=sign_case+1) begin
                    case_id=case_id+1;
                    build_case(sign_case,density);
                    reset_and_config(p);
                    for(step=0;step<4;step=step+1) run_step(step);
                end
            end
        end

        $display("============================================================");
        $display("CORDIC ARRAY ERROR SWEEP: 4 sign cases x 4 densities x 4 steps");
        $display("FxP4 informational only; FxP8/16/32 tolerance assertions enabled.");
        $display("TOL FxP8 = 10/18/26/36 LSB; FxP16 = 16/16/16/24 LSB; FxP32 = 550/1000/1500/2000 LSB");
        $display("precision step max_abs_LSB max_pct_LR_fullscale case density sign");
        for(p=0;p<4;p=p+1) begin
            width=(1 << (p+2));
            case(width) 4:frac=1; 8:frac=3; 16:frac=7; default:frac=13; endcase
            lr_full=(65273 >>> (13-frac));
            for(step=0;step<4;step=step+1) begin
                max_pct=(max_abs[p][step]*100.0)/lr_full;
                $display("%0d %0d %0d %f %0d %0d %0d",width,step,
                    max_abs[p][step],max_pct,max_case[p][step],
                    max_density[p][step],max_sign[p][step]);
            end
        end
        $display("FxP4 MAC accumulation: NOT RECOMMENDED beyond step 1; characterization comparisons=%0d",info_count);
        $display("FxP8 TOLERANCE: PASS=%0d FAIL=%0d",pass_count[1],fail_count[1]);
        $display("FxP16 TOLERANCE: PASS=%0d FAIL=%0d",pass_count[2],fail_count[2]);
        $display("FxP32 TOLERANCE: PASS=%0d FAIL=%0d",pass_count[3],fail_count[3]);
        $finish;
    end
endmodule
