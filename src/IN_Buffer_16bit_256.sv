`timescale 1ps/1ps
module IN_BUFFER #(
    parameter N = 256,
    parameter IDX_BITS = $clog2(N)
)(
    input logic CLK_IN, RESET_IN,

//stream input
    input logic [15:0] DATA_IN,
    input logic S_VALID, 
    output logic S_READY,

    input logic CLEAR, 
    output logic FULL,

//read
input logic [IDX_BITS-1:0] RD_IDX,
input logic [1:0] RD_SEL,   //0:position X, 1:position Y, 2:Mass
output logic [15:0] DATA_OUT
);

//internal storage
logic [15:0] posX [N-1:0];
logic [15:0] posY [N-1:0];
logic [15:0] Mass [N-1:0];

logic [IDX_BITS-1:0] w_idx;
logic [1:0] w_phase;    //0:X, 1:Y, 2:M
logic full_flag;

assign S_READY = !full_flag;
assign FULL = full_flag;

wire accept = S_READY && S_VALID;

//write
always_ff @(posedge CLK_IN) begin
    if(!RESET_IN) begin
        w_idx <= 0;
        w_phase <= 0;
        full_flag <= 0;
    end
    else if(CLEAR) begin
        w_idx <= 0;
        w_phase <= 0;
        full_flag <= 0;
    end
    else if(accept) begin
        unique case (w_phase)
            2'd0:   posX[w_idx] <= DATA_IN;
            2'd1:   posY[w_idx] <= DATA_IN;
            2'd2:   Mass[w_idx] <= DATA_IN; 
            default: ;
        endcase

        if(w_phase == 2'd2) begin
            w_phase <= 2'd0;
            if(w_idx == N - 1) full_flag <= 1'b1;
            else w_idx <= w_idx + 1;
        end
        else w_phase <= w_phase + 1;
    end
end

//read mux
always_comb begin
    unique case (RD_SEL)
        2'd0:   DATA_OUT = posX[RD_IDX];
        2'd1:   DATA_OUT = posY[RD_IDX];
        2'd2:   DATA_OUT = Mass[RD_IDX];
        default:    DATA_OUT = 16'h0;
    endcase
end
        
endmodule
