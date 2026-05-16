module id_stage(
    input  [31:0] inst,
    input         wb_wen,
    input  [4:0]  wb_rd,
    input  [31:0] wb_wdata,
    input         clk,
    input         rst_n,
    output [4:0]  rs1,
    output [4:0]  rs2,
    output [4:0]  rd,
    output [31:0] imm_alu,
    output [31:0] imm_aux,
    output [31:0] rdata1,
    output [31:0] rdata2,
    output [2:0]  funct3,
    output [3:0]  alu_ctrl,
    output        use_rs1,
    output        use_rs2,
    output        alu_src_imm,
    output        mem_read,
    output        mem_write,
    output        reg_wen,
    output        branch,
    output        jal,
    output        jalr,
    output        is_mul,
    output        flush_instr,
    output [1:0]  wb_sel
);
localparam WB_ALU = 2'd0;
localparam WB_MEM = 2'd1;
localparam WB_PC4 = 2'd2;
localparam WB_IMM = 2'd3;

wire [6:0] opcode;
wire [6:0] funct7;
wire is_rtype;
wire is_itype;
wire is_load;
wire is_store;
wire is_branch;
wire is_jal;
wire is_jalr;
wire is_lui;
wire is_mul_inst;
wire [31:0] imm_i;
wire [31:0] imm_s;
wire [31:0] imm_b;
wire [31:0] imm_j;
wire [31:0] imm_u;

assign opcode = inst[6:0];
assign funct3 = inst[14:12];
assign funct7 = inst[31:25];
assign rs1 = inst[19:15];
assign rs2 = inst[24:20];
assign rd  = inst[11:7];

assign is_rtype  = (opcode == 7'b0110011);
assign is_itype  = (opcode == 7'b0010011);
assign is_load   = (opcode == 7'b0000011);
assign is_store  = (opcode == 7'b0100011);
assign is_branch = (opcode == 7'b1100011);
assign is_jal    = (opcode == 7'b1101111);
assign is_jalr   = (opcode == 7'b1100111);
assign is_lui    = (opcode == 7'b0110111);
assign is_mul_inst = is_rtype & (funct7 == 7'b0000001) & (funct3 == 3'b000);

assign imm_i = {{20{inst[31]}}, inst[31:20]};
assign imm_s = {{20{inst[31]}}, inst[31:25], inst[11:7]};
assign imm_b = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
assign imm_j = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};
assign imm_u = {inst[31:12], 12'b0};
assign imm_alu = is_store ? imm_s : imm_i;
assign imm_aux = is_jal ? imm_j :
                 is_branch ? imm_b : imm_u;

assign use_rs1 = is_rtype | is_itype | is_load | is_store | is_branch | is_jalr;
assign use_rs2 = is_rtype | is_store | is_branch;
assign alu_src_imm = is_itype | is_load | is_store | is_jalr;
assign mem_read = is_load;
assign mem_write = is_store;
assign branch = is_branch;
assign jal = is_jal;
assign jalr = is_jalr;
assign is_mul = is_mul_inst;
assign flush_instr = (inst == 32'h00202007);
assign reg_wen = (is_rtype | is_itype | is_load | is_jal | is_jalr | is_lui) & ~flush_instr;
assign wb_sel = is_load ? WB_MEM :
                (is_jal | is_jalr) ? WB_PC4 :
                is_lui ? WB_IMM : WB_ALU;

register_file register_file0 (
    .clk        (clk),
    .rst_n      (rst_n),
    .read1      (rs1),
    .read2      (rs2),
    .write_reg  (wb_rd),
    .wdata      (wb_wdata),
    .wen        (wb_wen),
    .rdata1     (rdata1),
    .rdata2     (rdata2)
);

alu_ctrl_gen alu_ctrl_gen0 (
    .opcode     (opcode),
    .funct3     (funct3),
    .funct7     (funct7),
    .alu_ctrl   (alu_ctrl)
);
endmodule
