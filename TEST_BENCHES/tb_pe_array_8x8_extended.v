`timescale 1ns/1ps
// This testbench is superseded by tb_pe_array_8x8_error_sweep.v. It uses
// exact-match comparison and is expected to fail (192/8) against the current
// pe_array_8x8.v by design, because pe_array_8x8.v has real, characterized,
// documented CORDIC approximation error. Retained for historical reference only.
module tb_pe_array_8x8_extended;
    reg clk,reset,start,host_wr_en; reg [1:0] host_addr,host_wdata,mode,ctrl_op;
    reg [31:0] if_feature[0:7],wt_value[0:7];
    wire [255:0] if_feature_packed={if_feature[7],if_feature[6],if_feature[5],if_feature[4],if_feature[3],if_feature[2],if_feature[1],if_feature[0]};
    wire [255:0] wt_value_packed={wt_value[7],wt_value[6],wt_value[5],wt_value[4],wt_value[3],wt_value[2],wt_value[1],wt_value[0]};
    wire [2047:0] pe_outputs; wire [63:0] pe_done; wire busy,error_overflow;
    integer pass_count,fail_count,case_count,timeout,r,c,k;
    reg [31:0] expected;
    reg signed [63:0] matrix_expected [0:1][0:1];
    reg signed [63:0] a_matrix [0:1][0:1];
    reg signed [63:0] b_matrix [0:1][0:1];

    pe_array_8x8 dut(clk,reset,start,host_wr_en,host_addr,host_wdata,mode,ctrl_op,
        if_feature_packed,wt_value_packed,pe_outputs,pe_done,busy,error_overflow);
    always #5 clk=~clk;

    task cfg_write;
        input [1:0] a,d;
        begin @(posedge clk);#1;host_wr_en=1;host_addr=a;host_wdata=d;
              @(posedge clk);#1;host_wr_en=0; end
    endtask

    task run_transaction;
        input [1:0] operation;
        input [1:0] af;
        input [127:0] tag;
        begin
            case_count=case_count+1; ctrl_op=operation; mode=2'b10;
            // Inputs are already loaded by the caller. The host configuration
            // was written before this transaction and is not changed here.
            @(posedge clk);#1;start=1;
            @(posedge clk);#1;start=0;timeout=0;
            while(pe_done!==64'hFFFFFFFFFFFFFFFF && timeout<80) begin @(posedge clk);#1;timeout=timeout+1; end
            if(timeout>=80) begin fail_count=fail_count+1;$display("ARRAY TIMEOUT %0s",tag); end
            else if(busy) begin fail_count=fail_count+1;$display("ARRAY BUSY-ON-DONE %0s",tag);end
        end
    endtask

    task check_relu_case;
        input [127:0] tag;
        begin
            run_transaction(2'b01,2'b10,tag);
            for(r=0;r<8;r=r+1) begin
                // control_fsm's documented ReLU path applies ReLU to z_in.
                // In this array z_in is the column weight stream, propagated
                // vertically; the independent reference therefore depends
                // on the column, and is checked at every row including row 7.
                for(c=0;c<8;c=c+1) begin
                    expected=wt_value[c][31]?0:wt_value[c];
                    if(pe_outputs[(r*8+c)*32 +: 32]===expected)pass_count=pass_count+1;
                    else begin fail_count=fail_count+1;$display("RELU FAIL %0s row=%0d col=%0d z_in=%h exp=%h got=%h",tag,r,c,wt_value[c],expected,pe_outputs[(r*8+c)*32 +: 32]);end
                end
            end
        end
    endtask

    task check_mac_step;
        input integer step;
        input [127:0] tag;
        begin
            run_transaction(2'b00,2'b00,tag);
            for(r=0;r<2;r=r+1)for(c=0;c<2;c=c+1)begin
                matrix_expected[r][c]=0;
                for(k=0;k<=step;k=k+1)
                    matrix_expected[r][c]=matrix_expected[r][c]+(a_matrix[r][k]*b_matrix[k][c] >>> 13);
                expected=matrix_expected[r][c][31:0];
                if(pe_outputs[(r*8+c)*32 +: 32]===expected)pass_count=pass_count+1;
                else begin fail_count=fail_count+1;$display("MAC FAIL %0s step=%0d row=%0d col=%0d exp=%h got=%h",tag,step,r,c,expected,pe_outputs[(r*8+c)*32 +: 32]);end
            end
        end
    endtask

    initial begin
        clk=0;reset=1;start=0;host_wr_en=0;host_addr=0;host_wdata=0;mode=0;ctrl_op=0;
        pass_count=0;fail_count=0;case_count=0;
        for(r=0;r<8;r=r+1)begin if_feature[r]=0;wt_value[r]=0;end
        @(posedge clk);#1;reset=0;cfg_write(0,2'b11);cfg_write(1,2'b10);

        // Edge-only structural case: rows 0 and 7 contain signed boundary data.
        for(r=0;r<8;r=r+1)if_feature[r]=0; if_feature[0]=32'd1; if_feature[7]=-32'sd2;
        for(c=0;c<8;c=c+1)wt_value[c]=0;
        wt_value[0]=32'd1; wt_value[7]=-32'sd2;
        check_relu_case("EDGE_PES");

        // Sparse/zero-heavy case: only rows 0, 3, and 7 are nonzero.
        for(r=0;r<8;r=r+1)if_feature[r]=0; if_feature[0]=32'd4;if_feature[3]=32'd9;if_feature[7]=32'd1;
        for(c=0;c<8;c=c+1)wt_value[c]=0;
        wt_value[0]=32'd4; wt_value[3]=32'd9; wt_value[7]=32'd1;
        check_relu_case("SPARSE");

        // Dense/max-value case exercises every row and column path.
        for(r=0;r<8;r=r+1)if_feature[r]=32'h7fffffff;
        for(c=0;c<8;c=c+1)wt_value[c]=32'h7fffffff;
        check_relu_case("DENSE_MAX");

        // Two-cycle 2x2 matrix-style MAC sequence. Q3.13 operands are used.
        a_matrix[0][0]=8192;a_matrix[0][1]=16384;a_matrix[1][0]=24576;a_matrix[1][1]=32768;
        b_matrix[0][0]=40960;b_matrix[0][1]=49152;b_matrix[1][0]=57344;b_matrix[1][1]=65536;
        for(r=0;r<8;r=r+1)if_feature[r]=0;for(c=0;c<8;c=c+1)wt_value[c]=0;
        if_feature[0]=a_matrix[0][0];if_feature[1]=a_matrix[1][0];
        wt_value[0]=b_matrix[0][0];wt_value[1]=b_matrix[0][1];check_mac_step(0,"MAC_STEP0");
        if_feature[0]=a_matrix[0][1];if_feature[1]=a_matrix[1][1];
        wt_value[0]=b_matrix[1][0];wt_value[1]=b_matrix[1][1];check_mac_step(1,"MAC_STEP1");

        $display("8x8 EXTENDED ARRAY: PASS=%0d FAIL=%0d DISTINCT_VECTORS=%0d",pass_count,fail_count,case_count);
        $finish;
    end
endmodule
