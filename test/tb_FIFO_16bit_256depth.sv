`timescale 1ps/1ps

module tb_FIFO;

    // --- Parameters ---
    // Overriding the default depth to 16 so we can test the FULL condition quickly
    localparam DEPTH = 16; 
    localparam WIDTH = 16;
    localparam ADDER_BITS = $clog2(DEPTH);

    // --- Signals ---
    logic CLK_IN;
    logic RESET_IN;
    
    // Push side
    logic [15:0] DIN;
    logic DIN_VALID;
    logic DIN_READY;
    
    // Pop side
    logic [15:0] DOUT;
    logic DOUT_VALID;
    logic DOUT_READY;
    
    logic [ADDER_BITS:0] level;

    // --- DUT Instantiation ---
    FIFO #(
        .DEPTH(DEPTH),
        .WIDTH(WIDTH),
        .ADDER_BITS(ADDER_BITS)
    ) dut (
        .CLK_IN(CLK_IN),
        .RESET_IN(RESET_IN),
        .DIN(DIN),
        .DIN_VALID(DIN_VALID),
        .DIN_READY(DIN_READY),
        .DOUT(DOUT),
        .DOUT_VALID(DOUT_VALID),
        .DOUT_READY(DOUT_READY),
        .level(level)
    );

    // --- Clock Generation ---
    initial begin
        CLK_IN = 0;
        forever #5 CLK_IN = ~CLK_IN; // 100GHz clock based on 1ps/1ps timescale (10ps period)
    end

    // --- Helper Tasks ---
    // Task to safely write data into the FIFO using the Ready/Valid handshake
    task push_data(input [15:0] data);
        begin
            @(posedge CLK_IN);
            DIN = data;
            DIN_VALID = 1;
            // Wait until the FIFO is actually ready to accept the data
            wait(DIN_READY == 1'b1);
            @(posedge CLK_IN);
            DIN_VALID = 0;
        end
    endtask

    // Task to safely read data from the FIFO using the Ready/Valid handshake
    task pop_data();
        begin
            @(posedge CLK_IN);
            DOUT_READY = 1;
            // Wait until the FIFO actually has valid data to output
            wait(DOUT_VALID == 1'b1);
            @(posedge CLK_IN);
            DOUT_READY = 0;
        end
    endtask

    // --- Test Sequence ---
    initial begin
        // 1. Initialize Signals
        RESET_IN = 0; // Active low reset based on your DUT
        DIN = 0;
        DIN_VALID = 0;
        DOUT_READY = 0;

        // 2. Apply Reset
        #20;
        RESET_IN = 1;
        $display("[%0t] Reset Deasserted", $time);
        #10;

        // 3. Test 1: Simple Push and Pop
        $display("\n--- Starting Test 1: Single Push and Pop ---");
        push_data(16'hAAAA);
        $display("[%0t] Pushed 16'hAAAA. Current Level = %0d", $time, level);
        
        pop_data();
        $display("[%0t] Popped data: 16'h%0h. Current Level = %0d", $time, DOUT, level);

        // 4. Test 2: Fill the FIFO completely
        $display("\n--- Starting Test 2: Filling the FIFO ---");
        for (int i = 0; i < DEPTH; i++) begin
            push_data(i);
            $display("[%0t] Pushed: %0d | Level: %0d | DIN_READY: %0b", $time, i, level, DIN_READY);
        end
        if (DIN_READY == 1'b0) 
            $display("-> SUCCESS: FIFO is FULL. DIN_READY safely dropped to 0.");

        // 5. Test 3: Empty the FIFO completely
        $display("\n--- Starting Test 3: Emptying the FIFO ---");
        for (int i = 0; i < DEPTH; i++) begin
            pop_data();
            $display("[%0t] Popped: %0d | Level: %0d | DOUT_VALID: %0b", $time, DOUT, level, DOUT_VALID);
        end
        if (DOUT_VALID == 1'b0) 
            $display("-> SUCCESS: FIFO is EMPTY. DOUT_VALID safely dropped to 0.");

        // 6. Test 4: Concurrent Read and Write
        $display("\n--- Starting Test 4: Simultaneous Push and Pop ---");
        // Pre-load one item so we have something to read
        push_data(16'h1111);
        
        @(posedge CLK_IN);
        DIN = 16'h2222;
        DIN_VALID = 1;
        DOUT_READY = 1; // Assert read and write at the same time
        
        @(posedge CLK_IN);
        DIN_VALID = 0;
        DOUT_READY = 0;
        $display("[%0t] Performed simultaneous push and pop. Level should remain the same: %0d", $time, level);

        // Finish Simulation
        #50;
        $display("\nSimulation Complete.");
        $finish;
    end

    // --- Waveform Dumping (Optional but recommended) ---
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_FIFO);
    end

endmodule