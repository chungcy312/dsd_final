module blocking_cache #(
    parameter BLOCKS    = 16,
    parameter WAYS      = 1,
    parameter READ_ONLY = 0
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

localparam IS_READ_ONLY = (READ_ONLY != 0);
localparam SETS        = (BLOCKS / WAYS);
localparam SET_BITS    = clog2(SETS);
localparam WAY_BITS    = (WAYS <= 1) ? 1 : clog2(WAYS);
localparam TAG_BITS    = 28 - SET_BITS;

localparam S_IDLE       = 3'd0;
localparam S_WB_MISS    = 3'd1;
localparam S_REFILL     = 3'd2;
localparam S_FLUSH      = 3'd3;
localparam S_FLUSH_WB   = 3'd4;

reg [2:0] state;
reg [31:0] addr_r;
reg [31:0] wdata_r;
reg        wen_r;
reg [WAY_BITS-1:0] victim_way_r;
reg [SET_BITS-1:0] victim_set_r;
reg [31:4] mem_addr_r;
reg [127:0] mem_wdata_r;
reg [WAY_BITS-1:0] replace_way [0:SETS-1];
reg [WAY_BITS-1:0] flush_way;
reg [SET_BITS-1:0] flush_set;
reg flush_done_r;

reg [127:0] data [0:WAYS-1][0:SETS-1];
reg [TAG_BITS-1:0] tag [0:WAYS-1][0:SETS-1];
reg valid [0:WAYS-1][0:SETS-1];
reg dirty [0:WAYS-1][0:SETS-1];

wire [SET_BITS-1:0] set_idx;
wire [SET_BITS-1:0] set_idx_r;
wire [TAG_BITS-1:0] tag_addr;
wire [TAG_BITS-1:0] tag_addr_r;
wire [1:0] word_idx;
wire [1:0] word_idx_r;
wire [127:0] refill_line;
wire victim_dirty;
wire [31:4] victim_addr;
wire [31:4] flush_addr;
reg hit;
reg [WAY_BITS-1:0] hit_way;
reg [127:0] hit_line;
reg [31:0] hit_word_r;
wire [31:0] refill_word;
integer wi;
integer si;

assign set_idx = addr[4 + SET_BITS - 1:4];
assign set_idx_r = addr_r[4 + SET_BITS - 1:4];
assign tag_addr = addr[31:4 + SET_BITS];
assign tag_addr_r = addr_r[31:4 + SET_BITS];
assign word_idx = addr[3:2];
assign word_idx_r = addr_r[3:2];
assign refill_line = wen_r ? update_word(mem_rdata, word_idx_r, wdata_r) : mem_rdata;
assign victim_dirty = valid[replace_way[set_idx]][set_idx] &&
                      dirty[replace_way[set_idx]][set_idx] &&
                      !IS_READ_ONLY;
assign victim_addr = {tag[replace_way[set_idx]][set_idx], set_idx};
assign flush_addr = {tag[flush_way][flush_set], flush_set};
assign refill_word = select_word(mem_rdata, word_idx_r);
assign rdata = (state == S_REFILL) ? refill_word : hit_word_r;
assign ready = (state == S_IDLE && req && hit) ||
               (state == S_REFILL && mem_ready);
assign flush_done = IS_READ_ONLY ? ((state == S_IDLE) && flush) : flush_done_r;
assign mem_read = (state == S_REFILL);
assign mem_write = (state == S_WB_MISS) || (state == S_FLUSH_WB);
assign mem_addr = mem_addr_r;
assign mem_wdata = mem_wdata_r;

