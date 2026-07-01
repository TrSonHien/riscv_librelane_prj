# RTL Forwarding Precompute Patch Plan

## Scope

This is a patch plan only. It does not change RTL or LibreLane configuration.

Baseline timing analysis for `RUN_2026-06-30_23-58-26` shows the dominant non-reset setup cone starts from execute/memory destination-register state and drives same-cycle forwarding and hazard control before reaching execute datapath and redirect logic. The target of this patch is to remove the current-cycle dependency:

```text
RD_M/RD_W or RD_E-derived controls
  -> ForwardA_E/ForwardB_E compare logic
  -> Execute operand mux select
  -> ALU / branch compare / JALR target / PC redirect / EX/MEM register
```

The preferred architectural fix is to precompute forwarding selects while the consumer instruction is still in Decode, then carry those selects in the ID/EX pipeline register alongside `RD1_E`, `RD2_E`, `RS1_E`, `RS2_E`, `RD_E`, and the execute controls.

## 1. Current Forwarding Signal Path

### Current module path

The current forwarding decision is made in `Hazard_Unit` by instantiating `Forwarding_Unit`:

```text
CPU
  Hazard_Unit
    Forwarding_Unit
      inputs: RegWriteM, RegWriteW_fwd, RD_M, RD_W, RS1_E, RS2_E
      outputs: ForwardA_E, ForwardB_E
  Execute_Cycle
    Mux_3_by_1 muxA/muxB select with ForwardA_E/ForwardB_E
```

Current priority in `Forwarding_Unit.v`:

```verilog
if (RegWriteM && (RD_M != 0) && (RD_M == RS1_E))
    ForwardA_E = 2'b10;
else if (RegWriteW_fwd && (RD_W != 0) && (RD_W == RS1_E))
    ForwardA_E = 2'b01;
```

The same logic is repeated for `RS2_E`.

### Why this hurts timing

When an instruction is already in Execute, the forwarding select is still computed combinationally from current MEM/WB destination registers. That puts the register-number compare and priority muxing in front of all execute consumers:

```text
RD_M/RD_W
  -> register equality compare
  -> priority select
  -> ForwardA_E/ForwardB_E
  -> 3:1 operand muxes in Execute_Cycle
  -> ALU result, branch decision, MDU inputs, JALR target, store data
```

The top timing paths in the new baseline are consistent with this structure. They start from `Execute.RD_E_r[1]` / `Execute.RD_E_r[2]`, which are the flopped `RD_M` bits, then enter forwarding/hazard-derived logic before ending at `ALU_ResultM_out`/memory-address bits, `Fetch.PCF`, or Decode pipeline controls.

## 2. Proposed New Signals

Add Decode-stage precompute signals and register them into Execute:

```verilog
wire [1:0] ForwardA_D;
wire [1:0] ForwardB_D;
wire [1:0] ForwardA_E;
wire [1:0] ForwardB_E;
```

Recommended encoding remains unchanged:

| Select | Meaning in Execute | Data source in `Execute_Cycle` |
|---|---|---|
| `2'b00` | no forward | `RD1_E` / `RD2_E` |
| `2'b01` | forward from WB | `ResultW` |
| `2'b10` | forward from MEM | `ALU_ResultM` |

The precompute unit should use Decode source registers and current producer stages:

```text
Forward from next-cycle MEM:
  compare RS1_D/RS2_D against current RD_E

Forward from next-cycle WB:
  compare RS1_D/RS2_D against current RD_M
```

Use current `RegWriteE` and `RegWriteM` as producer-valid qualifiers. Preserve `rd == x0` behavior by never selecting a forward path when the producer destination is zero.

For load-use safety, current `MemReadE` must mask the current-EX producer from the next-cycle MEM forward candidate:

```verilog
ex_forward_valid = RegWriteE && !MemReadE && (RD_E != 5'b00000);
mem_forward_valid = RegWriteM && (RD_M != 5'b00000);
```

`MemReadE` masking is defensive. The existing `Stall_Unit` should already catch a load-use dependency and inject a bubble, but the forwarding precompute should still avoid marking an unsafe load result as forwardable from MEM in the immediately following cycle.

## 3. Exact Module and Interface Changes

### `Forwarding_Unit.v`

