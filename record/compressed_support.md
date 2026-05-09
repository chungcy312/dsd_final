# Compressed Instruction Support Record

## Goal

支援 RV32C compressed instruction，但盡量不影響 QSort / Conv / LFSR_HIST 這三個主要 final patterns 的 normal 32-bit aligned fast path。

## Key Rule

RISC-V instruction length 由 low 2 bits 判斷：

```verilog
is_32bit = (halfword[1:0] == 2'b11);
is_16bit = (halfword[1:0] != 2'b11);
```

## IF Aligner

目前 IF stage 加入 instruction aligner：

```text
S_FETCH0:
  fetch word at PC
  if current halfword is compressed:
      decompress to 32-bit equivalent instruction
      pc_inc = 2
  else if pc[1] == 0:
      normal 32-bit aligned instruction
      pc_inc = 4
  else:
      32-bit instruction starts at upper halfword
      save upper halfword and go S_FETCH1

S_FETCH1:
  fetch next word
  inst = {next_word[15:0], saved_upper_half}
  pc_inc = 4
```

這樣可處理：

- 16-bit instruction at lower halfword
- 16-bit instruction at upper halfword
- 32-bit instruction aligned at lower halfword
- 32-bit instruction crossing two 32-bit words
- 32-bit instruction crossing 128-bit cache block

跨 block 不需要特殊處理，因為 `S_FETCH1` 會向 I-cache 發出下一個 word address；如果 next word 在下一個 cache block，I-cache miss FSM 會處理。

## Fast Path

對主要 non-compressed patterns：

```text
pc[1] == 0 && fetched_word[1:0] == 2'b11
```

這是 normal 32-bit aligned instruction，仍可直接 1 cycle output。

因此 QSort / Conv / LFSR_HIST 理論上不會因為 instruction length 而多 cycle。實際仍需 synthesis 看 IF mux/decompressor 是否影響 critical path。

## Decompressor

新增 `compressed_decoder` module：

```text
16-bit compressed instruction
  -> 32-bit equivalent RISC-V instruction
```

目前支援 pattern 註解列出的指令：

- `c.nop`
- `c.add`
- `c.mv`
- `c.addi`
- `c.andi`
- `c.slli`
- `c.srli`
- `c.srai`
- `c.sw`
- `c.lw`
- `c.beqz`
- `c.bnez`
- `c.j`
- `c.jal`
- `c.jr`
- `c.jalr`

後面的 ID/EX/MEM/WB 基本上仍然只看 32-bit instruction。

## PC Increment

compressed instruction 的 link address 不一定是 `pc + 4`。

因此 pipeline 新增：

```verilog
if_pc_inc
ifid_pc_inc
idex_pc_inc
```

EX stage 的 link address 改成：

```verilog
link_pc = pc + pc_inc;
```

所以：

```text
normal jal/jalr -> pc + 4
c.jal/c.jalr   -> pc + 2
```

## Branch Prediction

BTFNT 對 compressed branch 也能使用 sign bit。

若看原始 compressed instruction：

```text
c.beqz / c.bnez sign bit = cinst[12]
c.j / c.jal     sign bit = cinst[12]
```

目前 IF 先 decompress 成 32-bit instruction，因此 ID stage 的 BTFNT 可以繼續看：

```verilog
ifid_inst[31]
```

因為 decompressed branch/jump immediate 已經 sign-extended 到 32-bit instruction format。

## Risks / Things to Verify

必跑 patterns：

- `compression`
- `compression_uncompressed`
- `noHazard`
- `hasHazard`
- `QSort`
- `Conv`
- `LFSR_HIST`

需要特別檢查：

- 16-bit instruction at upper halfword
- 32-bit instruction crossing word boundary
- 32-bit instruction crossing cache block boundary
- `c.jal` / `c.jalr` link address 是否為 `pc+2`
- branch/JAL/JALR flush 是否仍正確
- BTFNT 是否沒有對 compressed branch 造成錯誤 redirect
