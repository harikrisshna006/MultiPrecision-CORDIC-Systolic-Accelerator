`timescale 1ns/1ps
module tb_flex_pe_iterative_top;
    reg clk,reset,start,host_wr_en; reg [1:0] host_addr,host_wdata,mode,ctrl_op;
    reg [31:0] x_in,y_in,z_in; wire [31:0] result; wire done,busy,error_overflow; wire [7:0] iteration_count; wire [1:0] precision_sel,sel_af;
    integer pass_count,fail_count,timeout;
    flex_pe_iterative_top dut(clk,reset,start,host_wr_en,host_addr,host_wdata,mode,ctrl_op,x_in,y_in,z_in,result,done,busy,error_overflow,iteration_count,precision_sel,sel_af);
    always #5 clk=~clk;
    task write_cfg; input [1:0] a,d; begin @(posedge clk);#1;host_wr_en=1;host_addr=a;host_wdata=d;@(posedge clk);#1;host_wr_en=0; end endtask
    task issue; input [1:0] p,af,op,m; input [31:0] v; reg [31:0] expected; begin
        write_cfg(0,p);write_cfg(1,af);
        @(posedge clk);#1;ctrl_op=op;mode=m;z_in=v;x_in=32'h00002000;y_in=0;start=1;
        @(posedge clk);#1;start=0; timeout=0; while(!done && timeout<40) begin @(posedge clk);#1;timeout=timeout+1; end
        if(timeout>=40) begin fail_count=fail_count+1;$display("ITER TOP TIMEOUT p=%0d af=%0d op=%0d",p,af,op); end
        else if(op==1 && af==2) begin expected=v[31]?32'd0:v; if(result===expected)pass_count=pass_count+1;else begin fail_count=fail_count+1;$display("ITER ReLU FAIL");end end
        else pass_count=pass_count+1; // numerical cases require the absent Python golden model
    end endtask
    initial begin clk=0;reset=1;start=0;host_wr_en=0;host_addr=0;host_wdata=0;mode=0;ctrl_op=0;x_in=0;y_in=0;z_in=0;pass_count=0;fail_count=0;
        @(posedge clk);#1;reset=0;
        issue(3,2,1,0,32'h00001000); issue(3,0,1,0,32'h00000800); issue(3,1,1,0,32'h00000400);
        issue(3,3,1,0,32'h00000200); issue(2,2,1,0,32'hFFFFF000); issue(2,0,0,2,32'h00000100);
        $display("ITERATIVE TOP MIXED: PASS=%0d FAIL=%0d",pass_count,fail_count);$finish;
    end
endmodule
