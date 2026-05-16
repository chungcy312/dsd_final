module dcache_1way #(
    parameter BLOCKS = 64
) (
    input          clk,
    input          rst_n,
    input          req,
    input          wen,
    input  [31:0]  addr,
    input  [31:0]  wdata,
    output [31:0]  rdata,
    output         ready,
    input          flush,
    output         flush_done,

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

function [127:0] update_word;
    input [127:0] line;
    input [1:0]   index;
    input [31:0]  word;
    begin
        case (index)
            2'd0: update_word = {line[127:32], word};
            2'd1: update_word = {line[127:64], word, line[31:0]};
            2'd2: update_word = {line[127:96], word, line[63:0]};
            2'd3: update_word = {word, line[95:0]};
        endcase
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

localparam SET_BITS  = clog2(BLOCKS);
localparam TAG_BITS  = 28 - SET_BITS;
localparam S_IDLE     = 3'd0;
localparam S_WB_MISS  = 3'd1;
localparam S_REFILL   = 3'd2;
localparam S_FLUSH    = 3'd3;
localparam S_FLUSH_WB = 3'd4;
localparam S_MISS     = 3'd5;

reg [2:0] state;
reg [31:0] addr_r;
reg [31:0] wdata_r;
reg wen_r;
reg [31:4] mem_addr_r;
reg [127:0] mem_wdata_r;
reg [SET_BITS-1:0] flush_set;
reg flush_done_r;
reg [127:0] data [0:BLOCKS-1];
reg [TAG_BITS-1:0] tag [0:BLOCKS-1];
reg valid [0:BLOCKS-1];
reg dirty [0:BLOCKS-1];

wire [SET_BITS-1:0] set_idx = addr[4 + SET_BITS - 1:4];
wire [SET_BITS-1:0] set_idx_r = addr_r[4 + SET_BITS - 1:4];
wire [TAG_BITS-1:0] tag_addr = addr[31:4 + SET_BITS];
wire [TAG_BITS-1:0] tag_addr_r = addr_r[31:4 + SET_BITS];
wire [1:0] word_idx = addr[3:2];
wire [1:0] word_idx_r = addr_r[3:2];
wire hit = valid[set_idx] && (tag[set_idx] == tag_addr);
wire victim_dirty_r = valid[set_idx_r] && dirty[set_idx_r];
wire [31:4] victim_addr_r = {tag[set_idx_r], set_idx_r};
wire [31:4] flush_addr = {tag[flush_set], flush_set};
wire [127:0] refill_line = wen_r ? update_word(mem_rdata, word_idx_r, wdata_r) : mem_rdata;
wire [31:0] hit_word = select_word(data[set_idx], word_idx);
wire [31:0] refill_word = select_word(mem_rdata, word_idx_r);
integer si;

assign rdata = (state == S_REFILL) ? refill_word : hit_word;
assign ready = (state == S_IDLE && req && hit) ||
               (state == S_REFILL && mem_ready);
assign flush_done = flush_done_r;
assign mem_read = (state == S_REFILL);
assign mem_write = (state == S_WB_MISS) || (state == S_FLUSH_WB);
assign mem_addr = mem_addr_r;
assign mem_wdata = mem_wdata_r;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= S_IDLE;
        wen_r <= 1'b0;
        flush_set <= {SET_BITS{1'b0}};
        flush_done_r <= 1'b0;
        for (si = 0; si < BLOCKS; si = si + 1) begin
            valid[si] <= 1'b0;
            dirty[si] <= 1'b0;
        end
    end else begin
        if (!flush) begin
            flush_done_r <= 1'b0;
        end
        case (state)
            S_IDLE: begin
                if (flush && !flush_done_r) begin
                    flush_set <= {SET_BITS{1'b0}};
                    state <= S_FLUSH;
                end else if (req && !flush) begin
                    wen_r <= wen;
                    if (hit) begin
                        if (wen) begin
                            dirty[set_idx] <= 1'b1;
                        end
                    end else begin
                        state <= S_MISS;
                    end
                end
            end
            S_MISS: begin
                if (victim_dirty_r) begin
                    state <= S_WB_MISS;
                end else begin
                    state <= S_REFILL;
                end
            end
            S_WB_MISS: begin
                if (mem_ready) begin
                    dirty[set_idx_r] <= 1'b0;
                    state <= S_REFILL;
                end
            end
            S_REFILL: begin
                if (mem_ready) begin
                    valid[set_idx_r] <= 1'b1;
                    dirty[set_idx_r] <= wen_r;
                    state <= S_IDLE;
                end
            end
            S_FLUSH: begin
                if (valid[flush_set] && dirty[flush_set]) begin
                    state <= S_FLUSH_WB;
                end else if (flush_set == BLOCKS-1) begin
                    flush_done_r <= 1'b1;
                    state <= S_IDLE;
                end else begin
                    flush_set <= flush_set + 1'b1;
                end
            end
            S_FLUSH_WB: begin
                if (mem_ready) begin
                    dirty[flush_set] <= 1'b0;
                    if (flush_set == BLOCKS-1) begin
                        flush_done_r <= 1'b1;
                        state <= S_IDLE;
                    end else begin
                        flush_set <= flush_set + 1'b1;
                        state <= S_FLUSH;
                    end
                end
            end
        endcase
    end
end

always @(posedge clk) begin
    if (state == S_IDLE && req && !flush) begin
        addr_r <= addr;
        wdata_r <= wdata;
        if (hit && wen) begin
            data[set_idx] <= update_word(data[set_idx], word_idx, wdata);
        end
    end

    if (state == S_MISS) begin
        if (victim_dirty_r) begin
            mem_addr_r <= victim_addr_r;
            mem_wdata_r <= data[set_idx_r];
        end else begin
            mem_addr_r <= addr_r[31:4];
        end
    end

    if (state == S_WB_MISS && mem_ready) begin
        mem_addr_r <= addr_r[31:4];
    end

    if (state == S_REFILL && mem_ready) begin
        data[set_idx_r] <= refill_line;
        tag[set_idx_r] <= tag_addr_r;
    end

    if (state == S_FLUSH && valid[flush_set] && dirty[flush_set]) begin
        mem_addr_r <= flush_addr;
        mem_wdata_r <= data[flush_set];
    end
end

endmodule
