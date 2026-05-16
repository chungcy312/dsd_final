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
