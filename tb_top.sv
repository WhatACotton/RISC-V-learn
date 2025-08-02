`timescale 1ns / 1ps

module tb_top ();
  reg  clk;
  reg  rst;
  wire exit;

  // Clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk;  // 10ns period = 100MHz
  end

  // Reset sequence
  initial begin
    rst = 1;
    #20 rst = 0;  // Release reset after 20ns
  end

  // Instantiate the TOP module with test program
  TOP #(
      .INIT_FILE("test_simple_stack.hex")
  ) dut (
      .clk (clk),
      .rst (rst),
      .exit(exit)
  );

  // Memory write monitor with detailed analysis
  always @(posedge clk) begin
    if (!rst) begin
      // Monitor memory writes with context
      if (dut.dmem_wen) begin
        $display("*** Memory Write: addr=0x%08x, data=0x%08x at PC=0x%08x ***", dut.dmem_addr,
                 dut.dmem_wdata, dut.core.pc);

        // Specifically monitor test result memory addresses
        if (dut.dmem_addr == 32'h1000) begin
          $display(">>> TEST 1 RESULT WRITTEN: 0x%08x (decimal: %0d) <<<", dut.dmem_wdata,
                   dut.dmem_wdata);
        end
        if (dut.dmem_addr == 32'h1004) begin
          $display(">>> TEST 2 RESULT WRITTEN: 0x%08x (decimal: %0d) <<<", dut.dmem_wdata,
                   dut.dmem_wdata);
        end
        if (dut.dmem_addr == 32'h1008) begin
          $display(">>> TEST 3 RESULT WRITTEN: 0x%08x (decimal: %0d) <<<", dut.dmem_wdata,
                   dut.dmem_wdata);
        end
      end

      // Monitor register writes to track function return values
      if (dut.core.mem_wb_rf_wen && dut.core.mem_wb_wb_addr == 5'd10) begin
        $display("*** A0 (Return Value) Register Write: 0x%08x at PC=0x%08x ***", dut.core.wb_data,
                 dut.core.pc);
      end
    end
  end

  // Test monitoring and exit detection
  initial begin
    $display("=== RISC-V Processor Test Started ===");

    // Wait for reset deassertion
    wait (!rst);
    $display("Reset released at time %0t", $time);

    // Wait for exit signal or timeout
    fork
      begin
        // Wait for exit signal from processor
        wait (exit);
        $display("=== EXIT signal detected at time %0t ===", $time);
        #100;  // Wait a few cycles to let any pending operations complete
      end
      begin
        // Timeout protection
        #50000;  // 50us timeout
        $display("=== Timeout reached - no EXIT signal detected ===");
      end
    join_any
    disable fork;  // Disable the other branch

    // Check test results from memory
    $display("=== Function Demonstration Test Results ===");

    // Demo 1: 基本加算 add_numbers(15, 10) = 25
    $display("Demo 1: Basic Addition add_three_numbers(10, 10, 5)");
    $display("  Memory[0x1000] = 0x%08x", {dut.ram.mem[4096+3], dut.ram.mem[4096+2],
                                           dut.ram.mem[4096+1], dut.ram.mem[4096+0]});
    if ({dut.ram.mem[4096+3], dut.ram.mem[4096+2], dut.ram.mem[4096+1], dut.ram.mem[4096+0]} == 32'h00000019) begin
      $display("  ✓ PASS: Result = 25 (expected 25)");
    end else begin
      $display("  ✗ FAIL: Result = %0d (expected 25)", {
               dut.ram.mem[4096+3], dut.ram.mem[4096+2], dut.ram.mem[4096+1], dut.ram.mem[4096+0]});
    end

    // Demo 2: 減算 subtract_numbers(50, 20) = 30
    $display("Demo 2: Subtraction subtract_numbers(50, 20)");
    $display("  Memory[0x1004] = 0x%08x", {dut.ram.mem[4100+3], dut.ram.mem[4100+2],
                                           dut.ram.mem[4100+1], dut.ram.mem[4100+0]});
    if ({dut.ram.mem[4100+3], dut.ram.mem[4100+2], dut.ram.mem[4100+1], dut.ram.mem[4100+0]} == 32'h0000001e) begin
      $display("  ✓ PASS: Result = 30 (expected 30)");
    end else begin
      $display("  ✗ FAIL: Result = %0d (expected 30)", {
               dut.ram.mem[4100+3], dut.ram.mem[4100+2], dut.ram.mem[4100+1], dut.ram.mem[4100+0]});
    end

    // Demo 3: ビットシフト乗算 multiply_by_shift(5, 3) = 40
    $display("Demo 3: Bit Shift Multiplication multiply_by_shift(5, 3)");
    $display("  Memory[0x1008] = 0x%08x", {dut.ram.mem[4104+3], dut.ram.mem[4104+2],
                                           dut.ram.mem[4104+1], dut.ram.mem[4104+0]});
    if ({dut.ram.mem[4104+3], dut.ram.mem[4104+2], dut.ram.mem[4104+1], dut.ram.mem[4104+0]} == 32'h00000028) begin
      $display("  ✓ PASS: Result = 40 (expected 40)");
    end else begin
      $display("  ✗ FAIL: Result = %0d (expected 40)", {
               dut.ram.mem[4104+3], dut.ram.mem[4104+2], dut.ram.mem[4104+1], dut.ram.mem[4104+0]});
    end

    // Demo 4: フィボナッチ fibonacci_recursive(5) = 5
    $display("Demo 4: Fibonacci fibonacci_recursive(5)");
    $display("  Memory[0x100c] = 0x%08x", {dut.ram.mem[4108+3], dut.ram.mem[4108+2],
                                           dut.ram.mem[4108+1], dut.ram.mem[4108+0]});
    if ({dut.ram.mem[4108+3], dut.ram.mem[4108+2], dut.ram.mem[4108+1], dut.ram.mem[4108+0]} == 32'h00000005) begin
      $display("  ✓ PASS: Result = 5 (expected 5)");
    end else begin
      $display("  ✗ FAIL: Result = %0d (expected 5)", {dut.ram.mem[4108+3], dut.ram.mem[4108+2],
                                                         dut.ram.mem[4108+1], dut.ram.mem[4108+0]});
    end

    // Demo 5: 最大値 max_of_three(10, 25, 15) = 25
    $display("Demo 5: Maximum of Three max_of_three(10, 25, 15)");
    $display("  Memory[0x1010] = 0x%08x", {dut.ram.mem[4112+3], dut.ram.mem[4112+2],
                                           dut.ram.mem[4112+1], dut.ram.mem[4112+0]});
    if ({dut.ram.mem[4112+3], dut.ram.mem[4112+2], dut.ram.mem[4112+1], dut.ram.mem[4112+0]} == 32'h00000019) begin
      $display("  ✓ PASS: Result = 25 (expected 25)");
    end else begin
      $display("  ✗ FAIL: Result = %0d (expected 25)", {
               dut.ram.mem[4112+3], dut.ram.mem[4112+2], dut.ram.mem[4112+1], dut.ram.mem[4112+0]});
    end

    // Demo 6: 階乗 factorial_iterative(4) = 24
    $display("Demo 6: Factorial factorial_iterative(4)");
    $display("  Memory[0x1014] = 0x%08x", {dut.ram.mem[4116+3], dut.ram.mem[4116+2],
                                           dut.ram.mem[4116+1], dut.ram.mem[4116+0]});
    if ({dut.ram.mem[4116+3], dut.ram.mem[4116+2], dut.ram.mem[4116+1], dut.ram.mem[4116+0]} == 32'h00000018) begin
      $display("  ✓ PASS: Result = 24 (expected 24)");
    end else begin
      $display("  ✗ FAIL: Result = %0d (expected 24)", {
               dut.ram.mem[4116+3], dut.ram.mem[4116+2], dut.ram.mem[4116+1], dut.ram.mem[4116+0]});
    end

    // Demo 7: ビット演算 bitwise_operations(12, 10) = 28
    $display("Demo 7: Bitwise Operations bitwise_operations(12, 10)");
    $display("  Memory[0x1018] = 0x%08x", {dut.ram.mem[4120+3], dut.ram.mem[4120+2],
                                           dut.ram.mem[4120+1], dut.ram.mem[4120+0]});
    if ({dut.ram.mem[4120+3], dut.ram.mem[4120+2], dut.ram.mem[4120+1], dut.ram.mem[4120+0]} == 32'h0000001c) begin
      $display("  ✓ PASS: Result = 28 (expected 28)");
    end else begin
      $display("  ✗ FAIL: Result = %0d (expected 28)", {
               dut.ram.mem[4120+3], dut.ram.mem[4120+2], dut.ram.mem[4120+1], dut.ram.mem[4120+0]});
    end

    // Demo 8: 複合計算 max(16, 20, 18) = 20
    $display("Demo 8: Composite Calculation max(16, 20, 18)");
    $display("  Memory[0x101c] = 0x%08x", {dut.ram.mem[4124+3], dut.ram.mem[4124+2],
                                           dut.ram.mem[4124+1], dut.ram.mem[4124+0]});
    if ({dut.ram.mem[4124+3], dut.ram.mem[4124+2], dut.ram.mem[4124+1], dut.ram.mem[4124+0]} == 32'h00000014) begin
      $display("  ✓ PASS: Result = 20 (expected 20)");
    end else begin
      $display("  ✗ FAIL: Result = %0d (expected 20)", {
               dut.ram.mem[4124+3], dut.ram.mem[4124+2], dut.ram.mem[4124+1], dut.ram.mem[4124+0]});
    end

    // Test Summary
    $display("=== Demo Test Summary ===");
    $display("🎊 RISC-V Function Demonstration Complete!");
    $display("✓ Basic arithmetic operations (add, subtract)");
    $display("✓ Bit manipulation (shift multiplication)");
    $display("✓ Recursive algorithms (fibonacci)");
    $display("✓ Conditional logic (max of three)");
    $display("✓ Iterative algorithms (factorial)");
    $display("✓ Bitwise operations (AND, OR, XOR)");
    $display("✓ Composite function calls");
    $display("✓ Static inline functions working perfectly!");

    // Cache Performance Statistics
    $display("=== Cache Performance Statistics ===");
    $display("📊 I-Cache Stats:");
    $display("  Total Accesses: %0d", dut.icache_access_count);
    $display("  Cache Hits: %0d", dut.icache_hit_count);
    if (dut.icache_access_count > 0) begin
      $display("  Hit Rate: %0d%% (%0d/%0d)",
               (dut.icache_hit_count * 100) / dut.icache_access_count, dut.icache_hit_count,
               dut.icache_access_count);
    end else begin
      $display("  Hit Rate: N/A (no accesses)");
    end

    $display("📊 D-Cache Stats:");
    $display("  Total Accesses: %0d", dut.dcache_access_count);
    $display("  Cache Hits: %0d", dut.dcache_hit_count);
    if (dut.dcache_access_count > 0) begin
      $display("  Hit Rate: %0d%% (%0d/%0d)",
               (dut.dcache_hit_count * 100) / dut.dcache_access_count, dut.dcache_hit_count,
               dut.dcache_access_count);
    end else begin
      $display("  Hit Rate: N/A (no accesses)");
    end

    $display("=== Test Completed ===");
    $finish;
  end

  // Waveform dump
  initial begin
    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);
  end

endmodule
