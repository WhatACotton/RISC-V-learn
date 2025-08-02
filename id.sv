`include "consts.vh"
module decoder (
    input [31:0] inst,
    input [31:0] pc_i,

    // Register file interface
    input logic [ 4:0] rs1_addr,  // Read port 1 address (input from core)
    input logic [ 4:0] rs2_addr,  // Read port 2 address (input from core)
    input       [31:0] rs1_data,  // Read port 1 data
    input       [31:0] rs2_data,  // Read port 2 data

    output logic [31:0] pc_o,
    output logic [31:0] op1,
    output logic [31:0] op2,
    output logic [ 4:0] wb_addr,        // Write back address (rd)
    output logic [31:0] rf_wen,
    output logic [ 4:0] exe_fun,
    output logic [31:0] wb_sel,
    output logic [31:0] imm_i_sext,
    output logic [31:0] imm_s_sext,
    output logic [31:0] imm_b_sext,
    output logic [31:0] imm_u_shifted,
    output logic [31:0] imm_z_uext,
    output logic [31:0] imm_j_sext,
    output logic [31:0] csr_addr,
    output logic [31:0] csr_cmd,
    output logic [31:0] mem_wen,
    output logic        is_jalr
);
  logic [31:0] inst_reg;

  // Extract write-back register address from instruction
  assign wb_addr = inst[11:7];  // Destination register (rd)

  logic [11:0] imm_i;
  assign imm_i = inst[31:20];
  assign imm_i_sext = {{20{imm_i[11]}}, imm_i};

  logic [11:0] imm_s;
  assign imm_s = {inst[31:25], inst[11:7]};
  assign imm_s_sext = {{20{imm_s[11]}}, imm_s};

  logic [11:0] imm_b;
  assign imm_b = {inst[31], inst[7], inst[30:25], inst[11:8]};
  assign imm_b_sext = {{19{imm_b[11]}}, imm_b, 1'b0};

  logic [20:0] imm_j;
  assign imm_j = {inst[31], inst[19:12], inst[20], inst[30:21]};
  assign imm_j_sext = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};

  logic [19:0] imm_u;
  assign imm_u = inst[31:12];
  assign imm_u_shifted = {imm_u, 12'b0};

  logic [4:0] imm_z;
  assign imm_z = inst[19:15];
  assign imm_z_uext = {27'b0, imm_z};



  logic [4:0] _exe_fun;
  logic [1:0] op1_sel;  // Operand 1 selection  
  logic [2:0] op2_sel;  // Operand 2 selection
  logic [1:0] _mem_wen;  // Memory write enable
  logic       _rf_wen;  // Register file write enable
  logic [2:0] _wb_sel;  // Write back selection
  logic [2:0] _csr_cmd;  // CSR command

  logic [6:0] opcode;
  logic [2:0] funct3;
  logic [6:0] funct7;

  assign is_jalr = (inst[6:0] == 7'b1100111);

  always_comb begin
    inst_reg = inst;
  end

  assign opcode = inst_reg[6:0];
  assign funct3 = inst_reg[14:12];
  assign funct7 = inst_reg[31:25];

  always_comb begin : inst_lookup
    // Set default values for all outputs
    _exe_fun = ALU_X;
    op1_sel  = OP1_X;
    op2_sel  = OP2_X;
    _mem_wen = MEN_X;
    _rf_wen  = REN_X;
    _wb_sel  = WB_X;
    _csr_cmd = CSR_X;

    case (opcode)
      7'b0000011: begin
        casex (funct3)
          3'b000: begin
            // LB
          end
          3'b001: begin
            // LH
            _exe_fun = ALU_ADD;

          end
          3'b010: begin
            // LW
            _exe_fun = ALU_ADD;
            op1_sel  = OP1_RS1;
            op2_sel  = OP2_IMI;
            _mem_wen = MEN_X;
            _rf_wen  = REN_S;
            _wb_sel  = WB_MEM;
            _csr_cmd = CSR_X;
          end
          3'b100: begin
            // LBU
            _exe_fun = ALU_ADD;
          end
          3'b101: begin
            // LHU
            _exe_fun = ALU_ADD;
          end
          default: begin
            _exe_fun = ALU_X;
            op1_sel  = OP1_RS1;
            op2_sel  = OP2_RS2;
            _mem_wen = MEN_X;
            _rf_wen  = REN_X;
            _wb_sel  = WB_X;
            _csr_cmd = CSR_X;
          end
        endcase
      end
      7'b0100011: begin
        case (funct3)
          3'b000: begin
            // SB
            _exe_fun = ALU_ADD;
            op1_sel  = OP1_RS1;
            op2_sel  = OP2_IMS;
            _mem_wen = MEN_S;
            _rf_wen  = REN_X;
            _wb_sel  = WB_X;
            _csr_cmd = CSR_X;
          end
          3'b001: begin
            // SH
            _exe_fun = ALU_ADD;
            op1_sel  = OP1_RS1;
            op2_sel  = OP2_IMS;
            _mem_wen = MEN_S;
            _rf_wen  = REN_X;
            _wb_sel  = WB_X;
            _csr_cmd = CSR_X;
          end
          3'b010: begin
            // SW
            _exe_fun = ALU_ADD;
            op1_sel  = OP1_RS1;
            op2_sel  = OP2_IMS;
            _mem_wen = MEN_S;
            _rf_wen  = REN_X;
            _wb_sel  = WB_X;
            _csr_cmd = CSR_X;
          end
          default: begin
            _exe_fun = ALU_X;
            op1_sel  = OP1_RS1;
            op2_sel  = OP2_RS2;
            _mem_wen = MEN_X;
            _rf_wen  = REN_X;
            _wb_sel  = WB_X;
            _csr_cmd = CSR_X;
          end
        endcase
      end
      7'b0010011: begin
        casex (funct3)
          3'b000: begin
            // ADDI
            _exe_fun = ALU_ADD;
            op1_sel  = OP1_RS1;
            op2_sel  = OP2_IMI;
            _mem_wen = MEN_X;
            _rf_wen  = REN_S;
            _wb_sel  = WB_ALU;
            _csr_cmd = CSR_X;
          end
          3'b001: begin
            casex (funct7)
              7'b0000000: begin
                //SLLI
                _exe_fun = ALU_SLL;
                op1_sel  = OP1_RS1;
                op2_sel  = OP2_IMI;
                _mem_wen = MEN_X;
                _rf_wen  = REN_S;
                _wb_sel  = WB_ALU;
                _csr_cmd = CSR_X;
              end
              default: begin
                _exe_fun = ALU_X;
                op1_sel  = OP1_RS1;
                op2_sel  = OP2_RS2;
                _mem_wen = MEN_X;
                _rf_wen  = REN_X;
                _wb_sel  = WB_X;
                _csr_cmd = CSR_X;
              end
            endcase
          end
          3'b010: begin
            // SLTI
            _exe_fun = ALU_SLT;
            op1_sel  = OP1_RS1;
            op2_sel  = OP2_IMI;
            _mem_wen = MEN_X;
            _rf_wen  = REN_S;
            _wb_sel  = WB_ALU;
            _csr_cmd = CSR_X;
          end
          3'b011: begin
            // SLTIU
            _exe_fun = ALU_SLTU;
            op1_sel  = OP1_RS1;
            op2_sel  = OP2_IMI;
            _mem_wen = MEN_X;
            _rf_wen  = REN_S;
            _wb_sel  = WB_ALU;
            _csr_cmd = CSR_X;
          end
          3'b100: begin
            // XORI
            _exe_fun = ALU_XOR;
            op1_sel  = OP1_RS1;
            op2_sel  = OP2_IMI;
            _mem_wen = MEN_X;
            _rf_wen  = REN_S;
            _wb_sel  = WB_ALU;
            _csr_cmd = CSR_X;
          end
          3'b101: begin
            casex (funct7)
              7'b0000000: begin
                //SRLI
                _exe_fun = ALU_SRL;
                op1_sel  = OP1_RS1;
                op2_sel  = OP2_IMI;
                _mem_wen = MEN_X;
                _rf_wen  = REN_S;
                _wb_sel  = WB_ALU;
                _csr_cmd = CSR_X;
              end
              7'b0100000: begin
                //SRAI
                _exe_fun = ALU_SRA;
                op1_sel  = OP1_RS1;
                op2_sel  = OP2_IMI;
                _mem_wen = MEN_X;
                _rf_wen  = REN_S;
                _wb_sel  = WB_ALU;
                _csr_cmd = CSR_X;
              end
              default: begin
                _exe_fun = ALU_X;
                op1_sel  = OP1_RS1;
                op2_sel  = OP2_RS2;
                _mem_wen = MEN_X;
                _rf_wen  = REN_X;
                _wb_sel  = WB_X;
                _csr_cmd = CSR_X;
              end
            endcase
          end
          3'b110: begin
            // ORI
            _exe_fun = ALU_OR;
            op1_sel  = OP1_RS1;
            op2_sel  = OP2_IMI;
            _mem_wen = MEN_X;
            _rf_wen  = REN_S;
            _wb_sel  = WB_ALU;
            _csr_cmd = CSR_X;
          end

          3'b111: begin
            // ANDI
            _exe_fun = ALU_AND;
            op1_sel  = OP1_RS1;
            op2_sel  = OP2_IMI;
            _mem_wen = MEN_X;
            _rf_wen  = REN_S;
            _wb_sel  = WB_ALU;
            _csr_cmd = CSR_X;
          end
          default: begin
            _exe_fun = ALU_X;
            op1_sel  = OP1_RS1;
            op2_sel  = OP2_RS2;
            _mem_wen = MEN_X;
            _rf_wen  = REN_X;
            _wb_sel  = WB_X;
            _csr_cmd = CSR_X;
          end
        endcase
      end
      7'b0110011: begin
        casex (funct3)
          3'b000: begin
            casex (funct7)
              7'b0000000: begin
                //ADD
                _exe_fun = ALU_ADD;
                op1_sel  = OP1_RS1;
                op2_sel  = OP2_RS2;
                _mem_wen = MEN_X;
                _rf_wen  = REN_S;
                _wb_sel  = WB_ALU;
                _csr_cmd = CSR_X;
              end
              7'b0100000: begin
                //SUB
                _exe_fun = ALU_SUB;
                op1_sel  = OP1_RS1;
                op2_sel  = OP2_RS2;
                _mem_wen = MEN_X;
                _rf_wen  = REN_S;
                _wb_sel  = WB_ALU;
                _csr_cmd = CSR_X;
              end
              default: begin
                _exe_fun = ALU_X;
                op1_sel  = OP1_RS1;
                op2_sel  = OP2_RS2;
                _mem_wen = MEN_X;
                _rf_wen  = REN_X;
                _wb_sel  = WB_X;
                _csr_cmd = CSR_X;
              end
            endcase
          end
          3'b001: begin
            casex (funct7)
              7'b0000000: begin
                //SLL
                _exe_fun = ALU_SLL;
                op1_sel  = OP1_RS1;
                op2_sel  = OP2_RS2;
                _mem_wen = MEN_X;
                _rf_wen  = REN_S;
                _wb_sel  = WB_ALU;
                _csr_cmd = CSR_X;
              end
              default: begin
                _exe_fun = ALU_X;
                op1_sel  = OP1_RS1;
                op2_sel  = OP2_RS2;
                _mem_wen = MEN_X;
                _rf_wen  = REN_X;
                _wb_sel  = WB_X;
                _csr_cmd = CSR_X;
              end
            endcase
          end
          3'b010: begin
            casex (funct7)
              7'b0000000: begin
                // SLT
                _exe_fun = ALU_SLT;
                op1_sel  = OP1_RS1;
                op2_sel  = OP2_RS2;
                _mem_wen = MEN_X;
                _rf_wen  = REN_S;
                _wb_sel  = WB_ALU;
                _csr_cmd = CSR_X;
              end
              default: begin
                _exe_fun = ALU_X;
                op1_sel  = OP1_RS1;
                op2_sel  = OP2_RS2;
                _mem_wen = MEN_X;
                _rf_wen  = REN_X;
                _wb_sel  = WB_X;
                _csr_cmd = CSR_X;
              end
            endcase
          end
          3'b011: begin
            casex (funct7)
              7'b0000000: begin
                // SLTU
                _exe_fun = ALU_SLTU;
                op1_sel  = OP1_RS1;
                op2_sel  = OP2_RS2;
                _mem_wen = MEN_X;
                _rf_wen  = REN_S;
                _wb_sel  = WB_ALU;
                _csr_cmd = CSR_X;
              end
              default: begin
                _exe_fun = ALU_X;
                op1_sel  = OP1_RS1;
                op2_sel  = OP2_RS2;
                _mem_wen = MEN_X;
                _rf_wen  = REN_X;
                _wb_sel  = WB_X;
                _csr_cmd = CSR_X;
              end
            endcase
          end
          3'b100: begin
            casex (funct7)
              7'b0000000: begin
                //XOR
                _exe_fun = ALU_XOR;
                op1_sel  = OP1_RS1;
                op2_sel  = OP2_RS2;
                _mem_wen = MEN_X;
                _rf_wen  = REN_S;
                _wb_sel  = WB_ALU;
                _csr_cmd = CSR_X;
              end
              default: begin
                _exe_fun = ALU_X;
                op1_sel  = OP1_RS1;
                op2_sel  = OP2_RS2;
                _mem_wen = MEN_X;
                _rf_wen  = REN_X;
                _wb_sel  = WB_X;
                _csr_cmd = CSR_X;
              end
            endcase
          end
          3'b101: begin
            casex (funct7)
              7'b0000000: begin
                //SRL
                _exe_fun = ALU_SRL;
                op1_sel  = OP1_RS1;
                op2_sel  = OP2_RS2;
                _mem_wen = MEN_X;
                _rf_wen  = REN_S;
                _wb_sel  = WB_ALU;
                _csr_cmd = CSR_X;
              end
              7'b0100000: begin
                //SRA
                _exe_fun = ALU_SRA;
                op1_sel  = OP1_RS1;
                op2_sel  = OP2_RS2;
                _mem_wen = MEN_X;
                _rf_wen  = REN_S;
                _wb_sel  = WB_ALU;
                _csr_cmd = CSR_X;
              end
              default: begin
                _exe_fun = ALU_X;
                op1_sel  = OP1_RS1;
                op2_sel  = OP2_RS2;
                _mem_wen = MEN_X;
                _rf_wen  = REN_X;
                _wb_sel  = WB_X;
                _csr_cmd = CSR_X;
              end
            endcase
          end
          3'b110: begin
            casex (funct7)
              7'b0000000: begin
                //OR
                _exe_fun = ALU_OR;
                op1_sel  = OP1_RS1;
                op2_sel  = OP2_RS2;
                _mem_wen = MEN_X;
                _rf_wen  = REN_S;
                _wb_sel  = WB_ALU;
                _csr_cmd = CSR_X;
              end
              default: begin
                _exe_fun = ALU_X;
                op1_sel  = OP1_RS1;
                op2_sel  = OP2_RS2;
                _mem_wen = MEN_X;
                _rf_wen  = REN_X;
                _wb_sel  = WB_X;
                _csr_cmd = CSR_X;
              end
            endcase
          end

          3'b111: begin
            casex (funct7)
              7'b0000000: begin
                //AND
                _exe_fun = ALU_AND;
                op1_sel  = OP1_RS1;
                op2_sel  = OP2_RS2;
                _mem_wen = MEN_X;
                _rf_wen  = REN_S;
                _wb_sel  = WB_ALU;
                _csr_cmd = CSR_X;
              end
              default: begin
                _exe_fun = ALU_X;
                op1_sel  = OP1_RS1;
                op2_sel  = OP2_RS2;
                _mem_wen = MEN_X;
                _rf_wen  = REN_X;
                _wb_sel  = WB_X;
                _csr_cmd = CSR_X;
              end
            endcase
          end
          default: begin
            _exe_fun = ALU_X;
            op1_sel  = OP1_RS1;
            op2_sel  = OP2_RS2;
            _mem_wen = MEN_X;
            _rf_wen  = REN_X;
            _wb_sel  = WB_X;
            _csr_cmd = CSR_X;
          end
        endcase
      end
      7'b1100011: begin
        casex (funct3)
          3'b000: begin
            // BEQ
            _exe_fun = BR_BEQ;
            op1_sel  = OP1_RS1;
            op2_sel  = OP2_RS2;
            _mem_wen = MEN_X;
            _rf_wen  = REN_X;
            _wb_sel  = WB_X;
            _csr_cmd = CSR_X;
          end
          3'b001: begin
            // BNE
            _exe_fun = BR_BNE;
            op1_sel  = OP1_RS1;
            op2_sel  = OP2_RS2;
            _mem_wen = MEN_X;
            _rf_wen  = REN_X;
            _wb_sel  = WB_X;
            _csr_cmd = CSR_X;
          end
          3'b100: begin
            // BLT
            _exe_fun = BR_BLT;
            op1_sel  = OP1_RS1;
            op2_sel  = OP2_RS2;
            _mem_wen = MEN_X;
            _rf_wen  = REN_X;
            _wb_sel  = WB_X;
            _csr_cmd = CSR_X;
          end
          3'b101: begin
            // BGE
            _exe_fun = BR_BGE;
            op1_sel  = OP1_RS1;
            op2_sel  = OP2_RS2;
            _mem_wen = MEN_X;
            _rf_wen  = REN_X;
            _wb_sel  = WB_X;
            _csr_cmd = CSR_X;
          end
          3'b110: begin
            // BLTU
            _exe_fun = BR_BLTU;
            op1_sel  = OP1_RS1;
            op2_sel  = OP2_RS2;
            _mem_wen = MEN_X;
            _rf_wen  = REN_X;
            _wb_sel  = WB_X;
            _csr_cmd = CSR_X;
          end
          3'b111: begin
            // BGEU
            _exe_fun = BR_BGEU;
            op1_sel  = OP1_RS1;
            op2_sel  = OP2_RS2;
            _mem_wen = MEN_X;
            _rf_wen  = REN_X;
            _wb_sel  = WB_X;
            _csr_cmd = CSR_X;
          end
          default: begin
            _exe_fun = ALU_X;
            op1_sel  = OP1_RS1;
            op2_sel  = OP2_RS2;
            _mem_wen = MEN_X;
            _rf_wen  = REN_X;
            _wb_sel  = WB_X;
            _csr_cmd = CSR_X;
          end
        endcase
      end
      7'b1101111: begin
        // JAL
        _exe_fun = ALU_JAL;
        op1_sel  = OP1_PC;
        op2_sel  = OP2_IMJ;
        _mem_wen = MEN_X;
        _rf_wen  = REN_S;
        _wb_sel  = WB_PC;
        _csr_cmd = CSR_X;
      end
      7'b1100111: begin
        casex (funct3)
          3'b000: begin
            // JALR
            _exe_fun = ALU_JALR;
            op1_sel  = OP1_RS1;
            op2_sel  = OP2_IMI;
            _mem_wen = MEN_X;
            _rf_wen  = REN_S;
            _wb_sel  = WB_PC;
            _csr_cmd = CSR_X;
          end
          default: begin
            _exe_fun = ALU_X;
            op1_sel  = OP1_RS1;
            op2_sel  = OP2_RS2;
            _mem_wen = MEN_X;
            _rf_wen  = REN_X;
            _wb_sel  = WB_X;
            _csr_cmd = CSR_X;
          end
        endcase
      end
      7'b0110111: begin
        // LUI
        _exe_fun = ALU_ADD;
        op1_sel  = OP1_X;
        op2_sel  = OP2_IMU;
        _mem_wen = MEN_X;
        _rf_wen  = REN_S;
        _wb_sel  = WB_ALU;
        _csr_cmd = CSR_X;
      end
      7'b0010111: begin
        // AUIPC
        _exe_fun = ALU_ADD;
        op1_sel  = OP1_PC;
        op2_sel  = OP2_IMU;
        _mem_wen = MEN_X;
        _rf_wen  = REN_S;
        _wb_sel  = WB_ALU;
        _csr_cmd = CSR_X;
      end
      7'b1110011: begin
        casex (funct3)
          3'b001: begin
            // CSRRW
            _exe_fun = ALU_COPY1;
            op1_sel  = OP1_RS1;
            op2_sel  = OP2_X;
            _mem_wen = MEN_X;
            _rf_wen  = REN_S;
            _wb_sel  = WB_CSR;
            _csr_cmd = CSR_W;
          end
          3'b101: begin
            // CSRRWI
            _exe_fun = ALU_COPY1;
            op1_sel  = OP1_IMZ;
            op2_sel  = OP2_X;
            _mem_wen = MEN_X;
            _rf_wen  = REN_S;
            _wb_sel  = WB_CSR;
            _csr_cmd = CSR_W;
          end
          3'b010: begin
            // CSRRS
            _exe_fun = ALU_COPY1;
            op1_sel  = OP1_RS1;
            op2_sel  = OP2_X;
            _mem_wen = MEN_X;
            _rf_wen  = REN_S;
            _wb_sel  = WB_CSR;
            _csr_cmd = CSR_S;
          end
          3'b110: begin
            // CSRRSI
            _exe_fun = ALU_COPY1;
            op1_sel  = OP1_IMZ;
            op2_sel  = OP2_X;
            _mem_wen = MEN_X;
            _rf_wen  = REN_S;
            _wb_sel  = WB_CSR;
            _csr_cmd = CSR_S;
          end
          3'b011: begin
            // CSRRC
            _exe_fun = ALU_COPY1;
            op1_sel  = OP1_RS1;
            op2_sel  = OP2_X;
            _mem_wen = MEN_X;
            _rf_wen  = REN_S;
            _wb_sel  = WB_CSR;
            _csr_cmd = CSR_C;
          end
          3'b111: begin
            // CSRRCI
            _exe_fun = ALU_COPY1;
            op1_sel  = OP1_IMZ;
            op2_sel  = OP2_X;
            _mem_wen = MEN_X;
            _rf_wen  = REN_S;
            _wb_sel  = WB_CSR;
            _csr_cmd = CSR_C;
          end
          default: begin
            if (inst_reg[31:8] == 24'h0) begin
              // ECALL
              _exe_fun = ALU_X;
              op1_sel  = OP1_X;
              op2_sel  = OP2_X;
              _mem_wen = MEN_X;
              _rf_wen  = REN_X;
              _wb_sel  = WB_X;
              _csr_cmd = CSR_E;
            end else begin
              _exe_fun = ALU_X;
              op1_sel  = OP1_RS1;
              op2_sel  = OP2_RS2;
              _mem_wen = MEN_X;
              _rf_wen  = REN_X;
              _wb_sel  = WB_X;
              _csr_cmd = CSR_X;
            end
          end
        endcase
      end
      default: begin
        _exe_fun = ALU_X;
        op1_sel  = OP1_RS1;
        op2_sel  = OP2_RS2;
        _mem_wen = MEN_X;
        _rf_wen  = REN_X;
        _wb_sel  = WB_X;
        _csr_cmd = CSR_X;
      end
    endcase
  end  // always_comb

  // Output assignments
  assign pc_o = pc_i;
  logic [31:0] op1_reg;
  logic [31:0] op2_reg;
  logic [31:0] rf_wen_reg;
  logic [ 4:0] exe_fun_reg;
  logic [31:0] wb_sel_reg;
  logic [31:0] csr_cmd_reg;
  logic [31:0] mem_wen_reg;

  assign op1 = op1_reg;
  assign op2 = op2_reg;
  assign rf_wen = rf_wen_reg;
  assign exe_fun = exe_fun_reg;
  assign wb_sel = wb_sel_reg;
  assign csr_cmd = csr_cmd_reg;
  // mem_wen assignment moved below

  always_comb begin
    begin
      rf_wen_reg  = {30'b0, _rf_wen};  // 2-bit to 32-bit conversion (was wrong!)
      exe_fun_reg = _exe_fun;
      wb_sel_reg  = {29'b0, _wb_sel};  // 3-bit to 32-bit conversion
      csr_cmd_reg = {29'b0, _csr_cmd};  // 3-bit to 32-bit conversion
      mem_wen_reg = {30'b0, _mem_wen};  // Normal 2-bit to 32-bit conversion
    end
  end

  // CSR address selection logic
  assign csr_addr = (_csr_cmd == CSR_E) ? 12'h342 : imm_i_sext[11:0];
  assign mem_wen  = mem_wen_reg;


  always_comb begin
    casex (op1_sel)
      2'b00: op1_reg = rs1_data;  // OP1_RS1 - Use register data, not address
      2'b01: op1_reg = pc_i;  // OP1_PC
      2'b10: op1_reg = 32'h0;  // OP1_X
      2'b11: op1_reg = imm_z_uext;  // OP1_IMZ
      default: begin
        op1_reg = 32'h0;
      end
    endcase
  end

  always_comb begin
    casex (op2_sel)
      3'b000: op2_reg = 32'h0;  // OP2_X
      3'b001: op2_reg = rs2_data;  // OP2_RS2 - Use register data, not address
      3'b010: op2_reg = imm_i_sext;  // OP2_IMI
      3'b011: op2_reg = imm_s_sext;  // OP2_IMS
      3'b100: op2_reg = imm_j_sext;  // OP2_IMJ
      3'b101: op2_reg = imm_u_shifted;  // OP2_IMU
      default: begin
        op2_reg = 32'h0;
      end
    endcase
  end

  always_comb begin
    inst_reg = inst;
  end

endmodule
