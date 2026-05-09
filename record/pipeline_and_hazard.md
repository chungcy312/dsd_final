# Pipeline and Hazard Record

## Pipeline Organization

目前 core 已改成 pipeline CPU，並將各 stage 包成 module 以利 debug。

主要 stage/module：

- IF stage
- ID stage
- EX stage
- MEM stage
- WB path
- forwarding unit
- hazard / stall / flush control

## Stage Register Optimization

之前討論過 stage 間 data register 數量，已做或考慮過：

### PC / PC+4

不需要同時傳 `pc` 和 `pc+4`。

可只傳：

```text
pc
```

需要 link address 時再算：

```text
pc + 4
```

### Immediate

ID stage 先選後面需要的 immediate，ID/EX 不必傳所有 imm。

### EX/MEM Result

合併部分 writeback data：

```text
exmem_result
```

用 control signal 決定它是 ALU result / PC+4 / immediate 等。

## Hazard Handling

### Structural Hazard

I-cache 和 D-cache 分開，正常 IF/MEM 不互相搶同一個 memory port。

cache miss 時各自透過 ready/stall 控制 pipeline。

### Data Hazard

處理方式：

- EX/MEM forwarding
- MEM/WB forwarding
- store-data forwarding
- load-use bubble

load-use hazard 需要等 memory/cache 回資料，因為 load data 最早在 MEM/WB 才可靠。

### Control Hazard

目前 baseline 是 always not taken。

Branch / JAL / JALR redirect 後 flush younger instructions。

之前 debug 過的問題：

- JAL pattern 一開始因 pattern 本身沒有放對 nop/flush window 造成誤判。
- Branch + JALR flush 相關 pattern 曾抓到真正 flush/redirect 問題。

## Debug Patterns

曾建立或使用不同 hazard pattern，目標是讓每一類 hazard 能單獨 debug：

- `hazEXMEMForward`
- `hazMEMWBForward`
- `hazStoreDataForward`
- `hazLoadUse`
- `hazLoadBranch`
- `hazBranchForward`
- `hazJALFlush`
- `hazJALRForward`
- `hazJALRNegImm`
- `hazCallReturn`
- `hazDCacheConflictFlush`
- `hazFibOnly`
- `hazBubbleOnly`
- `hazFibNoOutput`
- `hazAddiBneLoop`
- `hazAdjacentAddiBne`
- `hazBneBack28`
- `hazFibBodyLoop`
- `hazFibBodyLong`
- `hazFibBodyGap`
- `hazFibInitBodyNoGap`
- `hazBranchFlushJalr`
- `hazStoreBranchFlushJalr`

重要 debug 結論：

- `hasHazard` 全部輸出 0 時，不一定是所有 forwarding 都錯，也可能是 flush/branch redirect 讓後續 store 根本沒執行。
- `fib only wrong, bubble only correct` 時，問題較像 branch/loop/flush，而不是單純 load-use bubble。
- `hazBranchFlushJalr` 和 `hazStoreBranchFlushJalr` fail 後，幫助定位 branch flush + jalr redirect 問題。

## Branch Prediction Integration Considerations

### BTFNT

只需看 branch immediate sign bit：

```verilog
predict_taken = is_branch && inst[31];
```

RISC-V branch immediate 的 sign bit 直接是 `inst[31]`。若要真正減少 penalty，需要在 ID stage 早一點 redirect backward branch。

### Bimodal Predictor

若使用 8-entry 2-bit bimodal：

```verilog
reg [1:0] pred_table [0:7];
index = pc[4:2]; // example
```

需要記錄 predicted taken/index，並在 branch resolve 時更新 counter。

需要注意：

- branch flush 時不能更新錯誤路徑的 branch。
- update 要使用實際 resolve 的 branch PC。
- prediction redirect 和 existing branch flush logic 要一致。

## Current Recommendation

短期若要低風險：

```text
BTFNT
```

原因：

- 幾乎不增加 FF。
- 對 BrPred 明顯提升。
- 不需要 table update hazard。

若 BTFNT 已穩定，下一步再考慮：

```text
8-entry 2-bit bimodal
```

原因：

- 只有 16 個 FF。
- BrPred accuracy 很高。
