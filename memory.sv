module ram #(
    parameter INIT_FILE = ""
) (
    input               clk,
    input  logic        rst_n,
    // inst memory I/O
    output       [31:0] imem_inst,
    input        [31:0] imem_addr,

    // dest memory I/O
    input         dmem_wen,
    input  [31:0] dmem_wdata,
    output [31:0] dmem_rdata,
    input  [31:0] dmem_addr
);

  // Unified byte-addressable memory array (16KB = 16384 bytes)
  logic [7:0] mem[0:16383];

  // Initialize memory from file if specified
  initial begin
    // First initialize all memory to zero
    for (int i = 0; i < 16384; i++) begin
      mem[i] = 8'h0;
    end

    if (INIT_FILE != "") begin
      // Read 32-bit words from hex file
      logic [31:0] temp_mem[0:4095];  // 16KB / 4 bytes = 4096 words
      $readmemh(INIT_FILE, temp_mem);

      // Convert 32-bit words to bytes (little-endian)
      for (int i = 0; i < 4096; i++) begin
        mem[i*4+0] = temp_mem[i][7:0];  // LSB
        mem[i*4+1] = temp_mem[i][15:8];
        mem[i*4+2] = temp_mem[i][23:16];
        mem[i*4+3] = temp_mem[i][31:24];  // MSB
      end

      // Debug: Show memory contents around critical addresses
      // $display("Memory Debug: addr 0x1C = %02h%02h%02h%02h", 
      //          mem[31], mem[30], mem[29], mem[28]);
      // $display("Memory Debug: temp_mem[7] = 0x%08h", temp_mem[7]);

    end
  end

  // Instruction memory read (combinational)
  // Following Chisel reference implementation pattern
  assign imem_inst = (imem_addr <= 16380) ? 
                     {mem[imem_addr+3], mem[imem_addr+2], mem[imem_addr+1], mem[imem_addr+0]} : 
                     32'h0;

  // Data memory read (combinational)
  assign dmem_rdata = (dmem_addr <= 16380) ? 
                      {mem[dmem_addr+3], mem[dmem_addr+2], mem[dmem_addr+1], mem[dmem_addr+0]} : 
                      32'h0;

  // Data memory write with instruction memory protection
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Do not reinitialize memory on reset to preserve loaded data
    end else if (dmem_wen && dmem_addr <= 16380) begin
      // Protect instruction memory area (0x0000-0x03FF) from data writes
      // Allow data writes only to data area (0x0400 and above)
      if (dmem_addr >= 32'h0400) begin
        // Write 32-bit word as 4 bytes (little-endian)
        // Following Chisel reference implementation pattern
        mem[dmem_addr+0] <= dmem_wdata[7:0];  // LSB
        mem[dmem_addr+1] <= dmem_wdata[15:8];
        mem[dmem_addr+2] <= dmem_wdata[23:16];
        mem[dmem_addr+3] <= dmem_wdata[31:24];  // MSB
      end
      // Silently ignore writes to instruction area to protect it
    end
  end

endmodule
