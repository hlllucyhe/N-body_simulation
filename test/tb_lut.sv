`timescale 1ns/1ps

module tb_lut;

  localparam int SEG_BITS   = 8;
  localparam int FRAC_BITS  = 8;
  localparam int LUT_DEPTH  = 256;

  // clock/reset
  logic clk;
  logic rst_n;

  initial clk = 0;
  always #5 clk = ~clk;

  // stream config input
  logic                 conf_mode;
  logic                 din_valid;
  logic signed [15:0]   din;

  // fsm -> lut_core config bus
  logic                 conf_wr_en;
  logic [SEG_BITS-1:0]  conf_addr;
  logic signed [15:0]   conf_data_base;
  logic signed [15:0]   conf_data_slope;

  // status/debug
  logic conf_done;
  logic configured;
  logic [SEG_BITS-1:0] ptr_dbg;
  logic [1:0]          state_dbg;

  // PE request
  logic                 pe_req_valid;
  logic [15:0]          pe_r2_code;
  logic signed [15:0]   lut_data_out;
  logic                 lut_ready;

  // ----------------------
  // DUT instances
  // ----------------------
  lut_core #(
    .DATA_WIDTH(16),
    .LUT_DEPTH(LUT_DEPTH),
    .SEG_BITS(SEG_BITS),
    .FRAC_BITS(FRAC_BITS)
  ) dut_lut (
    .clk(clk),
    .rst_n(rst_n),

    .conf_wr_en(conf_wr_en),
    .conf_addr(conf_addr),
    .conf_data_base(conf_data_base),
    .conf_data_slope(conf_data_slope),

    .pe_req_valid(pe_req_valid),
    .pe_r2_code(pe_r2_code),

    .lut_data_out(lut_data_out),
    .lut_ready(lut_ready)
  );

  lut_conf_fsm_stream #(
    .SEG_BITS(SEG_BITS),
    .LUT_DEPTH(LUT_DEPTH)
  ) dut_fsm (
    .clk(clk),
    .rst_n(rst_n),

    .conf_mode(conf_mode),
    .din_valid(din_valid),
    .din(din),

    .conf_wr_en(conf_wr_en),
    .conf_addr(conf_addr),
    .conf_data_base(conf_data_base),
    .conf_data_slope(conf_data_slope),

    .conf_done(conf_done),
    .configured(configured),

    .ptr_dbg(ptr_dbg),
    .state_dbg(state_dbg)
  );

  // ----------------------
  // TB golden tables
  // ----------------------
  logic signed [15:0] tb_base  [0:LUT_DEPTH-1];
  logic signed [15:0] tb_slope [0:LUT_DEPTH-1];

  // Match LUT core (after your fix): 16x9 => 25-bit (NO trunc to 24)
  function automatic logic signed [15:0] tb_eval_g(
    input logic signed [15:0] base,
    input logic signed [15:0] slope,
    input logic [7:0]         frac
  );
    logic signed [24:0] slope_mul_frac_25;
    logic signed [15:0] interp_term;
    logic signed [16:0] g_ext;
    begin
      slope_mul_frac_25 = slope * $signed({1'b0, frac});
      interp_term       = slope_mul_frac_25 >>> FRAC_BITS;
      g_ext             = $signed({base[15], base}) + $signed({interp_term[15], interp_term});
      tb_eval_g         = g_ext[15:0];
    end
  endfunction

  // drive one 16-bit config beat (1 cycle valid)
  task automatic send_conf_word(input logic signed [15:0] w);
    begin
      din       <= w;
      din_valid <= 1'b1;
      @(posedge clk);
      din_valid <= 1'b0;
      din       <= '0;
    end
  endtask

  // issue one PE request and check
  task automatic check_one(input logic [15:0] r2_code);
    logic [7:0] idx;
    logic [7:0] frac;
    logic signed [15:0] exp;
    begin
      idx  = r2_code[15:8];
      frac = r2_code[7:0];
      exp  = tb_eval_g(tb_base[idx], tb_slope[idx], frac);

      pe_r2_code   <= r2_code;
      pe_req_valid <= 1'b1;
      @(posedge clk);
      #1;
      pe_req_valid <= 1'b0;

      if (lut_ready !== 1'b1) begin
        $display("ERROR: lut_ready not asserted. r2_code=%h time=%0t", r2_code, $time);
        $fatal(1);
      end

      if (lut_data_out !== exp) begin
        $display("ERROR: mismatch r2_code=%h idx=%0d frac=%0d exp=%h got=%h time=%0t",
                 r2_code, idx, frac, exp, lut_data_out, $time);
        $fatal(1);
      end
    end
  endtask

  // ----------------------
  // Main
  // ----------------------
  initial begin
    // declarations must be first
    int fd;
    int entry;
    int r;
    logic [31:0] word32;
    int timeout;

    // init
    conf_mode    = 1'b0;
    din_valid    = 1'b0;
    din          = '0;
    pe_req_valid = 1'b0;
    pe_r2_code   = '0;

    // reset
    rst_n = 1'b0;
    repeat (3) @(posedge clk);
    rst_n = 1'b1;

    // IMPORTANT: generate conf_start edge AFTER reset, then WAIT 1 cycle before streaming data
    @(posedge clk);
    conf_mode = 1'b0;
    @(posedge clk);
    conf_mode = 1'b1;      // rising edge -> FSM enters ST_GET_B
    @(posedge clk);        // <-- critical: allow FSM to settle into GET_B before first base beat

    // open packed file (each line: {base[31:16], slope[15:0]})
    fd = $fopen("LUT_packed_32b.txt", "r");
    if (fd == 0) begin
      $display("ERROR: cannot open LUT_packed_32b.txt (put it in sim working dir).");
      $fatal(1);
    end

    // load exactly 256 lines
    entry = 0;
    while (entry < LUT_DEPTH) begin
      r = $fscanf(fd, "%h\n", word32);
      if (r != 1) begin
        $display("ERROR: packed file ended early at entry=%0d (need %0d lines).", entry, LUT_DEPTH);
        $fatal(1);
      end

      // packed format: {base[31:16], slope[15:0]}
      tb_base[entry]  = $signed(word32[31:16]);
      tb_slope[entry] = $signed(word32[15:0]);

      // stream b then s
      send_conf_word(tb_base[entry]);
      send_conf_word(tb_slope[entry]);

      entry++;
    end
    $fclose(fd);

    // wait configured with timeout
    timeout = 0;
    while (configured !== 1'b1 && timeout < 4000) begin
      @(posedge clk);
      timeout++;
    end
    if (configured !== 1'b1) begin
      $display("ERROR: never reached configured. state=%0d ptr=%h", state_dbg, ptr_dbg);
      $fatal(1);
    end
    $display("INFO: LUT configured. entries_loaded=%0d", entry);

    // quick checks
    check_one(16'h0000);
    check_one(16'h0001);
    check_one(16'h00FF);
    check_one(16'h0100);
    check_one(16'h01AB);
    check_one(16'h7A12);
    check_one(16'h8080);
    check_one(16'hFF00);
    check_one(16'hFFFF);

    $display("PASS: tb_lut finished.");
    $finish;
  end

endmodule

