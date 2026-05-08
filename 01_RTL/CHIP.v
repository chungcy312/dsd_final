module CHIP #(
    parameter ICACHE_BLOCKS = 16,
    parameter ICACHE_WAYS   = 1,
    parameter DCACHE_BLOCKS = 16,
    parameter DCACHE_WAYS   = 1
) (
    clk,
    rst_n,
//----------for slow_memD------------
    mem_read_D,
    mem_write_D,
    mem_addr_D,
    mem_wdata_D,
    mem_rdata_D,
    mem_ready_D,
//----------for slow_memI------------
    mem_read_I,
    mem_write_I,
    mem_addr_I,
    mem_wdata_I,
    mem_rdata_I,
    mem_ready_I,
//----------for TestBed--------------
    o_done
);
input           clk, rst_n;

output          mem_read_D;
output          mem_write_D;
output  [31:4]  mem_addr_D;
output  [127:0] mem_wdata_D;
input   [127:0] mem_rdata_D;
input           mem_ready_D;

output          mem_read_I;
output          mem_write_I;
output  [31:4]  mem_addr_I;
output  [127:0] mem_wdata_I;
input   [127:0] mem_rdata_I;
input           mem_ready_I;

output          o_done;

wire [31:0] core_i_addr;
wire [31:0] core_i_rdata;
wire        core_i_ready;

wire        core_d_req;
wire        core_d_wen;
wire [31:0] core_d_addr;
wire [31:0] core_d_wdata;
wire [31:0] core_d_rdata;
wire        core_d_ready;

wire        core_flush;
wire        dcache_flush_done;
wire        core_done;

assign o_done = core_done & dcache_flush_done;

core core0 (
    .clk            (clk),
    .rst_n          (rst_n),
    .imem_ready     (core_i_ready),
    .imem_addr      (core_i_addr),
    .imem_rdata     (core_i_rdata),
    .dmem_req       (core_d_req),
    .dmem_wen       (core_d_wen),
    .dmem_addr      (core_d_addr),
    .dmem_wdata     (core_d_wdata),
    .dmem_rdata     (core_d_rdata),
    .dmem_ready     (core_d_ready),
    .o_flush        (core_flush),
    .o_done         (core_done)
);

