module if_stage(
    input         clk,
    input         rst_n,
    input         stall,
    input         redirect,
    input  [31:0] redirect_pc,
    input         imem_ready,
    input  [31:0] imem_rdata,
    input         done,
    output [31:0] imem_addr,
    output        if_ready,
    output [31:0] if_pc,
    output [31:0] if_pc_inc,
    output [31:0] if_inst
);
localparam S_FETCH0 = 1'b0;
localparam S_FETCH1 = 1'b1;

reg [31:0] pc;
reg        state;
reg [15:0] saved_upper_half;
reg [31:0] saved_pc;
wire [31:0] pc4;
wire [31:0] pc2;
wire [31:0] fetch_word;
wire [15:0] first_half;
wire        first_is_32;
wire        need_second_word;
wire [31:0] compressed_inst;
wire [31:0] aligned_inst;
wire [31:0] aligned_pc;
wire [31:0] aligned_pc_inc;

assign pc4 = pc + 32'd4;
assign pc2 = pc + 32'd2;
assign imem_addr = (state == S_FETCH1) ? pc2 : pc;
assign fetch_word = {imem_rdata[7:0], imem_rdata[15:8], imem_rdata[23:16], imem_rdata[31:24]};
assign first_half = pc[1] ? fetch_word[31:16] : fetch_word[15:0];
assign first_is_32 = (first_half[1:0] == 2'b11);
assign need_second_word = (state == S_FETCH0) & ~stall & imem_ready & pc[1] & first_is_32;
assign if_ready = imem_ready & ~need_second_word;
assign aligned_inst = (state == S_FETCH1) ? {fetch_word[15:0], saved_upper_half} :
                      first_is_32 ? fetch_word : compressed_inst;
assign aligned_pc = (state == S_FETCH1) ? saved_pc : pc;
assign aligned_pc_inc = (state == S_FETCH1 || first_is_32) ? 32'd4 : 32'd2;
assign if_pc = aligned_pc;
assign if_pc_inc = aligned_pc_inc;
assign if_inst = aligned_inst;

compressed_decoder compressed_decoder0 (
    .cinst      (first_half),
    .inst       (compressed_inst)
);

always @(posedge clk) begin
    if (!rst_n) begin
        pc <= 32'b0;
        state <= S_FETCH0;
    end else if (!done) begin
        if (state == S_FETCH0) begin
            if (!stall && imem_ready && redirect && (redirect_pc != pc)) begin
                pc <= redirect_pc;
                state <= S_FETCH0;
            end else if (!stall && imem_ready && pc[1] && first_is_32) begin
                state <= S_FETCH1;
            end else if (!stall && imem_ready) begin
                pc <= redirect ? redirect_pc :
                      first_is_32 ? pc4 : pc2;
            end
        end else begin
            if (!stall && imem_ready) begin
                pc <= redirect ? redirect_pc : (saved_pc + 32'd4);
                state <= S_FETCH0;
            end
        end
    end
end

always @(posedge clk) begin
    if (!done && state == S_FETCH0 && !stall && imem_ready && pc[1] && first_is_32 &&
        !(redirect && (redirect_pc != pc))) begin
        saved_upper_half <= first_half;
        saved_pc <= pc;
    end
end

`ifdef DEBUG_IF_OUT
always @(posedge clk) begin
    if (rst_n && !done) begin
        if (!stall && imem_ready && if_ready) begin
            $display("[IF_OUT] t=%0t pc=%h inc=%0d inst=%h state=%0d word=%h half=%h is32=%0b",
                     $time, if_pc, if_pc_inc, if_inst, state, fetch_word, first_half, first_is_32);
        end
        if (!stall && imem_ready && (state == S_FETCH0) && pc[1] && first_is_32) begin
            $display("[IF_CROSS] t=%0t pc=%h upper=%h next_addr=%h",
                     $time, pc, first_half, pc + 32'd2);
        end
    end
end
`endif
endmodule
