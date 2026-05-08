module CHIP (
    input clk,
    input rst_n
);
    
    wire        mem_wen_D;
    wire [31:0] mem_addr_D;
    wire [31:0] mem_wdata_D;
    wire [31:0] mem_rdata_D;

    wire [31:0] mem_addr_I;
    wire [31:0] mem_rdata_I;

    memory mem_I(
        .clk(clk),
        .wen(1'b0),
        .a(mem_addr_I[6:2]),
        .d(32'd0),
        .q(mem_rdata_I)
    );

    memory mem_D(
        .clk(clk),
        .wen(mem_wen_D),
        .a(mem_addr_D[6:2]),
        .d(mem_wdata_D),
        .q(mem_rdata_D)
    );

    core core0(
        .clk(clk),
        .rst_n(rst_n),
        .mem_wen_D(mem_wen_D),
        .mem_addr_D(mem_addr_D),
        .mem_wdata_D(mem_wdata_D),
        .mem_rdata_D(mem_rdata_D),
        .mem_addr_I(mem_addr_I),
        .mem_rdata_I(mem_rdata_I)
    );
    
endmodule