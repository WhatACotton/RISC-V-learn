`include "consts.vh"

module alu (
    input [31:0] pc_i,
    input [4:0] exe_fun,
    input [31:0] op1,
    input [31:0] op2,
    output logic [31:0] alu_out,
    output logic br_flg,
    output logic jump
);

  logic signed [31:0] signed_op1;
  logic signed [31:0] signed_op2;
  always_comb begin
    signed_op1 = op1;
    signed_op2 = op2;
    casex (exe_fun)
      ALU_ADD: begin
        alu_out = op1 + op2;
      end
      ALU_SUB: begin
        alu_out = op1 - op2;
      end
      ALU_AND: begin
        alu_out = op1 & op2;
      end
      ALU_OR: begin
        alu_out = op1 | op2;
      end
      ALU_XOR: begin
        alu_out = op1 ^ op2;
      end
      ALU_SLL: begin
        alu_out = op1 << op2[4:0];
      end
      ALU_SRL: begin
        alu_out = op1 >> op2[4:0];
      end
      ALU_SRA: begin
        alu_out = signed_op1 >>> op2[4:0];
      end
      ALU_SLT: begin
        alu_out = (signed_op1 < signed_op2) ? 32'd1 : 32'd0;
      end
      ALU_SLTU: begin
        alu_out = (op1 < op2) ? 32'd1 : 32'd0;
      end
      ALU_JALR: begin
        alu_out = (op1 + op2) & ~32'b1;  // JALR target address, clear LSB
      end
      ALU_JAL: begin
        alu_out = op1 + op2;  // JAL target address (PC + offset)
      end
      ALU_COPY1: begin
        alu_out = op1;
      end
      default: begin
        alu_out = 32'b0;
      end
    endcase
    // Branch flag logic
    br_flg = 1'b0;
    case (exe_fun)
      BR_BEQ:  br_flg = (op1 == op2);
      BR_BNE:  br_flg = (op1 != op2);
      BR_BLT:  br_flg = (signed_op1 < signed_op2);
      BR_BGE:  br_flg = (signed_op1 >= signed_op2);
      BR_BLTU: br_flg = (op1 < op2);
      BR_BGEU: br_flg = (op1 >= op2);
      default: br_flg = 1'b0;
    endcase

    jump = (exe_fun == ALU_JALR) || (exe_fun == ALU_JAL);
  end


endmodule
