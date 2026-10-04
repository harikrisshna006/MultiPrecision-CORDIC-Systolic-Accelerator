`timescale 1ns/1ps

// Functional checks for the two-pass CORDIC activation sequence.  Tolerances
// are expressed in Q13 LSBs because the paper intentionally trades exact
// arithmetic for its selected Pareto stage counts.
module tb_flex_pe_config_fsm;
    reg clk,reset,start;
    reg [1:0] mode,ctrl_op,sel_af;
    reg signed [31:0] x_in,y_in,z_in;
    wire signed [31:0] result;
    wire busy,done,error_overflow;
    wire [7:0] iteration_count;
    integer pass_count,fail_count,timeout;

    flex_pe_config_fsm #(.WIDTH(32),.FRAC(13),.N_HV_STAGES(8),.N_LV_STAGES(9),.N_LR_STAGES(10)) dut(
        clk,reset,start,mode,ctrl_op,sel_af,x_in,y_in,z_in,
        result,busy,done,error_overflow,iteration_count);
    always #5 clk=~clk;

    task issue_and_wait;
        begin
            @(posedge clk); #1; start=1;
            @(posedge clk); #1; start=0; timeout=0;
            while(!done && timeout<100) begin @(posedge clk); #1; timeout=timeout+1; end
            if(timeout>=100) begin fail_count=fail_count+1;$display("CONFIG FSM TIMEOUT");end
        end
    endtask

    initial begin
        clk=0;reset=1;start=0;mode=0;ctrl_op=0;sel_af=0;x_in=0;y_in=0;z_in=0;pass_count=0;fail_count=0;
        @(posedge clk); #1; reset=0;

        ctrl_op=2'b01;sel_af=2'b10;z_in=-32'sd9;issue_and_wait;
        if(result==0 && !busy && !error_overflow)pass_count=pass_count+1;
        else begin fail_count=fail_count+1;$display("CONFIG RELU FAIL result=%0d error=%b",result,error_overflow);end

        ctrl_op=2'b01;sel_af=2'b01;z_in=0;issue_and_wait;
        if($signed(result)>=-128 && $signed(result)<=128 && iteration_count==17 && !error_overflow)pass_count=pass_count+1;
        else begin fail_count=fail_count+1;$display("CONFIG TANH(0) FAIL result=%0d iter=%0d error=%b",result,iteration_count,error_overflow);end

        ctrl_op=2'b01;sel_af=2'b00;z_in=0;issue_and_wait;
        if($signed(result)>=3600 && $signed(result)<=4600 && iteration_count==17 && !error_overflow)pass_count=pass_count+1;
        else begin fail_count=fail_count+1;$display("CONFIG SIGMOID(0) FAIL result=%0d iter=%0d error=%b",result,iteration_count,error_overflow);end

        ctrl_op=2'b01;sel_af=2'b11;z_in=0;issue_and_wait;
        if(error_overflow && result==0)pass_count=pass_count+1;
        else begin fail_count=fail_count+1;$display("CONFIG SCALAR SOFTMAX REJECT FAIL result=%0d error=%b",result,error_overflow);end

        ctrl_op=2'b00;sel_af=0;mode=2'b10;x_in=32'sh00002000;y_in=0;z_in=32'sh00001000;issue_and_wait;
        if(result!=0 && iteration_count==10 && !error_overflow)pass_count=pass_count+1;
        else begin fail_count=fail_count+1;$display("CONFIG MAC FAIL result=%0d iter=%0d error=%b",result,iteration_count,error_overflow);end

        $display("CONFIG AF FSM: PASS=%0d FAIL=%0d",pass_count,fail_count);
        $finish;
    end
endmodule
