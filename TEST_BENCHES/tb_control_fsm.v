`timescale 1ns/1ps
module tb_control_fsm;
    reg clk,reset,start;
    reg [1:0] mode,ctrl_op,sel_af;
    reg signed [31:0] x_in,y_in,z_in;
    wire signed [31:0] result;
    wire busy,done,error_overflow;
    wire [7:0] iteration_count;
    integer pass_count,fail_count,timeout;

    control_fsm #(.WIDTH(32),.FRAC(13),.N_STAGES(2)) dut(
        clk,reset,start,mode,ctrl_op,sel_af,x_in,y_in,z_in,
        result,busy,done,error_overflow,iteration_count);
    always #5 clk=~clk;

    task check_state;
        input [1:0] expected_state;
        input [127:0] label;
        begin
            if (dut.state===expected_state) pass_count=pass_count+1;
            else begin fail_count=fail_count+1;$display("FSM STATE FAIL %0s got=%0d exp=%0d",label,dut.state,expected_state);end
        end
    endtask

    task idle_start_and_wait;
        input [1:0] test_op;
        input [1:0] test_af;
        begin
            ctrl_op=test_op;sel_af=test_af;mode=2'b10;x_in=32'h2000;y_in=0;z_in=32'h100;
            @(posedge clk);#1;start=1;
            @(posedge clk);#1;start=0;check_state(2'd1,"IDLE_to_RUN");
            timeout=0;
            while(dut.state==2'd1 && timeout<20) begin @(posedge clk);#1;timeout=timeout+1; end
            if(timeout>=20) begin fail_count=fail_count+1;$display("FSM TIMEOUT op=%0d af=%0d",test_op,test_af);end
            else begin
                check_state(2'd2,"RUN_to_STORE");
                @(posedge clk);#1;check_state(2'd3,"STORE_to_FINISH");
                @(posedge clk);#1;
                if(done && !busy && dut.state==2'd0) pass_count=pass_count+1;
                else begin fail_count=fail_count+1;$display("FSM DONE/BUSY/IDLE FAIL done=%b busy=%b state=%0d",done,busy,dut.state);end
            end
        end
    endtask

    initial begin
        clk=0;reset=1;start=0;mode=0;ctrl_op=0;sel_af=0;x_in=0;y_in=0;z_in=0;pass_count=0;fail_count=0;
        @(posedge clk);#1;check_state(2'd0,"RESET_IDLE");reset=0;

        // MAC exercises IDLE->RUN->STORE->FINISH->IDLE.
        idle_start_and_wait(2'b00,2'b00);

        // NAF/ReLU is the direct bypass path and must complete without RUN.
        ctrl_op=2'b01;sel_af=2'b10;z_in=-32'sd7;
        @(posedge clk);#1;start=1;@(posedge clk);#1;start=0;
        if(done && !busy && result==0 && dut.state==2'd0) pass_count=pass_count+1;
        else begin fail_count=fail_count+1;$display("FSM RELU BYPASS FAIL done=%b busy=%b result=%0d state=%0d",done,busy,result,dut.state);end

        // Illegal/edge case: assert start while a CORDIC transaction is busy.
        ctrl_op=0;sel_af=0;mode=2;z_in=32'h100;
        @(posedge clk);#1;start=1;@(posedge clk);#1;start=0;check_state(2'd1,"EDGE_START_RUN");
        @(posedge clk);#1;start=1;@(posedge clk);#1;check_state(2'd1,"BUSY_IGNORES_START");start=0;

        // Reset-abort must force IDLE and clear busy/done.
        reset=1;@(posedge clk);#1;
        if(dut.state==2'd0 && !busy && !done)pass_count=pass_count+1;
        else begin fail_count=fail_count+1;$display("FSM RESET ABORT FAIL");end
        reset=0;
        $display("CONTROL FSM: PASS=%0d FAIL=%0d",pass_count,fail_count);
        $display("FSM COVERAGE: states IDLE/RUN/STORE/FINISH and transitions reset, start, complete, ReLU bypass, busy-start, reset-abort");
        $finish;
    end
endmodule
