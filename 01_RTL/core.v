module core #(
    parameter MUL_CYCLES = 3
) (
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
wire        id_predict_taken;
wire        id_predict_redirect;
wire [31:0] id_predict_pc;
wire        if_redirect;
wire [31:0] if_redirect_pc;
wire [31:0] if_pc;
wire [31:0] if_inst;
wire [31:0] if_pc_inc;
wire        if_ready;

reg        ifid_valid;
reg [31:0] ifid_pc;
reg [31:0] ifid_inst;
reg [31:0] ifid_pc_inc;

wire [4:0]  id_rs1;
wire [4:0]  id_rs2;
wire [4:0]  id_rd;
wire [31:0] id_imm_alu;
wire [31:0] id_imm_aux;
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
wire        id_is_mul;
wire        id_flush_instr;
wire [1:0]  id_wb_sel;

reg        idex_valid;
reg [31:0] idex_pc;
reg [31:0] idex_pc_inc;
reg [31:0] idex_rdata1;
reg [31:0] idex_rdata2;
reg [31:0] idex_imm_alu;
reg [31:0] idex_imm_aux;
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
reg        idex_is_mul;
reg        idex_flush_instr;
reg        idex_pred_taken;
reg [31:0] idex_pred_pc;
reg [1:0]  idex_wb_sel;

wire        ex_redirect;
wire [31:0] ex_redirect_pc;
wire [31:0] ex_result;
wire [31:0] ex_store_data;

reg        exmem_valid;
reg [31:0] exmem_result;
reg [31:0] exmem_store_data;
reg [4:0]  exmem_rd;
reg        exmem_mem_read;
reg        exmem_mem_write;
reg        exmem_reg_wen;
reg        exmem_flush_instr;

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
wire mul_stall;
wire global_stall;
wire idex_insert_bubble;
wire ex_redirect_valid;
wire id_rs1_from_ex;
wire id_rs2_from_ex;
wire id_rs1_from_mem;
wire id_rs2_from_mem;
wire [31:0] id_operand1;
wire [31:0] id_operand2;

assign mem_busy = exmem_valid & (exmem_mem_read | exmem_mem_write) & ~dmem_ready;
assign global_stall = (~done_r & ~if_ready) | mem_busy;
assign load_use_stall = ifid_valid & idex_valid & idex_mem_read & (idex_rd != 5'b0) &
                        ((id_use_rs1 & (id_rs1 == idex_rd)) |
                         (id_use_rs2 & (id_rs2 == idex_rd)));
assign ex_redirect_valid = idex_valid & ex_redirect;
assign idex_insert_bubble = ex_redirect_valid | load_use_stall;
assign id_predict_taken = ifid_valid & id_branch & ifid_inst[31];
assign id_predict_pc = ifid_pc + id_imm_aux;
assign id_predict_redirect = id_predict_taken & ~global_stall & ~load_use_stall & ~mul_stall & ~ex_redirect_valid;
assign if_redirect = ex_redirect_valid | id_predict_redirect;
assign if_redirect_pc = ex_redirect_valid ? ex_redirect_pc : id_predict_pc;
assign o_flush = done_r;
assign o_done = done_r;

assign id_rs1_from_ex = ifid_valid & id_use_rs1 & idex_valid &
                        idex_reg_wen & ~idex_mem_read &
                        (idex_rd != 5'b0) & (id_rs1 == idex_rd);
assign id_rs2_from_ex = ifid_valid & id_use_rs2 & idex_valid &
                        idex_reg_wen & ~idex_mem_read &
                        (idex_rd != 5'b0) & (id_rs2 == idex_rd);
assign id_rs1_from_mem = ifid_valid & id_use_rs1 & exmem_valid &
                         exmem_reg_wen & (exmem_rd != 5'b0) &
                         (id_rs1 == exmem_rd);
assign id_rs2_from_mem = ifid_valid & id_use_rs2 & exmem_valid &
                         exmem_reg_wen & (exmem_rd != 5'b0) &
                         (id_rs2 == exmem_rd);
assign id_operand1 = id_rs1_from_ex ? ex_result :
                     id_rs1_from_mem ? mem_wb_data :
                     id_rdata1;
assign id_operand2 = id_rs2_from_ex ? ex_result :
                     id_rs2_from_mem ? mem_wb_data :
                     id_rdata2;

if_stage if_stage0 (
    .clk            (clk),
    .rst_n          (rst_n),
    .stall          (if_stall),
    .redirect       (if_redirect),
    .redirect_pc    (if_redirect_pc),
    .imem_ready     (imem_ready),
    .imem_rdata     (imem_rdata),
    .done           (done_r),
    .imem_addr      (imem_addr),
    .if_ready       (if_ready),
    .if_pc          (if_pc),
    .if_pc_inc      (if_pc_inc),
    .if_inst        (if_inst)
);

assign if_stall = mem_busy | load_use_stall | mul_stall;

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
    .imm_alu        (id_imm_alu),
    .imm_aux        (id_imm_aux),
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
    .is_mul         (id_is_mul),
    .flush_instr    (id_flush_instr),
    .wb_sel         (id_wb_sel)
);

ex_stage #(
    .MUL_CYCLES     (MUL_CYCLES)
) ex_stage0 (
    .clk            (clk),
    .rst_n          (rst_n),
    .valid          (idex_valid),
    .advance        (~global_stall),
    .pc             (idex_pc),
    .pc_inc         (idex_pc_inc),
    .rdata1         (idex_rdata1),
    .rdata2         (idex_rdata2),
    .imm_alu        (idex_imm_alu),
    .imm_aux        (idex_imm_aux),
    .funct3         (idex_funct3),
    .alu_ctrl       (idex_alu_ctrl),
    .alu_src_imm    (idex_alu_src_imm),
    .branch         (idex_branch),
    .jal            (idex_jal),
    .jalr           (idex_jalr),
    .is_mul         (idex_is_mul),
    .pred_taken     (idex_pred_taken),
    .pred_pc        (idex_pred_pc),
    .wb_sel         (idex_wb_sel),
    .redirect       (ex_redirect),
    .redirect_pc    (ex_redirect_pc),
    .mul_stall      (mul_stall),
    .result         (ex_result),
    .store_data     (ex_store_data)
);

mem_stage mem_stage0 (
    .valid          (exmem_valid),
    .mem_read       (exmem_mem_read),
    .mem_write      (exmem_mem_write),
    .result         (exmem_result),
    .store_data     (exmem_store_data),
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

always @(posedge clk) begin
    if (!rst_n) begin
        done_r <= 1'b0;
        ifid_valid <= 1'b0;
        idex_valid <= 1'b0;
        idex_alu_src_imm <= 1'b0;
        idex_mem_read <= 1'b0;
        idex_mem_write <= 1'b0;
        idex_reg_wen <= 1'b0;
        idex_branch <= 1'b0;
        idex_jal <= 1'b0;
        idex_jalr <= 1'b0;
        idex_is_mul <= 1'b0;
        idex_flush_instr <= 1'b0;
        idex_pred_taken <= 1'b0;
        idex_wb_sel <= WB_ALU;
        exmem_valid <= 1'b0;
        exmem_mem_read <= 1'b0;
        exmem_mem_write <= 1'b0;
        exmem_reg_wen <= 1'b0;
        exmem_flush_instr <= 1'b0;
        memwb_valid <= 1'b0;
        memwb_reg_wen <= 1'b0;
        memwb_flush_instr <= 1'b0;
    end else begin
        if (if_redirect) begin
            ifid_valid <= 1'b0;
        end

        if (!global_stall) begin
            if (memwb_valid && memwb_flush_instr) begin
                done_r <= 1'b1;
            end

            memwb_valid <= exmem_valid;
            memwb_reg_wen <= exmem_reg_wen;
            memwb_flush_instr <= exmem_flush_instr;

            if (mul_stall) begin
                exmem_valid <= 1'b0;
                exmem_mem_read <= 1'b0;
                exmem_mem_write <= 1'b0;
                exmem_reg_wen <= 1'b0;
                exmem_flush_instr <= 1'b0;
            end else begin
                exmem_valid <= idex_valid;
                exmem_mem_read <= idex_mem_read;
                exmem_mem_write <= idex_mem_write;
                exmem_reg_wen <= idex_reg_wen;
                exmem_flush_instr <= idex_flush_instr;
            end

            if (mul_stall) begin
                // Hold ID/EX while the independent MUL block finishes.
            end else if (idex_insert_bubble) begin
                idex_valid <= 1'b0;
                idex_mem_read <= 1'b0;
                idex_mem_write <= 1'b0;
                idex_reg_wen <= 1'b0;
                idex_branch <= 1'b0;
                idex_jal <= 1'b0;
                idex_jalr <= 1'b0;
                idex_is_mul <= 1'b0;
                idex_flush_instr <= 1'b0;
                idex_pred_taken <= 1'b0;
            end else begin
                idex_valid <= ifid_valid;
                idex_alu_src_imm <= id_alu_src_imm;
                idex_mem_read <= id_mem_read;
                idex_mem_write <= id_mem_write;
                idex_reg_wen <= id_reg_wen;
                idex_branch <= id_branch;
                idex_jal <= id_jal;
                idex_jalr <= id_jalr;
                idex_is_mul <= id_is_mul;
                idex_flush_instr <= id_flush_instr;
                idex_pred_taken <= id_predict_taken;
                idex_wb_sel <= id_wb_sel;
            end

            if (if_redirect) begin
                ifid_valid <= 1'b0;
            end else if (!load_use_stall && !mul_stall) begin
                ifid_valid <= if_ready & ~done_r;
            end
        end
    end
end

always @(posedge clk) begin
    if (!global_stall) begin
        memwb_wb_data <= mem_wb_data;
        memwb_rd <= exmem_rd;

        if (!mul_stall) begin
            exmem_result <= ex_result;
            exmem_store_data <= ex_store_data;
            exmem_rd <= idex_rd;
        end

        if (!mul_stall && !idex_insert_bubble) begin
            idex_pc <= ifid_pc;
            idex_pc_inc <= ifid_pc_inc;
            idex_rdata1 <= id_operand1;
            idex_rdata2 <= id_operand2;
            idex_imm_alu <= id_imm_alu;
            idex_imm_aux <= id_imm_aux;
            idex_rd <= id_rd;
            idex_funct3 <= id_funct3;
            idex_alu_ctrl <= id_alu_ctrl;
            idex_pred_pc <= id_predict_pc;
        end

        if (!if_redirect && !load_use_stall && !mul_stall) begin
            ifid_pc <= if_pc;
            ifid_pc_inc <= if_pc_inc;
            ifid_inst <= if_inst;
        end
    end
end

endmodule
