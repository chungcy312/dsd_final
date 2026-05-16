module readonly_cache #(
    parameter BLOCKS = 16,
    parameter WAYS   = 1
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

localparam SETS     = (BLOCKS / WAYS);
localparam SET_BITS = clog2(SETS);
localparam WAY_BITS = (WAYS <= 1) ? 1 : clog2(WAYS);
localparam TAG_BITS = 28 - SET_BITS;

localparam S_IDLE   = 1'b0;
localparam S_REFILL = 1'b1;

reg state;
reg [31:0] addr_r;
reg [WAY_BITS-1:0] victim_way_r;
reg [SET_BITS-1:0] victim_set_r;
reg [31:4] mem_addr_r;
reg [WAY_BITS-1:0] replace_way [0:SETS-1];

reg [127:0] data [0:WAYS-1][0:SETS-1];
reg [TAG_BITS-1:0] tag [0:WAYS-1][0:SETS-1];
reg valid [0:WAYS-1][0:SETS-1];

wire [SET_BITS-1:0] set_idx;
wire [SET_BITS-1:0] set_idx_r;
wire [TAG_BITS-1:0] tag_addr;
wire [TAG_BITS-1:0] tag_addr_r;
wire [1:0] word_idx;
wire [1:0] word_idx_r;
reg hit;
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

assign refill_word = select_word(mem_rdata, word_idx_r);
assign rdata = (state == S_REFILL) ? refill_word : hit_word_r;
assign ready = (state == S_IDLE && req && hit) ||
               (state == S_REFILL && mem_ready);

assign mem_read = (state == S_REFILL);
assign mem_write = 1'b0;
assign mem_addr = mem_addr_r;
assign mem_wdata = 128'b0;

always @(*) begin
    hit = 1'b0;
    hit_line = 128'b0;
    hit_word_r = 32'b0;
    for (wi = 0; wi < WAYS; wi = wi + 1) begin
        if (valid[wi][set_idx] && tag[wi][set_idx] == tag_addr) begin
            hit = 1'b1;
            hit_line = data[wi][set_idx];
            hit_word_r = select_word(data[wi][set_idx], word_idx);
        end
    end
end

always @(posedge clk) begin
    if (!rst_n) begin
        state <= S_IDLE;
        victim_way_r <= {WAY_BITS{1'b0}};
        victim_set_r <= {SET_BITS{1'b0}};
        for (si = 0; si < SETS; si = si + 1) begin
            replace_way[si] <= {WAY_BITS{1'b0}};
            for (wi = 0; wi < WAYS; wi = wi + 1) begin
                valid[wi][si] <= 1'b0;
            end
        end
    end else begin
        case (state)
            S_IDLE: begin
                if (req && !hit) begin
                    addr_r <= addr;
                    victim_way_r <= replace_way[set_idx];
                    victim_set_r <= set_idx;
                    mem_addr_r <= addr[31:4];
                    state <= S_REFILL;
                end
            end
            S_REFILL: begin
                if (mem_ready) begin
                    data[victim_way_r][victim_set_r] <= mem_rdata;
                    tag[victim_way_r][victim_set_r] <= tag_addr_r;
                    valid[victim_way_r][victim_set_r] <= 1'b1;
                    replace_way[victim_set_r] <=
                        (replace_way[victim_set_r] == WAYS-1) ?
                        {WAY_BITS{1'b0}} : replace_way[victim_set_r] + 1'b1;
                    state <= S_IDLE;
                end
            end
            default: begin
                state <= S_IDLE;
            end
        endcase
    end
end

endmodule
