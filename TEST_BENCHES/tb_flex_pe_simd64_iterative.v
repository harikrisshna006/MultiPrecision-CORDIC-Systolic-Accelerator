`timescale 1ns/1ps

// Checks the paper's 64-bit SIMD widths (16/8/4/1) and the documented
// iterative CORDIC Pareto stage counts through the public interface.
module tb_flex_pe_simd64_iterative;
    reg clk,reset,start,host_wr_en;
    reg [1:0] host_addr,host_wdata,mode,ctrl_op;
    reg [63:0] x_in,y_in,z_in;
    wire [63:0] result;
    wire done,busy,error_overflow;
    wire [7:0] iteration_count;
    wire [1:0] precision_sel,sel_af;
    integer pass_count,fail_count,timeout,lane;
    reg [63:0] expected;

    flex_pe_simd64_iterative dut(
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

    task check_relu;
        input [1:0] precision;
        begin
            cfg_write(0,precision); cfg_write(1,2'b10);
            expected=0;
            case(precision)
                0: for(lane=0;lane<16;lane=lane+1)
                    expected[lane*4 +: 4] = z_in[lane*4+3] ? 0 : z_in[lane*4 +: 4];
                1: for(lane=0;lane<8;lane=lane+1)
                    expected[lane*8 +: 8] = z_in[lane*8+7] ? 0 : z_in[lane*8 +: 8];
                2: for(lane=0;lane<4;lane=lane+1)
                    expected[lane*16 +: 16] = z_in[lane*16+15] ? 0 : z_in[lane*16 +: 16];
                default: expected = z_in[31] ? 0 : {32'b0,z_in[31:0]};
            endcase
            ctrl_op=2'b01; mode=0;
            @(posedge clk); #1; start=1;
            @(posedge clk); #1; start=0;
            if(done && !busy && result===expected) pass_count=pass_count+1;
            else begin
                fail_count=fail_count+1;
                $display("SIMD RELU FAIL p=%0d done=%b busy=%b got=%h exp=%h",precision,done,busy,result,expected);
            end
        end
    endtask

    task check_mac_stage_count;
        input [1:0] precision;
        input [7:0] expected_iterations;
        begin
            cfg_write(0,precision); cfg_write(1,0);
            ctrl_op=2'b00; mode=2'b10;
            @(posedge clk); #1; start=1;
            @(posedge clk); #1; start=0; timeout=0;
            while(!done && timeout<80) begin @(posedge clk); #1; timeout=timeout+1; end
            if(timeout>=80 || iteration_count!==expected_iterations) begin
                fail_count=fail_count+1;
                $display("SIMD STAGE FAIL p=%0d got=%0d exp=%0d timeout=%0d",precision,iteration_count,expected_iterations,timeout);
            end else pass_count=pass_count+1;
        end
    endtask

    initial begin
        clk=0; reset=1; start=0; host_wr_en=0; host_addr=0; host_wdata=0;
        mode=0; ctrl_op=0; x_in=64'h0001_0001_0001_0001;
        y_in=0; z_in=64'hF123_8001_7FFF_0001;
        pass_count=0; fail_count=0;
        @(posedge clk); #1; reset=0;
        check_relu(0); check_relu(1); check_relu(2); check_relu(3);
        x_in=64'h0000_0000_0000_2000; y_in=0; z_in=64'h0000_0000_0000_0100;
        check_mac_stage_count(0,4); check_mac_stage_count(1,5);
        check_mac_stage_count(2,5); check_mac_stage_count(3,10);
        $display("SIMD64 ITERATIVE: PASS=%0d FAIL=%0d",pass_count,fail_count);
        $finish;
    end
endmodule
