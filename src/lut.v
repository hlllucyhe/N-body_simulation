module lut_core #(
    parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 32,
    parameter LUT_DEPTH  = 256,
    parameter SEG_BITS   = 8,
    parameter FRAC_BITS  = 8
) (
    input logic clk,
    input logic rst_n,

    input logic                       conf_wr_en,
    input logic        [SEG_BITS-1:0] conf_addr,
    input logic signed [        15:0] conf_data_base,
    input logic signed [        15:0] conf_data_slope,

    input logic               pe_req_valid,
    input logic signed [31:0] pe_r2_in,

    output logic signed [15:0] lut_data_out,
    output logic               lut_ready
);

  logic signed [         15:0] mem_base    [0:LUT_DEPTH-1];
  logic signed [         15:0] mem_slope   [0:LUT_DEPTH-1];


  logic signed [         15:0] s1_base;
  logic signed [         15:0] s1_slope;
  logic        [FRAC_BITS-1:0] s1_frac;
  logic                        s1_valid;

  logic signed [         31:0] s2_mult_res;
  logic signed [         15:0] s2_base_d;
  logic                        s2_valid;

  localparam signed [31:0] EPSILON = 32'd4;

  always_ff @(posedge clk) begin
    if (conf_wr_en) begin
      mem_base[conf_addr]  <= conf_data_base;
      mem_slope[conf_addr] <= conf_data_slope;
    end
  end


  wire [31:0] r2_offset = pe_r2_in + EPSILON;
  wire [SEG_BITS-1:0] segment_idx = r2_offset[SEG_BITS+FRAC_BITS-1 : FRAC_BITS];
  wire [FRAC_BITS-1:0] frac_part = r2_offset[FRAC_BITS-1 : 0];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s1_base  <= '0;
      s1_slope <= '0;
      s1_frac  <= '0;
      s1_valid <= 1'b0;
    end else begin
      s1_base  <= mem_base[segment_idx];
      s1_slope <= mem_slope[segment_idx];

      s1_frac  <= frac_part;
      s1_valid <= pe_req_valid;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      lut_data_out <= '0;
      lut_ready    <= 1'b0;
    end else begin
      // 1. Multiply Slope * Frac
      // Result width = 16 + FRAC_BITS
      // We use a temporary 32-bit register
      logic signed [31:0] raw_mult;
      raw_mult = s1_slope * $signed({1'b0, s1_frac});  // Treat frac as positive

      // 2. Shift and Add Base
      // We shift right by FRAC_BITS to normalize the fixed point
      lut_data_out <= s1_base + (raw_mult >>> FRAC_BITS);

      // 3. Output Handshake
      lut_ready <= s1_valid;
    end
  end

endmodule
