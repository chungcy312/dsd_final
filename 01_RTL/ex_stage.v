module ex_stage #(
    parameter MUL_CYCLES = 3
) (
    input         clk,
    input         rst_n,
    input         valid,
    input         advance,
    input  [31:0] pc,
    input  [31:0] pc_inc,
    input  [31:0] rdata1,
    input  [31:0] rdata2,
    input  [31:0] imm_alu,
    input  [31:0] imm_aux,
    input  [2:0]  funct3,
    input  [3:0]  alu_ctrl,
    input         alu_src_imm,
    input         branch,
    input         jal,
    input         jalr,
    input         is_mul,
    input         pred_taken,
    input  [31:0] pred_pc,
    input  [1:0]  wb_sel,
    output        redirect,
    output [31:0] redirect_pc,
    output        mul_stall,
    output [31:0] result,
    output [31:0] store_data
);
localparam WB_ALU = 2'd0;
localparam WB_MEM = 2'd1;
localparam WB_PC4 = 2'd2;
localparam WB_IMM = 2'd3;
localparam [3:0] MUL_CYCLES_4 = MUL_CYCLES;

wire [31:0] alu_input2;
wire [31:0] alu_result;
wire [31:0] pc4;
wire [31:0] branch_target;
wire [31:0] branch_next_pc;
wire branch_taken;
wire branch_mispredict;
wire mul_active;
wire mul_done;
wire [31:0] mul_product;
reg [31:0] mul_a_reg;
reg [31:0] mul_b_reg;
reg [31:0] mul_result_reg;
reg [3:0]  mul_count;
reg        mul_busy;
reg        mul_done_r;

assign pc4 = pc + pc_inc;
assign alu_input2 = alu_src_imm ? imm_alu : rdata2;
assign store_data = rdata2;
assign branch_taken = branch &&
                      ((funct3 == 3'b000 && rdata1 == rdata2) ||
                       (funct3 == 3'b001 && rdata1 != rdata2));
assign branch_target = pc + imm_aux;
assign branch_next_pc = branch_taken ? branch_target : pc4;
assign branch_mispredict = branch &&
                           ((branch_taken != pred_taken) ||
                            (branch_taken && (pred_pc != branch_target)));
assign redirect = jal | jalr | branch_mispredict;
assign redirect_pc = jal ? (pc + imm_aux) :
                     jalr ? ((rdata1 + imm_alu) & 32'hffff_fffe) :
                     branch_next_pc;
assign mul_active = valid & is_mul;
assign mul_done = mul_done_r;
assign mul_stall = mul_active & ~mul_done;
assign mul_product = mul_a_reg * mul_b_reg;
assign result = (wb_sel == WB_PC4) ? pc4 :
                (wb_sel == WB_IMM) ? imm_aux :
                is_mul ? mul_result_reg :
                alu_result;

always @(posedge clk) begin
    if (!rst_n) begin
        mul_count <= 4'b0;
        mul_busy <= 1'b0;
        mul_done_r <= 1'b0;
    end else begin
        if (mul_done_r) begin
            if (advance) begin
                mul_done_r <= 1'b0;
                mul_count <= 4'b0;
            end
        end else if (!mul_active) begin
            mul_busy <= 1'b0;
            mul_count <= 4'b0;
        end else if (!mul_busy) begin
            mul_a_reg <= rdata1;
            mul_b_reg <= rdata2;
            mul_busy <= 1'b1;
            mul_count <= 4'd1;
        end else if (mul_busy) begin
            if (mul_count >= MUL_CYCLES_4) begin
                mul_result_reg <= mul_product;
                mul_busy <= 1'b0;
                mul_done_r <= 1'b1;
            end else begin
                mul_count <= mul_count + 1'b1;
            end
        end
    end
end

alu alu0 (
    .input1     (rdata1),
    .input2     (alu_input2),
    .alu_ctrl   (alu_ctrl),
    .result     (alu_result)
);

`ifdef DEBUG_PC
always @(posedge clk) begin
    if (rst_n && redirect) begin
        $display("[EX_REDIRECT] t=%0t pc=%h target=%h jal=%0b jalr=%0b branch=%0b taken=%0b pred_taken=%0b pred_pc=%h rs1=%h rs2=%h imm_alu=%h imm_aux=%h",
                 $time, pc, redirect_pc, jal, jalr, branch, branch_taken,
                 pred_taken, pred_pc, rdata1, rdata2, imm_alu, imm_aux);
    end
end
`endif
endmodule