always @(*) begin
    hit = 1'b0;
    hit_way = {WAY_BITS{1'b0}};
    hit_line = 128'b0;
    hit_word_r = 32'b0;
    for (wi = 0; wi < WAYS; wi = wi + 1) begin
        if (valid[wi][set_idx] && tag[wi][set_idx] == tag_addr) begin
            hit = 1'b1;
            hit_way = wi;
            hit_line = data[wi][set_idx];
            hit_word_r = select_word(data[wi][set_idx], word_idx);
        end
    end
end

always @(posedge clk) begin
    if (!rst_n) begin
        state <= S_IDLE;
        wen_r <= 1'b0;
        victim_way_r <= {WAY_BITS{1'b0}};
        victim_set_r <= {SET_BITS{1'b0}};
        flush_way <= {WAY_BITS{1'b0}};
        flush_set <= {SET_BITS{1'b0}};
        flush_done_r <= 1'b0;
        for (si = 0; si < SETS; si = si + 1) begin
            replace_way[si] <= {WAY_BITS{1'b0}};
            for (wi = 0; wi < WAYS; wi = wi + 1) begin
                valid[wi][si] <= 1'b0;
                dirty[wi][si] <= 1'b0;
            end
        end
    end else begin
        if (!flush) begin
            flush_done_r <= 1'b0;
        end
        case (state)
            S_IDLE: begin
                if (flush && !flush_done_r && !IS_READ_ONLY) begin
                    flush_way <= {WAY_BITS{1'b0}};
                    flush_set <= {SET_BITS{1'b0}};
                    flush_done_r <= 1'b0;
                    state <= S_FLUSH;
                end else if (req && !flush) begin
                    addr_r <= addr;
                    wdata_r <= wdata;
                    wen_r <= wen && !IS_READ_ONLY;
                    if (hit) begin
                        if (wen && !IS_READ_ONLY) begin
                            data[hit_way][set_idx] <= update_word(hit_line, word_idx, wdata);
                            dirty[hit_way][set_idx] <= 1'b1;
                        end
                    end else begin
                        victim_way_r <= replace_way[set_idx];
                        victim_set_r <= set_idx;
                        if (victim_dirty) begin
                            mem_addr_r <= victim_addr;
                            mem_wdata_r <= data[replace_way[set_idx]][set_idx];
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
                    dirty[victim_way_r][victim_set_r] <= 1'b0;
                    mem_addr_r <= addr_r[31:4];
                    state <= S_REFILL;
                end
            end
            S_REFILL: begin
                if (mem_ready) begin
                    data[victim_way_r][victim_set_r] <= refill_line;
                    tag[victim_way_r][victim_set_r] <= tag_addr_r;
                    valid[victim_way_r][victim_set_r] <= 1'b1;
                    dirty[victim_way_r][victim_set_r] <= wen_r;
                    replace_way[victim_set_r] <=
                        (replace_way[victim_set_r] == WAYS-1) ?
                        {WAY_BITS{1'b0}} : replace_way[victim_set_r] + 1'b1;
                    state <= S_IDLE;
                end
            end
            S_FLUSH: begin
                if (valid[flush_way][flush_set] && dirty[flush_way][flush_set]) begin
                    mem_addr_r <= flush_addr;
                    mem_wdata_r <= data[flush_way][flush_set];
                    state <= S_FLUSH_WB;
                end else if (flush_way == WAYS-1 && flush_set == SETS-1) begin
                    flush_done_r <= 1'b1;
                    state <= S_IDLE;
                end else if (flush_way == WAYS-1) begin
                    flush_way <= {WAY_BITS{1'b0}};
                    flush_set <= flush_set + 1'b1;
                end else begin
                    flush_way <= flush_way + 1'b1;
                end
            end
            S_FLUSH_WB: begin
                if (mem_ready) begin
                    dirty[flush_way][flush_set] <= 1'b0;
                    if (flush_way == WAYS-1 && flush_set == SETS-1) begin
                        flush_done_r <= 1'b1;
                        state <= S_IDLE;
                    end else if (flush_way == WAYS-1) begin
                        flush_way <= {WAY_BITS{1'b0}};
                        flush_set <= flush_set + 1'b1;
                        state <= S_FLUSH;
                    end else begin
                        flush_way <= flush_way + 1'b1;
                        state <= S_FLUSH;
                    end
                end
            end
            default: begin
                state <= S_IDLE;
            end
        endcase
    end
end

endmodule
