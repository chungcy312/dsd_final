module icache_1way #(
    parameter BLOCKS = 32
) (
    input          clk,
    input          rst_n,
    input          req,
    input  [31:0]  addr,
    output [31:0]  rdata,
    output         ready,

    output         mem_read,
    output         mem_write,
    output [31:4]  mem_addr,
    output [127:0] mem_wdata,
    input  [127:0] mem_rdata,
    input          mem_ready
);
function integer clog2;
    input integer value;
    integer v;
    begin
        v = value - 1;
        for (clog2 = 0; v > 0; clog2 = clog2 + 1) begin
            v = v >> 1;
        end
    end
endfunction

function [31:0] select_word;
    input [127:0] line;
    input [1:0]   index;
    begin
        case (index)
            2'd0: select_word = line[31:0];
            2'd1: select_word = line[63:32];
            2'd2: select_word = line[95:64];
            2'd3: select_word = line[127:96];
        endcase
    end
endfunction

localparam SET_BITS = clog2(BLOCKS);
localparam TAG_BITS = 28 - SET_BITS;
localparam S_IDLE   = 2'd0;
localparam S_REFILL = 2'd1;
localparam S_FILL   = 2'd2;

reg [1:0] state;
reg [31:0] addr_r;
reg [31:4] mem_addr_r;
reg [127:0] mem_rdata_r;
reg [127:0] data [0:BLOCKS-1];
reg [TAG_BITS-1:0] tag [0:BLOCKS-1];
reg valid [0:BLOCKS-1];

wire [SET_BITS-1:0] set_idx = addr[4 + SET_BITS - 1:4];
wire [SET_BITS-1:0] set_idx_r = addr_r[4 + SET_BITS - 1:4];
wire [TAG_BITS-1:0] tag_addr = addr[31:4 + SET_BITS];
wire [TAG_BITS-1:0] tag_addr_r = addr_r[31:4 + SET_BITS];
wire [1:0] word_idx = addr[3:2];
wire hit = valid[set_idx] && (tag[set_idx] == tag_addr);
wire [31:0] hit_word = select_word(data[set_idx], word_idx);
integer si;

assign rdata = hit_word;
assign ready = state == S_IDLE && req && hit;
assign mem_read = (state == S_REFILL);
assign mem_write = 1'b0;
assign mem_addr = mem_addr_r;
assign mem_wdata = 128'b0;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= S_IDLE;
        for (si = 0; si < BLOCKS; si = si + 1) begin
            valid[si] <= 1'b0;
        end
    end else begin
        case (state)
            S_IDLE: begin
                if (req && !hit) begin
                    state <= S_REFILL;
                end
            end
            S_REFILL: begin
                if (mem_ready) begin
                    mem_rdata_r <= mem_rdata;
                    state <= S_FILL;
                end
            end
            S_FILL: begin
                data[set_idx_r] <= mem_rdata_r;
                tag[set_idx_r] <= tag_addr_r;
                valid[set_idx_r] <= 1'b1;
                state <= S_IDLE;
            end
        endcase
    end
end

always @(posedge clk) begin
    if (state == S_IDLE && req && !hit) begin
        addr_r <= addr;
        mem_addr_r <= addr[31:4];
    end
end

endmodule
