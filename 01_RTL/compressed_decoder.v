module compressed_decoder(
    input  [15:0] cinst,
    output reg [31:0] inst
);
wire [1:0] op;
wire [2:0] funct3;
wire [4:0] rd_rs1;
wire [4:0] rs2;
wire [4:0] rd_rs1_p;
wire [4:0] rs2_p;
wire [5:0] ci_imm;
wire [5:0] ci_shamt;
wire [6:0] clw_uimm;
wire [12:0] cb_imm;
wire [20:0] cj_imm;

assign op = cinst[1:0];
assign funct3 = cinst[15:13];
assign rd_rs1 = cinst[11:7];
assign rs2 = cinst[6:2];
assign rd_rs1_p = {2'b01, cinst[9:7]};
assign rs2_p = {2'b01, cinst[4:2]};
assign ci_imm = {cinst[12], cinst[6:2]};
assign ci_shamt = {cinst[12], cinst[6:2]};
assign clw_uimm = {cinst[5], cinst[12:10], cinst[6], 2'b00};
assign cb_imm = {{4{cinst[12]}}, cinst[12], cinst[6:5], cinst[2],
                 cinst[11:10], cinst[4:3], 1'b0};
assign cj_imm = {{9{cinst[12]}}, cinst[12], cinst[8], cinst[10:9],
                 cinst[6], cinst[7], cinst[2], cinst[11], cinst[5:3], 1'b0};

function [31:0] enc_i;
    input [6:0] opcode;
    input [2:0] f3;
    input [4:0] rd;
    input [4:0] rs1;
    input [11:0] imm;
    begin
        enc_i = {imm, rs1, f3, rd, opcode};
    end
endfunction

function [31:0] enc_r;
    input [6:0] f7;
    input [2:0] f3;
    input [4:0] rd;
    input [4:0] rs1;
    input [4:0] rs2_i;
    begin
        enc_r = {f7, rs2_i, rs1, f3, rd, 7'b0110011};
    end
endfunction

function [31:0] enc_s;
    input [2:0] f3;
    input [4:0] rs1;
    input [4:0] rs2_i;
    input [11:0] imm;
    begin
        enc_s = {imm[11:5], rs2_i, rs1, f3, imm[4:0], 7'b0100011};
    end
endfunction

function [31:0] enc_b;
    input [2:0] f3;
    input [4:0] rs1;
    input [4:0] rs2_i;
    input [12:0] imm;
    begin
        enc_b = {imm[12], imm[10:5], rs2_i, rs1, f3, imm[4:1], imm[11], 7'b1100011};
    end
endfunction

function [31:0] enc_j;
    input [4:0] rd;
    input [20:0] imm;
    begin
        enc_j = {imm[20], imm[10:1], imm[11], imm[19:12], rd, 7'b1101111};
    end
endfunction

always @(*) begin
    inst = 32'h00000013;
    case (op)
        2'b00: begin
            case (funct3)
                3'b010: inst = enc_i(7'b0000011, 3'b010, rs2_p, rd_rs1_p, {5'b0, clw_uimm});
                3'b110: inst = enc_s(3'b010, rd_rs1_p, rs2_p, {5'b0, clw_uimm});
            endcase
        end
        2'b01: begin
            case (funct3)
                3'b000: inst = enc_i(7'b0010011, 3'b000, rd_rs1, rd_rs1, {{6{ci_imm[5]}}, ci_imm});
                3'b001: inst = enc_j(5'd1, cj_imm);
                3'b100: begin
                    if (cinst[11:10] == 2'b00) begin
                        inst = enc_i(7'b0010011, 3'b101, rd_rs1_p, rd_rs1_p, {6'b000000, ci_shamt});
                    end else if (cinst[11:10] == 2'b01) begin
                        inst = enc_i(7'b0010011, 3'b101, rd_rs1_p, rd_rs1_p, {6'b010000, ci_shamt});
                    end else if (cinst[11:10] == 2'b10) begin
                        inst = enc_i(7'b0010011, 3'b111, rd_rs1_p, rd_rs1_p, {{6{ci_imm[5]}}, ci_imm});
                    end
                end
                3'b101: inst = enc_j(5'd0, cj_imm);
                3'b110: inst = enc_b(3'b000, rd_rs1_p, 5'd0, cb_imm);
                3'b111: inst = enc_b(3'b001, rd_rs1_p, 5'd0, cb_imm);
            endcase
        end
        2'b10: begin
            case (funct3)
                3'b000: inst = enc_i(7'b0010011, 3'b001, rd_rs1, rd_rs1, {6'b000000, ci_shamt});
                3'b100: begin
                    if (!cinst[12] && rs2 != 5'b0) begin
                        inst = enc_r(7'b0000000, 3'b000, rd_rs1, 5'd0, rs2);
                    end else if (!cinst[12]) begin
                        inst = enc_i(7'b1100111, 3'b000, 5'd0, rd_rs1, 12'b0);
                    end else if (rs2 != 5'b0) begin
                        inst = enc_r(7'b0000000, 3'b000, rd_rs1, rd_rs1, rs2);
                    end else begin
                        inst = enc_i(7'b1100111, 3'b000, 5'd1, rd_rs1, 12'b0);
                    end
                end
            endcase
        end
    endcase
end
endmodule
