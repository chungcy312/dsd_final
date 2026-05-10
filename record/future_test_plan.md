# Future Test Plan

This file records experiments to run later for cache, branch prediction, and
MUL support.  It is written in ASCII so it can be safely opened by different
editors and terminals.

## 1. Cache Experiments

Goal:

- Compare miss rate, total simulation time, synthesis area, and timing.
- Keep the normal final patterns in the loop: QSort, Conv, LFSR_HIST.

Parameters:

```text
I-cache blocks: 16, 32
D-cache blocks: 16, 32, 64
ways: 1, 2
```

Do not prioritize ways >= 4 for now.  Previous sweep results showed little
benefit, and higher associativity increases tag compare and way mux cost.

Suggested cache cases:

| Case | I-cache | D-cache | Purpose |
| --- | --- | --- | --- |
| C0 | 1-way, 16 blocks | 1-way, 16 blocks | fair small baseline |
| C1 | 1-way, 32 blocks | 1-way, 16 blocks | larger I-cache only |
| C2 | 1-way, 16 blocks | 1-way, 32 blocks | larger D-cache only |
| C3 | 1-way, 32 blocks | 1-way, 32 blocks | balanced small/mid cache |
| C4 | 1-way, 32 blocks | 1-way, 64 blocks | higher D hit-rate candidate |
| C5 | 1-way, 32 blocks | 2-way, 32 blocks | D-cache associativity test |
| C6 | 1-way, 32 blocks | 2-way, 64 blocks | high D-cache hit-rate candidate |

Patterns to run:

```text
noHazard
hasHazard
BrPred
QSort
Conv
LFSR_HIST
```

Suggested CSV columns:

```text
cache_case,ic_way,ic_blocks,dc_way,dc_blocks,pattern,cycle_ns,sim_time_ns,total_cell_area,wns,pass
```

## 2. Branch Prediction Experiments

Goal:

- Compare baseline always-not-taken with BTFNT.
- Keep hardware cost very small before trying predictor tables.

Cases:

| Case | Predictor | Description |
| --- | --- | --- |
| B0 | always not taken | original baseline |
| B1 | BTFNT | ID-stage backward branch redirect |

BTFNT rule:

```verilog
predict_taken = is_branch && inst[31];
```

For normal 32-bit B-type branches, `inst[31]` is the branch immediate sign bit.
For compressed branches, the decompressor produces a 32-bit equivalent branch,
so the same ID-stage rule can still use `ifid_inst[31]`.

Patterns to run:

```text
noHazard
hasHazard
BrPred
QSort
Conv
LFSR_HIST
```

Suggested CSV columns:

```text
predictor,pattern,cycle_ns,sim_time_ns,total_cell_area,critical_path,pass
```

## 3. Compressed Instruction Experiments

Goal:

- Verify RV32C correctness without hurting normal 32-bit aligned fast path.

Patterns to run:

```text
compression
compression_uncompressed
noHazard
hasHazard
QSort
Conv
LFSR_HIST
```

Things to check:

- 16-bit instruction at lower halfword.
- 16-bit instruction at upper halfword.
- 32-bit instruction crossing a 32-bit word boundary.
- 32-bit instruction crossing a 128-bit cache block boundary.
- `c.jal` / `c.jalr` link address must be `pc + 2`.

## 4. MUL Multicycle Experiments

Current plan:

```text
mul_a_reg / mul_b_reg -> multiplier -> mul_result_reg
```

The multiplier block latches EX-stage forwarded operands:

```verilog
mul_a_reg <= fwd_rs1;
mul_b_reg <= fwd_rs2;
```

This preserves RAW hazard behavior because the original forwarding muxes are
still used before the MUL operands are captured.

Tunable parameter:

```text
MUL_CYCLES = 2, 3, 4
```

When changing this value, update both:

```text
01_RTL/CHIP.v       parameter MUL_CYCLES
02_SYN/CHIP_syn.sdc set mul_cycles
```

Patterns to run:

```text
Mul
Conv
noHazard
hasHazard
QSort
LFSR_HIST
```

Expected behavior:

- MUL instruction stays in EX while `mul_stall` is high.
- IF/ID/IDEX are held.
- EX/MEM and MEM/WB are allowed to drain so previous memory operations are not
  repeated.
- When `mul_result_reg` is ready, the MUL instruction advances to EX/MEM like
  a normal ALU instruction.

Future area optimization to try:

```text
Share ALU operand/input registers with the multiplier.
```

Notes:

- Functionally, ALU inputs are already hazard-resolved by forwarding, so sharing
  can work.
- Timing-wise, sharing ALU input/output registers makes SDC multicycle
  constraints harder.  A broad register-to-register multicycle constraint could
  accidentally relax normal ALU paths.
- A safer future compromise is to share the forwarded operand muxes but keep an
  independent `mul_result_reg`.

## 5. Combined Final Experiments

After each feature is verified independently, run combined cases:

| Case | Cache | Predictor | MUL |
| --- | --- | --- | --- |
| F0 | best small-area cache | always not taken | disabled |
| F1 | best small-area cache | BTFNT | disabled |
| F2 | best performance cache | BTFNT | disabled |
| F3 | best performance cache | BTFNT | multicycle MUL |

Decision criteria:

```text
score impact = area impact + simulation time impact + timing feasibility
```

Keep changes isolated when debugging.  Do not tune cache, prediction, and MUL
at the same time unless each feature already passes its own regression.
