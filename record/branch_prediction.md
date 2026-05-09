# Branch Prediction Record

## Experiment Tools

新增 C++ branch prediction 模擬工具：

- `tools/branch_predictor_sweep.cpp`
- `tools/branch_predictor_init_sweep_result.csv`
- `tools/branch_predictor_global_counter_result.csv`
- `tools/branch_predictor_method_sweep.cpp`
- `tools/branch_predictor_method_sweep_result.csv`

模擬方法：

- 用簡單 RISC-V interpreter 跑 pattern。
- 收集 conditional branch trace：`pc`, `target`, `taken`。
- 對 trace 套不同 branch predictor，計算 prediction accuracy。

目前測試 patterns：

- BrPred
- QSort
- Conv
- LFSR_HIST

## Methods Tested

### Always Not Taken

Baseline 現況：

```text
predict_pc = pc + 4
```

硬體成本最低，幾乎 0 area。

### Always Taken

永遠預測 branch taken。對目前 pattern 普遍不如 always not taken，除了 BrPred 有比較高 taken 比例。

### BTFNT

Backward Taken, Forward Not Taken。

不需要真的算 `branch_target < pc`，看 branch immediate sign bit 即可：

```verilog
predict_taken = is_branch && inst[31];
```

因為 branch immediate 是 signed offset：

```text
imm < 0  => backward branch
imm >= 0 => forward branch
```

RISC-V B-type immediate 的 sign bit 直接來自 instruction bit 31，所以不需要先 sign-extend 出完整 immediate 才知道方向。

優點：

- 幾乎不用 predictor register。
- 對 loop backward branch 有幫助。

代價：

- 需要先 decode branch immediate。
- 若要更早 redirect，可能要把 branch decode/target decision 提早到 ID stage。

### Global Counter

所有 branch 共用一個 saturating counter：

```verilog
reg [2:0] branch_counter;
```

硬體很小，但不同 branch 互相干擾。實驗顯示 global 3-bit counter 沒有明顯贏 always not taken，因此暫時不推薦。

### Bimodal Predictor

用 PC index counter table：

```verilog
reg [1:0] pred_table [0:N-1];
index = pc[...];
```

每個 table entry 是一個 saturating counter。

例如 8-entry 2-bit bimodal：

```text
8 * 2 = 16 FF
```

### Gshare

用 PC index XOR global history：

```text
index = pc_index ^ global_history
```

需要：

- counter table
- global history register
- XOR logic

小 table 時也有不錯效果，但 control/RTL 複雜度比 bimodal 高。

## Key Results

### BrPred Pattern

`BrPred` 是專門測 branch prediction 的 pattern，conditional branch 數約 79。

| Method | Accuracy |
| --- | ---: |
| always not taken | 37.97% |
| always taken | 62.03% |
| BTFNT | 73.42% |
| global 2-bit counter | 46.84% |
| global 3-bit counter | 68.35% |
| 4-entry bimodal 2-bit | 70.89% |
| 4-entry gshare 2-bit | 86.08% |
| 8-entry bimodal 2-bit | 93.67% |
| 8-entry bimodal 3-bit | 93.67% |

結論：

- BTFNT 對 BrPred 很有效，且幾乎不用 FF。
- 8-entry 2-bit bimodal 非常划算，只需 16 個 FF。
- global counter 不推薦，準確率不如 BTFNT。

### QSort / Conv / LFSR_HIST

簡單方法比較：

| Pattern | Always NT | BTFNT | Global 3-bit |
| --- | ---: | ---: | ---: |
| QSort | 72.44% | 72.44% | 70.48% |
| Conv | 63.58% | 66.05% | 63.58% |
| LFSR_HIST | 85.46% | 85.46% | 85.44% |

結論：

- BTFNT 永遠不比 always not taken 差，Conv 有小幅提升。
- global 3-bit counter 沒有贏過 always not taken/BTFNT，因此不考慮。

## Counter Bits and Initial State

針對 bimodal/global counter 測過 2-bit, 3-bit, 4-bit。

觀察：

- 3-bit 通常比 2-bit 穩。
- 4-bit 幾乎沒有穩定提升。
- 2-bit 是經典設計，硬體更省。

Init state sweep：

- 2-bit 較適合 weak/strong not taken。
- 3-bit 較適合 init state around `2`，也就是偏 not taken 但不要太強。

## Recommendation

如果想最小硬體：

```text
BTFNT
```

原因：

- 0 predictor FF。
- BrPred 從 37.97% 提升到 73.42%。
- QSort / Conv / LFSR_HIST 不比 always not taken 差。

如果願意加一點點硬體：

```text
8-entry 2-bit bimodal
```

原因：

- 只有 16 個 FF。
- BrPred accuracy 93.67%。
- RTL 比 gshare 簡單。

暫時不推薦：

```text
global 3-bit counter
```

原因：

- 雖然只有 3 FF，但結果沒有贏 BTFNT。
