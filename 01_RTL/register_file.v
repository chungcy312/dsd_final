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

always @(posedge clk) begin
    if (!rst_n) begin
        for (i = 0; i < 32; i = i + 1) begin
            data_r[i] <= 32'b0;
        end
    end else if (wen && write_reg != 5'b0) begin
        data_r[write_reg] <= wdata;
    end
end

endmodule
