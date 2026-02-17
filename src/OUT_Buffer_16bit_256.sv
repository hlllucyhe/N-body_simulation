`timescale 1ps/1ps
module OUT_BUFFER #(
    parameter N = 256,
    parameter IDX_BITS = $clog2(N)
)(
    input  logic CLK_IN,
    input  logic RESET_IN,

    input  logic CLEAR, FRAME_VALID,

    // random write side (from compute core)
    input  logic        WR_EN,
    input  logic [IDX_BITS-1:0] WR_IDX,
    input  logic [15:0] FORCE_X, FORCE_Y,

    // stream output side
    output logic [15:0] DATA_OUT,
    output logic D_VALID,
    input  logic D_READY,

    output logic DONE              // level-high when one full frame is sent
);

    logic [15:0] force_X [N-1:0];
    logic [15:0] force_Y [N-1:0];

always_ff @(posedge CLK_IN) begin
    if (!RESET_IN) begin
    end 
    else if(WR_EN) begin
        force_X[WR_IDX] <= FORCE_X;
        force_Y[WR_IDX] <= FORCE_Y;
    end
end
        
//stream read logic
logic [IDX_BITS-1:0] rd_idx;
logic rd_phase;                 //0:X, 1:Y
logic done_flag;

assign D_VALID = FRAME_VALID && !done_flag;
assign DONE = done_flag;

always_comb begin
    if (!FRAME_VALID || done_flag) DATA_OUT = 16'h0;
    else DATA_OUT = (rd_phase == 1'b0)? force_X[rd_idx] : force_Y[rd_idx];
end

wire fire = D_VALID && D_READY;

always_ff @( posedge CLK_IN ) begin
    if (!RESET_IN) begin
        rd_idx <= 0;
        rd_phase <= 1'b0;
        done_flag <= 1'b0;
    end
    else if (CLEAR || !frame_valid) begin
        rd_idx <= 0;
        rd_phase <= 1'b0;
        done_flag <= 1'b0;
    end
    else if (fire) begin
        if (rd_phase == 1'b0) rd_phase <= 1'b1;
        else begin
            rd_phase <= 1'b0;
            if (rd_idx == N - 1) done_flag <= 1'b1;
            else rd_idx <= rd_idx + 1;
        end
    end
end

endmodule
