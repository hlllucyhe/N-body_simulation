module pe_core (
    input wire clk,
    input wire rstn,

    input wire lut_en,

    input wire signed [15:0] x_i,
    input wire signed [15:0] x_j,
    input wire signed [15:0] y_i,
    input wire signed [15:0] y_j,

    input wire signed [15:0] mass_i,
    input wire signed [15:0] mass_j,

    input wire signed [15:0] lut_data,

    output reg signed [15:0] lut_index_r,
    output reg signed [15:0] acc_x,
    output reg signed [15:0] acc_y
);




  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      lut_index_r <= 16'd0;
      acc_x       <= 16'd0;
      acc_y       <= 16'd0;
    end else begin
      lut_index_r <= (x_i - x_j) * (x_i - x_j) + (y_i - y_j) * (y_i - y_j);
      if (lut_en) begin
        acc_x <= acc_x + ((lut_data * mass_i) >>> 15);
        acc_y <= acc_y + ((lut_data * mass_j) >>> 15);
      end

    end
  end

endmodule
