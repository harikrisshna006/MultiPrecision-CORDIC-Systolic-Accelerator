`timescale 1ns/1ps


module flex_pe_simd64_array_3x3 (
    input clk, reset, start,
    input host_wr_en,
    input [1:0] host_addr, host_wdata,
    input [1:0] mode, ctrl_op,
    // Row-major boundary words: element 0 is row/column zero in [63:0].
    input [191:0] if_feature,
    input [191:0] wt_value,
    output [575:0] pe_outputs,
    output [8:0] pe_done,
    output busy, error_overflow
);
    // Registered operand links and staggered boundary injection implement
    // real systolic timing: A[r] enters at time r and B[c] at time c.
    reg [63:0] x_link [0:2][0:2];
    reg [63:0] z_link [0:2][0:2];
    reg x_valid [0:2][0:2];
    reg z_valid [0:2][0:2];
    reg [191:0] if_latched,wt_latched;
    reg [3:0] wave_time;
    reg array_running;
    reg [8:0] completion_seen;
    wire [63:0] pe_result [0:8];
    wire [8:0] pe_busy,pe_error,pe_done_raw;
    reg [63:0] local_acc [0:8];
    reg [63:0] pe_y_in [0:8];
    reg [1:0] last_ctrl_op;
    integer i,j;
    genvar r,c;

    // Results are retained only across MAC commands.  Activation commands
    // deliberately begin with a zero accumulator, matching the PE's role
    // at a layer boundary.
    always @* begin
        for(i=0;i<9;i=i+1) begin
            if(last_ctrl_op==2'b00)
                pe_y_in[i]=local_acc[i];
            else
                pe_y_in[i]=64'b0;
        end
    end

    always @(posedge clk) begin
        if(reset) begin
            last_ctrl_op<=2'b01; if_latched<=0; wt_latched<=0;
            wave_time<=0; array_running<=0; completion_seen<=0;
            for(i=0;i<9;i=i+1) local_acc[i]<=64'b0;
            for(i=0;i<3;i=i+1) for(j=0;j<3;j=j+1) begin
                x_link[i][j]<=0; z_link[i][j]<=0;
                x_valid[i][j]<=0; z_valid[i][j]<=0;
            end
        end else begin
            if(start && !array_running) begin
                last_ctrl_op<=ctrl_op;
                if_latched<=if_feature; wt_latched<=wt_value;
                wave_time<=0; array_running<=1; completion_seen<=0;
                if(ctrl_op!=2'b00)
                    for(i=0;i<9;i=i+1) local_acc[i]<=64'b0;
                for(i=0;i<3;i=i+1) for(j=0;j<3;j=j+1) begin
                    x_link[i][j]<=0; z_link[i][j]<=0;
                    x_valid[i][j]<=0; z_valid[i][j]<=0;
                end
            end else if(array_running) begin
                // Move features one PE to the right and weights one PE down.
                // Nonblocking assignments make every hop exactly one clock.
                for(i=0;i<3;i=i+1) begin
                    x_link[i][0] <= (wave_time==i) ? if_latched[i*64 +: 64] : 64'b0;
                    x_valid[i][0] <= (wave_time==i);
                    for(j=1;j<3;j=j+1) begin
                        x_link[i][j] <= x_link[i][j-1];
                        x_valid[i][j] <= x_valid[i][j-1];
                    end
                end
                for(j=0;j<3;j=j+1) begin
                    z_link[0][j] <= (wave_time==j) ? wt_latched[j*64 +: 64] : 64'b0;
                    z_valid[0][j] <= (wave_time==j);
                    for(i=1;i<3;i=i+1) begin
                        z_link[i][j] <= z_link[i-1][j];
                        z_valid[i][j] <= z_valid[i-1][j];
                    end
                end
                if(wave_time<15) wave_time<=wave_time+1;
                for(i=0;i<9;i=i+1)
                    if(pe_done_raw[i]) completion_seen[i]<=1'b1;
                // The last PE is launched after the r+c=4 wave.  Waiting
                // through time 7 avoids treating an unlaunched cell as done.
                if(wave_time>=7 && &(completion_seen | pe_done_raw))
                    array_running<=0;
            end
            if(last_ctrl_op==2'b00)
                for(i=0;i<9;i=i+1)
                    if(pe_done_raw[i]) local_acc[i]<=pe_result[i];
        end
    end

    generate
        for(r=0;r<3;r=r+1) begin: ROW
            for(c=0;c<3;c=c+1) begin: COL
                flex_pe_simd64_iterative pe(
                    .clk(clk),.reset(reset),.start(x_valid[r][c]&&z_valid[r][c]),
                    .host_wr_en(host_wr_en),.host_addr(host_addr),.host_wdata(host_wdata),
                    .mode(mode),.ctrl_op(ctrl_op),
                    .x_in(x_link[r][c]),.y_in(pe_y_in[r*3+c]),.z_in(z_link[r][c]),
                    .result(pe_result[r*3+c]),.done(pe_done_raw[r*3+c]),
                    .busy(pe_busy[r*3+c]),.error_overflow(pe_error[r*3+c]),
                    .iteration_count(),.precision_sel(),.sel_af());
                assign pe_outputs[(r*3+c)*64 +: 64]=pe_result[r*3+c];
            end
        end
    endgenerate
    assign pe_done=completion_seen;
    assign busy=array_running || (|pe_busy);
    assign error_overflow=|pe_error;
endmodule
