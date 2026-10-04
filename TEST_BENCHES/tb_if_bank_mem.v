`timescale 1ns/1ps
module tb_if_bank_mem;
 reg clk,reset,wr_en,rd_en; reg [3:0] wr_addr,rd_addr; reg [31:0] wr_data; wire [31:0] rd_data; integer p,f;
 if_bank_mem #(32,16,4) dut(clk,reset,wr_en,wr_addr,wr_data,rd_en,rd_addr,rd_data); always #5 clk=~clk;
 task write_read; input [3:0] a; input [31:0] v; begin
  @(posedge clk);#1;wr_en=1;wr_addr=a;wr_data=v;rd_en=0;
  @(posedge clk);#1;wr_en=0;rd_en=1;rd_addr=a;
  @(posedge clk);#1;rd_en=0;if(rd_data===v)p=p+1;else begin f=f+1;$display("IF FAIL addr=%0d",a);end
 end endtask
 initial begin clk=0;reset=1;wr_en=0;rd_en=0;wr_addr=0;rd_addr=0;wr_data=0;p=0;f=0;@(posedge clk);#1;reset=0;
  write_read(0,32'h11111111);write_read(15,32'hdeadbeef);write_read(7,32'h12345678);write_read(15,32'hcafebabe);
  $display("IF BANK: PASS=%0d FAIL=%0d",p,f);$finish;end
endmodule