Change the module from Execute-stage forwarding to Decode-stage precompute.

Current interface:

```verilog
input        RegWriteM;
input        RegWriteW_fwd;
input [4:0]  RD_M;
input [4:0]  RD_W;
input [4:0]  RS1_E;
input [4:0]  RS2_E;
output [1:0] ForwardA_E;
output [1:0] ForwardB_E;
```

Proposed interface:

```verilog
input        RegWriteE;
input        MemReadE;
input [4:0]  RD_E;
input        RegWriteM;
input [4:0]  RD_M;
input [4:0]  RS1_D;
input [4:0]  RS2_D;
output [1:0] ForwardA_D;
output [1:0] ForwardB_D;
```

Proposed priority:

```verilog
ForwardA_D = 2'b00;
ForwardB_D = 2'b00;

if (RegWriteE && !MemReadE && (RD_E != 5'b0) && (RD_E == RS1_D))
    ForwardA_D = 2'b10;       // current E will be MEM when consumer reaches E
else if (RegWriteM && (RD_M != 5'b0) && (RD_M == RS1_D))
    ForwardA_D = 2'b01;       // current M will be WB when consumer reaches E

if (RegWriteE && !MemReadE && (RD_E != 5'b0) && (RD_E == RS2_D))
    ForwardB_D = 2'b10;
else if (RegWriteM && (RD_M != 5'b0) && (RD_M == RS2_D))
    ForwardB_D = 2'b01;
```

This preserves newest-producer priority because current Execute is newer than current Memory for the consumer instruction currently in Decode.

### `Hazard_Unit.v`

Update forwarding-related ports.

Remove forwarding inputs no longer needed for select generation:

```verilog
input        RegWriteW_fwd;
input [4:0]  RD_W;
input [4:0]  RS1_E;
input [4:0]  RS2_E;
```

Add:

```verilog
input        RegWriteE;
```

Reuse existing:

```verilog
input        RegWriteM;
input [4:0]  RD_M;
input        MemReadE;
input [4:0]  RD_E;
input [4:0]  RS1_D;
input [4:0]  RS2_D;
```

Rename forwarding outputs to make the stage explicit:

```verilog
output [1:0] ForwardA_D;
output [1:0] ForwardB_D;
```

The stall/flush logic in `Hazard_Unit` should remain functionally unchanged:

```verilog
StallF = StallF_lw | axi_stall | mdu_stall;
StallD = StallD_lw | axi_stall | mdu_stall;
StallE = axi_stall | mdu_stall;
StallM = axi_stall | mdu_stall;
HoldE  = axi_stall | mdu_stall;
FlushD = PCSrcE & ~(axi_stall | mdu_stall);
FlushE = FlushE_stall;
```

### `Decode_Cycle.v`

Add forwarding precompute inputs:

```verilog
input [1:0] ForwardA_D;
input [1:0] ForwardB_D;
input       FlushE;
```

Add registered outputs to Execute:

```verilog
output [1:0] ForwardA_E;
output [1:0] ForwardB_E;
```

Add ID/EX pipeline registers:

```verilog
reg [1:0] ForwardA_D_r;
reg [1:0] ForwardB_D_r;
```

Register behavior should match the instruction already in the ID/EX register:

| Condition | Existing control behavior | Forwarding register behavior |
|---|---|---|
| reset | clear ID/EX | clear to `2'b00` |
| `FlushD` | inject bubble | clear to `2'b00` |
| `HoldE` | hold ID/EX | hold current `ForwardA_D_r/ForwardB_D_r` |
| `FlushE` / load-use bubble | inject bubble into Execute | clear to `2'b00` |
| normal advance | latch Decode instruction | latch `ForwardA_D/ForwardB_D` |

Keep `HoldE` before `FlushE`/`StallD` in the priority order to preserve the current AXI/MDU stall behavior, where ID/EX is held while MEM or MDU is not ready.

Recommended assignment pattern:

```verilog
if (!reset) begin
    ForwardA_D_r <= 2'b00;
    ForwardB_D_r <= 2'b00;
end else if (FlushD) begin
    ForwardA_D_r <= 2'b00;
    ForwardB_D_r <= 2'b00;
end else if (HoldE) begin
    // hold all ID/EX state, including forwarding selects
end else if (FlushE || StallD) begin
    ForwardA_D_r <= 2'b00;
    ForwardB_D_r <= 2'b00;
end else begin
    ForwardA_D_r <= ForwardA_D;
    ForwardB_D_r <= ForwardB_D;
end
```

