`timescale 1ns/1ps
module tb_af_precision_ctrl;
    reg clk,reset,wr_en; reg [1:0] addr,wdata; wire [1:0] precision_sel,sel_af; integer pass_count,fail_count;
    af_precision_ctrl dut(clk,reset,wr_en,addr,wdata,precision_sel,sel_af); always #5 clk=~clk;
    task write_reg; input [1:0] a,d; begin @(posedge clk);#1;wr_en=1;addr=a;wdata=d;@(posedge clk);#1;wr_en=0; end endtask
    initial begin clk=0;reset=1;wr_en=0;addr=0;wdata=0;pass_count=0;fail_count=0;
        @(posedge clk);#1;reset=0;
        write_reg(0,0);if(precision_sel==0)pass_count=pass_count+1;else fail_count=fail_count+1;
        write_reg(0,1);if(precision_sel==1)pass_count=pass_count+1;else fail_count=fail_count+1;
        write_reg(0,2);if(precision_sel==2)pass_count=pass_count+1;else fail_count=fail_count+1;
        write_reg(0,3);if(precision_sel==3)pass_count=pass_count+1;else fail_count=fail_count+1;
        write_reg(1,0);if(sel_af==0)pass_count=pass_count+1;else fail_count=fail_count+1;
        write_reg(1,1);if(sel_af==1)pass_count=pass_count+1;else fail_count=fail_count+1;
        write_reg(1,2);if(sel_af==2)pass_count=pass_count+1;else fail_count=fail_count+1;
        write_reg(1,3);if(sel_af==3)pass_count=pass_count+1;else fail_count=fail_count+1;
        $display("AF CTRL: PASS=%0d FAIL=%0d",pass_count,fail_count);$finish;
    end
endmodule
