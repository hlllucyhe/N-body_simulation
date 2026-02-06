module pe_core (
    input wire clk,
    input wire rstn,

    input wire signed [15:0] x_i,
    input wire signed [15:0] x_j,
    input wire signed [15:0] y_i,
    input wire signed [15:0] y_j
);

  reg signed [31:0] mult_i;
  reg signed [31:0] mult_j;


  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      mult_i <= 32'd0;
      mult_j <= 32'd0;
    end else begin
      mult_i <= (x_j - x_i) * (x_j - x_i);
      mult_j <= (y_j - y_i) * (y_j - y_i);
    end
  end

endmodule
