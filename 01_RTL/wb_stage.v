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
