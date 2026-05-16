module dcache_2way #(
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

localparam SETS       = (BLOCKS >> 1);
localparam SET_BITS   = clog2(SETS);
localparam TAG_BITS   = 28 - SET_BITS;
localparam S_IDLE     = 3'd0;
localparam S_WB_MISS  = 3'd1;
localparam S_REFILL   = 3'd2;
localparam S_FLUSH    = 3'd3;
localparam S_FLUSH_WB = 3'd4;

reg [2:0] state;
reg [31:0] addr_r;
reg [31:0] wdata_r;
reg wen_r;
reg victim_way_r;
reg [SET_BITS-1:0] victim_set_r;
reg [31:4] mem_addr_r;
reg [127:0] mem_wdata_r;
reg replace_way [0:SETS-1];
reg flush_way;
reg [SET_BITS-1:0] flush_set;
reg flush_done_r;
reg [127:0] data0 [0:SETS-1];
reg [127:0] data1 [0:SETS-1];
reg [TAG_BITS-1:0] tag0 [0:SETS-1];
reg [TAG_BITS-1:0] tag1 [0:SETS-1];
reg valid0 [0:SETS-1];
reg valid1 [0:SETS-1];
reg dirty0 [0:SETS-1];
reg dirty1 [0:SETS-1];

wire [SET_BITS-1:0] set_idx = addr[4 + SET_BITS - 1:4];
wire [SET_BITS-1:0] set_idx_r = addr_r[4 + SET_BITS - 1:4];
wire [TAG_BITS-1:0] tag_addr = addr[31:4 + SET_BITS];
wire [TAG_BITS-1:0] tag_addr_r = addr_r[31:4 + SET_BITS];
wire [1:0] word_idx = addr[3:2];
wire [1:0] word_idx_r = addr_r[3:2];
wire hit0 = valid0[set_idx] && (tag0[set_idx] == tag_addr);
wire hit1 = valid1[set_idx] && (tag1[set_idx] == tag_addr);
wire hit = hit0 | hit1;
wire hit_way = hit1;
wire victim_way = replace_way[set_idx];
wire victim_valid = victim_way ? valid1[set_idx] : valid0[set_idx];
wire victim_dirty_bit = victim_way ? dirty1[set_idx] : dirty0[set_idx];
wire [TAG_BITS-1:0] victim_tag = victim_way ? tag1[set_idx] : tag0[set_idx];
wire [127:0] victim_line = victim_way ? data1[set_idx] : data0[set_idx];
wire [31:4] victim_addr = {victim_tag, set_idx};
wire flush_valid = flush_way ? valid1[flush_set] : valid0[flush_set];
wire flush_dirty = flush_way ? dirty1[flush_set] : dirty0[flush_set];
wire [TAG_BITS-1:0] flush_tag = flush_way ? tag1[flush_set] : tag0[flush_set];
wire [127:0] flush_line = flush_way ? data1[flush_set] : data0[flush_set];
wire [31:4] flush_addr = {flush_tag, flush_set};
wire [31:0] word0 = select_word(data0[set_idx], word_idx);
wire [31:0] word1 = select_word(data1[set_idx], word_idx);
wire [127:0] hit_line = hit1 ? data1[set_idx] : data0[set_idx];
wire [127:0] refill_line = wen_r ? update_word(mem_rdata, word_idx_r, wdata_r) : mem_rdata;
wire [31:0] refill_word = select_word(mem_rdata, word_idx_r);
integer si;

assign rdata = (state == S_REFILL) ? refill_word :
               hit1 ? word1 : word0;
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
        victim_way_r <= 1'b0;
        victim_set_r <= {SET_BITS{1'b0}};
        flush_way <= 1'b0;
        flush_set <= {SET_BITS{1'b0}};
        flush_done_r <= 1'b0;
        for (si = 0; si < SETS; si = si + 1) begin
            replace_way[si] <= 1'b0;
            valid0[si] <= 1'b0;
            valid1[si] <= 1'b0;
            dirty0[si] <= 1'b0;
            dirty1[si] <= 1'b0;
        end
    end else begin
        if (!flush) begin
            flush_done_r <= 1'b0;
        end
        case (state)
            S_IDLE: begin
                if (flush && !flush_done_r) begin
                    flush_way <= 1'b0;
                    flush_set <= {SET_BITS{1'b0}};
                    state <= S_FLUSH;
                end else if (req && !flush) begin
                    addr_r <= addr;
                    wdata_r <= wdata;
                    wen_r <= wen;
                    if (hit) begin
                        if (wen) begin
                            if (hit_way) begin
                                data1[set_idx] <= update_word(hit_line, word_idx, wdata);
                                dirty1[set_idx] <= 1'b1;
                            end else begin
                                data0[set_idx] <= update_word(hit_line, word_idx, wdata);
                                dirty0[set_idx] <= 1'b1;
                            end
                        end
                    end else begin
                        victim_way_r <= victim_way;
                        victim_set_r <= set_idx;
                        if (victim_valid && victim_dirty_bit) begin
                            mem_addr_r <= victim_addr;
                            mem_wdata_r <= victim_line;
                            state <= S_WB_MISS;
                        end else begin
                            mem_addr_r <= addr[31:4];
                            state <= S_REFILL;
                        end
                    end
                end
            end
            S_WB_MISS: begin
                if (mem_ready) begin
                    if (victim_way_r) begin
                        dirty1[victim_set_r] <= 1'b0;
                    end else begin
                        dirty0[victim_set_r] <= 1'b0;
                    end
                    mem_addr_r <= addr_r[31:4];
                    state <= S_REFILL;
                end
            end
            S_REFILL: begin
                if (mem_ready) begin
                    if (victim_way_r) begin
                        data1[victim_set_r] <= refill_line;
                        tag1[victim_set_r] <= tag_addr_r;
                        valid1[victim_set_r] <= 1'b1;
                        dirty1[victim_set_r] <= wen_r;
                    end else begin
                        data0[victim_set_r] <= refill_line;
                        tag0[victim_set_r] <= tag_addr_r;
                        valid0[victim_set_r] <= 1'b1;
                        dirty0[victim_set_r] <= wen_r;
                    end
                    replace_way[victim_set_r] <= ~victim_way_r;
                    state <= S_IDLE;
                end
            end
            S_FLUSH: begin
                if (flush_valid && flush_dirty) begin
                    mem_addr_r <= flush_addr;
                    mem_wdata_r <= flush_line;
                    state <= S_FLUSH_WB;
                end else if (flush_way && flush_set == SETS-1) begin
                    flush_done_r <= 1'b1;
                    state <= S_IDLE;
                end else if (flush_way) begin
                    flush_way <= 1'b0;
                    flush_set <= flush_set + 1'b1;
                end else begin
                    flush_way <= 1'b1;
                end
            end
            S_FLUSH_WB: begin
                if (mem_ready) begin
                    if (flush_way) begin
                        dirty1[flush_set] <= 1'b0;
                    end else begin
                        dirty0[flush_set] <= 1'b0;
                    end
                    if (flush_way && flush_set == SETS-1) begin
                        flush_done_r <= 1'b1;
                        state <= S_IDLE;
                    end else if (flush_way) begin
                        flush_way <= 1'b0;
                        flush_set <= flush_set + 1'b1;
                        state <= S_FLUSH;
                    end else begin
                        flush_way <= 1'b1;
                        state <= S_FLUSH;
                    end
                end
            end
        endcase
    end
end

endmodule
