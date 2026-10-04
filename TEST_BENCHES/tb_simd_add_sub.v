`timescale 1ns/1ps

module tb_simd_add_sub;
    reg [31:0] A, B;
    reg [1:0] precision_sel;
    reg add_sub;
    wire [31:0] result;
    wire [7:0] overflow;
    reg [31:0] expected;
    reg [7:0] expected_overflow;
    integer pass_count [0:3];
    integer fail_count [0:3];
    integer mode, n, lane, width, base, bit_i;
    reg clk;
    reg signed [31:0] av, bv, rv;
    reg a_sign, b_sign, r_sign;

    function signed [31:0] get_lane;
        input [31:0] value;
        input integer lane_base;
        input integer lane_width_arg;
        reg [31:0] mask;
        reg [31:0] bits;
        begin
            mask = 32'hFFFFFFFF >> (32 - lane_width_arg);
            bits = (value >> lane_base) & mask;
            if (bits[lane_width_arg-1]) get_lane = bits | ~mask;
            else                       get_lane = bits;
        end
    endfunction

    simd_add_sub dut(.A(A), .B(B), .precision_sel(precision_sel),
                     .add_sub(add_sub), .result(result), .overflow(overflow));

    always #5 clk = ~clk;

    task check;
        input [31:0] ta;
        input [31:0] tb;
        input [1:0] tm;
        input tsub;
        begin
            case (tm)
                2'b00: width = 4;
                2'b01: width = 8;
                2'b10: width = 16;
                default: width = 32;
            endcase
            expected = 0;
            expected_overflow = 0;
            for (lane = 0; lane < (32 / width); lane = lane + 1) begin
                base = lane * width;
                av = get_lane(ta, base, width);
                bv = get_lane(tb, base, width);
                if (tsub) rv = av - bv;
                else      rv = av + bv;
                for (bit_i = 0; bit_i < width; bit_i = bit_i + 1)
                    expected[base + bit_i] = rv[bit_i];
                a_sign = ta[base + width - 1];
                b_sign = tb[base + width - 1];
                r_sign = rv[width-1];
                if (!tsub) expected_overflow[lane] = (a_sign == b_sign) && (r_sign != a_sign);
                else       expected_overflow[lane] = (a_sign != b_sign) && (r_sign != a_sign);
            end
            @(posedge clk); #1;
            A = ta; B = tb; precision_sel = tm; add_sub = tsub;
            @(posedge clk); #1;
            if ((result === expected) && (overflow === expected_overflow))
                pass_count[tm] = pass_count[tm] + 1;
            else begin
                fail_count[tm] = fail_count[tm] + 1;
                $display("ADD FAIL mode=%0d A=%h B=%h sub=%b got=%h/%b exp=%h/%b",
                         tm, ta, tb, tsub, result, overflow, expected, expected_overflow);
            end
        end
    endtask

    initial begin
        clk = 0; A = 0; B = 0; precision_sel = 0; add_sub = 0;
        for (mode = 0; mode < 4; mode = mode + 1) begin
            pass_count[mode] = 0; fail_count[mode] = 0;
        end
        for (mode = 0; mode < 4; mode = mode + 1) begin
            check(32'h00000000, 32'h11111111, mode[1:0], 0);
            check(32'hFFFFFFFF, 32'h11111111, mode[1:0], 1);
            check(32'h77777777, 32'h11111111, mode[1:0], 0);
            check(32'h88888888, 32'h77777777, mode[1:0], 1);
            for (n = 0; n < 50; n = n + 1)
                check($random, $random, mode[1:0], n[0]);
        end
        for (mode = 0; mode < 4; mode = mode + 1)
            $display("SIMD ADD/SUB precision %0d: PASS=%0d FAIL=%0d", mode, pass_count[mode], fail_count[mode]);
        $finish;
    end
endmodule
