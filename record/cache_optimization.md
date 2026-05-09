# Cache Optimization Record

## Background

目前 slow memory interface 固定是 128-bit，所以 cache line 固定為 4 words。之前 sweep 的參數主要是：

- blocks: 8, 16, 32, 64, 128
- ways: 1, 2, 4, 8, 16
- patterns: QSort, Conv, LFSR_HIST

結果來源：

- `tools/cache_sweep.cpp`
- `tools/cache_sweep_result.csv`

## Main Observations

### Way 數

實驗結果顯示 `ways >= 4` 幾乎沒有明顯進步，所以目前只考慮：

- direct-mapped / 1-way
- 2-way set associative

另外，在同樣 `blocks * ways` 或同樣總 line 數附近，1-way 有時反而 miss rate 更低。主要原因是 2-way 會讓 set 數減半，某些 pattern 反而增加 set conflict。

### I-cache

I-cache 對 QSort / LFSR_HIST 在 blocks 到 32 後，miss rate 幾乎已經很低：

- QSort: 32 blocks 後 I miss rate 約 0.000541
- LFSR_HIST: 32 blocks 後 I miss rate 約 0.000130
- Conv: 32 blocks 後 I miss rate 約 0.009 左右

因此 I-cache 比較適合：

```text
icache_1way
ICACHE_BLOCKS = 16 或 32
```

若以 area/timing 優先，`16 blocks` 比較公平，因為和原本泛用 2-way cache 的總 data line 數相同。

若以 hit rate 優先，`32 blocks` 是 I-cache 很好的飽和點。

### D-cache

D-cache 的 pattern 差異比較大：

- QSort: D-cache 2-way 在 32/64 blocks 有明顯幫助。
- Conv: 2-way 在 16/64 blocks 對 D miss rate 有幫助。
- LFSR_HIST: D miss rate 本身偏高，但 1-way/2-way 差異不大。

目前若考慮 area/timing，先用：

```text
dcache_1way
DCACHE_BLOCKS = 16
```

若有 timing margin，再實驗：

```text
dcache_1way, DCACHE_BLOCKS = 32 or 64
dcache_2way, DCACHE_BLOCKS = 32 or 64
```

## RTL Changes

新增四個專用 cache module：

- `icache_1way`
- `icache_2way`
- `dcache_1way`
- `dcache_2way`

目的：

- 從 RTL 層面移除泛用 `WAYS` loop。
- 1-way 不需要 way compare、way mux、replacement bit。
- 2-way 寫死 `data0/data1`, `tag0/tag1`，讓合成器看到更直接的結構。

目前 top 預設接：

```verilog
icache_1way
dcache_1way
```

最外層只保留：

```verilog
parameter ICACHE_BLOCKS = 16;
parameter DCACHE_BLOCKS = 16;
```

## Data Array Declaration Discussion

曾討論：

```verilog
reg [31:0] cache [0:WAY-1][0:BLOCK-1];
```

這種寫法不一定比較快。真正影響 timing 的是：

- 是否有 way compare
- 是否有 way mux
- 是否有 generate/for-loop 造成的泛用 mux
- hit data path 是否先做 word select，再做 32-bit way mux

2-way 較佳 hit path：

```text
addr
  -> set/tag/word decode
  -> way0 tag compare + way0 word select
  -> way1 tag compare + way1 word select
  -> 32-bit way mux
```

## Reset Optimization

Cache data array 不需要 reset，只需要 reset：

- valid bit
- dirty bit
- FSM/control registers

原因：

- valid bit 決定 cache line 是否可用。
- data array reset 會增加 reset mux path，也可能造成 gate-level timing 壓力。

這個策略已用在 cache data array 上。

## Current Recommendation

目前為了公平比較 area/timing，先用：

```text
I-cache: 1-way, 16 blocks
D-cache: 1-way, 16 blocks
```

若 gate timing 有餘裕，建議下一輪 sweep：

```text
I-cache: 1-way, 16 vs 32 blocks
D-cache: 1-way, 16 vs 32 vs 64 blocks
D-cache: 2-way, 32 vs 64 blocks
```

不要先切 memory/cache pipeline，除非 critical path 明確卡在 cache hit path 且其他優化已做完。
