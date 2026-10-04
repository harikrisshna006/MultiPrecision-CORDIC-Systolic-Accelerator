`timescale 1ns/1ps

module tb_simd_barrel_shifter;
    reg [31:0] A;
    reg [4:0] shift_amt;
    reg [1:0] precision_sel;
    wire [31:0] result;
    reg [31:0] expected;
    integer pass_count [0:3];
    integer fail_count [0:3];
    integer mode, n, lane, width, base, shamt, bit_i;
    reg signed [31:0] av, rv;
    reg clk;

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

    simd_barrel_shifter dut(.A(A), .shift_amt(shift_amt),
                            .precision_sel(precision_sel), .result(result));

    always #5 clk = ~clk;

    task check;
        input [31:0] ta;
        input [4:0] ts;
        input [1:0] tm;
        begin
            case (tm)
                2'b00: width = 4;
                2'b01: width = 8;
                2'b10: width = 16;
                default: width = 32;
            endcase
            expected = 0;
            for (lane = 0; lane < (32 / width); lane = lane + 1) begin
                base = lane * width;
                av = get_lane(ta, base, width);
                rv = av >>> ts;
                for (bit_i = 0; bit_i < width; bit_i = bit_i + 1)
                    expected[base + bit_i] = rv[bit_i];
            end
            @(posedge clk); #1;
            A = ta; shift_amt = ts; precision_sel = tm;
            @(posedge clk); #1;
            if (result === expected)
                pass_count[tm] = pass_count[tm] + 1;
            else begin
                fail_count[tm] = fail_count[tm] + 1;
                $display("SHIFT FAIL mode=%0d A=%h shamt=%0d got=%h exp=%h",
                         tm, ta, ts, result, expected);
            end
        end
    endtask

    initial begin
        clk = 0; A = 0; shift_amt = 0; precision_sel = 0;
        for (mode = 0; mode < 4; mode = mode + 1) begin
            pass_count[mode] = 0; fail_count[mode] = 0;
        end
        for (mode = 0; mode < 4; mode = mode + 1) begin
            check(32'h87654321, 0, mode[1:0]);
            check(32'h87654321, 1, mode[1:0]);
            check(32'h87654321, 31, mode[1:0]);
            check(32'h7FFFFFFF, 4, mode[1:0]);
            for (n = 0; n < 50; n = n + 1) begin
                shamt = $random;
                check($random, shamt[4:0], mode[1:0]);
            end
        end
        for (mode = 0; mode < 4; mode = mode + 1)
            $display("SIMD BARREL SHIFT precision %0d: PASS=%0d FAIL=%0d", mode, pass_count[mode], fail_count[mode]);
        $finish;
    end
endmodule
