`timescale 1ps/1ps

module tb_IN_BUFFER;

    // --- Parameters ---
    localparam N = 4; // 减小深度以便快速测试 FULL 状态
    localparam IDX_BITS = $clog2(N);

    // --- Signals ---
    logic CLK_IN;
    logic RESET_IN;
    
    // Stream input
    logic [15:0] DATA_IN;
    logic S_VALID;
    logic S_READY;
    
    // Control
    logic CLEAR;
    logic FULL;
    
    // Read ports
    logic [IDX_BITS-1:0] RD_IDX;
    logic [1:0] RD_SEL;
    logic [15:0] DATA_OUT;

    // --- DUT Instantiation ---
    IN_BUFFER #(
        .N(N),
        .IDX_BITS(IDX_BITS)
    ) dut (
        .CLK_IN(CLK_IN),
        .RESET_IN(RESET_IN),
        .DATA_IN(DATA_IN),
        .S_VALID(S_VALID),
        .S_READY(S_READY),
        .CLEAR(CLEAR),
        .FULL(FULL),
        .RD_IDX(RD_IDX),
        .RD_SEL(RD_SEL),
        .DATA_OUT(DATA_OUT)
    );

    // --- Clock Generation ---
    initial begin
        CLK_IN = 0;
        forever #5 CLK_IN = ~CLK_IN; // 10ps period (100GHz based on 1ps/1ps)
    end

    // --- Helper Tasks ---
    // 单次写入握手任务
    task push_word(input [15:0] data, input string name);
        begin
            @(posedge CLK_IN);
            DATA_IN = data;
            S_VALID = 1;
            wait(S_READY == 1'b1); // 等待模块准备好接收
            $display("[%0t] Pushed %s: 16'h%0h", $time, name, data);
            @(posedge CLK_IN);
            S_VALID = 0;
        end
    endtask

    // 写入一个完整的粒子信息 (X, Y, Mass)
    task push_particle(input [15:0] x, input [15:0] y, input [15:0] m);
        begin
            push_word(x, "PosX");
            push_word(y, "PosY");
            push_word(m, "Mass");
            $display("--- Particle written ---");
        end
    endtask

    // 验证读取数据任务
    task check_read(input [IDX_BITS-1:0] idx, input [1:0] sel, input [15:0] expected);
        begin
            RD_IDX = idx;
            RD_SEL = sel;
            #1; // 等待组合逻辑结算
            if (DATA_OUT === expected) begin
                $display("[%0t] READ OK - Idx: %0d, Sel: %0d | Data: 16'h%0h", $time, idx, sel, DATA_OUT);
            end else begin
                $error("[%0t] READ FAIL - Idx: %0d, Sel: %0d | Expected: 16'h%0h, Got: 16'h%0h", $time, idx, sel, expected, DATA_OUT);
            end
        end
    endtask

    // --- Test Sequence ---
    initial begin
        // 1. 初始化
        RESET_IN = 0;
        CLEAR = 0;
        DATA_IN = 0;
        S_VALID = 0;
        RD_IDX = 0;
        RD_SEL = 0;

        // 2. 复位释放
        #20;
        RESET_IN = 1;
        $display("[%0t] Reset Deasserted", $time);
        #10;

        // 3. 写入两个粒子数据进行测试
        $display("\n---> Test 1: Writing initial particles");
        push_particle(16'h1111, 16'h2222, 16'h3333); // Index 0
        push_particle(16'h4444, 16'h5555, 16'h6666); // Index 1

        // 4. 随机读取并验证
        $display("\n---> Test 2: Reading back and verifying");
        check_read(0, 0, 16'h1111); // Read Idx 0, X
        check_read(0, 1, 16'h2222); // Read Idx 0, Y
        check_read(0, 2, 16'h3333); // Read Idx 0, Mass
        
        check_read(1, 0, 16'h4444); // Read Idx 1, X
        check_read(1, 2, 16'h6666); // Read Idx 1, Mass

        // 5. 将缓存写满 (N=4, 当前已经写了2个，再写2个)
        $display("\n---> Test 3: Filling the buffer to trigger FULL");
        push_particle(16'h7777, 16'h8888, 16'h9999); // Index 2
        push_particle(16'hAAAA, 16'hBBBB, 16'hCCCC); // Index 3
        
        #10;
        if (FULL) $display("[%0t] SUCCESS: FULL flag asserted.", $time);
        else $error("[%0t] FAIL: FULL flag is not asserted when buffer should be full.", $time);
        
        if (!S_READY) $display("[%0t] SUCCESS: S_READY correctly dropped.", $time);

        // 6. 测试 CLEAR 功能
        $display("\n---> Test 4: Testing CLEAR functionality");
        @(posedge CLK_IN);
        CLEAR = 1;
        @(posedge CLK_IN);
        CLEAR = 0;
        
        #10;
        if (!FULL && S_READY) 
            $display("[%0t] SUCCESS: CLEAR worked. FULL dropped, S_READY asserted.", $time);
        else 
            $error("[%0t] FAIL: CLEAR did not reset status flags.", $time);

        // 7. 结束仿真
        #50;
        $display("\nSimulation Complete.");
        $finish;
    end

    // --- Waveform Dumping ---
    initial begin
        $dumpfile("in_buffer_dump.vcd");
        $dumpvars(0, tb_IN_BUFFER);
    end

endmodule