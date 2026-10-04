`timescale 1ns/1ps
module tb_af_combinational;
    reg clk; reg signed [31:0] x,co,si; reg [31:0] expv; reg [3:0] mode;
    reg af_mode; reg [35:0] sum; wire signed [31:0] relu;
    wire signed [31:0] exp_out; wire [35:0] divisor;
    integer pass_count, fail_count;
    relu_mux rm(x,relu); exp_accumulator ea(co,si,exp_out);
    sigmoid_softmax_selector ss(expv,sum,af_mode,divisor);
    always #5 clk=~clk;
    task check_relu; input signed [31:0] v; begin
        @(posedge clk); #1; x=v; @(posedge clk); #1;
        if(relu === (v[31]?0:v)) pass_count=pass_count+1; else begin fail_count=fail_count+1;$display("ReLU FAIL");end
    end endtask
    task check_exp; input signed [31:0] a,b; begin
        @(posedge clk); #1; co=a;si=b; @(posedge clk); #1;
        if(exp_out === a+b) pass_count=pass_count+1; else begin fail_count=fail_count+1;$display("EXP FAIL");end
    end endtask
    task check_sel; input [31:0] e; input [35:0] s; input m; reg [35:0] want; begin
        want=m?s:({4'b0,e}+36'd8192); @(posedge clk); #1; expv=e;sum=s;af_mode=m; @(posedge clk); #1;
        if(divisor === want) pass_count=pass_count+1; else begin fail_count=fail_count+1;$display("SELECT FAIL mode=%b",m);end
    end endtask
    initial begin clk=0;x=0;co=0;si=0;expv=0;sum=0;af_mode=0;pass_count=0;fail_count=0;
        check_relu(32'sd0);check_relu(32'sd17);check_relu(-32'sd1);check_relu(-32'sh80000000);
        check_exp(32'sd100,32'sd23); check_exp(-32'sd5,32'sd9);
        check_sel(32'd0,36'd123,0); check_sel(32'd8192,36'd456,0); check_sel(32'd8192,36'd456,1); check_sel(32'd0,36'd0,1);
        $display("AF COMBINATIONAL: PASS=%0d FAIL=%0d",pass_count,fail_count);$finish;
    end
endmodule
