`timescale 1ns/1ps

module tb_pe_systolic_core_simple;

  localparam int DATA_WIDTH = 16;
  localparam int ACC_WIDTH  = 28;
  localparam int LUT_DEPTH  = 256;
  localparam int SEG_BITS   = 8;
  localparam int FRAC_BITS  = 8;

  logic clk;  initial clk = 1'b0; always #5 clk = ~clk;
  logic rst_n;

  logic in_valid;

  logic signed [DATA_WIDTH-1:0] x_i, y_i, m_i;
  logic signed [DATA_WIDTH-1:0] x_j, y_j, m_j;

  logic signed [ACC_WIDTH-1:0]  acc_in_x, acc_in_y;
  logic signed [ACC_WIDTH-1:0]  acc_out_x, acc_out_y;

  logic                      conf_wr_en;
  logic        [SEG_BITS-1:0] conf_addr;
  logic signed [15:0]         conf_data_base;
  logic signed [15:0]         conf_data_slope;

  pe_systolic_core #(
    .DATA_WIDTH(DATA_WIDTH),
    .ACC_WIDTH (ACC_WIDTH),
    .LUT_DEPTH (LUT_DEPTH),
    .SEG_BITS  (SEG_BITS),
    .FRAC_BITS (FRAC_BITS)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),

    .in_valid(in_valid),

    .x_i(x_i), .y_i(y_i), .m_i(m_i),
    .x_j(x_j), .y_j(y_j), .m_j(m_j),

    .acc_in_x(acc_in_x),
    .acc_in_y(acc_in_y),

    .acc_out_x(acc_out_x),
    .acc_out_y(acc_out_y),

    .conf_wr_en(conf_wr_en),
    .conf_addr(conf_addr),
    .conf_data_base(conf_data_base),
    .conf_data_slope(conf_data_slope)
  );

  task automatic cfg_write(input logic [7:0] idx,
                           input logic signed [15:0] base,
                           input logic signed [15:0] slope);
    begin
      @(negedge clk);
      conf_addr       <= idx;
      conf_data_base  <= base;
      conf_data_slope <= slope;
      conf_wr_en      <= 1'b1;
      @(posedge clk);
      #1;
      conf_wr_en      <= 1'b0;
      conf_addr       <= '0;
      conf_data_base  <= '0;
      conf_data_slope <= '0;
    end
  endtask

  task automatic apply_pair(
    input logic signed [15:0] xi, input logic signed [15:0] yi, input logic signed [15:0] mi_,
    input logic signed [15:0] xj, input logic signed [15:0] yj, input logic signed [15:0] mj_,
    input logic signed [ACC_WIDTH-1:0] ax_in,
    input logic signed [ACC_WIDTH-1:0] ay_in
  );
    begin
      @(negedge clk);
      x_i     <= xi;  y_i <= yi;  m_i <= mi_;
      x_j     <= xj;  y_j <= yj;  m_j <= mj_;
      acc_in_x<= ax_in;
      acc_in_y<= ay_in;
      in_valid<= 1'b1;
      @(posedge clk);
      #1;
      in_valid<= 1'b0;
    end
  endtask

  task automatic expect_xy(input string tag,
                           input logic signed [ACC_WIDTH-1:0] expx,
                           input logic signed [ACC_WIDTH-1:0] expy);
    begin
      #1;
      if ($signed(acc_out_x) !== $signed(expx) || $signed(acc_out_y) !== $signed(expy)) begin
        $display("ERROR: %s time=%0t", tag, $time);
        $display("  exp_x=%0d got_x=%0d", $signed(expx), $signed(acc_out_x));
        $display("  exp_y=%0d got_y=%0d", $signed(expy), $signed(acc_out_y));
        $fatal(1);
      end
    end
  endtask

  initial begin
    localparam logic signed [15:0] MI = 16'sh4000; // 0.5 in Q1.15
    localparam logic signed [15:0] MJ = 16'sh4000; // 0.5 in Q1.15

    localparam logic signed [15:0] XI1 = 16'sh0000;
    localparam logic signed [15:0] YI1 = 16'sh0000;
    localparam logic signed [15:0] XJ1 = 16'sd512;   // dx_int=512  => r2_code = 2 => idx=0, frac=2
    localparam logic signed [15:0] YJ1 = 16'sh0000;

    localparam logic signed [15:0] XI2 = 16'sh0000;
    localparam logic signed [15:0] YI2 = 16'sh0000;
    localparam logic signed [15:0] XJ2 = 16'sd8192;  // dx_int=8192 => r2_code = 512 => idx=2, frac=0
    localparam logic signed [15:0] YJ2 = 16'sh0000;

    localparam logic signed [ACC_WIDTH-1:0] EXP1_X = 28'sd128;    // derived expected after pair1
    localparam logic signed [ACC_WIDTH-1:0] EXP1_Y = 28'sd0;
    localparam logic signed [ACC_WIDTH-1:0] EXP2_X = 28'sd4224;   // 128 + 4096
    localparam logic signed [ACC_WIDTH-1:0] EXP2_Y = 28'sd0;

    in_valid       = 1'b0;
    x_i='0; y_i='0; m_i='0;
    x_j='0; y_j='0; m_j='0;
    acc_in_x='0; acc_in_y='0;

    conf_wr_en     = 1'b0;
    conf_addr      = '0;
    conf_data_base = '0;
    conf_data_slope= '0;

    rst_n = 1'b0;
    repeat (3) @(posedge clk);
    rst_n = 1'b1;

    // Configure only the indices we will hit:
    // idx 0: g = 1.0 (Q4.12 => 0x1000), slope=0
    // idx 2: g = 2.0 (Q4.12 => 0x2000), slope=0
    cfg_write(8'h00, 16'sh1000, 16'sh0000);
    cfg_write(8'h02, 16'sh2000, 16'sh0000);

    // Idle cycle: ensure no accidental update (output should remain 0 after reset)
    @(posedge clk);
    expect_xy("Idle hold", 28'sd0, 28'sd0);

    // Pair 1 (acc_in = 0): expect (128, 0) after 2 cycles
    apply_pair(XI1, YI1, MI, XJ1, YJ1, MJ, 28'sd0, 28'sd0);
    @(posedge clk);
    @(posedge clk);
    expect_xy("After pair1", EXP1_X, EXP1_Y);

    // Another idle window: should hold last value
    repeat (2) @(posedge clk);
    expect_xy("Hold after pair1", EXP1_X, EXP1_Y);

    // Pair 2 (acc_in = previous output): expect (4224, 0) after 2 cycles
    apply_pair(XI2, YI2, MI, XJ2, YJ2, MJ, EXP1_X, EXP1_Y);
    @(posedge clk);
    @(posedge clk);
    expect_xy("After pair2 accumulate", EXP2_X, EXP2_Y);

    $display("PASS: tb_pe_systolic_core_simple finished.");
    $finish;
  end

endmodule
