module pe_systolic_core #(
    parameter int DATA_WIDTH = 16,
    parameter int ACC_WIDTH  = 28,
    parameter int LUT_DEPTH  = 256,
    parameter int SEG_BITS   = 8,
    parameter int FRAC_BITS  = 8
) (
    input  logic clk,
    input  logic rst_n,

    input  logic in_valid,

    input  logic signed [DATA_WIDTH-1:0] x_i,
    input  logic signed [DATA_WIDTH-1:0] y_i,
    input  logic signed [DATA_WIDTH-1:0] m_i,

    input  logic signed [DATA_WIDTH-1:0] x_j,
    input  logic signed [DATA_WIDTH-1:0] y_j,
    input  logic signed [DATA_WIDTH-1:0] m_j,

    input  logic signed [ACC_WIDTH-1:0]  acc_in_x,
    input  logic signed [ACC_WIDTH-1:0]  acc_in_y,

    output logic signed [ACC_WIDTH-1:0]  acc_out_x,
    output logic signed [ACC_WIDTH-1:0]  acc_out_y,

    input  logic                      conf_wr_en,
    input  logic        [SEG_BITS-1:0] conf_addr,
    input  logic signed [15:0]         conf_data_base,
    input  logic signed [15:0]         conf_data_slope
);

  logic signed [DATA_WIDTH:0]	dx_g, dy_g;
  logic [15:0] r2_code_g;
  logic signed [DATA_WIDTH:0]   mprod_g;

  // combinational computation of dx, dy, r^2, and attr_product
  pe_geometry #(.DATA_WIDTH(DATA_WIDTH)) u_geom (
    .x_i(x_i), .y_i(y_i), .m_i(m_i),
    .x_j(x_j), .y_j(y_j), .m_j(m_j),
    .dx_out(dx_g), 
    .dy_out(dy_g), 
    .r2_code_out(r2_code_g), 
    .m_prod_out(mprod_g)
  );

  logic signed [15:0] lut_data;
  logic lut_ready;

  lut_bs_core #(
      .DATA_WIDTH(DATA_WIDTH),
      .LUT_DEPTH(LUT_DEPTH),
      .SEG_BITS(SEG_BITS),
      .FRAC_BITS(FRAC_BITS)
  ) u_lut (
      .clk(clk),
      .rst_n(rst_n),
      .conf_wr_en(conf_wr_en),
      .conf_addr(conf_addr),
      .conf_data_base(conf_data_base),
      .conf_data_slope(conf_data_slope),
      .pe_req_valid(in_valid),
      .pe_r2_code(r2_code_g),
      .lut_data_out(lut_data),
      .lut_ready(lut_ready)
  );
  
  // Register the geometry outputs to align with LUT outputs for the PE accumulate stage
  logic signed [DATA_WIDTH:0] dx_d1, dy_d1;
  logic signed [DATA_WIDTH:0] mprod_d1;
  logic vld_d1;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      dx_d1    <= '0;
      dy_d1    <= '0;
      mprod_d1 <= '0;
      vld_d1   <= 1'b0;
    end else begin
      dx_d1    <= dx_g;
      dy_d1    <= dy_g;
      mprod_d1 <= mprod_g;
      vld_d1   <= in_valid;
    end
  end
  
  logic pe_acc_en;
  assign pe_acc_en = lut_ready & vld_d1;

  pe_accumulate_systolic #(
      .DATA_WIDTH(DATA_WIDTH),
      .ACC_WIDTH(ACC_WIDTH)
  ) u_acc (
      .clk(clk),
      .rst_n(rst_n),
      .pe_acc_en(pe_acc_en),
      .acc_in_x(acc_in_x),
      .acc_in_y(acc_in_y),
      .dx_in(dx_d1),
      .dy_in(dy_d1),
      .attr_prod_in(mprod_d1),
      .lut_force_val(lut_data),
      .acc_out_x(acc_out_x),
      .acc_out_y(acc_out_y)
  );

endmodule

