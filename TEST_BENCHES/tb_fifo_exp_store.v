`timescale 1ns/1ps
module tb_fifo_exp_store;
    reg clk,reset,wr_en,rd_en; reg [7:0] data_in; wire [7:0] data_out; wire [11:0] running_sum; wire full,empty; wire [3:0] count;
    integer pass_count,fail_count,i;
    fifo_exp_store #(8,8,3,12) dut(clk,reset,wr_en,rd_en,data_in,data_out,running_sum,full,empty,count);
    always #5 clk=~clk;
    initial begin clk=0;reset=1;wr_en=0;rd_en=0;data_in=0;pass_count=0;fail_count=0;
        @(posedge clk);#1;reset=0;
        for(i=1;i<=8;i=i+1) begin @(posedge clk);#1;wr_en=1;data_in=i; end
        @(posedge clk);#1;wr_en=0;if(full&&running_sum==36)pass_count=pass_count+1;else fail_count=fail_count+1;
        for(i=1;i<=8;i=i+1) begin @(posedge clk);#1;rd_en=1; if(data_out==i-1 || (i==1&&data_out==0)) pass_count=pass_count+1; else fail_count=fail_count+1; end
        @(posedge clk);#1;rd_en=0;if(empty&&running_sum==0)pass_count=pass_count+1;else fail_count=fail_count+1;
        $display("FIFO: PASS=%0d FAIL=%0d",pass_count,fail_count);$finish;
    end
endmodule