Then:

```verilog
assign ForwardA_E = ForwardA_D_r;
assign ForwardB_E = ForwardB_D_r;
```

### `Execute_Cycle.v`

Keep the interface unchanged if `ForwardA_E` and `ForwardB_E` names are preserved at the CPU level.

No execute datapath change is required:

```verilog
Mux_3_by_1 muxA (... .s(ForwardA_E), ...);
Mux_3_by_1 muxB (... .s(ForwardB_E), ...);
```

This is intentional. The muxes, ALU, branch unit, MDU, and JALR target calculation should continue to see the same select encoding, only from flops instead of a same-cycle compare cone.

### `CPU.v`

Add or reinterpret forwarding wires:

```verilog
wire [1:0] ForwardA_D;
wire [1:0] ForwardB_D;
wire [1:0] ForwardA_E;
wire [1:0] ForwardB_E;
```

Connect `Hazard_Unit` precompute outputs to `Decode_Cycle`:

```verilog
Hazard_Unit Hazard (
    .RegWriteE  (RegWriteE),
    .MemReadE   (MemReadE),
    .RD_E       (RD_E),
    .RegWriteM  (RegWriteM),
    .RD_M       (RD_M),
    .RS1_D      (RS1_D),
    .RS2_D      (RS2_D),
    .ForwardA_D (ForwardA_D),
    .ForwardB_D (ForwardB_D),
    ...
);

Decode_Cycle Decode (
    .ForwardA_D (ForwardA_D),
    .ForwardB_D (ForwardB_D),
    .FlushE     (FlushE),
    .ForwardA_E (ForwardA_E),
    .ForwardB_E (ForwardB_E),
    ...
);
```

Keep `Execute_Cycle` connected to the registered Execute-stage selects:

```verilog
Execute_Cycle Execute (
    .ForwardA_E (ForwardA_E),
    .ForwardB_E (ForwardB_E),
    ...
);
```

Remove `RegWriteW_fwd`, `RD_W`, `RS1_E`, and `RS2_E` from the `Hazard_Unit` forwarding interface if they are no longer used there. `RD_W` and `RegWriteW_fwd` still remain in the CPU for Memory/Writeback behavior.

### `Stall_Unit.v`

No functional change is required. It already detects the load-use case in Decode:

```verilog
lw_stall = MemReadE &&
           ((RD_E == RS1_D) || (RD_E == RS2_D)) &&
           (RD_E != 0);
```

The patch should rely on this behavior, while also masking `MemReadE` in forwarding precompute.

## 4. Stage-by-Stage Timing Alignment Table

Assume instruction `P` produces `rd`, and instruction `C` consumes it.

### ALU producer immediately followed by consumer

| Cycle | Producer stage | Consumer stage | Precompute action | Execute select when consumed |
|---|---|---|---|---|
| N | `P` in E | `C` in D | `RS*_D == RD_E`, `RegWriteE=1`, `MemReadE=0` -> select `2'b10` | not used yet |
| N+1 | `P` in M | `C` in E | registered select is active | forward from `ALU_ResultM` |

### Producer two cycles ahead

| Cycle | Producer stage | Consumer stage | Precompute action | Execute select when consumed |
|---|---|---|---|---|
| N | `P` in M | `C` in D | `RS*_D == RD_M`, `RegWriteM=1` -> select `2'b01` | not used yet |
| N+1 | `P` in W | `C` in E | registered select is active | forward from `ResultW` |

### Two matching producers

| Cycle | Older producer | Newer producer | Consumer stage | Required select |
|---|---|---|---|---|
| N | matching `RD_M` | matching `RD_E` | `C` in D | `2'b10` from current E, because it is newer |
| N+1 | older in W | newer in M | `C` in E | forward from `ALU_ResultM` |

### Load-use dependency

