module l1_cache #(
    parameter CACHE_SIZE = 1024,  // Cache size in bytes (1KB)
    parameter BLOCK_SIZE = 16,    // Block size in bytes (4 words)
    parameter ADDR_WIDTH = 32,    // Address width
    parameter DATA_WIDTH = 32     // Data width
) (
    input logic clk,
    input logic rst_n,

    // CPU interface
    input  logic                  req,    // Request from CPU
    input  logic                  we,     // Write enable
    input  logic [ADDR_WIDTH-1:0] addr,   // Address from CPU
    input  logic [DATA_WIDTH-1:0] wdata,  // Write data from CPU
    output logic [DATA_WIDTH-1:0] rdata,  // Read data to CPU
    output logic                  hit,    // Cache hit signal
    output logic                  ready,  // Cache ready signal

    // Memory interface
    output logic                  mem_req,    // Request to memory
    output logic                  mem_we,     // Write enable to memory
    output logic [ADDR_WIDTH-1:0] mem_addr,   // Address to memory
    output logic [DATA_WIDTH-1:0] mem_wdata,  // Write data to memory
    input  logic [DATA_WIDTH-1:0] mem_rdata,  // Read data from memory
    input  logic                  mem_ready   // Memory ready signal
);

  // Cache parameters
  localparam NUM_BLOCKS = CACHE_SIZE / BLOCK_SIZE;  // 64 blocks
  localparam NUM_WORDS = BLOCK_SIZE / 4;  // 4 words per block
  localparam INDEX_BITS = $clog2(NUM_BLOCKS);  // 6 bits
  localparam OFFSET_BITS = $clog2(BLOCK_SIZE);  // 4 bits
  localparam TAG_BITS = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS;  // 22 bits
  localparam WORD_OFFSET_BITS = OFFSET_BITS - 2;  // 2 bits

  // Address breakdown
  wire [TAG_BITS-1:0] tag = addr[ADDR_WIDTH-1:INDEX_BITS+OFFSET_BITS];
  wire [INDEX_BITS-1:0] index = addr[INDEX_BITS+OFFSET_BITS-1:OFFSET_BITS];
  wire [WORD_OFFSET_BITS-1:0] word_offset = addr[OFFSET_BITS-1:2];

  // Cache arrays
  logic [TAG_BITS-1:0] tag_array[NUM_BLOCKS-1:0];
  logic valid_array[NUM_BLOCKS-1:0];
  logic dirty_array[NUM_BLOCKS-1:0];
  logic [DATA_WIDTH-1:0] data_array[NUM_BLOCKS-1:0][NUM_WORDS-1:0];

  // Cache state machine
  typedef enum logic [2:0] {
    IDLE,
    COMPARE,
    MISS_HANDLE,
    REFILL,
    COMPLETE
  } cache_state_t;

  cache_state_t state, next_state;

  // Internal signals
  logic cache_hit_comb;
  logic [DATA_WIDTH-1:0] cache_rdata;
  logic [1:0] refill_count;
  logic [ADDR_WIDTH-1:0] miss_addr_reg;
  logic miss_we_reg;
  logic [DATA_WIDTH-1:0] miss_wdata_reg;

  // Cache hit/miss logic
  assign cache_hit_comb = valid_array[index] && (tag_array[index] == tag);
  assign cache_rdata = data_array[index][word_offset];

  // State machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      refill_count <= 2'b00;
      miss_addr_reg <= '0;
      miss_we_reg <= '0;
      miss_wdata_reg <= '0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          if (req) begin
            miss_addr_reg <= addr;
            miss_we_reg <= we;
            miss_wdata_reg <= wdata;
          end
        end

        MISS_HANDLE: begin
          refill_count <= 2'b00;
        end

        REFILL: begin
          if (mem_ready && mem_req) begin
            refill_count <= refill_count + 1;
          end
        end
      endcase
    end
  end

  // Next state logic
  always_comb begin
    next_state = state;

    case (state)
      IDLE: begin
        if (req) begin
          next_state = COMPARE;
        end
      end

      COMPARE: begin
        if (cache_hit_comb) begin
          next_state = COMPLETE;
        end else begin
          next_state = MISS_HANDLE;
        end
      end

      MISS_HANDLE: begin
        next_state = REFILL;
      end

      REFILL: begin
        if (mem_ready && refill_count == (NUM_WORDS - 1)) begin
          next_state = COMPARE;
        end
      end

      COMPLETE: begin
        next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Memory interface logic
  always_comb begin
    mem_req = 1'b0;
    mem_we = 1'b0;
    mem_addr = addr;
    mem_wdata = wdata;

    case (state)
      REFILL: begin
        mem_req  = 1'b1;
        mem_we   = 1'b0;
        mem_addr = {miss_addr_reg[ADDR_WIDTH-1:OFFSET_BITS], refill_count, 2'b00};
      end
    endcase
  end

  // Cache array updates
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < NUM_BLOCKS; i++) begin
        valid_array[i] <= 1'b0;
        dirty_array[i] <= 1'b0;
        tag_array[i]   <= '0;
        for (int j = 0; j < NUM_WORDS; j++) begin
          data_array[i][j] <= '0;
        end
      end
    end else begin
      case (state)
        COMPLETE: begin
          if (cache_hit_comb && miss_we_reg) begin
            // Write hit
            data_array[miss_addr_reg[INDEX_BITS+OFFSET_BITS-1:OFFSET_BITS]][miss_addr_reg[OFFSET_BITS-1:2]] <= miss_wdata_reg;
            dirty_array[miss_addr_reg[INDEX_BITS+OFFSET_BITS-1:OFFSET_BITS]] <= 1'b1;
          end
        end

        REFILL: begin
          if (mem_ready && mem_req) begin
            // Fill cache with data from memory
            data_array[miss_addr_reg[INDEX_BITS+OFFSET_BITS-1:OFFSET_BITS]][refill_count] <= mem_rdata;

            // Update tag and valid bit when refill completes
            if (refill_count == (NUM_WORDS - 1)) begin
              tag_array[miss_addr_reg[INDEX_BITS+OFFSET_BITS-1:OFFSET_BITS]] <= miss_addr_reg[ADDR_WIDTH-1:INDEX_BITS+OFFSET_BITS];
              valid_array[miss_addr_reg[INDEX_BITS+OFFSET_BITS-1:OFFSET_BITS]] <= 1'b1;
              dirty_array[miss_addr_reg[INDEX_BITS+OFFSET_BITS-1:OFFSET_BITS]] <= 1'b0;
            end
          end
        end
      endcase
    end
  end

  // Output logic
  assign rdata = cache_rdata;
  assign hit   = (state == COMPLETE) && cache_hit_comb;
  assign ready = (state == IDLE) || (state == COMPLETE);

endmodule
