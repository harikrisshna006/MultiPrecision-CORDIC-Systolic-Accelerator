`timescale 1ns/1ps
module tb_input_normalizer;
    reg clk;
    reg signed [3:0]  in4;  reg signed [7:0]  in8;
    reg signed [15:0] in16; reg signed [31:0] in32;
    reg [1:0] mode;
    wire signed [3:0]  out4;  wire signed [7:0]  out8;
    wire signed [15:0] out16; wire signed [31:0] out32;
    wire ov4,ov8,ov16,ov32;
    integer pass_count, fail_count, width_i, mode_i, case_i;
    integer value_i, expected_i, limit_i, max_i, min_i, frac_i;

    input_normalizer #(4,1)  d4(in4,mode,out4,ov4);
    input_normalizer #(8,3)  d8(in8,mode,out8,ov8);
    input_normalizer #(16,7) d16(in16,mode,out16,ov16);
    input_normalizer #(32,13)d32(in32,mode,out32,ov32);
    always #5 clk = ~clk;

    // Independent reference: derive the real-valued convergence bound, round
    // it into the active Q format, then saturate it to the representable type.
    task check_one;
        input integer test_width;
        input integer test_frac;
        input integer test_value;
        input [1:0] test_mode;
        reg signed [31:0] actual_value;
        reg actual_overflow;
        real bound_real;
        begin
            if (test_mode==2'b00) bound_real=1.1182;
            else if (test_mode==2'b01) bound_real=1.0;
            else bound_real=7.968;
            // RTL convention is truncation toward zero, not rounding.
            limit_i = $rtoi(bound_real * (1<<test_frac));
            max_i = (1 << (test_width-1))-1;
            min_i = -(1 << (test_width-1));
            if (limit_i > max_i) limit_i=max_i;
            value_i=test_value;
            expected_i=value_i;
            if (value_i > limit_i) expected_i=limit_i;
            else if (value_i < -limit_i) expected_i=-limit_i;
            if (expected_i < min_i) expected_i=min_i;
            @(posedge clk); #1;
            mode=test_mode;
            case(test_width)
                4:  in4=test_value;
                8:  in8=test_value;
                16: in16=test_value;
                default: in32=test_value;
            endcase
            @(posedge clk); #1;
            case(test_width)
                4:  begin actual_value=out4;  actual_overflow=ov4;  end
                8:  begin actual_value=out8;  actual_overflow=ov8;  end
                16: begin actual_value=out16; actual_overflow=ov16; end
                default: begin actual_value=out32; actual_overflow=ov32; end
            endcase
            if (actual_value===expected_i && actual_overflow===((value_i>limit_i)||(value_i<-limit_i)))
                pass_count=pass_count+1;
            else begin
                fail_count=fail_count+1;
                $display("NORMALIZER FAIL W=%0d mode=%0d in=%0d got=%0d ov=%b exp=%0d ov=%b",
                    test_width,test_mode,test_value,actual_value,actual_overflow,expected_i,
                    ((value_i>limit_i)||(value_i<-limit_i)));
            end
        end
    endtask

    initial begin
        clk=0; mode=0; in4=0;in8=0;in16=0;in32=0;pass_count=0;fail_count=0;
        for(width_i=0;width_i<4;width_i=width_i+1) begin
            case(width_i) 0: begin frac_i=1;max_i=7;min_i=-8;end
                1: begin frac_i=3;max_i=127;min_i=-128;end
                2: begin frac_i=7;max_i=32767;min_i=-32768;end
                default: begin frac_i=13;max_i=2147483647;min_i=-2147483647-1;end
            endcase
            for(mode_i=0;mode_i<3;mode_i=mode_i+1) begin
                check_one(1<<((width_i==0)?2:(width_i==1)?3:(width_i==2)?4:5), frac_i, 0, mode_i);
                check_one(1<<((width_i==0)?2:(width_i==1)?3:(width_i==2)?4:5), frac_i, max_i, mode_i);
                check_one(1<<((width_i==0)?2:(width_i==1)?3:(width_i==2)?4:5), frac_i, min_i, mode_i);
                check_one(1<<((width_i==0)?2:(width_i==1)?3:(width_i==2)?4:5), frac_i, max_i/2, mode_i);
                check_one(1<<((width_i==0)?2:(width_i==1)?3:(width_i==2)?4:5), frac_i, -max_i/2, mode_i);
            end
        end
        $display("INPUT NORMALIZER: PASS=%0d FAIL=%0d",pass_count,fail_count);
        $finish;
    end
endmodule
