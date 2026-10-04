`timescale 1ns/1ps
module tb_axi_signal_interface;
 reg clk,aresetn,awvalid,wvalid,bready,arvalid,rready; reg [31:0] awaddr,wdata,araddr,read_data; reg [3:0] wstrb;
 wire awready,wready,arready; wire [1:0] bresp,rresp; wire bvalid,rvalid; wire [31:0] rdata; wire cfg_wr_en,mem_wr_en,mem_rd_en; wire [5:2] cfg_addr; wire [31:0] cfg_wdata,mem_wdata; wire [1:0] mem_sel,mem_rd_sel; wire [7:0] mem_addr,mem_rd_addr; integer p,f;
 axi_signal_interface dut(clk,aresetn,awaddr,awvalid,awready,wdata,wstrb,wvalid,wready,bresp,bvalid,bready,araddr,arvalid,arready,rdata,rresp,rvalid,rready,cfg_wr_en,cfg_addr,cfg_wdata,mem_wr_en,mem_sel,mem_addr,mem_wdata,mem_rd_en,mem_rd_sel,mem_rd_addr,read_data);
 always #5 clk=~clk;
 task write_pair; input [31:0] a,d; input aw_first; begin
  if(aw_first)begin @(posedge clk);#1;awaddr=a;awvalid=1;@(posedge clk);#1;awvalid=0;wdata=d;wvalid=1;end
  else begin @(posedge clk);#1;wdata=d;wvalid=1;@(posedge clk);#1;wvalid=0;awaddr=a;awvalid=1;end
  @(posedge clk);#1;awvalid=0;wvalid=0;
  @(posedge clk);#1;
  if(bvalid && ((a[11:8]==0 && cfg_wr_en && cfg_addr==a[5:2] && cfg_wdata==d) ||
                (a[11:8]!=0 && mem_wr_en && mem_sel==a[9:8] && mem_addr==a[7:0] && mem_wdata==d)))p=p+1;
  else begin f=f+1;$display("AXI WRITE ISSUE FAIL addr=%h bvalid=%b cfg=%b mem=%b",a,bvalid,cfg_wr_en,mem_wr_en);end
  bready=1;@(posedge clk);#1;bready=0;if(!bvalid)p=p+1;else begin f=f+1;$display("AXI BVALID HOLD FAIL");end
 end endtask
 initial begin clk=0;aresetn=0;awvalid=0;wvalid=0;bready=0;arvalid=0;rready=0;awaddr=0;wdata=0;araddr=0;wstrb=4'hf;read_data=32'hfeedface;p=0;f=0;
  @(posedge clk);#1;aresetn=1;write_pair(32'h00000004,32'h1234,1);write_pair(32'h00000123,32'habcd,0);
  @(posedge clk);#1;araddr=32'h00000234;arvalid=1;@(posedge clk);#1;arvalid=0;if(mem_rd_en&&mem_rd_sel==2&&mem_rd_addr==8'h34&&rdata==32'hfeedface)p=p+1;else begin f=f+1;$display("AXI READ FAIL en=%b sel=%0d addr=%h data=%h rvalid=%b",mem_rd_en,mem_rd_sel,mem_rd_addr,rdata,rvalid);end
  rready=1;@(posedge clk);#1;rready=0;if(!rvalid)p=p+1;else begin f=f+1;$display("AXI RESPONSE HOLD FAIL rvalid=%b rready=%b",rvalid,rready);end
  $display("AXI SIGNAL INTERFACE: PASS=%0d FAIL=%0d",p,f);$finish;end
endmodule