// combinational logic to compute r2
module pe_geometry #(
    parameter int DATA_WIDTH = 16
) (
  input  logic signed [DATA_WIDTH-1:0] x_i,	// signed Q1.15
  input  logic signed [DATA_WIDTH-1:0] y_i,	// signed Q1.15
  input  logic signed [DATA_WIDTH-1:0] m_i,	// signed Q1.15

  input  logic signed [DATA_WIDTH-1:0] x_j,	// signed Q1.15
  input  logic signed [DATA_WIDTH-1:0] y_j,	// signed Q1.15
  input  logic signed [DATA_WIDTH-1:0] m_j,	// signed Q1.15

  output logic signed [DATA_WIDTH:0] dx_out,		// signed Q2.15
  output logic signed [DATA_WIDTH:0] dy_out,		// signed Q2.15
  output logic        [DATA_WIDTH-1:0]         r2_code_out,  // unsigned Q3.13
  output logic signed [DATA_WIDTH:0]         m_prod_out    // signed Q2.15 (one extra bit for +1)
);

  logic signed [31:0] m_prod_full;	// signed Q2.30
  logic signed [33:0] dx2_w, dy2_w;	//signed Q4.30
  logic [31:0] dx2, dy2;	// unsigned Q2.30
  logic [32:0] r2_q330;		// unsigned Q3.30
  logic [32:0] r2_shifted;	// unsigned Q3.13

  always_comb begin
    dx_out = $signed({x_j[DATA_WIDTH-1], x_j}) - $signed({x_i[DATA_WIDTH-1], x_i});
    dy_out = $signed({y_j[DATA_WIDTH-1], y_j}) - $signed({y_i[DATA_WIDTH-1], y_i});

    dx2_w = dx_out * dx_out; 
    dy2_w = dy_out * dy_out;
    
    dx2 = dx2_w[31:0];
    dy2 = dy2_w[31:0];

    r2_q330 = {1'b0, dx2} + {1'b0, dy2};

    r2_shifted = r2_q330 >> 17;
    if (r2_shifted > 33'd65535) r2_code_out = 16'hFFFF;
    else                        r2_code_out = r2_shifted[15:0];

    m_prod_full = $signed(m_i) * $signed(m_j);
    m_prod_out = $signed((m_prod_full + 32'sd16384) >>> 15);	// round and truncate
  end

endmodule

// LUT module
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


// calculate pairwise force from lut output and accumulate
module pe_accumulate_systolic #(
    parameter int DATA_WIDTH = 16,
    parameter int ACC_WIDTH  = 28
) (
    input  logic clk,
    input  logic rst_n,
    input  logic pe_acc_en,

  input  logic signed [ACC_WIDTH-1:0]  acc_in_x,	// Q13.15 accumulate
  input  logic signed [ACC_WIDTH-1:0]  acc_in_y,	// Q13.15 accumulate

  input  logic signed [DATA_WIDTH:0] dx_in,				// Q2.15
  input  logic signed [DATA_WIDTH:0] dy_in,				// Q2.15
  input  logic signed [DATA_WIDTH:0] attr_prod_in,		// Q2.15
  input  logic signed [DATA_WIDTH-1:0] lut_force_val,	// Q4.12

  output logic signed [ACC_WIDTH-1:0]  acc_out_x,	// Q13.15
  output logic signed [ACC_WIDTH-1:0]  acc_out_y	// Q13.15
);

  logic signed [32:0] force_mag_full;	// Q4.12*Q2.15 = Q6.27
  logic signed [19:0] force_mag;		// Q5.15
  logic signed [36:0] fvx_w, fvy_w;		// Q5.15*Q2.15 = Q7.30
  logic signed [20:0] fvx, fvy;			// Q6.15

  always_comb begin
    force_mag_full = $signed(lut_force_val) * $signed(attr_prod_in);
    force_mag = $signed((force_mag_full + 33'sd2048) >>> 12);	// round and shift
    
    fvx_w = $signed(force_mag) * $signed(dx_in);
    fvy_w = $signed(force_mag) * $signed(dy_in);
    fvx = $signed((fvx_w + 37'sd16384) >>> 15);
    fvy = $signed((fvy_w + 37'sd16384) >>> 15);
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      acc_out_x <= '0;
      acc_out_y <= '0;
    end else if (pe_acc_en) begin
      acc_out_x <= $signed(acc_in_x) + $signed({{(ACC_WIDTH-21){fvx[20]}}, fvx});
      acc_out_y <= $signed(acc_in_y) + $signed({{(ACC_WIDTH-21){fvy[20]}}, fvy});
    end
  end

endmodule


