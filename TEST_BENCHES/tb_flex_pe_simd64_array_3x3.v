`timescale 1ns/1ps

module tb_flex_pe_simd64_array_3x3;
    reg clk,reset,start,host_wr_en;
    reg [1:0] host_addr,host_wdata,mode,ctrl_op;
    reg [191:0] if_feature,wt_value;
    wire [575:0] pe_outputs;
    wire [8:0] pe_done;
    wire busy,error_overflow;
    integer pass_count,fail_count,timeout,row,col,lane;
    reg [63:0] expected_relu;

    flex_pe_simd64_array_3x3 dut(
        clk,reset,start,host_wr_en,host_addr,host_wdata,mode,ctrl_op,
        if_feature,wt_value,pe_outputs,pe_done,busy,error_overflow);
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
            while((pe_done!==9'h1ff || busy) && timeout<100) begin
                @(posedge clk); #1; timeout=timeout+1;
            end
            if(timeout>=100 || busy) begin
                fail_count=fail_count+1;
                $display("SIMD64 ARRAY HANDSHAKE FAIL done=%h busy=%b",pe_done,busy);
            end else pass_count=pass_count+1;
        end
    endtask

    initial begin
        clk=0; reset=1; start=0; host_wr_en=0; host_addr=0; host_wdata=0;
        mode=0; ctrl_op=0; if_feature=0; wt_value=0; pass_count=0; fail_count=0;
        @(posedge clk); #1; reset=0;

        // FxP8 ReLU verifies every row/column PE observes the correct packed
        // vertical weight operand and performs all eight SIMD lanes.
        cfg_write(0,2'b01); cfg_write(1,2'b10);
        if_feature=192'h0101010101010101_0202020202020202_0303030303030303;
        wt_value=192'h80ff7f0102030405_81027e0304050607_82037d0506070809;
        ctrl_op=2'b01; mode=0;
        start_and_wait;
        for(col=0;col<3;col=col+1) begin
            expected_relu=0;
            for(lane=0;lane<8;lane=lane+1)
                expected_relu[lane*8 +: 8]=wt_value[col*64+lane*8+7] ? 0 : wt_value[col*64+lane*8 +: 8];
            for(row=0;row<3;row=row+1) begin
                if(pe_outputs[(row*3+col)*64 +: 64]===expected_relu) pass_count=pass_count+1;
                else begin
                    fail_count=fail_count+1;
                    $display("SIMD64 ARRAY RELU FAIL row=%0d col=%0d got=%h exp=%h",row,col,pe_outputs[(row*3+col)*64 +: 64],expected_relu);
                end
            end
        end

        // A MAC transaction confirms accumulator-capable PE operation and
        // the common completion signal used for each systolic K step.
        cfg_write(0,2'b11); cfg_write(1,0); ctrl_op=0; mode=2'b10;
        if_feature=192'h0000000000002000_0000000000002000_0000000000002000;
        wt_value=192'h0000000000001000_0000000000001000_0000000000001000;
        start_and_wait;
        if(!error_overflow && pe_outputs[31:0]!==32'b0) pass_count=pass_count+1;
        else begin fail_count=fail_count+1;$display("SIMD64 ARRAY MAC RESULT FAIL out=%h error=%b",pe_outputs[63:0],error_overflow);end
        $display("SIMD64 3x3 ARRAY: PASS=%0d FAIL=%0d",pass_count,fail_count);
        $finish;
    end
endmodule
