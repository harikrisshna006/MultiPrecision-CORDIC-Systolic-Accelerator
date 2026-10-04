`timescale 1ns/1ps
module tb_cordic_lv_stage;
    reg signed [31:0] x,y,z; reg signed [7:0] i; wire signed [31:0] xn,yn,zn;
    reg [199:0] mem[0:63]; integer k,pass_count,fail_count;
    cordic_lv_stage dut(x,y,z,i,xn,yn,zn);
    initial begin $readmemh("rtl/cordic_lv_stage_vectors.mem",mem);pass_count=0;fail_count=0;
        for(k=0;k<64;k=k+1)begin x=mem[k][199:168];y=mem[k][167:136];z=mem[k][135:104];i=mem[k][103:96];#1;
            if(xn===mem[k][95:64]&&yn===mem[k][63:32]&&zn===mem[k][31:0])pass_count=pass_count+1;else begin fail_count=fail_count+1;$display("LV STAGE FAIL %0d",k);end end
        $display("CORDIC LV STAGE: PASS=%0d FAIL=%0d",pass_count,fail_count);$finish; end
endmodule
