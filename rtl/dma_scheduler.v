`timescale 1ns/1ps

// Scheduling policy: stream every feature once, then every weight once, in
// bank-address order. The array broadcasts each feature across a row and each
// weight down a column, so this avoids rereading values for the eight PEs that
// consume them. No fixed numeric reduction factor is assumed; the policy's
// reuse is exactly 8 consumers per loaded bank word.
module dma_scheduler #(parameter ADDR_WIDTH=8) (
    input clk, reset, input start,
    input [ADDR_WIDTH:0] feature_count, weight_count,
    input [31:0] feature_stream_data, weight_stream_data,
    input feature_stream_valid, weight_stream_valid,
    output reg if_wr_en, output reg [ADDR_WIDTH-1:0] if_wr_addr, output reg [31:0] if_wr_data,
    output reg wt_wr_en, output reg [ADDR_WIDTH-1:0] wt_wr_addr, output reg [31:0] wt_wr_data,
    output reg busy, done
);
    localparam IDLE=0, FEATURES=1, WEIGHTS=2, FINISH=3;
    reg [1:0] state; reg [ADDR_WIDTH:0] index;
    always @(posedge clk) begin
        if(reset)begin state<=IDLE;index<=0;busy<=0;done<=0;if_wr_en<=0;wt_wr_en<=0;end
        else begin
            if_wr_en<=0;wt_wr_en<=0;done<=0;
            case(state)
                IDLE:if(start)begin state<=FEATURES;index<=0;busy<=1;end
                FEATURES:if(feature_stream_valid)begin if_wr_en<=1;if_wr_addr<=index[ADDR_WIDTH-1:0];if_wr_data<=feature_stream_data;
                    if(index+1>=feature_count)begin index<=0;state<=WEIGHTS;end else index<=index+1;end
                WEIGHTS:if(weight_stream_valid)begin wt_wr_en<=1;wt_wr_addr<=index[ADDR_WIDTH-1:0];wt_wr_data<=weight_stream_data;
                    if(index+1>=weight_count)state<=FINISH;else index<=index+1;end
                FINISH:begin busy<=0;done<=1;state<=IDLE;end
            endcase
        end
    end
endmodule
