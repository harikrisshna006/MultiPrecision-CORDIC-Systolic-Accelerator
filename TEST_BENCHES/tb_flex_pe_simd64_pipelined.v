`timescale 1ns/1ps

module tb_flex_pe_simd64_pipelined;
    reg clk,reset,start,host_wr_en;
    reg [1:0] host_addr,host_wdata,mode,ctrl_op;
    reg [63:0] x_in,y_in,z_in;
    wire [63:0] result;
    wire done,busy,error_overflow;
    wire [7:0] iteration_count;
    wire [1:0] precision_sel,sel_af;
    integer pass_count,fail_count,timeout,lane,sum;

    flex_pe_simd64_pipelined dut(
        clk,reset,start,host_wr_en,host_addr,host_wdata,mode,ctrl_op,
        x_in,y_in,z_in,result,done,busy,error_overflow,iteration_count,
        precision_sel,sel_af);
    always #5 clk=~clk;

    task cfg_write;
        input [1:0] a,d;
        begin
            @(posedge clk); #1; host_wr_en=1; host_addr=a; host_wdata=d;
            @(posedge clk); #1; host_wr_en=0;
        end
    endtask

    task start_and_wait;
        begin
            @(posedge clk); #1; start=1;
            @(posedge clk); #1; start=0; timeout=0;
            while(!done && timeout<100) begin @(posedge clk); #1; timeout=timeout+1; end
            if(timeout>=100) begin fail_count=fail_count+1;$display("SIMD64 PIPE TIMEOUT");end
        end
    endtask

    initial begin
        clk=0;reset=1;start=0;host_wr_en=0;host_addr=0;host_wdata=0;
        mode=0;ctrl_op=0;x_in=0;y_in=0;z_in=0;pass_count=0;fail_count=0;
        @(posedge clk); #1; reset=0;

        // A zero-valued eight-element vector has uniform SoftMax.  FxP8
        // Q3 lanes represent 1/8 as one LSB, so the packed lane sum should
        // remain close to 1.0 despite CORDIC approximation.
        cfg_write(0,2'b01); cfg_write(1,2'b11);
        ctrl_op=2'b01; x_in=0; start_and_wait;
        sum=0;
        for(lane=0;lane<8;lane=lane+1) sum=sum+$signed(result[lane*8 +: 8]);
        if(!error_overflow && iteration_count==9 && sum>=6 && sum<=10) pass_count=pass_count+1;
        else begin fail_count=fail_count+1;$display("SOFTMAX FXP8 FAIL result=%h sum=%0d iter=%0d error=%b",result,sum,iteration_count,error_overflow);end

        // A one-element vector must normalize to approximately 1.0 in the
        // Q13 FxP32 representation.
        cfg_write(0,2'b11); cfg_write(1,2'b11);
        x_in=0; start_and_wait;
        if(!error_overflow && $signed(result[31:0])>=7600 && $signed(result[31:0])<=8500 && iteration_count==17) pass_count=pass_count+1;
        else begin fail_count=fail_count+1;$display("SOFTMAX FXP32 FAIL result=%h iter=%0d error=%b",result,iteration_count,error_overflow);end

        // The paper does not claim a pipelined FxP4 NAF; reject it visibly.
        cfg_write(0,2'b00); cfg_write(1,2'b11);
        x_in=0; start_and_wait;
        if(error_overflow && !busy) pass_count=pass_count+1;
        else begin fail_count=fail_count+1;$display("SOFTMAX FXP4 REJECT FAIL error=%b busy=%b",error_overflow,busy);end

        $display("SIMD64 PIPELINED: PASS=%0d FAIL=%0d",pass_count,fail_count);
        $finish;
    end
endmodule
