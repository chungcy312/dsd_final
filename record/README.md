# DSD Final Research Record

這個資料夾整理目前做過的設計、實驗和 debug 紀錄，方便之後寫 final presentation 或 report。

## Files

- `cache_optimization.md`
  - cache sweep 結果、1-way/2-way 觀察、目前 RTL cache 修改方向。
- `branch_prediction.md`
  - branch prediction 方法比較，包含 always not taken、BTFNT、global counter、bimodal、gshare。
- `synthesis_and_gate_timing.md`
  - synthesis constraint、gate simulation timing violation、reset/input delay、critical path 觀察。
- `pipeline_and_hazard.md`
  - pipeline stage、hazard/debug pattern、之前遇到的 hazard 問題和處理方向。
- `future_test_plan.md`
  - 後續 cache block/way 與 branch prediction 實驗計畫。

## Current Baseline Notes

- Core 已改成 pipeline CPU。
- Cache 使用 write-back D-cache，支援 dirty bit 與 flush FSM。
- I-cache 是 read-only cache。
- Synthesis / gate simulation 目前曾以 3 ns 作為 checkpoint 基準。
- 後續主要優化方向：
  - cache area/timing/hit-rate tradeoff
  - branch prediction
  - critical path 與 gate-level setup margin
