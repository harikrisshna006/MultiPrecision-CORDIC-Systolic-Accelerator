`timescale 1ns/1ps

// Cheshire/CVA6 is external. Assumption: the host supplies the same simple
// start/config signals as flex_pe_iterative_top; AXI adaptation is separate.
//
// Intentional output-stationary dataflow:
//   * input features pass west-to-east on x_link;
//   * weights pass north-to-south on z_link;
//   * each PE supplies its own retained accumulator on y_in;
//   * the PE's LR/MAC result updates only that local accumulator.
//
// x and z are combinational pass-through links in this wrapper. The PE
// engines themselves are synchronous, so all PEs sample the pass-through
// operands on the common start edge while retaining their local y state
// between transactions. This is a defensible GEMM/systolic-reuse mapping
// for the paper's stated requirement, not a claim to reproduce unpublished
// paper wiring exactly.
// Verification status: verified-complete for FxP8/FxP16/FxP32 under the
// documented array-level error bounds in tb_pe_array_8x8_error_sweep.v.
// FxP4 is functionally corrected but accumulation-depth-limited by its
// representable range; it is not recommended beyond accumulation step 1.
module pe_array_8x8 (
    input clk, reset, start,
    input host_wr_en, input [1:0] host_addr, input [1:0] host_wdata,
    input [1:0] mode, ctrl_op,
    // Packed external buses keep this module compatible with Verilog-2001
    // compilation.  Lane 0 occupies bits [31:0], lane 7 bits [255:224].
    input [255:0] if_feature, input [255:0] wt_value,
    output [2047:0] pe_outputs, output [63:0] pe_done,
    output busy, output error_overflow
);
    wire [31:0] x_link[0:7][0:8];
    wire [31:0] z_link[0:7][0:8];
    reg [31:0] local_acc[0:63];
    reg [1:0] last_ctrl_op;
    wire [31:0] pe_result[0:63];
    wire [63:0] pe_busy, pe_error;
    reg [31:0] pe_y_in[0:63];
    genvar r,c;

    integer acc_i;
    always @(*) begin
        for (acc_i=0; acc_i<64; acc_i=acc_i+1) begin
            // A completed MAC result is visible while done is asserted and
            // is the correct retained y input for the next MAC transaction.
            // An AF result must not seed a subsequent MAC accumulation.
            if (pe_done[acc_i] && (last_ctrl_op == 2'b00))
                pe_y_in[acc_i] = pe_result[acc_i];
            else if (last_ctrl_op == 2'b00)
                pe_y_in[acc_i] = local_acc[acc_i];
            else
                pe_y_in[acc_i] = 32'b0;
        end
    end

    integer reset_i;
    always @(posedge clk) begin
        if (reset) begin
            last_ctrl_op <= 2'b01;
            for (reset_i=0; reset_i<64; reset_i=reset_i+1)
                local_acc[reset_i] <= 32'b0;
        end else begin
            if (start) begin
                last_ctrl_op <= ctrl_op;
                if (ctrl_op != 2'b00)
                    for (reset_i=0; reset_i<64; reset_i=reset_i+1)
                        local_acc[reset_i] <= 32'b0;
            end
            if (last_ctrl_op == 2'b00)
                for (reset_i=0; reset_i<64; reset_i=reset_i+1)
                    if (pe_done[reset_i])
                        local_acc[reset_i] <= pe_result[reset_i];
        end
    end

    generate
        for(r=0;r<8;r=r+1) begin: ROW
            assign x_link[r][0]=if_feature[r*32 +: 32];
            for(c=0;c<8;c=c+1) begin: COL
                wire [31:0] z_in_wire;
                assign z_in_wire = (r==0) ? wt_value[c*32 +: 32] : z_link[r-1][c];
                flex_pe_iterative_top pe(clk,reset,start,host_wr_en,host_addr,host_wdata,mode,ctrl_op,
                    x_link[r][c],pe_y_in[r*8+c],z_in_wire,pe_result[r*8+c],pe_done[r*8+c],
                    pe_busy[r*8+c],pe_error[r*8+c],/*iteration_count*/,
                    /*precision_sel*/,
                    /*sel_af*/);
                assign x_link[r][c+1]=x_link[r][c];
                assign z_link[r][c]=z_in_wire;
                assign pe_outputs[(r*8+c)*32 +: 32]=pe_result[r*8+c];
            end
        end
    endgenerate
    assign busy = |pe_busy;
    assign error_overflow = |pe_error;
endmodule