| Cycle | Load stage | Consumer stage | Required behavior |
|---|---|---|---|
| N | load in E | consumer in D | `Stall_Unit` asserts `StallF`, `StallD`, `FlushE`; forwarding precompute must not latch `2'b10` for the load |
| N+1 | load in M | bubble in E, consumer still in D | recompute against current `RD_M`; select `2'b01` for next-cycle WB if `RegWriteM` is true |
| N+2 | load in W | consumer in E | registered select `2'b01` forwards `ResultW` |

### AXI or MDU hold

| Cycle | Condition | Required behavior |
|---|---|---|
| N | `axi_stall` or `MDU_Busy` asserts `HoldE` | ID/EX instruction and registered forwarding selects hold together |
| N+k | hold releases | same instruction resumes Execute with the same forwarding selects |

## 5. Load-Use Handling

The existing load-use stall must remain the correctness mechanism:

```text
load in E + dependent instruction in D
  -> StallF = 1
  -> StallD = 1
  -> FlushE = 1
  -> dependent instruction does not enter Execute yet
```

The new forwarding precompute must add two protections:

1. Do not generate forward-from-M for current `RD_E` when `MemReadE=1`.
2. Clear registered forwarding selects when a load-use bubble enters Execute.

This avoids an unsafe assumption that the load data is available on `ALU_ResultM`. The load result should be consumed through the existing WB path as `ResultW` after the one-cycle bubble.

The patch should not relax or remove the `Stall_Unit` condition. It should also not convert load-use into a forward-from-M case unless the Memory stage is redesigned to provide load data early enough to the Execute input mux, which is outside the requested minimal patch.

## 6. Flush and Stall Handling

### `FlushD`

`FlushD` currently clears the Decode-to-Execute register on a taken branch/jump when there is no AXI/MDU hold. Forwarding registers must clear with the rest of ID/EX:

```text
FlushD -> ForwardA_E = 00, ForwardB_E = 00
```

This prevents a killed instruction from carrying stale forwarding selects into Execute.

### `FlushE`

`FlushE` currently comes from the load-use stall path. The new forwarding registers must also become no-forward/default when `FlushE` injects a bubble:

```text
FlushE -> ForwardA_E = 00, ForwardB_E = 00
```

Because current `Decode_Cycle` does not take `FlushE` directly, the patch should add `FlushE` as a `Decode_Cycle` input or explicitly use the existing `StallD` bubble branch to clear the forwarding registers. Adding `FlushE` is clearer and matches the stage intent.

### `StallD`

Current `StallD` is used for load-use and AXI/MDU stalls:

```text
StallD = StallD_lw | axi_stall | mdu_stall
```

The existing priority in `Decode_Cycle` is:

```text
reset -> FlushD -> HoldE -> StallD -> normal advance
```

Keep that priority. It distinguishes these two cases:

| Case | Current behavior | Forwarding-select behavior |
|---|---|---|
| `StallD_lw` only | inject bubble into ID/EX | clear selects to `00` |
| `axi_stall` or `mdu_stall` | `HoldE=1`, hold ID/EX | hold selects with the instruction |

This preserves alignment between the instruction and the select bits.

### `HoldE`

When `HoldE` is asserted, the entire ID/EX state must stay stable. That includes:

```text
control regs
RD1/RD2
RS1/RS2/RD
PC/PCPlus4
ForwardA_E/ForwardB_E
```

Do not recompute or overwrite forwarding selects while ID/EX is held.

## 7. Minimal Test Cases Required Before PnR

The repo has a cocotb/Icarus simulation path through `make sim`, with the testbench at `cocotb/chip_top_tb.py`. Before running PnR, add or run directed RTL tests that exercise the forwarding alignment. These should be run at RTL first, not through LibreLane.

Minimum directed instruction sequences:

1. EX-to-EX ALU forwarding on `rs1`
   - Example: `add x5, x1, x2`; next instruction consumes `x5` as `rs1`.
   - Expected: Decode precompute selects `2'b10`; Execute forwards from MEM.

2. EX-to-EX ALU forwarding on `rs2`
   - Same as above, but consumer uses producer as `rs2`.
   - Expected: `ForwardB_E == 2'b10`.

3. WB forwarding after one independent instruction
   - Producer, one unrelated instruction, then consumer.
   - Expected: Decode precompute selects `2'b01`; Execute forwards from `ResultW`.

