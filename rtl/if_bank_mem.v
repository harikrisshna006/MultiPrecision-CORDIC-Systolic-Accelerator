`timescale 1ns/1ps
module if_bank_mem #(parameter WIDTH=32, parameter DEPTH=256, parameter ADDR_WIDTH=(DEPTH<=2)?1:$clog2(DEPTH)) (
    input clk, reset, input wr_en, input [ADDR_WIDTH-1:0] wr_addr, input [WIDTH-1:0] wr_data,
    input rd_en, input [ADDR_WIDTH-1:0] rd_addr, output reg [WIDTH-1:0] rd_data
);
    reg [WIDTH-1:0] mem [0:DEPTH-1];
    always @(posedge clk) begin
        if(reset) rd_data<=0;
        else begin if(wr_en) mem[wr_addr]<=wr_data; if(rd_en) rd_data<=mem[rd_addr]; end
    end
endmodule
