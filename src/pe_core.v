module pe_core (
    input wire clk,
    input wire rstn,

    input wire comp_en,
    input wire lut_en,

    input logic signed [15:0] x_i,
    y_i,
    attr_i,
    input logic signed [15:0] x_j,
    y_j,
    attr_j,

    output logic signed [31:0] lut_addr_out,
    output logic               lut_req_valid,
    input  logic signed [15:0] lut_data_in,
    input  logic               lut_ready,

    output logic signed [31:0] acc_x,
    acc_y
);

  pe_geometry geom_inst (
      .x_i(x_i),
      .y_i(y_i),
      .attr_i(attr_i),
      .x_j(x_j),
      .y_j(y_j),
      .attr_j(attr_j),
      .lut_addr(lut_addr_out),
      .dx_out(dx_raw),
      .dy_out(dy_raw),
      .attr_prod_out(attr_raw)
  );

  pe_accumulate acc_inst (
      .clk(clk),
      .rst_n(rst_n),
      .pe_acc_en(lut_ready && !fifo_empty),

      .dx_in(dx_fifo_out),
      .dy_in(dy_fifo_out),
      .attr_prod_in(attr_fifo_out),
      .lut_force_val(lut_data_in),

      .acc_x(acc_x),
      .acc_y(acc_y)
  );

endmodule


module pe_geometry #(
    parameter DATA_WIDTH = 16
) (
    input logic signed [DATA_WIDTH-1:0] x_i,
    y_i,
    attr_i,
    input logic signed [DATA_WIDTH-1:0] x_j,
    y_j,
    attr_j,

    output logic signed [31:0] lut_addr,

    output logic signed [DATA_WIDTH-1:0] dx_out,
    output logic signed [DATA_WIDTH-1:0] dy_out,
    output logic signed [          31:0] attr_prod_out
);

  always_comb begin
    dx_out = x_j - x_i;
    dy_out = y_j - y_i;

    lut_addr = (dx_out * dx_out) + (dy_out * dy_out);

    // Pre-calc Attribute Product
    attr_prod_out = attr_i * attr_j;
  end
endmodule


module pe_accumulate #(
    parameter DATA_WIDTH = 16,
    parameter ACC_WIDTH  = 32
) (
    input logic clk,
    input logic rst_n,
    input logic pe_acc_en,

    input logic signed [DATA_WIDTH-1:0] dx_in,
    input logic signed [DATA_WIDTH-1:0] dy_in,
    input logic signed [          31:0] attr_prod_in,
    input logic signed [DATA_WIDTH-1:0] lut_force_val,

    output logic signed [ACC_WIDTH-1:0] acc_x,
    output logic signed [ACC_WIDTH-1:0] acc_y
);

  logic signed [31:0] force_magnitude;
  logic signed [31:0] f_vec_x, f_vec_y;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      acc_x <= '0;
      acc_y <= '0;
    end else if (pe_acc_en) begin
      force_magnitude = (lut_force_val * attr_prod_in);

      f_vec_x = (force_magnitude * dx_in) >>> 8;
      f_vec_y = (force_magnitude * dy_in) >>> 8;

      acc_x <= acc_x + f_vec_x;
      acc_y <= acc_y + f_vec_y;
    end
  end

endmodule