blocking_cache #(
    .BLOCKS         (ICACHE_BLOCKS),
    .WAYS           (ICACHE_WAYS),
    .READ_ONLY      (1)
) icache0 (
    .clk            (clk),
    .rst_n          (rst_n),
    .req            (~core_done),
    .wen            (1'b0),
    .addr           (core_i_addr),
    .wdata          (32'b0),
    .rdata          (core_i_rdata),
    .ready          (core_i_ready),
    .flush          (1'b0),
    .flush_done     (),
    .mem_read       (mem_read_I),
    .mem_write      (mem_write_I),
    .mem_addr       (mem_addr_I),
    .mem_wdata      (mem_wdata_I),
    .mem_rdata      (mem_rdata_I),
    .mem_ready      (mem_ready_I)
);

blocking_cache #(
    .BLOCKS         (DCACHE_BLOCKS),
    .WAYS           (DCACHE_WAYS),
    .READ_ONLY      (0)
) dcache0 (
    .clk            (clk),
    .rst_n          (rst_n),
    .req            (core_d_req),
    .wen            (core_d_wen),
    .addr           (core_d_addr),
    .wdata          (core_d_wdata),
    .rdata          (core_d_rdata),
    .ready          (core_d_ready),
    .flush          (core_flush),
    .flush_done     (dcache_flush_done),
    .mem_read       (mem_read_D),
    .mem_write      (mem_write_D),
    .mem_addr       (mem_addr_D),
    .mem_wdata      (mem_wdata_D),
    .mem_rdata      (mem_rdata_D),
    .mem_ready      (mem_ready_D)
);

endmodule

module core (
    input         clk,
    input         rst_n,

    input         imem_ready,
    output [31:0] imem_addr,
    input  [31:0] imem_rdata,

    output        dmem_req,
    output        dmem_wen,
    output [31:0] dmem_addr,
    output [31:0] dmem_wdata,
    input  [31:0] dmem_rdata,
    input         dmem_ready,

    output        o_flush,
    output        o_done
);
localparam WB_ALU = 2'd0;
localparam WB_MEM = 2'd1;
localparam WB_PC4 = 2'd2;
localparam WB_IMM = 2'd3;

reg done_r;

wire        if_stall;
wire        branch_predict_taken;
wire [31:0] if_pc;
wire [31:0] if_pc4;
wire [31:0] if_inst;

reg        ifid_valid;
reg [31:0] ifid_pc;
reg [31:0] ifid_pc4;
reg [31:0] ifid_inst;

wire [4:0]  id_rs1;
wire [4:0]  id_rs2;
wire [4:0]  id_rd;
wire [31:0] id_imm_i;
wire [31:0] id_imm_s;
wire [31:0] id_imm_b;
wire [31:0] id_imm_j;
wire [31:0] id_imm_u;
wire [31:0] id_rdata1;
wire [31:0] id_rdata2;
wire [2:0]  id_funct3;
wire [3:0]  id_alu_ctrl;
wire        id_use_rs1;
wire        id_use_rs2;
wire        id_alu_src_imm;
wire        id_mem_read;
wire        id_mem_write;
wire        id_reg_wen;
wire        id_branch;
wire        id_jal;
wire        id_jalr;
wire        id_lui;
wire        id_flush_instr;
wire [1:0]  id_wb_sel;

reg        idex_valid;
reg [31:0] idex_pc;
reg [31:0] idex_pc4;
reg [31:0] idex_rdata1;
reg [31:0] idex_rdata2;
reg [31:0] idex_imm_i;
reg [31:0] idex_imm_s;
reg [31:0] idex_imm_b;
reg [31:0] idex_imm_j;
reg [31:0] idex_imm_u;
reg [4:0]  idex_rs1;
reg [4:0]  idex_rs2;
reg [4:0]  idex_rd;
reg [2:0]  idex_funct3;
reg [3:0]  idex_alu_ctrl;
reg        idex_alu_src_imm;
reg        idex_mem_read;
reg        idex_mem_write;
reg        idex_reg_wen;
reg        idex_branch;
reg        idex_jal;
reg        idex_jalr;
reg        idex_lui;
reg        idex_flush_instr;
reg [1:0]  idex_wb_sel;

wire [31:0] exmem_forward_data;
wire [31:0] memwb_forward_data;
wire        ex_redirect;
wire [31:0] ex_redirect_pc;
wire [31:0] ex_alu_result;
wire [31:0] ex_store_data;
wire [31:0] ex_wb_data;

reg        exmem_valid;
reg [31:0] exmem_alu_result;
reg [31:0] exmem_store_data;
reg [31:0] exmem_wb_data;
reg [4:0]  exmem_rd;
reg        exmem_mem_read;
reg        exmem_mem_write;
reg        exmem_reg_wen;
reg        exmem_flush_instr;
reg [1:0]  exmem_wb_sel;

wire [31:0] mem_wb_data;

reg        memwb_valid;
reg [31:0] memwb_wb_data;
reg [4:0]  memwb_rd;
reg        memwb_reg_wen;
reg        memwb_flush_instr;

wire wb_wen;
wire [4:0] wb_rd;
wire [31:0] wb_wdata;
wire load_use_stall;
wire mem_busy;
wire global_stall;
wire idex_insert_bubble;
wire ex_redirect_valid;

assign branch_predict_taken = 1'b0;
assign mem_busy = exmem_valid & (exmem_mem_read | exmem_mem_write) & ~dmem_ready;
assign global_stall = (~done_r & ~imem_ready) | mem_busy;
assign load_use_stall = ifid_valid & idex_valid & idex_mem_read & (idex_rd != 5'b0) &
                        ((id_use_rs1 & (id_rs1 == idex_rd)) |
                         (id_use_rs2 & (id_rs2 == idex_rd)));
assign ex_redirect_valid = idex_valid & ex_redirect;
assign idex_insert_bubble = ex_redirect_valid | load_use_stall;
assign o_flush = done_r;
assign o_done = done_r;

if_stage if_stage0 (
    .clk            (clk),
    .rst_n          (rst_n),
    .stall          (if_stall),
    .redirect       (ex_redirect_valid),
    .redirect_pc    (ex_redirect_pc),
    .predict_taken  (branch_predict_taken),
    .predict_pc     (32'b0),
    .imem_ready     (imem_ready),
    .imem_rdata     (imem_rdata),
    .done           (done_r),
    .imem_addr      (imem_addr),
    .if_pc          (if_pc),
    .if_pc4         (if_pc4),
    .if_inst        (if_inst)
);

assign if_stall = global_stall | load_use_stall;

id_stage id_stage0 (
    .inst           (ifid_inst),
    .wb_wen         (wb_wen),
    .wb_rd          (wb_rd),
    .wb_wdata       (wb_wdata),
    .clk            (clk),
    .rst_n          (rst_n),
    .rs1            (id_rs1),
    .rs2            (id_rs2),
    .rd             (id_rd),
    .imm_i          (id_imm_i),
    .imm_s          (id_imm_s),
    .imm_b          (id_imm_b),
    .imm_j          (id_imm_j),
    .imm_u          (id_imm_u),
    .rdata1         (id_rdata1),
    .rdata2         (id_rdata2),
    .funct3         (id_funct3),
    .alu_ctrl       (id_alu_ctrl),
    .use_rs1        (id_use_rs1),
    .use_rs2        (id_use_rs2),
    .alu_src_imm    (id_alu_src_imm),
    .mem_read       (id_mem_read),
    .mem_write      (id_mem_write),
    .reg_wen        (id_reg_wen),
    .branch         (id_branch),
    .jal            (id_jal),
    .jalr           (id_jalr),
    .lui            (id_lui),
    .flush_instr    (id_flush_instr),
    .wb_sel         (id_wb_sel)
);

ex_stage ex_stage0 (
    .pc             (idex_pc),
    .pc4            (idex_pc4),
    .rdata1         (idex_rdata1),
    .rdata2         (idex_rdata2),
    .imm_i          (idex_imm_i),
    .imm_s          (idex_imm_s),
    .imm_b          (idex_imm_b),
    .imm_j          (idex_imm_j),
    .imm_u          (idex_imm_u),
    .rs1            (idex_rs1),
    .rs2            (idex_rs2),
    .funct3         (idex_funct3),
    .alu_ctrl       (idex_alu_ctrl),
    .alu_src_imm    (idex_alu_src_imm),
    .mem_write      (idex_mem_write),
    .branch         (idex_branch),
    .jal            (idex_jal),
    .jalr           (idex_jalr),
    .lui            (idex_lui),
    .wb_sel         (idex_wb_sel),
    .exmem_wen      (exmem_valid & exmem_reg_wen & ~exmem_mem_read),
    .exmem_rd       (exmem_rd),
    .exmem_wdata    (exmem_forward_data),
    .memwb_wen      (memwb_valid & memwb_reg_wen),
    .memwb_rd       (memwb_rd),
    .memwb_wdata    (memwb_forward_data),
    .redirect       (ex_redirect),
    .redirect_pc    (ex_redirect_pc),
    .alu_result     (ex_alu_result),
    .store_data     (ex_store_data),
    .wb_data        (ex_wb_data)
);

mem_stage mem_stage0 (
    .valid          (exmem_valid),
    .mem_read       (exmem_mem_read),
    .mem_write      (exmem_mem_write),
    .alu_result     (exmem_alu_result),
    .store_data     (exmem_store_data),
    .ex_wb_data     (exmem_wb_data),
    .dmem_rdata     (dmem_rdata),
    .dmem_req       (dmem_req),
    .dmem_wen       (dmem_wen),
    .dmem_addr      (dmem_addr),
    .dmem_wdata     (dmem_wdata),
    .wb_data        (mem_wb_data)
);

wb_stage wb_stage0 (
    .valid          (memwb_valid),
    .reg_wen        (memwb_reg_wen),
    .rd             (memwb_rd),
    .wb_data        (memwb_wb_data),
    .wb_wen         (wb_wen),
    .wb_rd          (wb_rd),
    .wb_wdata       (wb_wdata)
);

assign exmem_forward_data = exmem_wb_data;
assign memwb_forward_data = memwb_wb_data;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        done_r <= 1'b0;
        ifid_valid <= 1'b0;
        ifid_pc <= 32'b0;
        ifid_pc4 <= 32'b0;
        ifid_inst <= 32'b0;
        idex_valid <= 1'b0;
        idex_pc <= 32'b0;
        idex_pc4 <= 32'b0;
        idex_rdata1 <= 32'b0;
        idex_rdata2 <= 32'b0;
        idex_imm_i <= 32'b0;
        idex_imm_s <= 32'b0;
        idex_imm_b <= 32'b0;
        idex_imm_j <= 32'b0;
        idex_imm_u <= 32'b0;
        idex_rs1 <= 5'b0;
        idex_rs2 <= 5'b0;
        idex_rd <= 5'b0;
        idex_funct3 <= 3'b0;
        idex_alu_ctrl <= 4'b0;
        idex_alu_src_imm <= 1'b0;
        idex_mem_read <= 1'b0;
        idex_mem_write <= 1'b0;
        idex_reg_wen <= 1'b0;
        idex_branch <= 1'b0;
        idex_jal <= 1'b0;
        idex_jalr <= 1'b0;
        idex_lui <= 1'b0;
        idex_flush_instr <= 1'b0;
        idex_wb_sel <= WB_ALU;
        exmem_valid <= 1'b0;
        exmem_alu_result <= 32'b0;
        exmem_store_data <= 32'b0;
        exmem_wb_data <= 32'b0;
        exmem_rd <= 5'b0;
        exmem_mem_read <= 1'b0;
        exmem_mem_write <= 1'b0;
        exmem_reg_wen <= 1'b0;
        exmem_flush_instr <= 1'b0;
        exmem_wb_sel <= WB_ALU;
        memwb_valid <= 1'b0;
        memwb_wb_data <= 32'b0;
        memwb_rd <= 5'b0;
        memwb_reg_wen <= 1'b0;
        memwb_flush_instr <= 1'b0;
    end else begin
        if (ex_redirect_valid) begin
            ifid_valid <= 1'b0;
        end

        if (!global_stall) begin
            if (memwb_valid && memwb_flush_instr) begin
                done_r <= 1'b1;
            end

            memwb_valid <= exmem_valid;
            memwb_wb_data <= mem_wb_data;
            memwb_rd <= exmem_rd;
            memwb_reg_wen <= exmem_reg_wen;
            memwb_flush_instr <= exmem_flush_instr;

            exmem_valid <= idex_valid;
            exmem_alu_result <= ex_alu_result;
            exmem_store_data <= ex_store_data;
            exmem_wb_data <= ex_wb_data;
            exmem_rd <= idex_rd;
            exmem_mem_read <= idex_mem_read;
            exmem_mem_write <= idex_mem_write;
            exmem_reg_wen <= idex_reg_wen;
            exmem_flush_instr <= idex_flush_instr;
            exmem_wb_sel <= idex_wb_sel;

            if (idex_insert_bubble) begin
                idex_valid <= 1'b0;
                idex_mem_read <= 1'b0;
                idex_mem_write <= 1'b0;
                idex_reg_wen <= 1'b0;
                idex_branch <= 1'b0;
                idex_jal <= 1'b0;
                idex_jalr <= 1'b0;
                idex_flush_instr <= 1'b0;
            end else begin
                idex_valid <= ifid_valid;
                idex_pc <= ifid_pc;
                idex_pc4 <= ifid_pc4;
                idex_rdata1 <= id_rdata1;
                idex_rdata2 <= id_rdata2;
                idex_imm_i <= id_imm_i;
                idex_imm_s <= id_imm_s;
                idex_imm_b <= id_imm_b;
                idex_imm_j <= id_imm_j;
                idex_imm_u <= id_imm_u;
                idex_rs1 <= id_rs1;
                idex_rs2 <= id_rs2;
                idex_rd <= id_rd;
                idex_funct3 <= id_funct3;
                idex_alu_ctrl <= id_alu_ctrl;
                idex_alu_src_imm <= id_alu_src_imm;
                idex_mem_read <= id_mem_read;
                idex_mem_write <= id_mem_write;
                idex_reg_wen <= id_reg_wen;
                idex_branch <= id_branch;
                idex_jal <= id_jal;
                idex_jalr <= id_jalr;
                idex_lui <= id_lui;
                idex_flush_instr <= id_flush_instr;
                idex_wb_sel <= id_wb_sel;
            end

            if (ex_redirect_valid) begin
                ifid_valid <= 1'b0;
            end else if (!load_use_stall) begin
                ifid_valid <= imem_ready & ~done_r;
                ifid_pc <= if_pc;
                ifid_pc4 <= if_pc4;
                ifid_inst <= if_inst;
            end
        end
    end
end

endmodule

module if_stage(
    input         clk,
    input         rst_n,
    input         stall,
    input         redirect,
    input  [31:0] redirect_pc,
    input         predict_taken,
    input  [31:0] predict_pc,
    input         imem_ready,
    input  [31:0] imem_rdata,
    input         done,
    output [31:0] imem_addr,
    output [31:0] if_pc,
    output [31:0] if_pc4,
    output [31:0] if_inst
);
reg [31:0] pc;
wire [31:0] pc4;
wire [31:0] seq_pc;

assign pc4 = pc + 32'd4;
assign seq_pc = predict_taken ? predict_pc : pc4;
assign imem_addr = pc;
assign if_pc = pc;
assign if_pc4 = pc4;
assign if_inst = {imem_rdata[7:0], imem_rdata[15:8], imem_rdata[23:16], imem_rdata[31:24]};

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pc <= 32'b0;
    end else if (!stall && imem_ready && !done) begin
        pc <= redirect ? redirect_pc : seq_pc;
    end
end
endmodule

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
    output [31:0] imm_i,
    output [31:0] imm_s,
    output [31:0] imm_b,
    output [31:0] imm_j,
    output [31:0] imm_u,
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
    output        lui,
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

assign imm_i = {{20{inst[31]}}, inst[31:20]};
assign imm_s = {{20{inst[31]}}, inst[31:25], inst[11:7]};
assign imm_b = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
assign imm_j = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};
assign imm_u = {inst[31:12], 12'b0};

assign use_rs1 = is_rtype | is_itype | is_load | is_store | is_branch | is_jalr;
assign use_rs2 = is_rtype | is_store | is_branch;
assign alu_src_imm = is_itype | is_load | is_store | is_jalr;
assign mem_read = is_load;
assign mem_write = is_store;
assign branch = is_branch;
assign jal = is_jal;
assign jalr = is_jalr;
assign lui = is_lui;
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

module ex_stage(
    input  [31:0] pc,
    input  [31:0] pc4,
    input  [31:0] rdata1,
    input  [31:0] rdata2,
    input  [31:0] imm_i,
    input  [31:0] imm_s,
    input  [31:0] imm_b,
    input  [31:0] imm_j,
    input  [31:0] imm_u,
    input  [4:0]  rs1,
    input  [4:0]  rs2,
    input  [2:0]  funct3,
    input  [3:0]  alu_ctrl,
    input         alu_src_imm,
    input         mem_write,
    input         branch,
    input         jal,
    input         jalr,
    input         lui,
    input  [1:0]  wb_sel,
    input         exmem_wen,
    input  [4:0]  exmem_rd,
    input  [31:0] exmem_wdata,
    input         memwb_wen,
    input  [4:0]  memwb_rd,
    input  [31:0] memwb_wdata,
    output        redirect,
    output [31:0] redirect_pc,
    output [31:0] alu_result,
    output [31:0] store_data,
    output [31:0] wb_data
);
localparam WB_ALU = 2'd0;
localparam WB_MEM = 2'd1;
localparam WB_PC4 = 2'd2;
localparam WB_IMM = 2'd3;

wire [31:0] fwd_rs1;
wire [31:0] fwd_rs2;
wire [31:0] alu_input2;
wire branch_taken;

assign fwd_rs1 = (exmem_wen && exmem_rd != 5'b0 && exmem_rd == rs1) ? exmem_wdata :
                 (memwb_wen && memwb_rd != 5'b0 && memwb_rd == rs1) ? memwb_wdata :
                 rdata1;
assign fwd_rs2 = (exmem_wen && exmem_rd != 5'b0 && exmem_rd == rs2) ? exmem_wdata :
                 (memwb_wen && memwb_rd != 5'b0 && memwb_rd == rs2) ? memwb_wdata :
                 rdata2;
assign alu_input2 = mem_write ? imm_s :
                    alu_src_imm ? imm_i : fwd_rs2;
assign store_data = fwd_rs2;
assign branch_taken = branch &&
                      ((funct3 == 3'b000 && fwd_rs1 == fwd_rs2) ||
                       (funct3 == 3'b001 && fwd_rs1 != fwd_rs2));
assign redirect = jal | jalr | branch_taken;
assign redirect_pc = jal ? (pc + imm_j) :
                     jalr ? ((fwd_rs1 + imm_i) & 32'hffff_fffe) :
                     (pc + imm_b);
assign wb_data = (wb_sel == WB_PC4) ? pc4 :
                 (wb_sel == WB_IMM) ? imm_u :
                 alu_result;

alu alu0 (
    .input1     (fwd_rs1),
    .input2     (alu_input2),
    .alu_ctrl   (alu_ctrl),
    .result     (alu_result)
);
endmodule

module mem_stage(
    input         valid,
    input         mem_read,
    input         mem_write,
    input  [31:0] alu_result,
    input  [31:0] store_data,
    input  [31:0] ex_wb_data,
    input  [31:0] dmem_rdata,
    output        dmem_req,
    output        dmem_wen,
    output [31:0] dmem_addr,
    output [31:0] dmem_wdata,
    output [31:0] wb_data
);
wire [31:0] dmem_rdata_cpu;

assign dmem_req = valid & (mem_read | mem_write);
assign dmem_wen = mem_write;
assign dmem_addr = alu_result;
assign dmem_wdata = {store_data[7:0], store_data[15:8], store_data[23:16], store_data[31:24]};
assign dmem_rdata_cpu = {dmem_rdata[7:0], dmem_rdata[15:8], dmem_rdata[23:16], dmem_rdata[31:24]};
assign wb_data = mem_read ? dmem_rdata_cpu : ex_wb_data;
endmodule

module wb_stage(
    input         valid,
    input         reg_wen,
    input  [4:0]  rd,
    input  [31:0] wb_data,
    output        wb_wen,
    output [4:0]  wb_rd,
    output [31:0] wb_wdata
);
assign wb_wen = valid & reg_wen & (rd != 5'b0);
assign wb_rd = rd;
assign wb_wdata = wb_data;
endmodule

module alu_ctrl_gen(
    input  [6:0] opcode,
    input  [2:0] funct3,
    input  [6:0] funct7,
    output reg [3:0] alu_ctrl
);
localparam ALU_ADD = 4'd0;
localparam ALU_SUB = 4'd1;
localparam ALU_AND = 4'd2;
localparam ALU_OR  = 4'd3;
localparam ALU_XOR = 4'd4;
localparam ALU_SLT = 4'd5;
localparam ALU_SLL = 4'd6;
localparam ALU_SRL = 4'd7;
localparam ALU_SRA = 4'd8;

always @(*) begin
    alu_ctrl = ALU_ADD;
    if (opcode == 7'b0110011) begin
        alu_ctrl = 4'bxxxx;
        case (funct3)
            3'b000: alu_ctrl = (funct7 == 7'b0100000) ? ALU_SUB : ALU_ADD;
            3'b111: alu_ctrl = ALU_AND;
            3'b110: alu_ctrl = ALU_OR;
            3'b100: alu_ctrl = ALU_XOR;
            3'b010: alu_ctrl = ALU_SLT;
            3'b001: alu_ctrl = ALU_SLL;
            3'b101: alu_ctrl = (funct7 == 7'b0100000) ? ALU_SRA : ALU_SRL;
            default: alu_ctrl = 4'bxxxx;
        endcase
    end else if (opcode == 7'b0010011) begin
        alu_ctrl = 4'bxxxx;
        case (funct3)
            3'b000: alu_ctrl = ALU_ADD;
            3'b111: alu_ctrl = ALU_AND;
            3'b110: alu_ctrl = ALU_OR;
            3'b100: alu_ctrl = ALU_XOR;
            3'b010: alu_ctrl = ALU_SLT;
            3'b001: alu_ctrl = ALU_SLL;
            3'b101: alu_ctrl = (funct7 == 7'b0100000) ? ALU_SRA : ALU_SRL;
            default: alu_ctrl = 4'bxxxx;
        endcase
    end else if (opcode == 7'b1100011) begin
        alu_ctrl = ALU_SUB;
    end
end
endmodule

module alu(
    input  [31:0] input1,
    input  [31:0] input2,
    input  [3:0]  alu_ctrl,
    output reg [31:0] result
);
localparam ALU_ADD = 4'd0;
localparam ALU_SUB = 4'd1;
localparam ALU_AND = 4'd2;
localparam ALU_OR  = 4'd3;
localparam ALU_XOR = 4'd4;
localparam ALU_SLT = 4'd5;
localparam ALU_SLL = 4'd6;
localparam ALU_SRL = 4'd7;
localparam ALU_SRA = 4'd8;

wire is_sub_op;
wire [31:0] add_sub_b;
wire [31:0] add_sub_result;
wire signed_less;

assign is_sub_op = (alu_ctrl == ALU_SUB) || (alu_ctrl == ALU_SLT);
assign add_sub_b = input2 ^ {32{is_sub_op}};
assign add_sub_result = input1 + add_sub_b + is_sub_op;
assign signed_less = (input1[31] ^ input2[31]) ? input1[31] : add_sub_result[31];

always @(*) begin
    case (alu_ctrl)
        ALU_ADD: result = add_sub_result;
        ALU_SUB: result = add_sub_result;
        ALU_AND: result = input1 & input2;
        ALU_OR : result = input1 | input2;
        ALU_XOR: result = input1 ^ input2;
        ALU_SLT: result = signed_less ? 32'd1 : 32'd0;
        ALU_SLL: result = input1 << input2[4:0];
        ALU_SRL: result = input1 >> input2[4:0];
        ALU_SRA: result = $signed(input1) >>> input2[4:0];
        default: result = 32'bx;
    endcase
end
endmodule

module register_file(
    input         clk,
    input         rst_n,
    input  [4:0]  read1,
    input  [4:0]  read2,
    input  [4:0]  write_reg,
    input  [31:0] wdata,
    input         wen,
    output [31:0] rdata1,
    output [31:0] rdata2
);
reg [31:0] data_r [0:31];
integer i;

assign rdata1 = (read1 == 5'b0) ? 32'b0 :
                (wen && write_reg == read1) ? wdata :
                data_r[read1];
assign rdata2 = (read2 == 5'b0) ? 32'b0 :
                (wen && write_reg == read2) ? wdata :
                data_r[read2];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0; i < 32; i = i + 1) begin
            data_r[i] <= 32'b0;
        end
    end else if (wen && write_reg != 5'b0) begin
        data_r[write_reg] <= wdata;
    end
end

endmodule

module blocking_cache #(
    parameter BLOCKS    = 16,
    parameter WAYS      = 1,
    parameter READ_ONLY = 0
) (
    input          clk,
    input          rst_n,
    input          req,
    input          wen,
    input  [31:0]  addr,
    input  [31:0]  wdata,
    output [31:0]  rdata,
    output         ready,
    input          flush,
    output         flush_done,

    output         mem_read,
    output         mem_write,
    output [31:4]  mem_addr,
    output [127:0] mem_wdata,
    input  [127:0] mem_rdata,
    input          mem_ready
);
function integer clog2;
    input integer value;
    integer v;
    begin
        v = value - 1;
        for (clog2 = 0; v > 0; clog2 = clog2 + 1) begin
            v = v >> 1;
        end
    end
endfunction

function [127:0] update_word;
    input [127:0] line;
    input [1:0]   index;
    input [31:0]  word;
    begin
        case (index)
            2'd0: update_word = {line[127:32], word};
            2'd1: update_word = {line[127:64], word, line[31:0]};
            2'd2: update_word = {line[127:96], word, line[63:0]};
            2'd3: update_word = {word, line[95:0]};
        endcase
    end
endfunction

function [31:0] select_word;
    input [127:0] line;
    input [1:0]   index;
    begin
        case (index)
            2'd0: select_word = line[31:0];
            2'd1: select_word = line[63:32];
            2'd2: select_word = line[95:64];
            2'd3: select_word = line[127:96];
        endcase
    end
endfunction

localparam IS_READ_ONLY = (READ_ONLY != 0);
localparam SETS        = (BLOCKS / WAYS);
localparam SET_BITS    = clog2(SETS);
localparam WAY_BITS    = (WAYS <= 1) ? 1 : clog2(WAYS);
localparam TAG_BITS    = 28 - SET_BITS;

localparam S_IDLE       = 3'd0;
localparam S_WB_MISS    = 3'd1;
localparam S_REFILL     = 3'd2;
localparam S_FLUSH      = 3'd3;
localparam S_FLUSH_WB   = 3'd4;

reg [2:0] state;
reg [31:0] addr_r;
reg [31:0] wdata_r;
reg        wen_r;
reg [WAY_BITS-1:0] victim_way_r;
reg [SET_BITS-1:0] victim_set_r;
reg [31:4] mem_addr_r;
reg [127:0] mem_wdata_r;
reg [WAY_BITS-1:0] replace_way [0:SETS-1];
reg [WAY_BITS-1:0] flush_way;
reg [SET_BITS-1:0] flush_set;
reg flush_done_r;

reg [127:0] data [0:WAYS-1][0:SETS-1];
reg [TAG_BITS-1:0] tag [0:WAYS-1][0:SETS-1];
reg valid [0:WAYS-1][0:SETS-1];
reg dirty [0:WAYS-1][0:SETS-1];

wire [SET_BITS-1:0] set_idx;
wire [SET_BITS-1:0] set_idx_r;
wire [TAG_BITS-1:0] tag_addr;
wire [TAG_BITS-1:0] tag_addr_r;
wire [1:0] word_idx;
wire [1:0] word_idx_r;
wire [127:0] refill_line;
wire victim_dirty;
wire [31:4] victim_addr;
wire [31:4] flush_addr;
reg hit;
reg [WAY_BITS-1:0] hit_way;
reg [127:0] hit_line;
wire [31:0] hit_word;
wire [31:0] refill_word;
integer wi;
integer si;

assign set_idx = addr[4 + SET_BITS - 1:4];
assign set_idx_r = addr_r[4 + SET_BITS - 1:4];
assign tag_addr = addr[31:4 + SET_BITS];
assign tag_addr_r = addr_r[31:4 + SET_BITS];
assign word_idx = addr[3:2];
assign word_idx_r = addr_r[3:2];
assign refill_line = wen_r ? update_word(mem_rdata, word_idx_r, wdata_r) : mem_rdata;
assign victim_dirty = valid[replace_way[set_idx]][set_idx] &&
                      dirty[replace_way[set_idx]][set_idx] &&
                      !IS_READ_ONLY;
assign victim_addr = {tag[replace_way[set_idx]][set_idx], set_idx};
assign flush_addr = {tag[flush_way][flush_set], flush_set};
assign hit_word = select_word(hit_line, word_idx);
assign refill_word = select_word(mem_rdata, word_idx_r);
assign rdata = (state == S_REFILL) ? refill_word : hit_word;
assign ready = (state == S_IDLE && req && hit) ||
               (state == S_REFILL && mem_ready);
assign flush_done = IS_READ_ONLY ? ((state == S_IDLE) && flush) : flush_done_r;
assign mem_read = (state == S_REFILL);
assign mem_write = (state == S_WB_MISS) || (state == S_FLUSH_WB);
assign mem_addr = mem_addr_r;
assign mem_wdata = mem_wdata_r;

always @(*) begin
    hit = 1'b0;
    hit_way = {WAY_BITS{1'b0}};
    hit_line = 128'b0;
    for (wi = 0; wi < WAYS; wi = wi + 1) begin
        if (valid[wi][set_idx] && tag[wi][set_idx] == tag_addr) begin
            hit = 1'b1;
            hit_way = wi;
            hit_line = data[wi][set_idx];
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        addr_r <= 32'b0;
        wdata_r <= 32'b0;
        wen_r <= 1'b0;
        victim_way_r <= {WAY_BITS{1'b0}};
        victim_set_r <= {SET_BITS{1'b0}};
        mem_addr_r <= 28'b0;
        mem_wdata_r <= 128'b0;
        flush_way <= {WAY_BITS{1'b0}};
        flush_set <= {SET_BITS{1'b0}};
        flush_done_r <= 1'b0;
        for (si = 0; si < SETS; si = si + 1) begin
            replace_way[si] <= {WAY_BITS{1'b0}};
            for (wi = 0; wi < WAYS; wi = wi + 1) begin
                data[wi][si] <= 128'b0;
                tag[wi][si] <= {TAG_BITS{1'b0}};
                valid[wi][si] <= 1'b0;
                dirty[wi][si] <= 1'b0;
            end
        end
    end else begin
        if (!flush) begin
            flush_done_r <= 1'b0;
        end
        case (state)
            S_IDLE: begin
                if (flush && !flush_done_r && !IS_READ_ONLY) begin
                    flush_way <= {WAY_BITS{1'b0}};
                    flush_set <= {SET_BITS{1'b0}};
                    flush_done_r <= 1'b0;
                    state <= S_FLUSH;
                end else if (req && !flush) begin
                    addr_r <= addr;
                    wdata_r <= wdata;
                    wen_r <= wen && !IS_READ_ONLY;
                    if (hit) begin
                        if (wen && !IS_READ_ONLY) begin
                            data[hit_way][set_idx] <= update_word(hit_line, word_idx, wdata);
                            dirty[hit_way][set_idx] <= 1'b1;
                        end
                    end else begin
                        victim_way_r <= replace_way[set_idx];
                        victim_set_r <= set_idx;
                        if (victim_dirty) begin
                            mem_addr_r <= victim_addr;
                            mem_wdata_r <= data[replace_way[set_idx]][set_idx];
                            state <= S_WB_MISS;
                        end else begin
                            mem_addr_r <= addr[31:4];
                            state <= S_REFILL;
                        end
                    end
                end
            end
            S_WB_MISS: begin
                if (mem_ready) begin
                    dirty[victim_way_r][victim_set_r] <= 1'b0;
                    mem_addr_r <= addr_r[31:4];
                    state <= S_REFILL;
                end
            end
            S_REFILL: begin
                if (mem_ready) begin
                    data[victim_way_r][victim_set_r] <= refill_line;
                    tag[victim_way_r][victim_set_r] <= tag_addr_r;
                    valid[victim_way_r][victim_set_r] <= 1'b1;
                    dirty[victim_way_r][victim_set_r] <= wen_r;
                    replace_way[victim_set_r] <=
                        (replace_way[victim_set_r] == WAYS-1) ?
                        {WAY_BITS{1'b0}} : replace_way[victim_set_r] + 1'b1;
                    state <= S_IDLE;
                end
            end
            S_FLUSH: begin
                if (valid[flush_way][flush_set] && dirty[flush_way][flush_set]) begin
                    mem_addr_r <= flush_addr;
                    mem_wdata_r <= data[flush_way][flush_set];
                    state <= S_FLUSH_WB;
                end else if (flush_way == WAYS-1 && flush_set == SETS-1) begin
                    flush_done_r <= 1'b1;
                    state <= S_IDLE;
                end else if (flush_way == WAYS-1) begin
                    flush_way <= {WAY_BITS{1'b0}};
                    flush_set <= flush_set + 1'b1;
                end else begin
                    flush_way <= flush_way + 1'b1;
                end
            end
            S_FLUSH_WB: begin
                if (mem_ready) begin
                    dirty[flush_way][flush_set] <= 1'b0;
                    if (flush_way == WAYS-1 && flush_set == SETS-1) begin
                        flush_done_r <= 1'b1;
                        state <= S_IDLE;
                    end else if (flush_way == WAYS-1) begin
                        flush_way <= {WAY_BITS{1'b0}};
                        flush_set <= flush_set + 1'b1;
                        state <= S_FLUSH;
                    end else begin
                        flush_way <= flush_way + 1'b1;
                        state <= S_FLUSH;
                    end
                end
            end
            default: begin
                state <= S_IDLE;
            end
        endcase
    end
end

endmodule
