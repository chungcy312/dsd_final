module mem_stage(
    input         valid,
    input         mem_read,
    input         mem_write,
    input  [31:0] result,
    input  [31:0] store_data,
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
assign dmem_addr = result;
assign dmem_wdata = {store_data[7:0], store_data[15:8], store_data[23:16], store_data[31:24]};
assign dmem_rdata_cpu = {dmem_rdata[7:0], dmem_rdata[15:8], dmem_rdata[23:16], dmem_rdata[31:24]};
assign wb_data = mem_read ? dmem_rdata_cpu : result;
endmodule
