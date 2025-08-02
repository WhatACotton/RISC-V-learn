`include "consts.vh"
`include "id.sv"
`include "exe.sv"
`include "mem.sv"

module CORE (
    input clk,
    input rst,
    output reg exit,

    // inst memory I/O
    input  [31:0] imem_inst,
    output [31:0] imem_addr,

    // data memory I/O
    output dmem_wen,
    output [31:0] dmem_wdata,
    input [31:0] dmem_rdata,
    output [31:0] dmem_addr,

    output logic gp
);

  // ========== Data Hazard Detection and Control ==========
  logic load_use_hazard;
  logic data_hazard_stall;
  logic stall_pipeline;

  // Extract register addresses from current instruction (IF/ID stage)
  logic [4:0] current_rs1, current_rs2;
  assign current_rs1 = if_id_inst[19:15];
  assign current_rs2 = if_id_inst[24:20];

  // Detect load-use hazard and other data hazards
  always_comb begin
    load_use_hazard   = 1'b0;
    data_hazard_stall = 1'b0;

    // Check for load-use hazard (load instruction followed by use)
    // Only stall if the load instruction is currently in EX stage and writes to a register that current instruction reads
    if (id_ex_wb_sel == WB_MEM && id_ex_rf_wen && id_ex_wb_addr != 5'h0) begin
      if ((id_ex_wb_addr == current_rs1 && current_rs1 != 5'h0) ||
          (id_ex_wb_addr == current_rs2 && current_rs2 != 5'h0)) begin
        load_use_hazard = 1'b1;
      end
    end

    // 基本的なRAWハザード検出（保守的アプローチ）
    // EX段階でレジスタファイルに書き込む命令があり、ID段階の命令がそのレジスタを読み取る場合
    if (id_ex_rf_wen && id_ex_wb_addr != 5'h0 && id_ex_wb_sel != WB_MEM) begin  // Non-load instructions
      if ((id_ex_wb_addr == current_rs1 && current_rs1 != 5'h0) ||
          (id_ex_wb_addr == current_rs2 && current_rs2 != 5'h0)) begin
        data_hazard_stall = 1'b1;
      end
    end

    // Additional stall for consecutive memory operations to ensure data integrity
    if (ex_mem_mem_wen && id_ex_mem_wen) begin
      data_hazard_stall = 1'b1;
    end

    // Stall for any detected hazard
    stall_pipeline = load_use_hazard || data_hazard_stall;
  end

  // ========== Pipeline Registers ==========
  // IF/ID Pipeline Register
  logic [31:0] if_id_pc;
  logic [31:0] if_id_inst;

  // ID/EX Pipeline Register
  logic [31:0] id_ex_pc;
  logic [31:0] id_ex_inst;  // Track instruction through ID/EX stage
  logic [31:0] id_ex_op1;
  logic [31:0] id_ex_op2;
  logic [ 4:0] id_ex_wb_addr;
  logic [ 4:0] id_ex_exe_fun;
  logic [ 2:0] id_ex_wb_sel;
  logic        id_ex_rf_wen;
  logic        id_ex_mem_wen;
  logic [ 2:0] id_ex_csr_cmd;
  logic [11:0] id_ex_csr_addr;
  logic [31:0] id_ex_rs2_data;
  logic [31:0] id_ex_imm_b_sext;
  logic [31:0] id_ex_imm_j_sext;
  logic        id_ex_is_jalr;  // JALR detection signal in pipeline

  // EX/MEM Pipeline Register
  logic [31:0] ex_mem_pc;
  logic [31:0] ex_mem_alu_out;
  logic [31:0] ex_mem_inst;  // Track instruction through EX/MEM stage
  logic [ 4:0] ex_mem_wb_addr;
  logic [ 2:0] ex_mem_wb_sel;
  logic        ex_mem_rf_wen;
  logic        ex_mem_mem_wen;
  logic [ 2:0] ex_mem_csr_cmd;
  logic [11:0] ex_mem_csr_addr;
  logic [31:0] ex_mem_rs2_data;
  logic [31:0] ex_mem_op1_data;
  logic        ex_mem_br_taken;
  logic [31:0] ex_mem_br_target;
  logic        ex_mem_jump;

  // MEM/WB Pipeline Register
  logic [31:0] mem_wb_pc;
  logic [31:0] mem_wb_alu_out;
  logic [31:0] mem_wb_mem_data;
  logic [31:0] mem_wb_inst;  // Track instruction through MEM/WB stage for ECALL detection
  logic [ 4:0] mem_wb_wb_addr;
  logic [ 2:0] mem_wb_wb_sel;
  logic        mem_wb_rf_wen;
  logic [31:0] mem_wb_csr_rdata;

  // ========== Program Counter ==========
  logic [31:0] pc;
  logic [31:0] pc_plus4;
  logic [31:0] pc_next;
  logic        br_taken;
  logic [31:0] br_target;
  logic        exe_br_flg;
  logic        exe_jmp_flg;
  logic [31:0] if_inst;  // Declare if_inst signal properly

  assign imem_addr = pc;  // Use full PC address for byte-addressable memory
  assign if_inst   = imem_inst;  // Connect instruction memory output to IF stage

  always_comb begin
    pc_plus4 = pc + 32'h4;

    if (ex_mem_br_taken) begin
      pc_next = ex_mem_br_target;  // ブランチターゲットを使用
    end else if (ex_mem_jump) begin
      // ジャンプ命令の処理 - EX/MEM段階のデータを使用
      pc_next = ex_mem_br_target;  // ジャンプターゲットもbr_targetに格納
    end else begin
      pc_next = pc_plus4;
    end
  end


  always_ff @(posedge clk) begin
    if (rst) begin
      pc <= 32'h0;
    end else if (!stall_pipeline) begin  // Only update PC if not stalling
      pc <= pc_next;
    end
  end


  // ========== Pipeline Stage: IF/ID ==========
  logic flush_pipeline;
  always_comb begin
    flush_pipeline = ex_mem_jump || ex_mem_br_taken;  // MEM段階の結果を使用
  end

  // ========== Pipeline Stage: ID (Instruction Decode) ==========
  logic [4:0] rs1_addr, rs2_addr, wb_addr;
  logic [31:0] imm_i_sext, imm_s_sext, imm_b_sext, imm_j_sext, imm_u_shifted, imm_z_uext;
  logic [31:0] op1, op2;
  logic [4:0] exe_fun;
  logic rf_wen;
  logic mem_wen;
  logic [2:0] csr_cmd;
  logic [11:0] csr_addr_decode;
  logic [1:0] op1_sel;
  logic [2:0] op2_sel;

  // Extract register addresses directly from instruction
  assign rs1_addr = if_id_inst[19:15];
  assign rs2_addr = if_id_inst[24:20];

  // ID stage signals with correct bit widths
  logic [31:0] rf_wen_32bit;
  logic [31:0] wb_sel_32bit;
  logic [31:0] csr_addr_32bit;
  logic [31:0] csr_cmd_32bit;
  logic [31:0] mem_wen_32bit;
  logic is_jalr;  // JALR instruction detection signal

  // ID stage instantiation using decoder module
  decoder id_stage (
      .inst         (if_id_inst),
      .pc_i         (if_id_pc),
      .rs1_addr     (rs1_addr),
      .rs2_addr     (rs2_addr),
      .rs1_data     (rs1_data),        // Add register data inputs
      .rs2_data     (rs2_data),        // Add register data inputs
      .pc_o         (),
      .op1          (op1),
      .op2          (op2),
      .wb_addr      (wb_addr),
      .rf_wen       (rf_wen_32bit),
      .exe_fun      (exe_fun),
      .wb_sel       (wb_sel_32bit),
      .imm_i_sext   (imm_i_sext),
      .imm_s_sext   (imm_s_sext),
      .imm_b_sext   (imm_b_sext),
      .imm_u_shifted(imm_u_shifted),
      .imm_z_uext   (imm_z_uext),
      .imm_j_sext   (imm_j_sext),
      .csr_addr     (csr_addr_32bit),
      .csr_cmd      (csr_cmd_32bit),
      .mem_wen      (mem_wen_32bit),
      .is_jalr      (is_jalr)
  );

  // Convert 32-bit outputs to appropriate sizes
  assign rf_wen = rf_wen_32bit[0];  // Use LSB directly since REN_S = 2'd1
  assign wb_sel = wb_sel_32bit[2:0];
  assign csr_addr_decode = csr_addr_32bit[11:0];
  assign csr_cmd = csr_cmd_32bit[2:0];
  assign mem_wen = (mem_wen_32bit[1:0] == 2'd1);  // MEN_S check


  // ========== Pipeline Stage: IF/ID ==========
  always_ff @(posedge clk) begin
    if (rst) begin
      if_id_pc   <= 32'h0;
      if_id_inst <= 32'h0;
    end else if (ex_mem_jump || ex_mem_br_taken) begin
      // Flush pipeline on jump/branch - MEM段階の結果を使用
      if_id_pc   <= 32'h0;
      if_id_inst <= 32'h13;  // NOP instruction (addi x0, x0, 0)
    end else if (!stall_pipeline) begin  // Only update if not stalling
      if_id_pc   <= pc;
      if_id_inst <= if_inst;
    end
    // If stalling, keep current values (no update)
  end

  // ========== Pipeline Stage: ID/EX ==========
  always_ff @(posedge clk) begin
    if (rst || flush_pipeline) begin
      // フラッシュ時はNOPを挿入
      id_ex_pc <= 32'h0;
      id_ex_inst <= 32'h0;  // NOP instruction
      id_ex_op1 <= 32'h0;
      id_ex_op2 <= 32'h0;
      id_ex_wb_addr <= 5'h0;
      id_ex_exe_fun <= ALU_X;
      id_ex_wb_sel <= WB_X;
      id_ex_rf_wen <= 1'b0;
      id_ex_mem_wen <= 1'b0;
      id_ex_csr_cmd <= CSR_X;
      id_ex_csr_addr <= 12'h0;
      id_ex_rs2_data <= 32'h0;
      id_ex_imm_b_sext <= 32'h0;
      id_ex_imm_j_sext <= 32'h0;
      id_ex_is_jalr <= 1'b0;
    end else if (stall_pipeline) begin
      // ストール時はID/EX段階でNOPを挿入 - レジスタを0にリセット
      id_ex_pc <= 32'h0;
      id_ex_inst <= 32'h0;  // NOP instruction
      id_ex_op1 <= 32'h0;
      id_ex_op2 <= 32'h0;
      id_ex_wb_addr <= 5'h0;
      id_ex_exe_fun <= ALU_X;
      id_ex_wb_sel <= WB_X;
      id_ex_rf_wen <= 1'b0;  // 重要: Write enableを無効化
      id_ex_mem_wen <= 1'b0;  // 重要: Memory write enableを無効化
      id_ex_csr_cmd <= CSR_X;
      id_ex_csr_addr <= 12'h0;
      id_ex_rs2_data <= 32'h0;
      id_ex_imm_b_sext <= 32'h0;
      id_ex_imm_j_sext <= 32'h0;
      id_ex_is_jalr <= 1'b0;
    end else begin
      // 通常動作: IF/IDからID/EXに命令を転送
      id_ex_pc <= if_id_pc;
      id_ex_inst <= if_id_inst;  // Forward instruction through pipeline
      id_ex_op1 <= op1;
      id_ex_op2 <= op2;
      id_ex_wb_addr <= wb_addr;
      id_ex_exe_fun <= exe_fun;
      id_ex_wb_sel <= wb_sel_32bit[2:0];
      id_ex_rf_wen <= rf_wen;
      id_ex_mem_wen <= mem_wen;
      id_ex_csr_cmd <= csr_cmd;
      id_ex_csr_addr <= csr_addr_decode;
      id_ex_rs2_data <= rs2_data;
      id_ex_imm_b_sext <= imm_b_sext;
      id_ex_imm_j_sext <= imm_j_sext;
      id_ex_is_jalr <= is_jalr;
    end
  end

  // ========== Pipeline Stage: EX (Execute) ==========
  logic [31:0] alu_out;
  logic jump_instr;

  // EX stage instantiation using alu module
  alu ex_stage (
      .pc_i(id_ex_pc),
      .exe_fun(id_ex_exe_fun),
      .op1(id_ex_op1),
      .op2(id_ex_op2),
      .alu_out(alu_out),
      .br_flg(exe_br_flg),
      .jump(jump_instr)
  );

  // Branch target calculation
  logic [31:0] branch_target;
  always_comb begin
    case (id_ex_exe_fun)
      ALU_JAL: begin
        // JAL instruction: use ALU result (PC + J-immediate)
        branch_target = alu_out;
      end
      ALU_JALR: begin
        // JALR instruction: use ALU result (rs1 + imm) & ~1
        branch_target = alu_out;
      end
      BR_BEQ, BR_BNE, BR_BLT, BR_BGE, BR_BLTU, BR_BGEU: begin
        // Branch instructions: PC + B-immediate
        branch_target = id_ex_pc + id_ex_imm_b_sext;
      end
      default: begin
        branch_target = 32'h0;
      end
    endcase
  end

  assign exe_jmp_flg = jump_instr;

  // ========== Pipeline Stage: EX/MEM ==========
  always_ff @(posedge clk) begin
    if (rst) begin
      ex_mem_pc <= 32'h0;
      ex_mem_alu_out <= 32'h0;
      ex_mem_inst <= 32'h0;  // Reset instruction in EX/MEM stage
      ex_mem_wb_addr <= 5'h0;
      ex_mem_wb_sel <= WB_X;
      ex_mem_rf_wen <= 1'b0;
      ex_mem_mem_wen <= 1'b0;
      ex_mem_csr_cmd <= CSR_X;
      ex_mem_csr_addr <= 12'h0;
      ex_mem_rs2_data <= 32'h0;
      ex_mem_op1_data <= 32'h0;
      ex_mem_br_taken <= 1'b0;
      ex_mem_br_target <= 32'h0;
      ex_mem_jump <= 1'b0;
    end else begin
      ex_mem_pc <= id_ex_pc;
      ex_mem_inst <= id_ex_inst;  // Forward instruction to EX/MEM stage
      ex_mem_alu_out <= alu_out;
      ex_mem_wb_addr <= id_ex_wb_addr;
      ex_mem_wb_sel <= id_ex_wb_sel;
      ex_mem_rf_wen <= id_ex_rf_wen;
      ex_mem_mem_wen <= id_ex_mem_wen;
      ex_mem_csr_cmd <= id_ex_csr_cmd;
      ex_mem_csr_addr <= id_ex_csr_addr;
      ex_mem_rs2_data <= id_ex_rs2_data;
      ex_mem_op1_data <= id_ex_op1;
      ex_mem_br_taken <= exe_br_flg;  // ブランチ命令の結果
      ex_mem_br_target <= branch_target;
      ex_mem_jump <= jump_instr;  // ジャンプ命令の検出
    end
  end

  // ========== Pipeline Stage: MEM (Memory Access) ==========
  logic [31:0] mem_stage_wb_data;

  // MEM stage instantiation using mem module
  mem mem_stage (
      .clk(clk),
      .rst(rst),
      .pc(ex_mem_pc),
      .alu_out(ex_mem_alu_out),
      .op1_data(ex_mem_op1_data),
      .wb_addr(ex_mem_wb_addr),
      .wb_sel(ex_mem_wb_sel),
      .csr_cmd(ex_mem_csr_cmd),
      .csr_addr_i(ex_mem_csr_addr),
      .dmem_rdata(dmem_rdata),
      .csr_wen(csr_wen),
      .csr_addr_o(csr_addr),
      .csr_wdata(csr_wdata),
      .csr_rdata(csr_rdata),
      .mem_wb_data(mem_stage_wb_data)
  );

  // Data memory interface
  assign dmem_addr  = ex_mem_alu_out;  // Use full address for byte-addressable memory
  assign dmem_wen   = ex_mem_mem_wen;
  assign dmem_wdata = ex_mem_rs2_data;

  // ========== Register File ==========
  logic [31:0] regfile[31:0];
  logic [31:0] rs1_data, rs2_data;
  logic [31:0] wb_data;


  // Register file read with improved forwarding logic
  always_comb begin
    // rs1 forwarding logic
    if (rs1_addr == 5'h0) begin
      rs1_data = 32'h0;  // x0 is always zero
    end else if (ex_mem_rf_wen && ex_mem_wb_addr == rs1_addr && ex_mem_wb_addr != 5'h0 && 
                 ex_mem_wb_sel == WB_MEM) begin
      // Forward from MEM stage for load instructions - use memory data (highest priority for loads)
      rs1_data = dmem_rdata;
    end else if (ex_mem_rf_wen && ex_mem_wb_addr == rs1_addr && ex_mem_wb_addr != 5'h0 && 
                 ex_mem_wb_sel != WB_MEM) begin
      // Forward from MEM stage for non-load instructions
      rs1_data = ex_mem_alu_out;
    end else if (mem_wb_rf_wen && mem_wb_wb_addr == rs1_addr && mem_wb_wb_addr != 5'h0) begin
      // Forward from WB stage
      rs1_data = wb_data;
    end else if (id_ex_rf_wen && id_ex_wb_addr == rs1_addr && id_ex_wb_addr != 5'h0 && 
                 id_ex_wb_sel != WB_MEM) begin
      // Forward from EX stage for non-load instructions (lower priority)
      rs1_data = alu_out;
    end else begin
      // No forwarding needed, read from register file
      rs1_data = regfile[rs1_addr];
    end

    // rs2 forwarding logic
    if (rs2_addr == 5'h0) begin
      rs2_data = 32'h0;  // x0 is always zero
    end else if (ex_mem_rf_wen && ex_mem_wb_addr == rs2_addr && ex_mem_wb_addr != 5'h0 && 
                 ex_mem_wb_sel == WB_MEM) begin
      // Forward from MEM stage for load instructions - use memory data (highest priority for loads)
      rs2_data = dmem_rdata;
    end else if (ex_mem_rf_wen && ex_mem_wb_addr == rs2_addr && ex_mem_wb_addr != 5'h0 && 
                 ex_mem_wb_sel != WB_MEM) begin
      // Forward from MEM stage for non-load instructions
      rs2_data = ex_mem_alu_out;
    end else if (mem_wb_rf_wen && mem_wb_wb_addr == rs2_addr && mem_wb_wb_addr != 5'h0) begin
      // Forward from WB stage
      rs2_data = wb_data;
    end else if (id_ex_rf_wen && id_ex_wb_addr == rs2_addr && id_ex_wb_addr != 5'h0 && 
                 id_ex_wb_sel != WB_MEM) begin
      // Forward from EX stage for non-load instructions (lower priority)
      rs2_data = alu_out;
    end else begin
      // No forwarding needed, read from register file
      rs2_data = regfile[rs2_addr];
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      for (integer i = 0; i < 32; i++) begin
        if (i == 2) begin
          regfile[i] <= 32'h3000;  // x2 = sp (stack pointer) - safe high address
        end else begin
          regfile[i] <= 32'd0;
        end
      end
    end else begin
      if (mem_wb_rf_wen && mem_wb_wb_addr != 5'h0) begin
        regfile[mem_wb_wb_addr] <= wb_data;
      end
    end
  end

  // ========== CSR Register File ==========
  logic [31:0] csr_regfile[0:4095];
  logic        csr_wen;
  logic [11:0] csr_addr;
  logic [31:0] csr_wdata;
  logic [31:0] csr_rdata;

  // CSR read logic
  always_comb begin
    csr_rdata = csr_regfile[csr_addr];
  end

  // CSR write logic
  always_ff @(posedge clk) begin
    if (rst) begin
      for (integer i = 0; i < 4096; i++) begin
        csr_regfile[i] <= 32'd0;
      end
    end else begin
      if (csr_wen) begin
        csr_regfile[csr_addr] <= csr_wdata;
      end
    end
  end

  // ========== Pipeline Stage: MEM/WB ==========
  always_ff @(posedge clk) begin
    if (rst) begin
      mem_wb_pc <= 32'h0;
      mem_wb_alu_out <= 32'h0;
      mem_wb_mem_data <= 32'h0;
      mem_wb_inst <= 32'h0;  // Reset instruction in MEM/WB stage
      mem_wb_wb_addr <= 5'h0;
      mem_wb_wb_sel <= WB_X;
      mem_wb_rf_wen <= 1'b0;
      mem_wb_csr_rdata <= 32'h0;
    end else begin
      mem_wb_pc <= ex_mem_pc;
      mem_wb_inst <= ex_mem_inst;  // Forward instruction to MEM/WB stage
      mem_wb_alu_out <= ex_mem_alu_out;
      mem_wb_mem_data <= mem_stage_wb_data;
      mem_wb_wb_addr <= ex_mem_wb_addr;
      mem_wb_wb_sel <= ex_mem_wb_sel;
      mem_wb_rf_wen <= ex_mem_rf_wen;
      mem_wb_csr_rdata <= csr_rdata;
    end
  end

  // ========== Pipeline Stage: WB (Write Back) ==========
  always_comb begin
    case (mem_wb_wb_sel)
      WB_MEM:  wb_data = mem_wb_mem_data;
      WB_PC:   wb_data = mem_wb_pc + 32'd4;  // JAL/JALR命令のリターンアドレス
      WB_CSR:  wb_data = mem_wb_csr_rdata;
      default: wb_data = mem_wb_alu_out;  // WB_ALU
    endcase
  end

  // ========== Exit Logic ==========
  logic exit_delayed;
  logic [3:0] exit_counter;  // Increased to 4 bits for longer delay

  always_ff @(posedge clk) begin
    if (rst) begin
      exit <= 1'b0;
      exit_delayed <= 1'b0;
      exit_counter <= 4'b0000;
    end else begin
      // Detect ECALL instruction (environment call) for exit
      // ECALL instruction: 0x00000073
      // Wait until ECALL reaches MEM/WB stage to ensure all previous instructions complete
      if (!rst && pc != 32'h0 && mem_wb_inst == 32'h00000073) begin
        exit_delayed <= 1'b1;
        exit_counter <= 4'b0000;
      end

      // Exit after more clock cycles to allow ALL pending operations to complete
      if (exit_delayed) begin
        exit_counter <= exit_counter + 1;
        if (exit_counter == 4'b1111) begin  // Exit after 15 cycles
          exit <= 1'b1;
        end
      end
    end
  end
  always @(posedge clk) begin
    //gp = regfile[3];  // Set gp to register x3 (gp register)
    if (rst) begin
      gp <= 1'b0;
    end else begin
      gp <= regfile[3];  // Set gp to register x3 (gp register)
    end

    // Debug output for load-use hazard detection
    if (!rst && load_use_hazard) begin
      $display(
          "*** LOAD-USE HAZARD: id_ex_wb_addr=%d, current_rs1=%d, current_rs2=%d, stall=%b ***",
          id_ex_wb_addr, current_rs1, current_rs2, stall_pipeline);
    end
  end

endmodule
