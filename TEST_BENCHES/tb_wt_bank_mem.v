`timescale 1ns/1ps
module tb_wt_bank_mem;
 reg clk,reset,wr_en,rd_en; reg [3:0] wr_addr,rd_addr; reg [31:0] wr_data; wire [31:0] rd_data; integer p,f;
 wt_bank_mem #(32,16,4) dut(clk,reset,wr_en,wr_addr,wr_data,rd_en,rd_addr,rd_data); always #5 clk=~clk;
 task check; input [3:0] a; input [31:0] v; begin @(posedge clk);#1;wr_en=1;wr_addr=a;wr_data=v;rd_en=0;@(posedge clk);#1;wr_en=0;rd_en=1;rd_addr=a;@(posedge clk);#1;rd_en=0;if(rd_data===v)p=p+1;else begin f=f+1;$display("WT FAIL addr=%0d",a);end end endtask
 initial begin clk=0;reset=1;wr_en=0;rd_en=0;wr_addr=0;rd_addr=0;wr_data=0;p=0;f=0;@(posedge clk);#1;reset=0;check(0,1);check(15,32'hffffffff);check(8,32'h87654321);check(15,32'h0);$display("WT BANK: PASS=%0d FAIL=%0d",p,f);$finish;end
endmodule
