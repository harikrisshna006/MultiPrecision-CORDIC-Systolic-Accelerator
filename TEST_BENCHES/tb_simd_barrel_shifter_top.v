`timescale 1ns/1ps
module tb_simd_barrel_shifter_top;
    reg clk; reg [31:0] data_in; reg [4:0] shift_amt; reg [1:0] precision_sel;
    wire [31:0] data_out; reg [31:0] exp;
    integer mode,n,lane,width,base,bit_i,random_shift; integer pass_count[0:3],fail_count[0:3];
    reg signed [31:0] av,rv;
    simd_barrel_shifter_top dut(data_in,shift_amt,precision_sel,data_out);
    always #5 clk=~clk;
    function signed [31:0] lane_value;
        input [31:0] v; input integer b,w; reg [31:0] mask,bits;
        begin mask=32'hFFFFFFFF>>(32-w); bits=(v>>b)&mask;
          if(bits[w-1]) lane_value=bits|~mask; else lane_value=bits; end
    endfunction
    task check;
        input [31:0] tv; input [4:0] ts; input [1:0] tm;
        begin
            case(tm) 0:width=4; 1:width=8; 2:width=16; default:width=32; endcase
            exp=0;
            for(lane=0;lane<(32/width);lane=lane+1) begin
                base=lane*width; av=lane_value(tv,base,width); rv=av>>>ts;
                for(bit_i=0;bit_i<width;bit_i=bit_i+1) exp[base+bit_i]=rv[bit_i];
            end
            @(posedge clk); #1; data_in=tv; shift_amt=ts; precision_sel=tm;
            @(posedge clk); #1;
            if(data_out===exp) pass_count[tm]=pass_count[tm]+1;
            else begin fail_count[tm]=fail_count[tm]+1; $display("BARREL TOP FAIL mode=%0d A=%h sh=%0d got=%h exp=%h",tm,tv,ts,data_out,exp); end
        end
    endtask
    initial begin
        clk=0;data_in=0;shift_amt=0;precision_sel=0;
        for(mode=0;mode<4;mode=mode+1) begin pass_count[mode]=0;fail_count[mode]=0; end
        for(mode=0;mode<4;mode=mode+1) begin
            check(32'h87654321,0,mode); check(32'h87654321,31,mode);
            check(32'h7FFFFFFF,4,mode); check(32'hFFFFFFFF,1,mode);
            for(n=0;n<50;n=n+1) begin random_shift=$random; check($random,random_shift[4:0],mode); end
        end
        for(mode=0;mode<4;mode=mode+1) $display("BARREL TOP precision %0d: PASS=%0d FAIL=%0d",mode,pass_count[mode],fail_count[mode]);
        $finish;
    end
endmodule
