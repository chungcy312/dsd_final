# Synthesis and Gate Timing Record

## Constraint Organization

已將 timing/design constraints 集中到：

```text
02_SYN/CHIP_syn.sdc
```

`02_SYN/CHIP_syn.tcl` 現在只負責：

- read RTL
- elaborate/link/uniquify
- `read_sdc ./CHIP_syn.sdc`
- compile / optimize
- write netlist/report/sdf/sdc

這樣之後修改 clock/input/output delay，只需要改 SDC。

## Current SDC Concepts

主要設定：

```tcl
set cycle 3
create_clock -name CLK -period $cycle [get_ports clk]
set_clock_uncertainty 0.15 [get_clocks CLK]
set_clock_latency 0.5 [get_clocks CLK]
```

memory interface:

```tcl
set mem_input_delay  [expr $cycle * 0.5]
set mem_output_delay [expr $cycle * 0.5]
```

reset:

```tcl
set reset_input_delay [expr $cycle * 0.6]
```

reason:

- slow memory 在 negedge 附近和 CHIP 溝通，所以 memory I/O 是 half-cycle interface。
- reset 在 testbench 中和 memory input phase 不同，需要獨立 input delay。

## Gate Simulation Timing Violation Types

### RN / Reset Pin Violation

之前看過類似：

```text
$setup(posedge RN, posedge CK, limit: ...)
```

這代表 standard cell reset pin timing 不滿足。

解法：

- 使用 synchronous reset。
- 在 SDC 中對 `rst_n` 設定正確 input delay。
- cache data array 不 reset，只 reset valid/dirty/control。

### D Pin Violation

後來看過：

```text
Timing violation in core0_exmem_store_data_reg_29_
$setup(negedge D:5921, posedge CK:6000, limit:89)
```

這代表一般 data path 太晚到 FF D input。

若 D 在 5921ps 到，CK 在 6000ps，setup 需要 89ps：

```text
6000 - 5921 = 79ps < 89ps
```

只差約 10ps。這類問題通常是 synthesis 剛好壓在 0 slack，gate simulation 的 setup/rounding 讓它爆。

處理方式：

- 將 clock uncertainty 從 0.10ns 增加到 0.15ns，讓 DC 留更多 setup margin。
- 若仍爆，考慮拿掉 payload data register reset，只 reset valid/control。

## Payload Register Reset Discussion

像這些 data payload register：

- `exmem_store_data`
- `exmem_result`
- `memwb_wb_data`
- `idex_rdata1/rdata2`
- `ifid_pc/inst`

若都有 valid/control bit 保護，不一定需要 reset。

保留 reset 的必要項目：

- pipeline valid bit
- control signal
- FSM state
- done/flush control

移除 payload reset 的好處：

- 減少 reset mux。
- 縮短 D path。
- 降低 reset/input delay 造成的 timing pressure。

風險：

- simulation 可能出現 X。
- 必須確認 payload 只在 valid/control 有效時被使用。

## Critical Path Observations

曾看過 critical path 與 cache 相關，特別是：

- I-cache data array refill/reset related path
- D-cache hit data path
- reset path through cache array/control

Cache hit path 重要結構：

```text
addr
  -> index/tag/word decode
  -> tag compare
  -> word select
  -> way mux
  -> ready/rdata
```

優化方向：

- 1-way cache 移除 way mux/compare。
- 2-way cache 寫死 way0/way1，不使用泛用 for-loop。
- hit data path 做成每個 way 先 `select_word`，最後只做 32-bit mux。
- cache data array 不 reset。

## Synthesis Area Notes

Checkpoint area report 曾使用：

```text
Combinational area:             221357.932724
Buf/Inv area:                    34873.083013
Noncombinational area:          178868.619936
Macro/Black Box area:                0.000000
Net Interconnect area:         3749825.752380

Total cell area:                400226.552660
Total area:                    4150052.305040
```

注意：

- QoR report 中的 `Critical Path Length: 0.92 ns` 不適合直接放到 slide，因為它可能不包含 input delay / full timing context。
- 應以 `timing_max` / `critical_path` 的 full path 為準。
