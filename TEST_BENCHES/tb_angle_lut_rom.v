`timescale 1ns/1ps
module tb_angle_lut_rom;
    reg signed [7:0] i; reg [1:0] mode; wire signed [31:0] angle;
    reg [43:0] mem[0:35]; integer k,pass_count,fail_count;
    angle_lut_rom dut(i,mode,angle);
    initial begin $readmemh("rtl/angle_lut_vectors.mem",mem);pass_count=0;fail_count=0;
        for(k=0;k<36;k=k+1)begin mode=mem[k][43:40];i=mem[k][39:32];#1;
            if(angle===mem[k][31:0])pass_count=pass_count+1;else begin fail_count=fail_count+1;$display("LUT FAIL %0d",k);end end
        $display("ANGLE LUT: PASS=%0d FAIL=%0d",pass_count,fail_count);$finish; end
endmodule
