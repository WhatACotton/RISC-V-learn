`include "consts.vh"

module mem (
    input clk,
    input rst,

    // Pipeline registers from EX stage
    input [31:0] pc,
    input [31:0] alu_out,
    input [31:0] op1_data,
    input [ 4:0] wb_addr,
    input [ 2:0] wb_sel,
    input [ 2:0] csr_cmd,
    input [11:0] csr_addr_i,

    // Data memory interface
    input [31:0] dmem_rdata,

    // CSR interface (connected to core)
    output logic        csr_wen,
    output logic [11:0] csr_addr_o,
    output logic [31:0] csr_wdata,
    input        [31:0] csr_rdata,

    // Outputs
    output logic [31:0] mem_wb_data
);

  // CSR interface assignments
  assign csr_addr_o = csr_addr_i;
  assign csr_wen = (csr_cmd != CSR_X);

  // CSR write data logic
  always_comb begin
    case (csr_cmd)
      CSR_W:   csr_wdata = op1_data;
      CSR_S:   csr_wdata = csr_rdata | op1_data;
      CSR_C:   csr_wdata = csr_rdata & ~op1_data;
      CSR_E:   csr_wdata = 32'd11;
      default: csr_wdata = 32'd0;
    endcase
  end

  // Write back data selection
  always_comb begin
    case (wb_sel)
      WB_MEM:  mem_wb_data = dmem_rdata;
      WB_PC:   mem_wb_data = pc + 32'd4;
      WB_CSR:  mem_wb_data = csr_rdata;
      default: mem_wb_data = alu_out;  // WB_ALU
    endcase
  end

endmodule
