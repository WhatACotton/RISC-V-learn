`include "core.sv"
`include "memory.sv"

module TOP #(
    parameter INIT_FILE = ""
) (
    input  clk,
    input  rst,
    output exit
);
  logic rst_n;
  assign rst_n = ~rst;

  logic [31:0] imem_inst;
  logic [31:0] imem_addr;

  // memory I/O
  logic        dmem_wen;
  logic [31:0] dmem_wdata;
  logic [31:0] dmem_rdata;
  logic [31:0] dmem_addr;

  // Cache statistics
  logic [31:0] icache_access_count;
  logic [31:0] icache_hit_count;
  logic [31:0] dcache_access_count;
  logic [31:0] dcache_hit_count;

  // Simple cache simulation counters
  logic [31:0] prev_imem_addr;
  logic [31:0] prev_dmem_addr;
  logic        prev_dmem_wen;
  logic        imem_cache_hit;
  logic        dmem_cache_hit;

  CORE core (
      .clk(clk),
      .rst(rst),
      .exit(exit),
      .imem_inst(imem_inst),
      .imem_addr(imem_addr),
      .dmem_wen(dmem_wen),
      .dmem_wdata(dmem_wdata),
      .dmem_rdata(dmem_rdata),
      .dmem_addr(dmem_addr)
  );

  // Instantiate memory (direct connection for now)
  ram #(
      .INIT_FILE(INIT_FILE)
  ) ram (
      .clk(clk),
      .rst_n(rst_n),
      .imem_inst(imem_inst),
      .imem_addr(imem_addr),
      .dmem_wen(dmem_wen),
      .dmem_wdata(dmem_wdata),
      .dmem_rdata(dmem_rdata),
      .dmem_addr(dmem_addr)
  );

  // Cache simulation logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      icache_access_count <= 0;
      icache_hit_count <= 0;
      dcache_access_count <= 0;
      dcache_hit_count <= 0;
      prev_imem_addr <= 32'hFFFFFFFF;
      prev_dmem_addr <= 32'hFFFFFFFF;
      prev_dmem_wen <= 0;
      imem_cache_hit <= 0;
      dmem_cache_hit <= 0;
    end else begin
      // Track instruction cache accesses
      if (imem_addr != prev_imem_addr) begin
        icache_access_count <= icache_access_count + 1;
        // Simulate cache hit (same 16-byte block)
        imem_cache_hit <= (imem_addr[31:4] == prev_imem_addr[31:4]) && (prev_imem_addr != 32'hFFFFFFFF);
        if (imem_cache_hit) begin
          icache_hit_count <= icache_hit_count + 1;
        end
        prev_imem_addr <= imem_addr;
      end

      // Track data cache accesses
      if ((dmem_wen || (dmem_addr != 0)) && (dmem_addr != prev_dmem_addr || dmem_wen != prev_dmem_wen)) begin
        dcache_access_count <= dcache_access_count + 1;
        // Simulate cache hit (same 16-byte block)
        dmem_cache_hit <= (dmem_addr[31:4] == prev_dmem_addr[31:4]) && (prev_dmem_addr != 32'hFFFFFFFF);
        if (dmem_cache_hit) begin
          dcache_hit_count <= dcache_hit_count + 1;
        end
        prev_dmem_addr <= dmem_addr;
        prev_dmem_wen  <= dmem_wen;
      end
    end
  end

  // Debug output (simulation only)
  always @(posedge clk) begin
    if (!rst) begin
      $display("PC=0x%08h, INST=0x%08h, DMEM_ADDR=%0d, DMEM_DATA=0x%08h", core.pc, imem_inst,
               dmem_addr, dmem_rdata);
      // Check for exit signal (0xDEADBEEF written to 0x100C)
      if (exit) begin
        $display("Exit signal detected: 0xDEADBEEF written to address 0x100C at PC=0x%08h",
                 core.pc);
      end
    end
  end
endmodule
