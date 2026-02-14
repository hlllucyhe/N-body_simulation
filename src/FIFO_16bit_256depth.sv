`timescale 1ps/1ps
module FIFO #(
      parameter DEPTH = 256,
      parameter WIDTH = 16,
      parameter ADDER_BITS = $clog2(DEPTH)
)(
      input logic CLK_IN, RESET_IN,

//push side
      input logic [15:0] DIN,
      input logic DIN_VALID,
      output logic DIN_READY,

//pop side
      output logic [15:0] DOUT,
      output logic DOUT_VALID,
      input logic DOUT_READY,

      output logic [ADDER_BITS:0] level
);
      logic [WIDTH-1:0] mem [DEPTH-1:0];
      logic [ADDER_BITS-1:0] wptr, rptr;
      logic [ADDER_BITS:0] count;

      assign DIN_READY = (count < DEPTH);
      assign DOUT = mem[rptr];
      assign DOUT_VALID = (count > 0);
      assign level = count;

      wire push = DIN_READY && DIN_VALID;
      wire pop = DOUT_READY && DOUT_VALID;

      always_ff @( posedge CLK_IN ) begin
            if(!RESET_IN)begin
                  wptr <= 0;
                  rptr <= 0;
                  count <= 0;
            end
            else begin
//write            
                  if(push) begin
                        mem[wptr] <= DIN;
                        wptr <= (wptr == DEPTH - 1)? 0 : wptr + 1;
                  end
//read pointer advance
                  if(pop) rptr <= (rptr == DEPTH - 1)? 0 : rptr + 1;
// update count
            unique case ({push, pop})
                  2'b10:      count <= count + 1;
                  2'b01:      count <= count - 1;       
                  default:    ; 
            endcase
            end
      end

endmodule