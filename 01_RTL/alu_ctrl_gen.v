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
