
`ifndef CONSTS_VH
`define CONSTS_VH

localparam ADDR_WIDTH   = 8;
localparam DATA_WIDTH   = 32;
localparam CLK_PERIOD   = 10;
localparam MEMORY_DEPTH = 2 ** ADDR_WIDTH;

localparam EXE_FUN_LEN     = 5;
localparam [4:0] ALU_X     = 5'd0;
localparam [4:0] ALU_ADD   = 5'd1;
localparam [4:0] ALU_SUB   = 5'd2;
localparam [4:0] ALU_AND   = 5'd3;
localparam [4:0] ALU_OR    = 5'd4;
localparam [4:0] ALU_XOR   = 5'd5;
localparam [4:0] ALU_SLL   = 5'd6;
localparam [4:0] ALU_SRL   = 5'd7;
localparam [4:0] ALU_SRA   = 5'd8;
localparam [4:0] ALU_SLT   = 5'd9;
localparam [4:0] ALU_SLTU  = 5'd10;
localparam [4:0] BR_BEQ    = 5'd11;
localparam [4:0] BR_BNE    = 5'd12;
localparam [4:0] BR_BLT    = 5'd13;
localparam [4:0] BR_BGE    = 5'd14;
localparam [4:0] BR_BLTU   = 5'd15;
localparam [4:0] BR_BGEU   = 5'd16;
localparam [4:0] ALU_JALR  = 5'd17;
localparam [4:0] ALU_JAL   = 5'd18;
localparam [4:0] ALU_COPY1 = 5'd19;

// Operand 1 Selection
localparam OP1_LEN       = 2;
localparam [1:0] OP1_RS1 = 2'd0;
localparam [1:0] OP1_PC  = 2'd1;
localparam [1:0] OP1_X   = 2'd2;
localparam [1:0] OP1_IMZ = 2'd3;

// Operand 2 Selection
localparam OP2_LEN       = 3;
localparam [2:0] OP2_X   = 3'd0;
localparam [2:0] OP2_RS2 = 3'd1;
localparam [2:0] OP2_IMI = 3'd2;
localparam [2:0] OP2_IMS = 3'd3;
localparam [2:0] OP2_IMJ = 3'd4;
localparam [2:0] OP2_IMU = 3'd5;

// Memory Enable
localparam MEN_LEN     = 2;
localparam [1:0] MEN_X = 2'd0;
localparam [1:0] MEN_S = 2'd1;  // スカラ命令用
localparam [1:0] MEN_V = 2'd2;  // ベクトル命令用

// Register Enable
localparam REN_LEN     = 2;
localparam [1:0] REN_X = 2'd0;
localparam [1:0] REN_S = 2'd1;  // スカラ命令用
localparam [1:0] REN_V = 2'd2;  // ベクトル命令用

// Write Back Selection
localparam WB_SEL_LEN     = 3;
localparam [2:0] WB_X     = 3'd0;
localparam [2:0] WB_ALU   = 3'd0;
localparam [2:0] WB_MEM   = 3'd1;
localparam [2:0] WB_PC    = 3'd2;
localparam [2:0] WB_CSR   = 3'd3;
localparam [2:0] WB_MEM_V = 3'd4;
localparam [2:0] WB_ALU_V = 3'd5;
localparam [2:0] WB_VL    = 3'd6;

// Memory Width
localparam MW_LEN      = 3;
localparam [2:0] MW_X  = 3'd0;
localparam [2:0] MW_W  = 3'd1;
localparam [2:0] MW_H  = 3'd2;
localparam [2:0] MW_B  = 3'd3;
localparam [2:0] MW_HU = 3'd4;
localparam [2:0] MW_BU = 3'd5;
localparam [2:0] CSR_X = 3'd0;
localparam [2:0] CSR_W = 3'd1;
localparam [2:0] CSR_S = 3'd2;
localparam [2:0] CSR_C = 3'd3;
localparam [2:0] CSR_E = 3'd4;
localparam [2:0] CSR_V = 3'd5;

localparam [31:0] ECALL = 32'b00000000000000000000000001110011;
`endif // CONSTS_VH
