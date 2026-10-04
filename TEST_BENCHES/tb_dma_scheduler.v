`timescale 1ns/1ps
module tb_dma_scheduler;
 reg clk,reset,start,fv,wv; reg [8:0] fc,wc; reg [31:0] fd,wd; wire iwe,wwe,busy,done; wire [7:0] ia,wa; wire [31:0] id,wdout; integer p,f,n;
 dma_scheduler #(8) dut(clk,reset,start,fc,wc,fd,wd,fv,wv,iwe,ia,id,wwe,wa,wdout,busy,done); always #5 clk=~clk;
 task transfer; input integer features,weights,base; begin
  @(posedge clk);#1;fc=features;wc=weights;start=1;@(posedge clk);#1;start=0;n=0;
  while(!done&&n<40)begin fv=(dut.state==1);wv=(dut.state==2);fd=base+n;wd=32'h8000+base+n;@(posedge clk);#1;
   if(iwe)if(ia==n&&id==base+n)p=p+1;else f=f+1;
   if(wwe)if(wa==(n-features)&&wdout==32'h8000+base+n)p=p+1;else f=f+1;n=n+1;end
  if(done&&n<40)p=p+1;else f=f+1;
 end endtask
 initial begin clk=0;reset=1;start=0;fv=0;wv=0;fc=0;wc=0;fd=0;wd=0;p=0;f=0;@(posedge clk);#1;reset=0;transfer(2,2,10);transfer(3,1,30);$display("DMA SCHEDULER: PASS=%0d FAIL=%0d",p,f);$finish;end
endmodule
