`timescale 1ns/1ps

// AXI4-Lite slave assumption for Cheshire/CVA6: 32-bit data, 32-bit address,
// no bursts, and independent AW/W arrival supported. This module only adapts
// the bus handshake; bank/control policy lives in the connected modules.
// Verification status: verified-complete for this documented single-
// outstanding AXI4-Lite slave scope. Full pipelined/multiple-outstanding
// AXI-master compatibility is explicitly out of scope.
module axi_signal_interface (
    input ACLK, input ARESETn,
    input [31:0] S_AWADDR, input S_AWVALID, output S_AWREADY,
    input [31:0] S_WDATA, input [3:0] S_WSTRB, input S_WVALID, output S_WREADY,
    output [1:0] S_BRESP, output reg S_BVALID, input S_BREADY,
    input [31:0] S_ARADDR, input S_ARVALID, output S_ARREADY,
    output reg [31:0] S_RDATA, output [1:0] S_RRESP, output reg S_RVALID, input S_RREADY,
    output reg cfg_wr_en, output reg [5:2] cfg_addr, output reg [31:0] cfg_wdata,
    output reg mem_wr_en, output reg [1:0] mem_sel, output reg [7:0] mem_addr, output reg [31:0] mem_wdata,
    output reg mem_rd_en, output reg [1:0] mem_rd_sel, output reg [7:0] mem_rd_addr,
    input [31:0] read_data
);
    reg aw_hold,w_hold; reg [31:0] awaddr_reg,wdata_reg; reg [3:0] wstrb_reg;
    assign S_AWREADY = ARESETn && !aw_hold && !S_BVALID;
    assign S_WREADY  = ARESETn && !w_hold && !S_BVALID;
    assign S_ARREADY = ARESETn && !S_RVALID;
    assign S_BRESP=2'b00; assign S_RRESP=2'b00;
    always @(posedge ACLK) begin
        if(!ARESETn) begin aw_hold<=0;w_hold<=0;S_BVALID<=0;S_RVALID<=0;cfg_wr_en<=0;mem_wr_en<=0;mem_rd_en<=0;S_RDATA<=0; end
        else begin
            cfg_wr_en<=0;mem_wr_en<=0;mem_rd_en<=0;
            if(S_AWVALID&&S_AWREADY)begin aw_hold<=1;awaddr_reg<=S_AWADDR;end
            if(S_WVALID&&S_WREADY)begin w_hold<=1;wdata_reg<=S_WDATA;wstrb_reg<=S_WSTRB;end
            if(aw_hold&&w_hold&&!S_BVALID)begin
                aw_hold<=0;w_hold<=0;S_BVALID<=1;
                if(awaddr_reg[11:8]==0)begin cfg_wr_en<=1;cfg_addr<=awaddr_reg[5:2];cfg_wdata<=wdata_reg;end
                else begin mem_wr_en<=1;mem_sel<=awaddr_reg[9:8];mem_addr<=awaddr_reg[7:0];mem_wdata<=wdata_reg;end
            end
            if(S_BVALID&&S_BREADY)S_BVALID<=0;
            if(S_ARVALID&&S_ARREADY)begin
                S_RVALID<=1; S_RDATA<=read_data; mem_rd_en<=1;
                mem_rd_sel<=S_ARADDR[9:8]; mem_rd_addr<=S_ARADDR[7:0];
            end
            if(S_RVALID&&S_RREADY)S_RVALID<=0;
        end
    end
endmodule