4. Newest producer priority
   - Two consecutive writes to the same `rd`, followed by a consumer.
   - Expected: consumer gets the newer current-EX producer via `2'b10`, not the older current-M producer via `2'b01`.

5. `x0` no-forward behavior
   - Instruction writes `x0`, next instruction reads `x0`.
   - Expected: forwarding select remains `2'b00`; architectural zero is preserved.

6. Load-use stall
   - `lw x5, 0(x1)` followed immediately by consumer of `x5`.
   - Expected: one bubble, no forward-from-M selected while load is in E, then consumer forwards from WB or reads the correct value.

7. Store-data forwarding
   - ALU producer followed by `sw` using produced value as store data.
   - Expected: `ForwardB_E` aligns with store data and `WriteDataM` captures the forwarded value.

8. Branch compare forwarding
   - ALU producer followed by `beq`/`bne` consuming the result.
   - Expected: branch decision uses forwarded operands.

9. JALR base-register forwarding
   - ALU producer computes base register, immediately followed by `jalr`.
   - Expected: JALR target uses forwarded `SrcA`.

10. AXI/MDU hold alignment
    - Create a sequence where `HoldE` is asserted while an instruction with nonzero forwarding selects is in Execute.
    - Expected: forwarding selects remain stable for the held instruction and do not update from the instruction currently visible in Decode.

Recommended waveform/assertion signals:

```text
Decode.ForwardA_D / Decode.ForwardB_D or Hazard.ForwardA_D / Hazard.ForwardB_D
Decode.ForwardA_E / Decode.ForwardB_E
Execute.ForwardA_out / Execute.ForwardB_out
RS1_D, RS2_D, RD_E, RD_M
RegWriteE, MemReadE, RegWriteM
StallD, FlushE, HoldE, FlushD
PCSrcE, PCTargetE
```

Also run the existing smoke test after directed tests, because it is the current project-level simulation path.

## 8. Risk Assessment

| Risk | Severity | Why it matters | Mitigation |
|---|---:|---|---|
| Stage off-by-one in forwarding selects | High | A select computed from the wrong producer stage silently corrupts ALU, branch, store, or JALR operands | Use the stage table above as the implementation checklist; inspect waveforms for all directed tests |
| Load-use becomes unsafe | High | A load result is not available through `ALU_ResultM`; forwarding it as MEM data would use the address or stale data | Keep `Stall_Unit` unchanged, mask `MemReadE` from `2'b10`, and clear selects on `FlushE`/load-use bubble |
| `HoldE` misalignment | High | AXI/MDU stalls can hold Execute while Decode still exposes another instruction; recomputed selects would attach to the wrong instruction | Hold forwarding registers in the same `HoldE` branch as other ID/EX registers |
| Flush carries stale selects | Medium | A killed instruction could still affect execute operand selection if selects are not cleared | Clear forwarding regs on reset, `FlushD`, and `FlushE`/bubble |
| JAL/JALR/link forwarding semantics remain limited by existing data muxes | Medium | Current MEM forwarding path forwards `ALU_ResultM`, while some writeback sources may be `PCPlus4` or load data | The patch preserves existing behavior; add directed tests for JALR base forwarding and any link-register dependency before broader cleanup |
| Interface churn creates synthesis/elaboration errors | Medium | `CPU`, `Hazard_Unit`, `Decode_Cycle`, and `Forwarding_Unit` all change ports together | Patch these files in one atomic RTL edit and run RTL elaboration/simulation before PnR |
| Timing improvement smaller than expected | Medium | The compare cone moves earlier, but Decode may become more complex | The critical execute path should lose the same-cycle register compare and priority logic; confirm later with OpenROAD timing only after RTL tests pass |

## Expected Timing Effect

The intended post-patch Execute path becomes:

```text
registered ForwardA_E/ForwardB_E
  -> Execute operand mux
  -> ALU / branch compare / JALR target / PC redirect
```

The removed current-cycle timing arc is:

```text
RD_M/RD_W compare
  -> forwarding priority logic
  -> ForwardA_E/ForwardB_E
  -> Execute operand mux
```

This is the smallest RTL change that directly cuts the dominant architectural bottleneck without changing pipeline depth, memory protocol, MDU implementation, floorplan, or LibreLane configuration.
