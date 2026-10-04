`timescale 1ns/1ps
// Register map: 0x00 control {ctrl_op,mode,start}; 0x04 precision; 0x08 AF.
// 0x0c status {error,busy}; 0x10..0x18 expose eight done-flag bytes.
module status_control_reg (
    input clk, reset, input wr_en, input [5:2] addr, input [31:0] wr_data,
    input array_busy, input [63:0] pe_done, input error_flags,
    output reg start_pulse, output reg [1:0] mode, ctrl_op, precision_sel, sel_af,
    output reg [31:0] status_data
);
    integer i;
    always @(posedge clk) begin
        if(reset) begin start_pulse<=0;mode<=0;ctrl_op<=0;precision_sel<=3;sel_af<=0; end
        else begin
            start_pulse<=0;
            if(wr_en) case(addr)
                4'h0: begin start_pulse<=wr_data[0]; mode<=wr_data[2:1]; ctrl_op<=wr_data[4:3]; end
                4'h1: precision_sel<=wr_data[1:0];
                4'h2: sel_af<=wr_data[1:0];
                default: ;
            endcase
        end
    end
    always @* begin
        status_data=0;
        case(addr)
            4'h3: status_data={30'b0,error_flags,array_busy};
            4'h4: status_data=pe_done[31:0];
            4'h5: status_data=pe_done[63:32];
            default: status_data=0;
        endcase
    end
endmodule
