# Future Test Plan

這份紀錄整理後續要做的實驗，用來比較 cache 參數與 branch prediction 方法對 area、timing、cycle count 的影響。

## 1. Cache Experiments

### Goal

比較不同 I-cache / D-cache 組合在以下指標的 tradeoff：

- miss rate
- total simulation time
- synthesis area
- critical path / minimum clock period
- gate-level simulation 是否有 timing violation

### Cache Parameters

目前 slow memory interface 固定為 128-bit，所以 cache line 固定是 4 words。

要測的參數：

```text
I-cache blocks: 16, 32
D-cache blocks: 16, 32, 64
ways: 1, 2
```

因為之前 sweep 顯示 `ways >= 4` 幾乎沒有明顯改善，所以暫時不測 4-way 以上。

### Suggested Test Matrix

先從 area/timing 較小的組合開始：

| Case | I-cache | D-cache | Purpose |
| --- | --- | --- | --- |
| C0 | 1-way, 16 blocks | 1-way, 16 blocks | fair baseline, same line count as old cache |
| C1 | 1-way, 32 blocks | 1-way, 16 blocks | test larger I-cache only |
| C2 | 1-way, 16 blocks | 1-way, 32 blocks | test larger D-cache only |
| C3 | 1-way, 32 blocks | 1-way, 32 blocks | balanced small/mid cache |
| C4 | 1-way, 32 blocks | 1-way, 64 blocks | higher hit-rate candidate |
| C5 | 1-way, 32 blocks | 2-way, 32 blocks | test D-cache associativity |
| C6 | 1-way, 32 blocks | 2-way, 64 blocks | high D-cache hit-rate candidate |

如果 synthesis timing 壓力很大，優先保留：

```text
C0, C1, C2, C3
```

如果 timing 有餘裕，再測：

```text
C4, C5, C6
```

### Patterns

必測：

```text
noHazard
hasHazard
BrPred
QSort
Conv
LFSR_HIST
```

其中：

- `noHazard` / `hasHazard`: correctness baseline
- `BrPred`: branch prediction behavior
- `QSort`, `Conv`, `LFSR_HIST`: final performance patterns

### Data to Record

每個 cache case 記錄：

```text
case name
ICACHE_BLOCKS
DCACHE_BLOCKS
I-cache way
D-cache way
RTL sim pass/fail
gate sim pass/fail
clock cycle
total cell area
critical path start/end
WNS/TNS
pattern simulation time
```

建議整理成 CSV：

```text
cache_case,ic_way,ic_blocks,dc_way,dc_blocks,pattern,cycle_ns,sim_time_ns,total_cell_area,wns,pass
```

## 2. Branch Prediction Experiments

### Goal

比較 baseline `always not taken` 與新加入的 `BTFNT` 對 cycle count / simulation time 的影響。

### Methods

#### Always Not Taken

Baseline:

```text
predict branch not taken
next PC = PC + 4
```

優點：

- 0 extra predictor hardware
- control 最簡單

缺點：

- backward loop branch 通常會 mispredict

#### BTFNT

Backward Taken, Forward Not Taken:

```verilog
predict_taken = is_branch && inst[31];
```

因為 RISC-V branch immediate 的 sign bit 直接是 `inst[31]`：

```text
inst[31] = 1 -> negative offset -> backward branch -> predict taken
inst[31] = 0 -> positive offset -> forward branch -> predict not taken
```

優點：

- 幾乎不需要 predictor FF
- 對 loop branch 有幫助

代價：

- 需要在 ID stage decode branch immediate
- 若預測 taken，需要 ID stage 提前產生 branch target

### Suggested Branch Prediction Test Matrix

| Case | Predictor | Description |
| --- | --- | --- |
| B0 | always not taken | original baseline |
| B1 | BTFNT | ID-stage backward branch redirect |

先不要混入 bimodal/gshare，以免 register 數和 update control 增加太多。

### Patterns

必測：

```text
BrPred
QSort
Conv
LFSR_HIST
```

另外也要跑：

```text
noHazard
hasHazard
```

確認 BTFNT 沒有破壞 control hazard / flush correctness。

### Data to Record

每個 branch predictor case 記錄：

```text
predictor
pattern
RTL sim pass/fail
gate sim pass/fail
cycle count or total simulation time
total cell area
critical path
```

建議 CSV：

```text
predictor,pattern,cycle_ns,sim_time_ns,total_cell_area,critical_path,pass
```

## 3. Combined Experiments

等 cache 和 branch prediction 分別穩定後，再做組合實驗。

建議先測：

| Case | Cache | Predictor |
| --- | --- | --- |
| F0 | best small-area cache | always not taken |
| F1 | best small-area cache | BTFNT |
| F2 | best performance cache | always not taken |
| F3 | best performance cache | BTFNT |

目的：

- 分清楚 performance improvement 來自 cache 還是 branch prediction。
- 避免一次改太多導致 debug 不知道問題來源。

## 4. Expected Decision Criteria

最後選 design 時，不只看 hit rate 或 branch accuracy，要同時看：

```text
score impact = area impact + simulation time impact + timing feasibility
```

可能的選擇策略：

- 如果 area penalty 很敏感：選 1-way small cache + BTFNT。
- 如果 timing 最敏感：選 1-way cache，避免 2-way way mux。
- 如果 runtime 最敏感：考慮 larger D-cache 或 2-way D-cache，再確認 timing。
- 如果 BrPred pattern 權重很高：BTFNT 應該比 always not taken 更值得保留。
