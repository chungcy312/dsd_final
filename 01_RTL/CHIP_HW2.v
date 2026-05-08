// Your single-cycle RISC-V code
// rs1:a
// rs2:b
// rd :c
// imm:i



// add 
// 00000 00bbb bbaaa aa000 ccccc 01100 11

// sub c=a-b
// 01000 00bbb bbaaa aa000 ccccc 01100 11

// and 
// 00000 00bbb bbaaa aa111 ccccc 01100 11

// or 
// 00000 00bbb bbaaa aa110 ccccc 01100 11

// slt rd=(a<b)?1:0
// 00000 00bbb bbaaa aa010 ccccc 01100 11

// lw
// iiiii iiiii iiaaa aa010 ccccc 00000 11

// sw 
// iiiii iibbb bbaaa aa010 iiiii 01000 11
// imm[11:5]              imm[4:0] 

// beq
// iiiii iibbb bbaaa aa000 iiiii 11000 11
// imm[12|10:5]         imm[4:1|11] 

// jal rd=pc+4 pc=pc+imm*2
// iiiii iiiii iiiii iiiii ccccc 11011 11
// imm[20|10:1|11|19:12]   

// jalr rd=pc+4 pc=rs1+imm
// iiiii iiiii iiaaa aa000 ccccc 11001 11
// imm[11:0]


module core (
    input clk,
    input rst_n,

    // for mem_D
    output mem_wen_D,          // high: writes data to D-mem, low: reads data from D-mem
    output [31:0] mem_addr_D,  // the specific address to fetch/store data
    output [31:0] mem_wdata_D, // data writing to D-mem
    input  [31:0] mem_rdata_D, // data reading from D-mem

    // for mem_I
    output [31:0] mem_addr_I,  // the fetching address of next instruction
    input  [31:0] mem_rdata_I  // instruction reading from I-mem
);
// I-mem stores bytes in little-endian order per pattern format.
// Reorder to canonical instruction bit layout before decode.
wire [31:0]inst = {mem_rdata_I[7:0], mem_rdata_I[15:8], mem_rdata_I[23:16], mem_rdata_I[31:24]};

wire [4:0]rs1 = inst[19:15];
wire [4:0]rs2 = inst[24:20];
wire [4:0]rd = inst[11:7];
wire [31:0]imm;
wire [4:0]write_reg = rd;
wire [31:0] write_data; // TODO: write data
wire write_enable; // TODO: write enable
wire [31:0] rdata1, rdata2;
wire [31:0] alu_input1, alu_input2;
wire branch;
wire zero;
wire [31:0] alu_result;
wire [2:0] alu_ctrl;
wire new_wen;
wire [31:0] dmem_rdata_swapped;
wire [31:0] dmem_wdata_swapped;

reg [31:0] pc;
wire [31:0] pc_add4;
wire [31:0] branch_target;
assign mem_addr_I = pc;
assign pc_add4 = pc + 4;

