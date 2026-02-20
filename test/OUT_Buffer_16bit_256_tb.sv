`timescale 1ps/1ps

module tb_OUT_BUFFER;

    localparam int N = 4;
    localparam int IDX_BITS = $clog2(N);

    logic CLK_IN;
    logic RESET_IN;

    logic CLEAR;
    logic FRAME_VALID;

    logic WR_EN;
    logic [IDX_BITS-1:0] WR_IDX;
    logic [15:0] FORCE_X;
    logic [15:0] FORCE_Y;

    logic [15:0] DATA_OUT;
    logic D_VALID;
    logic D_READY;
    logic DONE;

    OUT_BUFFER #(
        .N(N),
        .IDX_BITS(IDX_BITS)
    ) dut (
        .CLK_IN(CLK_IN),
        .RESET_IN(RESET_IN),
        .CLEAR(CLEAR),
        .FRAME_VALID(FRAME_VALID),
        .WR_EN(WR_EN),
        .WR_IDX(WR_IDX),
        .FORCE_X(FORCE_X),
        .FORCE_Y(FORCE_Y),
        .DATA_OUT(DATA_OUT),
        .D_VALID(D_VALID),
        .D_READY(D_READY),
        .DONE(DONE)
    );

    initial begin
        CLK_IN = 0;
        forever #5 CLK_IN = ~CLK_IN;
    end

    task write_xy(input [IDX_BITS-1:0] idx, input [15:0] x, input [15:0] y);
        begin
            @(posedge CLK_IN);
            WR_EN   = 1'b1;
            WR_IDX  = idx;
            FORCE_X = x;
            FORCE_Y = y;
            @(posedge CLK_IN);
            WR_EN   = 1'b0;
            FORCE_X = '0;
            FORCE_Y = '0;
            $display("[%0t] WRITE idx=%0d X=%h Y=%h", $time, idx, x, y);
        end
    endtask

    task check_beat(input [15:0] expected, input string tag);
        begin
            while (!(D_VALID && D_READY)) @(posedge CLK_IN);
            #1;
            if (DATA_OUT !== expected) begin
                $error("[%0t] %s FAIL: expected=%h got=%h", $time, tag, expected, DATA_OUT);
            end else begin
                $display("[%0t] %s OK: %h", $time, tag, DATA_OUT);
            end
            @(posedge CLK_IN);
        end
    endtask

    initial begin
        RESET_IN    = 1'b0;
        CLEAR       = 1'b0;
        FRAME_VALID = 1'b0;
        WR_EN       = 1'b0;
        WR_IDX      = '0;
        FORCE_X     = '0;
        FORCE_Y     = '0;
        D_READY     = 1'b0;

        #20;
        RESET_IN = 1'b1;
        $display("[%0t] Reset deasserted", $time);

        write_xy(0, 16'h1001, 16'h2001);
        write_xy(1, 16'h1002, 16'h2002);
        write_xy(2, 16'h1003, 16'h2003);
        write_xy(3, 16'h1004, 16'h2004);

        @(posedge CLK_IN);
        FRAME_VALID = 1'b1;
        D_READY     = 1'b1;
        $display("\n---> Test 1: Normal streaming order X0,Y0,X1,Y1,...");

        check_beat(16'h1001, "beat0 X0");
        check_beat(16'h2001, "beat1 Y0");
        check_beat(16'h1002, "beat2 X1");
        check_beat(16'h2002, "beat3 Y1");

        $display("\n---> Test 2: Backpressure (D_READY=0 should hold state)");
        D_READY = 1'b0;
        repeat (3) @(posedge CLK_IN);
        if (D_VALID !== 1'b1) $error("[%0t] D_VALID dropped during backpressure", $time);
        D_READY = 1'b1;

        check_beat(16'h1003, "beat4 X2");
        check_beat(16'h2003, "beat5 Y2");
        check_beat(16'h1004, "beat6 X3");
        check_beat(16'h2004, "beat7 Y3");

        #1;
        if (DONE !== 1'b1) $error("[%0t] DONE not asserted after full frame", $time);
        else $display("[%0t] DONE asserted correctly", $time);

        if (D_VALID !== 1'b0) $error("[%0t] D_VALID should be 0 after DONE", $time);

        $display("\n---> Test 3: CLEAR resets stream state");
        @(posedge CLK_IN);
        CLEAR = 1'b1;
        @(posedge CLK_IN);
        CLEAR = 1'b0;
        #1;
        if (DONE !== 1'b0) $error("[%0t] DONE not cleared by CLEAR", $time);

        D_READY = 1'b1;
        FRAME_VALID = 1'b1;
        check_beat(16'h1001, "after CLEAR beat0 X0");
        check_beat(16'h2001, "after CLEAR beat1 Y0");

        $display("\n---> Test 4: FRAME_VALID low resets read pointer");
        @(posedge CLK_IN);
        FRAME_VALID = 1'b0;
        repeat (2) @(posedge CLK_IN);
        FRAME_VALID = 1'b1;

        check_beat(16'h1001, "after FRAME_VALID toggle X0");
        check_beat(16'h2001, "after FRAME_VALID toggle Y0");

        #30;
        $display("\nSimulation Complete.");
        $finish;
    end

    initial begin
        $dumpfile("out_buffer_dump.vcd");
        $dumpvars(0, tb_OUT_BUFFER);
    end

endmodule
