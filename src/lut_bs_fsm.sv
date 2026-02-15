//Maybe merged to the top fsm, or the LUT should not exist at all...

module lut_conf_fsm_stream #(
    parameter int SEG_BITS  = 8,
    parameter int LUT_DEPTH = 256
) (
    input  logic                 clk,
    input  logic                 rst_n,

    input  logic                 conf_mode,   

    input  logic                 din_valid,
    input  logic signed [15:0]   din,

    // to lut_core
    output logic                 conf_wr_en,      // COMB pulse in ST_GET_S when din_valid
    output logic [SEG_BITS-1:0]  conf_addr,       // current ptr
    output logic signed [15:0]   conf_data_base,  // held base
    output logic signed [15:0]   conf_data_slope, // current din

    output logic                 conf_done,       
    output logic                 configured,      

    output logic [SEG_BITS-1:0]  ptr_dbg,
    output logic [1:0]           state_dbg
);

  localparam int LAST = LUT_DEPTH - 1;

  typedef enum logic [1:0] {
    ST_READY = 2'd0,
    ST_GET_B = 2'd1,
    ST_GET_S = 2'd2
  } state_t;

  state_t st, st_next;

  logic [SEG_BITS-1:0] ptr, ptr_next;
  logic signed [15:0]  base_hold, base_hold_next;

  logic configured_next;

  // conf_mode rising edge detect
  logic conf_mode_d;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) conf_mode_d <= 1'b0;
    else        conf_mode_d <= conf_mode;
  end
  wire conf_start = conf_mode & ~conf_mode_d;

  // address/data outputs (combinational)
  assign conf_addr       = ptr;
  assign conf_data_base  = base_hold;
  assign conf_data_slope = din;

  // *** CRITICAL: Mealy pulses for write & done ***
  assign conf_wr_en = (st == ST_GET_S) && din_valid;
  assign conf_done  = (st == ST_GET_S) && din_valid && (ptr == LAST[SEG_BITS-1:0]);

  // next-state logic
  always_comb begin
    st_next        = st;
    ptr_next       = ptr;
    base_hold_next = base_hold;

    configured_next = configured; // sticky by default

    unique case (st)
      ST_READY: begin
        if (conf_start) begin
          st_next         = ST_GET_B;
          ptr_next        = '0;
          base_hold_next  = '0;
          configured_next = 1'b0; // new load clears done
        end
      end

      ST_GET_B: begin
        if (din_valid) begin
          base_hold_next = din;
          st_next        = ST_GET_S;
        end
      end

      ST_GET_S: begin
        if (din_valid) begin
          if (ptr == LAST[SEG_BITS-1:0]) begin
            configured_next = 1'b1;
            st_next         = ST_READY;
          end else begin
            ptr_next = ptr + 1'b1;
            st_next  = ST_GET_B;
          end
        end
      end

      default: st_next = ST_READY;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      st         <= ST_READY;
      ptr        <= '0;
      base_hold  <= '0;
      configured <= 1'b0;
    end else begin
      st         <= st_next;
      ptr        <= ptr_next;
      base_hold  <= base_hold_next;
      configured <= configured_next;
    end
  end

  assign ptr_dbg   = ptr;
  assign state_dbg = st;

endmodule

