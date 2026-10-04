`timescale 1ns/1ps
module tb_address_mapper;
 reg clk; reg [2:0] row,col; wire [7:0] if_addr,wt_addr,of_addr; integer r,c,p,f,expected;
 address_mapper #(8) dut(row,col,if_addr,wt_addr,of_addr);
 initial begin p=0;f=0;for(r=0;r<8;r=r+1)for(c=0;c<8;c=c+1)begin @(posedge clk);#1;row=r;col=c;@(posedge clk);#1;expected=(r<<3)|c;if(if_addr===r&&wt_addr===c&&of_addr===expected)p=p+1;else begin f=f+1;$display("MAP FAIL row=%0d col=%0d",r,c);end end $display("ADDRESS MAPPER: PASS=%0d FAIL=%0d",p,f);$finish;end
 always #5 clk=~clk;
 initial clk=0;
endmodule
