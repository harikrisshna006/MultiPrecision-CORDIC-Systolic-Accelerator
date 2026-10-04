`timescale 1ns/1ps

module fifo_exp_store #(
    parameter WIDTH=32,
    parameter DEPTH=8,
    parameter PTR_WIDTH=(DEPTH <= 2) ? 1 : $clog2(DEPTH),
    parameter SUM_WIDTH=WIDTH+$clog2(DEPTH+1)
) (
    input clk,
    input reset,
    input wr_en,
    input rd_en,
    input [WIDTH-1:0] data_in,
    output reg [WIDTH-1:0] data_out,
    output reg [SUM_WIDTH-1:0] running_sum,
    output full,
    output empty,
    output reg [PTR_WIDTH:0] count
);
    reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [PTR_WIDTH-1:0] wr_ptr, rd_ptr;
    wire do_write = wr_en && !full;
    wire do_read  = rd_en && !empty;

    assign full  = (count == DEPTH);
    assign empty = (count == 0);

    always @(posedge clk) begin
        if (reset) begin
            wr_ptr <= 0; rd_ptr <= 0; count <= 0;
            data_out <= 0; running_sum <= 0;
        end else begin
            if (do_write) begin
                mem[wr_ptr] <= data_in;
                if (wr_ptr == DEPTH-1) wr_ptr <= 0; else wr_ptr <= wr_ptr + 1'b1;
            end
            if (do_read) begin
                data_out <= mem[rd_ptr];
                if (rd_ptr == DEPTH-1) rd_ptr <= 0; else rd_ptr <= rd_ptr + 1'b1;
            end
            case ({do_write,do_read})
                2'b10: begin count <= count + 1'b1; running_sum <= running_sum + data_in; end
                2'b01: begin count <= count - 1'b1; running_sum <= running_sum - mem[rd_ptr]; end
                2'b11: begin running_sum <= running_sum + data_in - mem[rd_ptr]; end
                default: ;
            endcase
        end
    end
endmodule
