`timescale 1ns/1ps
module tb_pe_array_8x8;
    reg clk,reset,start,host_wr_en; reg [1:0] host_addr,host_wdata,mode,ctrl_op;
    reg [31:0] if_feature[0:7],wt_value[0:7];
    wire [255:0] if_feature_packed={if_feature[7],if_feature[6],if_feature[5],if_feature[4],if_feature[3],if_feature[2],if_feature[1],if_feature[0]};
    wire [255:0] wt_value_packed={wt_value[7],wt_value[6],wt_value[5],wt_value[4],wt_value[3],wt_value[2],wt_value[1],wt_value[0]};
    wire [2047:0] pe_outputs; wire [63:0] pe_done; wire busy,error_overflow;
    integer i,pass_count,fail_count;
    pe_array_8x8 dut(clk,reset,start,host_wr_en,host_addr,host_wdata,mode,ctrl_op,if_feature_packed,wt_value_packed,pe_outputs,pe_done,busy,error_overflow);
    always #5 clk=~clk;
    task cfg_write; input [1:0] a,d; begin @(posedge clk);#1;host_wr_en=1;host_addr=a;host_wdata=d;@(posedge clk);#1;host_wr_en=0;end endtask
    initial begin clk=0;reset=1;start=0;host_wr_en=0;host_addr=0;host_wdata=0;mode=0;ctrl_op=1;pass_count=0;fail_count=0;
        for(i=0;i<8;i=i+1)begin if_feature[i]=i;wt_value[i]=32'h100+i;end
        @(posedge clk);#1;reset=0;cfg_write(0,3);cfg_write(1,2);
        @(posedge clk);#1;start=1;@(posedge clk);#1;
        if(pe_done===64'hFFFFFFFFFFFFFFFF && !busy)pass_count=pass_count+1;else begin fail_count=fail_count+1;$display("ARRAY HANDSHAKE FAIL done=%h busy=%b",pe_done,busy);end
        if(!error_overflow)pass_count=pass_count+1;else fail_count=fail_count+1;
        start=0;
        $display("8x8 ARRAY: PASS=%0d FAIL=%0d",pass_count,fail_count);$finish;
    end
endmodule
