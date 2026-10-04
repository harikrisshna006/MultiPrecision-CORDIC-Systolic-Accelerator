`timescale 1ns/1ps
module tb_status_control_reg;
 reg clk,reset,wr_en; reg [5:2] addr; reg [31:0] wr_data; reg array_busy,error_flags; reg [63:0] pe_done; wire start_pulse; wire [1:0] mode,ctrl_op,precision_sel,sel_af; wire [31:0] status_data; integer p,f;
 status_control_reg dut(clk,reset,wr_en,addr,wr_data,array_busy,pe_done,error_flags,start_pulse,mode,ctrl_op,precision_sel,sel_af,status_data); always #5 clk=~clk;
 task write; input [3:0] a; input [31:0] d; begin @(posedge clk);#1;wr_en=1;addr=a;wr_data=d;@(posedge clk);#1;wr_en=0;end endtask
 initial begin clk=0;reset=1;wr_en=0;addr=0;wr_data=0;array_busy=0;error_flags=0;pe_done=0;p=0;f=0;@(posedge clk);#1;reset=0;
  write(0,32'b1| (2<<1)|(1<<3));if(start_pulse&&mode==2&&ctrl_op==1)p=p+1;else f=f+1;
  write(1,3);if(precision_sel==3)p=p+1;else f=f+1;write(2,2);if(sel_af==2)p=p+1;else f=f+1;
  @(posedge clk);#1;addr=3;array_busy=1;error_flags=1;@(posedge clk);#1;if(status_data==32'h3)p=p+1;else f=f+1;
  pe_done=64'h0123456789abcdef;addr=4;@(posedge clk);#1;if(status_data==32'h89abcdef)p=p+1;else f=f+1;addr=5;@(posedge clk);#1;if(status_data==32'h01234567)p=p+1;else f=f+1;
  $display("STATUS CONTROL: PASS=%0d FAIL=%0d",p,f);$finish;end
endmodule
