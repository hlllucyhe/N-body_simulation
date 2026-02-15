module lut_bs_core #(
    parameter int DATA_WIDTH = 16,
    parameter int LUT_DEPTH  = 256,
    parameter int SEG_BITS   = 8,
    parameter int FRAC_BITS  = 8
) (
    input  logic                     clk,
    input  logic                     rst_n,

    // config
    input  logic                      conf_wr_en,
    input  logic        [SEG_BITS-1:0] conf_addr,
    input  logic signed [15:0]         conf_data_base,
    input  logic signed [15:0]         conf_data_slope,

    // PE request
    input  logic                      pe_req_valid,
    input  logic        [15:0]         pe_r2_code,     // {idx[15:8], frac[7:0]}

    output logic signed [15:0]         lut_data_out,    // output Q4.12
    output logic                      lut_ready
);

  logic signed [15:0] lut_base  [0:LUT_DEPTH-1];
  logic signed [15:0] lut_slope [0:LUT_DEPTH-1];

  always_ff @(posedge clk) begin
    if (conf_wr_en) begin
      lut_base [conf_addr] <= conf_data_base;
      lut_slope[conf_addr] <= conf_data_slope;
    end
  end

  logic [SEG_BITS-1:0]  idx;
  logic [FRAC_BITS-1:0] frac;

  logic signed [15:0] base_val, slope_val;
  logic signed [24:0] slope_mul_frac;
  logic signed [15:0] interp_term;
  logic signed [16:0] g_ext;

  always_comb begin
    idx  = pe_r2_code[15:8];
    frac = pe_r2_code[7:0];

    base_val  = lut_base[idx];
    slope_val = lut_slope[idx];

    if (conf_wr_en && (conf_addr == idx)) begin
      base_val  = conf_data_base;
      slope_val = conf_data_slope;
    end

    slope_mul_frac = slope_val * $signed({1'b0, frac}); // 16x9 -> 25 (kept in 24 ok-ish)
    interp_term    = slope_mul_frac >>> FRAC_BITS;

    g_ext = $signed({base_val[15], base_val}) + $signed({interp_term[15], interp_term});
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      lut_data_out <= '0;
      lut_ready    <= 1'b0;
    end else begin
      lut_ready <= 1'b0;
      if (pe_req_valid) begin
        lut_data_out <= g_ext[15:0];
        lut_ready    <= 1'b1;
      end
    end
  end

endmodule

