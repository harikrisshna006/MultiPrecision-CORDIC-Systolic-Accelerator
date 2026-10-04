`timescale 1ns/1ps
module tb_simd_lane_mux;
    reg clk; reg [31:0] A,B; reg add_sub; reg [1:0] precision_sel;
    wire [31:0] result; wire [7:0] overflow;
    integer mode,n,lane,width,base,bit_i; integer pass_count[0:3],fail_count[0:3];
    reg [31:0] exp; reg [7:0] exp_ov; reg signed [31:0] av,bv,rv;
    simd_lane_mux dut(A,B,add_sub,precision_sel,result,overflow);
    always #5 clk=~clk;
    function signed [31:0] lane_value;
        input [31:0] v; input integer b,w; reg [31:0] mask,bits;
        begin mask=32'hFFFFFFFF>>(32-w); bits=(v>>b)&mask;
          if(bits[w-1]) lane_value=bits|~mask; else lane_value=bits; end
    endfunction
    task check;
        input [31:0] ta,tb; input [1:0] tm; input ts;
        begin
            case(tm) 0:width=4; 1:width=8; 2:width=16; default:width=32; endcase
            exp=0; exp_ov=0;
            for(lane=0;lane<(32/width);lane=lane+1) begin
                base=lane*width; av=lane_value(ta,base,width); bv=lane_value(tb,base,width);
                if(ts) rv=av-bv; else rv=av+bv;
                for(bit_i=0;bit_i<width;bit_i=bit_i+1) exp[base+bit_i]=rv[bit_i];
                if(!ts) exp_ov[lane]=(ta[base+width-1]==tb[base+width-1])&&(rv[width-1]!=ta[base+width-1]);
                else exp_ov[lane]=(ta[base+width-1]!=tb[base+width-1])&&(rv[width-1]!=ta[base+width-1]);
            end
            @(posedge clk); #1; A=ta; B=tb; precision_sel=tm; add_sub=ts;
            @(posedge clk); #1;
            if(result===exp && overflow===exp_ov) pass_count[tm]=pass_count[tm]+1;
            else begin fail_count[tm]=fail_count[tm]+1; $display("LANE ADD FAIL mode=%0d",tm); end
        end
    endtask
    initial begin
        clk=0;A=0;B=0;add_sub=0;precision_sel=0;
        for(mode=0;mode<4;mode=mode+1) begin pass_count[mode]=0;fail_count[mode]=0; end
        for(mode=0;mode<4;mode=mode+1) begin
            check(32'h00000000,32'h11111111,mode,0);
            check(32'h88888888,32'h77777777,mode,1);
            check(32'h77777777,32'h11111111,mode,0);
            check(32'hFFFFFFFF,32'h00000001,mode,1);
            for(n=0;n<50;n=n+1) check($random,$random,mode,n[0]);
        end
        for(mode=0;mode<4;mode=mode+1) $display("LANE MUX precision %0d: PASS=%0d FAIL=%0d",mode,pass_count[mode],fail_count[mode]);
        $finish;
    end
endmodule