assign write_enable = ( inst[2] | inst[3] | inst[4] ) | ~(inst[5] | inst[6]);
assign alu_input1 = rdata1;
assign alu_input2 = (inst[6:2] == 5'b01100 | inst[6:2] == 5'b11000)? rdata2: imm;
assign branch = inst[2] | (inst[6:2] == 5'b11000 & zero);
assign dmem_rdata_swapped = {mem_rdata_D[7:0], mem_rdata_D[15:8], mem_rdata_D[23:16], mem_rdata_D[31:24]};
assign dmem_wdata_swapped = {rdata2[7:0], rdata2[15:8], rdata2[23:16], rdata2[31:24]};

assign branch_target = (inst[3:2]==2'b01)? alu_result : (pc + imm);

assign mem_wdata_D = dmem_wdata_swapped;
assign mem_addr_D = alu_result;
assign new_wen = (inst[6:2] == 5'b01000);
assign mem_wen_D = new_wen;
assign write_data = (inst[2])? pc_add4 : ((inst[6:2] == 5'b00000)? dmem_rdata_swapped : alu_result);

imm_gen imm_gen0(
    .inst(inst),
    .imm(imm)
);

register register0(
    .clk(clk),
    .rst_n(rst_n),
    .read1(rs1),
    .read2(rs2),
    .write_reg(write_reg),
    .wdata(write_data), // TODO: write data
    .wen(write_enable),   // TODO: write enable
    .rdata1(rdata1), // TODO: read data 1
    .rdata2(rdata2)  // TODO: read data 2
);
// alu support +, sub, and, or, slt
//+ : 000, sub:001, and:011, or:010, slt:1xx
get_alu_ctrl alu_ctrl0(
    .inst(inst),
    .alu_ctrl(alu_ctrl)
);

alu alu(
    .input1(alu_input1),
    .input2(alu_input2),
    .alu_op(alu_ctrl),
    .result(alu_result), // TODO: write data
    .zero(zero)
);


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pc <= 0;
    end else begin
        pc <= (branch)? branch_target : pc_add4;
    end
end

endmodule

module imm_gen(
    input [31:0] inst,
    output reg [31:0] imm
);
always @(*) begin
    case (inst[6:2])
        5'b00000, 5'b11001: imm[31:0] = {{20{inst[31]}}, inst[31:20]};
        5'b01000: imm[31:0] = {{20{inst[31]}}, inst[31:25], inst[11:7]};
        5'b11000: imm[31:0] = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0}; // B-type
        5'b11011: imm[31:0] = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0}; // J-type
        default: imm = 32'b0;
    endcase
end


endmodule

module get_alu_ctrl(
    input [31:0] inst,
    output reg [2:0] alu_ctrl
);
always @(*) begin
    case(inst[6:4])
        3'b011: begin
            alu_ctrl[2] = (inst[14:12] == 3'b010); // slt
            alu_ctrl[1] = inst[13];
            alu_ctrl[0] = (inst[13]) ? inst[12] : inst[30];
        end
        3'b110: alu_ctrl = (~inst[2]) ? 3'b001 : 3'b000; // sub or add
        default: alu_ctrl = 3'b000; // add imm
    endcase
end
endmodule

module alu(
    input [31:0] input1,
    input [31:0] input2,
    input [2:0] alu_op,
    output [31:0] result,
    output zero
);
wire [31:0] and_result = input1 & input2;
wire [31:0] or_result = input1 | input2;
wire [32:0]add_sub_result;
wire cout;

assign {cout, add_sub_result} = {input1[31], input1} + ({input2[31], input2} ^ {33{alu_op[0]}}) + alu_op[0];

wire less_than = add_sub_result[32];
wire [31:0] slt_result = (less_than)? 32'b1 : 32'b0;

assign zero = add_sub_result[31:0] == 32'b0;

wire [31:0] ao_result = (alu_op[0])? and_result : or_result;

wire [31:0] compute_result = alu_op[1]? ao_result : add_sub_result[31:0];

assign result = alu_op[2]? slt_result : compute_result;

endmodule

module add_sub #(
    parameter WIDTH = 32
)(
    input  [WIDTH-1:0] A,
    input  [WIDTH-1:0] B,
    input              sub,   // 0:add, 1:sub
    output [WIDTH-1:0] S,
    output             Cout
);

    wire [WIDTH-1:0] B_xor;
    wire [WIDTH:0]   C;   // carry chain

    assign C[0] = sub;   // carry in

    assign B_xor = B ^ {WIDTH{sub}};

    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : rca
            assign S[i] = A[i] ^ B_xor[i] ^ C[i];
            assign C[i+1] = (A[i] & B_xor[i]) |
                            (A[i] & C[i]) |
                            (B_xor[i] & C[i]);
        end
    endgenerate

    assign Cout = C[WIDTH];

endmodule

module register(
    input clk,
    input rst_n,
    input [4:0] read1,
    input [4:0] read2,
    input [4:0] write_reg,
    input [31:0] wdata,
    input wen,
    output [31:0] rdata1,
    output [31:0] rdata2
);
reg [31:0]data_r[31:0];

integer i;
initial begin
    for(i=0;i<32;i=i+1) data_r[i] = 0;
end

assign rdata1 = (read1 == 5'b0) ? 32'b0 : data_r[read1];
assign rdata2 = (read2 == 5'b0) ? 32'b0 : data_r[read2];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for(i=0;i<32;i=i+1) data_r[i] <= 0;
    end else begin
        if (wen && (write_reg != 5'b0)) begin
            data_r[write_reg] <= wdata;
        end
    end
end

endmodule