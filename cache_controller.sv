module cache_controller #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input logic clk,
    input logic rst_n,

    // CPU instruction interface
    input  logic [ADDR_WIDTH-1:0] imem_addr,
    output logic [DATA_WIDTH-1:0] imem_inst,
    output logic                  imem_ready,

    // CPU data interface
    input  logic                  dmem_req,
    input  logic                  dmem_we,
    input  logic [ADDR_WIDTH-1:0] dmem_addr,
    input  logic [DATA_WIDTH-1:0] dmem_wdata,
    output logic [DATA_WIDTH-1:0] dmem_rdata,
    output logic                  dmem_ready,

    // Main memory interface
    output logic                  mem_req,
    output logic                  mem_we,
    output logic [ADDR_WIDTH-1:0] mem_addr,
    output logic [DATA_WIDTH-1:0] mem_wdata,
    input  logic [DATA_WIDTH-1:0] mem_rdata,
    input  logic                  mem_ready
);

  // Internal signals for instruction cache
  logic icache_req;
  logic icache_hit;
  logic icache_ready;
  logic [DATA_WIDTH-1:0] icache_rdata;
  logic icache_mem_req;
  logic icache_mem_we;
  logic [ADDR_WIDTH-1:0] icache_mem_addr;
  logic [DATA_WIDTH-1:0] icache_mem_wdata;

  // Internal signals for data cache
  logic dcache_hit;
  logic dcache_ready;
  logic dcache_mem_req;
  logic dcache_mem_we;
  logic [ADDR_WIDTH-1:0] dcache_mem_addr;
  logic [DATA_WIDTH-1:0] dcache_mem_wdata;

  // Memory arbiter state
  typedef enum logic [1:0] {
    ARB_IDLE,
    ARB_ICACHE,
    ARB_DCACHE
  } arbiter_state_t;

  arbiter_state_t arb_state, arb_next_state;

  // Generate instruction cache request (always request for simplicity)
  assign icache_req = 1'b1;

  // Instruction Cache (I-Cache)
  l1_cache #(
      .CACHE_SIZE(512),         // 512B I-Cache (smaller for now)
      .BLOCK_SIZE(16),          // 16-byte blocks
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH)
  ) icache (
      .clk      (clk),
      .rst_n    (rst_n),
      .req      (icache_req),
      .we       (1'b0),                                   // Instructions are read-only
      .addr     (imem_addr),
      .wdata    ('0),
      .rdata    (icache_rdata),
      .hit      (icache_hit),
      .ready    (icache_ready),
      .mem_req  (icache_mem_req),
      .mem_we   (icache_mem_we),
      .mem_addr (icache_mem_addr),
      .mem_wdata(icache_mem_wdata),
      .mem_rdata(mem_rdata),
      .mem_ready(mem_ready && (arb_state == ARB_ICACHE))
  );

  // Data Cache (D-Cache)
  l1_cache #(
      .CACHE_SIZE(512),         // 512B D-Cache (smaller for now)
      .BLOCK_SIZE(16),          // 16-byte blocks
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH)
  ) dcache (
      .clk(clk),
      .rst_n(rst_n),
      .req(dmem_req),
      .we(dmem_we),
      .addr(dmem_addr),
      .wdata(dmem_wdata),
      .rdata(dmem_rdata),
      .hit(dcache_hit),
      .ready(dcache_ready),
      .mem_req(dcache_mem_req),
      .mem_we(dcache_mem_we),
      .mem_addr(dcache_mem_addr),
      .mem_wdata(dcache_mem_wdata),
      .mem_rdata(mem_rdata),
      .mem_ready(mem_ready && (arb_state == ARB_DCACHE))
  );

  // Memory arbiter state machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      arb_state <= ARB_IDLE;
    end else begin
      arb_state <= arb_next_state;
    end
  end

  // Arbiter next state logic with priority to data cache
  always_comb begin
    arb_next_state = arb_state;

    case (arb_state)
      ARB_IDLE: begin
        if (dcache_mem_req) begin
          arb_next_state = ARB_DCACHE;
        end else if (icache_mem_req) begin
          arb_next_state = ARB_ICACHE;
        end
      end

      ARB_ICACHE: begin
        if (!icache_mem_req) begin
          if (dcache_mem_req) begin
            arb_next_state = ARB_DCACHE;
          end else begin
            arb_next_state = ARB_IDLE;
          end
        end else if (dcache_mem_req) begin
          // Priority to data cache
          arb_next_state = ARB_DCACHE;
        end
      end

      ARB_DCACHE: begin
        if (!dcache_mem_req) begin
          if (icache_mem_req) begin
            arb_next_state = ARB_ICACHE;
          end else begin
            arb_next_state = ARB_IDLE;
          end
        end
      end

      default: arb_next_state = ARB_IDLE;
    endcase
  end

  // Memory interface arbitration
  always_comb begin
    mem_req = 1'b0;
    mem_we = 1'b0;
    mem_addr = '0;
    mem_wdata = '0;

    case (arb_state)
      ARB_ICACHE: begin
        mem_req = icache_mem_req;
        mem_we = icache_mem_we;
        mem_addr = icache_mem_addr;
        mem_wdata = icache_mem_wdata;
      end

      ARB_DCACHE: begin
        mem_req = dcache_mem_req;
        mem_we = dcache_mem_we;
        mem_addr = dcache_mem_addr;
        mem_wdata = dcache_mem_wdata;
      end
    endcase
  end

  // CPU interface outputs
  assign imem_inst  = icache_rdata;
  assign imem_ready = icache_ready;
  assign dmem_ready = dcache_ready;

endmodule
