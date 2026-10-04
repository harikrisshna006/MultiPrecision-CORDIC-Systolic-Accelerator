`timescale 1ns/1ps
module tb_cordic_stage_iterative;
    reg clk,reset,start; reg [1:0] mode; reg signed [31:0] x,y,z; wire signed [31:0] xo,yo,zo; wire busy,done;
    reg [195:0] mem[0:191]; integer k,t,pass_count,fail_count;
    cordic_stage_iterative dut(clk,reset,start,mode,x,y,z,xo,yo,zo,busy,done); always #5 clk=~clk;
    task run_one; begin
        @(posedge clk);#1;start=1;@(posedge clk);#1;start=0;t=0;
        while(!done&&t<40)begin @(posedge clk);#1;t=t+1;end
        if(t>=40)begin fail_count=fail_count+1;$display("ITERATIVE TIMEOUT %0d",k);end
        else if(xo===mem[k][95:64]&&yo===mem[k][63:32]&&zo===mem[k][31:0])pass_count=pass_count+1;
        else begin fail_count=fail_count+1;$display("ITERATIVE FAIL %0d mode=%0d got=%h/%h/%h exp=%h/%h/%h",k,mode,xo,yo,zo,mem[k][95:64],mem[k][63:32],mem[k][31:0]);end
    end endtask
    initial begin clk=0;reset=1;start=0;mode=0;x=0;y=0;z=0;pass_count=0;fail_count=0;$readmemh("rtl/cordic_iterative_vectors.mem",mem);
        @(posedge clk);#1;reset=0;
        for(k=0;k<192;k=k+1)begin mode=mem[k][195:192];x=mem[k][191:160];y=mem[k][159:128];z=mem[k][127:96];run_one;end
        $display("CORDIC ITERATIVE: PASS=%0d FAIL=%0d",pass_count,fail_count);$finish;end
endmodule
