`timescale 1ns/1ps
// Row-major mapping: IF is indexed by row, WT by column, OF by PE number.
module address_mapper #(parameter ADDR_WIDTH=8) (
    input [2:0] row, input [2:0] col,
    output [ADDR_WIDTH-1:0] if_addr, wt_addr, of_addr
);
    assign if_addr = row;
    assign wt_addr = col;
    assign of_addr = (row << 3) | col;
endmodule
