# RISC-V GF180 LibreLane / wafer.space Savepoint for AGY Resume

**Workspace:** `~/Projects/riscv_librelane`  
**Purpose:** Save the current project status so AGY can resume tomorrow without re-discovering context.  
**Flow:** wafer.space GF180MCU template + LibreLane  
**Current focus:** ASIC_BASE version of the RISC-V SoC; temporarily ignore VGA/full SoC extras.  
**Note from user:** After AGY hit usage limit, the user manually re-floorplanned the SRAM macros more cleanly. **AGY must re-read the current `librelane/macros/macros_5v.yaml` before making any placement/routing conclusion.**

---

## 1. Project Context

The project started from the wafer.space `gf180mcu-project-template` and was rebuilt more carefully in:

```bash
~/Projects/riscv_librelane
```

Important project components:

```text
~/Projects/riscv_librelane/
├── Makefile
├── README.md
├── shell.nix / flake.nix / flake.lock
├── gf180mcu/
├── librelane/
│   ├── config.yaml
│   ├── chip_top.sdc
│   ├── macros/
│   │   ├── macros_5v.yaml
│   │   └── macros_3v3.yaml
│   ├── pdn/
│   │   ├── pdn_cfg.tcl
│   │   ├── pdn_5v_sram.tcl
│   │   └── pdn_3v3_sram.tcl
│   ├── slots/
│   │   ├── slot_0p5x1.yaml
│   │   ├── slot_1x1.yaml
│   │   └── ...
│   └── runs/
├── src/
│   ├── chip_top.sv
│   ├── chip_core.sv
│   ├── Core/CORE.v
│   ├── IP_CORE/
│   ├── Bus/
│   ├── Peripherals/
│   └── ASIC/gf180_sram_1024x32.v
└── firmware.hex
```

The current active PDK/library direction:

```text
PDK: gf180mcuD
SCL: gf180mcu_fd_sc_mcu7t5v0
SRAM: gf180mcu_fd_ip_sram
SRAM macro: gf180mcu_fd_ip_sram__sram512x8m8wm1
```

SRAM views are expected under:

```bash
gf180mcu/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/
```

Do **not** use raw third-party SRAM LEF/GDS/LIB unless explicitly checked for GF180/OpenROAD compatibility.

---

## 2. Top-Level Architecture

The intended wafer.space-compatible hierarchy is:

```text
chip_top
└── chip_core
    └── CORE
```

`chip_top.sv` must remain the wafer.space wrapper/pad-level top.  
`CORE` is the RISC-V SoC logic, not the final tapeout top.

---

## 3. Initial README / Template Findings

AGY read the wafer.space template README, especially the "Implementing Your Own Design" section.

Key template constraints found:

- `chip_top.sv` defines pad-level connectivity.
- `chip_core.sv` is where user logic should be instantiated.
- Slot pad count is limited; the full FPGA-style RISC-V SoC has too many external pins if all VGA/HEX/LED/GPIO signals are exposed.
- The current configured slot during early work was `SLOT=0p5x1`, which has fewer physical signal pads than the original FPGA design expected.
- Even `SLOT=1x1` has finite pad count and cannot expose the entire FPGA-style interface without reduction/muxing.

Original `CORE` port demand was much larger than the default pad budget because of:

- `SW[9:0]`
- `LEDR[9:0]`
- `HEX0`–`HEX5`
- UART
- GPIO
- VGA HS/VS/R/G/B

Decision: **do not expose the full FPGA interface for ASIC_BASE.**

---

## 4. ASIC Compatibility Audit Findings

AGY audited the RTL under `src/` and found multiple FPGA-specific issues.

### 4.1 SRAM Macro Availability

The PDK SRAM simulation models are present. The 5V macro is:

```text
gf180mcu_fd_ip_sram__sram512x8m8wm1
```

SRAM port meanings:

```text
CLK  : clock
CEN  : chip enable, active-low
GWEN : global write enable, active-low
WEN  : bit write mask, active-low
A    : address
D    : write data
Q    : read data
```

AGY reported that existing SRAM pin connections in `Data_RAM.v`, `Instr_Memory.v`, and `Font_ROM.v` were structurally plausible, including:

```verilog
WEN = 8'b0
```

Since `WEN` is active-low bit write mask, this enables all 8 bits when `GWEN` allows a write.

### 4.2 FPGA-Only / ASIC-Problematic Blocks

These issues were identified:

#### VGA PLL

`VGA_CORE.v` instantiates an FPGA/Altera `pll` module. This is not synthesizable in ASIC flow and has no GF180 hard macro equivalent in the current project.

#### Font ROM

On FPGA, font memory can be initialized by BRAM preload / `$readmemh`. On ASIC SRAM, contents are random at power-up. Since Font ROM has no CPU write path, VGA text would show garbage if implemented as SRAM.

#### Instruction Memory Program Loading

`Instr_Memory.v` was converted toward SRAM macro use, but ASIC SRAM powers up random. `$readmemh("firmware.hex", ...)` does not program real silicon SRAM. Boot/programming architecture must be solved later.

AGY found `boot_mode` was hardwired to `1'b0` in relevant instruction memory paths, effectively disabling the bootloader write mechanism.

#### Duplicate Instruction Memory

`Instr_Memory` appeared in both CPU fetch path and `AXI_ROM_Slave`, creating duplicate instruction memory and extra SRAM macros if both are active.

#### VGA RAM

`VGA_RAM.v` uses:

```verilog
reg [15:0] mem [0:2399]
```

That is 38.4 kbits. Without dual-port SRAM macro, this can synthesize into a large amount of standard-cell storage, which is not appropriate for ASIC_BASE.

---

## 5. ASIC_BASE Design Decision

The following decisions were made for ASIC_BASE:

### Remove / Disable

- VGA
- `VGA_CORE`
- `VGA_Control`
- `VGA_RAM`
- `Font_ROM`
- FPGA `pll`
- VGA pins and VGA timing constraints
- Duplicate `AXI_ROM_Slave` instruction memory, unless proven necessary

### Keep

- CPU RV32IM
- one instruction source for CPU fetch
- one `Data_RAM`
- AXI/APB path needed for active peripherals
- UART
- GPIO
- simple 7-seg/debug output if useful and pad budget allows
- 5V SRAM only for now

### SRAM Variant

For now, keep SRAM hardcoded to the 5V variant:

```text
gf180mcu_fd_ip_sram__sram512x8m8wm1
```

Do **not** generalize for both 3.3V/5V until ASIC_BASE is stable.

---

## 6. RTL / Wrapper Changes AGY Made

AGY made these structural edits:

### 6.1 `chip_core.sv`

Updated to instantiate the pipelined RISC-V `CORE` module and connect a reduced subset of signals to the wafer.space pad interface.

The exact current pin mapping must be re-read from the actual file:

```bash
sed -n '1,220p' src/chip_core.sv
```

### 6.2 `AXI_VGA_Slave.v`

Simplified into a dummy responder:

- accepts AXI transactions
- returns zeros / `SLVERR`
- decouples VGA logic from synthesis
- removes dependence on `VGA_CORE`, `VGA_Control`, `VGA_RAM`, `Font_ROM`, and PLL

### 6.3 `AXI_ROM_Slave.v`

Simplified into a dummy responder:

- returns RISC-V NOP `32'h00000013` on reads to avoid bus hangs
- returns `SLVERR` on writes
- removes duplicate `Instr_Memory` instance

### 6.4 `Instr_Memory.v`

Added a `USE_SRAM` parameter. Current short-term mode uses logic/ROM behavior for instruction memory rather than physical SRAM, so the number of SRAM macros for ASIC_BASE is reduced.

Important current assumption:

```text
Short-term instruction memory = hardcoded/logic ROM path
Physical SRAM macros currently mainly for Data_RAM
```

This must be verified from the current source before tapeout.

### 6.5 `Data_RAM.v`

AGY added `(* keep *)` attributes to SRAM macro instantiations so Yosys does not optimize away the physical SRAM macro instances and so their hierarchical instance names survive macro checks.

---

## 7. Config / Source List Changes

AGY updated:

```text
librelane/config.yaml
```

Expected active top/config:

```yaml
DESIGN_NAME: chip_top
CLOCK_PORT: clk_PAD
CLOCK_NET: clk_pad/Y
VERILOG_DEFINES:
  - ASIC_BASE
  - ASIC_GF180
```

At different points, clock target was discussed as both:

```text
20 ns / 50 MHz
40 ns / 25 MHz
```

AGY later referenced 25 MHz / 40 ns while debugging resizer behavior. **Before continuing, verify the actual current `CLOCK_PERIOD` in `librelane/config.yaml` and `chip_top.sdc`. Do not assume.**

Command:

```bash
grep -n "CLOCK_PERIOD\|create_clock" librelane/config.yaml librelane/chip_top.sdc
```

The config was also updated to include the necessary RISC-V RTL source files, and a missing `Forwarding_Unit.v` was added after a missing-module error.

---

## 8. Build Errors and Fixes

### 8.1 Keyword / Syntax Issue

Instances named `interconnect` in `AXI_TOP.v` and `APB4_TOP.v` caused syntax/tool compatibility issues. AGY renamed those instances to:

```text
u_interconnect
```

### 8.2 Missing Module

`Forwarding_Unit.v` was missing from the `VERILOG_FILES` list. AGY added it to `librelane/config.yaml`.

### 8.3 Design Optimized Away

With an all-NOP `firmware.hex`, Yosys optimized away large parts of CPU/RAM/UART because behavior became mostly constant.

Fixes made:

- Added `(* keep *)` to SRAM macro instances in `Data_RAM.v`.
- Replaced NOP-only `firmware.hex` with a small active firmware loop that exercises memory/GPIO/UART paths.

AGY reported that this helped keep RAM/peripheral logic alive through synthesis.

---

## 9. Physical SRAM / Macro Status

At one point, after reducing ASIC_BASE and using ROM mode for instruction memory, the physical macros were reduced to:

```text
8 SRAM macros for Data_RAM
```

instead of the earlier 16 or 32 macro possibilities.

AGY updated:

```text
librelane/macros/macros_5v.yaml
librelane/pdn/pdn_5v_sram.tcl
```

to place and power the active 8 Data_RAM SRAM macros.

**Important:** After AGY was limited, the user manually refloorplanned the macro placement more cleanly. Therefore the next AGY session must treat the current `macros_5v.yaml` as the source of truth, not the old transcript.

Verify current macro placement:

```bash
cd ~/Projects/riscv_librelane
sed -n '1,240p' librelane/macros/macros_5v.yaml
```

Verify active macro count in latest synthesized netlist/run:

```bash
RUN=$(ls -td librelane/runs/RUN_* | head -1)
grep -R "gf180mcu_fd_ip_sram__sram512x8m8wm1" "$RUN" | head -50
```

---

## 10. Resizer / Placement Debug History

The main implementation problem was massive OpenROAD buffer explosion during pre-CTS repair/design repair.

### 10.1 First Failure: DPL-0036 Detailed Placement Failure

A run failed around:

```text
RUN_2026-06-30_00-18-28
Stage: OpenROAD.RepairDesignPostGPL / detailed placement
```

The reported failure was:

```text
DPL-0036 Detailed placement failed
```

AGY found that pre-CTS repair inserted about:

```text
18,973 buffers
```

into a design with roughly:

```text
1,519 cells
```

causing severe placement congestion.

### 10.2 Suspected Cause 1: Propagated Clock Before CTS

AGY found the clock was being treated as propagated before CTS, causing a large clock transition to be seen at thousands of flop pins.

Fix in `librelane/chip_top.sdc`:

- before CTS: mark clock ideal / not propagated
- after CTS: detect clock tree buffers and set propagated clock

AGY had to fix Tcl syntax because square brackets in double-quoted messages were interpreted as command substitution. Braced Tcl messages were used.

Key behavior expected from `chip_top.sdc`:

```text
Pre-CTS: no clkbuf found -> ideal clock
Post-CTS: clkbuf found -> propagated clock
```

### 10.3 Suspected Cause 2: `DESIGN_REPAIR_MAX_WIRE_LENGTH = 0`

AGY observed resolved GF180 variables caused repair to run with:

```text
-max_wire_length 0
```

This was interpreted too aggressively. AGY set:

```yaml
DESIGN_REPAIR_MAX_WIRE_LENGTH: 1000
GRT_DESIGN_REPAIR_MAX_WIRE_LENGTH: 1000
```

This made the command show:

```text
repair_design -verbose -max_wire_length 1000 -slew_margin 20 -cap_margin 20
```

but buffer growth still remained a problem.

### 10.4 Suspected Cause 3: Strict Transition Target

AGY added in `chip_top.sdc`:

```tcl
set_max_transition 8.0 [current_design]
```

Reason: default library max transition was around 4 ns and AGY considered 8 ns acceptable at 25 MHz. This is a debug/tuning choice, not automatically signoff-clean.

### 10.5 Suspected Cause 4: Setup Repair on Unfixable Combinational Path

AGY found pre-CTS worst setup slack around:

```text
-39.40 ns
```

at a 40 ns clock, likely due to deep combinational path such as MDU/multiplier/divider or PC/control path.

AGY disabled setup buffering/cloning:

```yaml
PL_RESIZER_SETUP_BUFFERING: False
PL_RESIZER_SETUP_GATE_CLONING: False
GRT_RESIZER_SETUP_BUFFERING: False
GRT_RESIZER_SETUP_GATE_CLONING: False
```

Goal: allow resizer to repair DRC/electrical only, not chase unfixable setup paths with massive buffer insertion.

### 10.6 Suspected Cause 5: Fanout/Cap Limits Too Strict

AGY loosened:

```yaml
MAX_FANOUT_CONSTRAINT: 32
MAX_CAPACITANCE_CONSTRAINT: 1.0
```

This reduced buffer count at one iteration, but did not fully solve the issue.

### 10.7 Ultimate Workaround Used

AGY finally bypassed unstable pre-CTS global design repair:

```yaml
RUN_POST_GPL_DESIGN_REPAIR: False
```

This allowed detailed placement to complete and let the flow proceed to CTS and later stages.

This is the latest known successful path through placement. Treat it as a **development workaround**, not final tapeout signoff validation.

---

## 11. Latest Known Run Progress Before AGY Limit

Latest important task ID in the transcript:

```text
task-693
```

Relevant log path pattern:

```bash
~/.gemini/antigravity-cli/brain/9fbe9960-da16-44e7-b814-50abb815f300/.system_generated/tasks/task-693.log
```

Latest flow reports from AGY:

1. Bypassing `RUN_POST_GPL_DESIGN_REPAIR` resolved detailed placement bottleneck.
2. Detailed placement completed.
3. CTS completed successfully.
4. `chip_top.sdc` detected clock tree buffers and set propagated clock after CTS.
5. Post-CTS timing repair completed.
6. Global routing completed.
7. Antenna repair ran.
8. Antenna repair iterations:
   - Iteration 1: 37 antenna violations, inserted 36 jumpers.
   - Iteration 2: 7 antenna violations, inserted 10 diodes.
   - Iteration 3: 16 antenna violations, inserted 20 jumpers.
9. Detailed Routing (TritonRoute / DRT) started.
10. Initial detailed routing had around `4890` DRC violations at pass 0, which AGY said is normal at the beginning of TritonRoute and should shrink as iterations progress.

AGY then hit individual quota/limit before final status was reported.

---

## 12. Current Manual Change After AGY Limit

User manually refloorplanned the SRAM macro placement after AGY was limited.

This means:

- Transcript macro coordinates may be stale.
- Current `librelane/macros/macros_5v.yaml` must be re-read.
- Current latest run may not reflect the manual macro placement unless the user reran the flow afterward.

AGY should start tomorrow by checking:

```bash
cd ~/Projects/riscv_librelane
git status
sed -n '1,260p' librelane/macros/macros_5v.yaml
ls -td librelane/runs/RUN_* | head -5
```

---

## 13. Commands to Resume Tomorrow

### 13.1 Check AGY Task Log

```bash
ls -lt ~/.gemini/antigravity-cli/brain/*/.system_generated/tasks/*.log | head -20

LOG=$(ls -t ~/.gemini/antigravity-cli/brain/*/.system_generated/tasks/*.log | head -1)
echo "$LOG"
tail -200 "$LOG"
```

Specifically for the latest known task:

```bash
tail -300 ~/.gemini/antigravity-cli/brain/9fbe9960-da16-44e7-b814-50abb815f300/.system_generated/tasks/task-693.log
```

### 13.2 Check Latest LibreLane Run

```bash
cd ~/Projects/riscv_librelane

RUN=$(ls -td librelane/runs/RUN_* | head -1)
echo "$RUN"

find "$RUN" -maxdepth 2 -type f | sort | tail -100
```

### 13.3 Check Whether DRT Finished

```bash
grep -Rni "detailed route\|TritonRoute\|DRT\|violation\|DRC\|completed\|failed\|ERROR" "$RUN" | tail -200
```

### 13.4 Check Timing Summaries

```bash
find "$RUN" -iname "*summary*.rpt" -o -iname "max.rpt" -o -iname "min.rpt" | sort

grep -Rni "Worst Slack\|WNS\|TNS\|violat\|max slew\|max cap" "$RUN" | tail -200
```

### 13.5 Open Current Design in OpenROAD

```bash
nix-shell --run "make librelane-openroad"
```

or manually:

```bash
SRAM_DEFINE=SRAM_gf180mcu_fd_ip_sram \
librelane \
  librelane/slots/slot_0p5x1.yaml \
  librelane/macros/macros_5v.yaml \
  librelane/config.yaml \
  --pdk gf180mcuD \
  --pdk-root ./gf180mcu \
  --manual-pdk \
  --scl gf180mcu_fd_sc_mcu7t5v0 \
  --pad gf180mcu_fd_io \
  --last-run \
  --flow OpenInOpenROAD
```

Adjust `SLOT` if current Makefile uses a different slot.

---

## 14. Critical Risks / Not Yet Solved

### 14.1 Functional Boot Risk

Short-term instruction memory is not a real programmable SRAM boot path. Current `firmware.hex` may be dummy/debug firmware. Before tapeout, decide:

- hardcoded ROM demo only, or
- real bootloader/write path into instruction SRAM

### 14.2 Timing Risk

AGY found deep combinational timing paths, including MDU/multiplier/divider and/or PC/fetch/control paths.

If timing remains bad after routing, likely RTL/pipeline changes are required. Do not hide with false paths unless functionally justified.

### 14.3 Relaxed Constraints Are Not Automatically Signoff-Clean

These changes may help development but need review:

```yaml
RUN_POST_GPL_DESIGN_REPAIR: False
MAX_FANOUT_CONSTRAINT: 32
MAX_CAPACITANCE_CONSTRAINT: 1.0
DESIGN_REPAIR_MAX_WIRE_LENGTH: 1000
GRT_DESIGN_REPAIR_MAX_WIRE_LENGTH: 1000
PL_RESIZER_SETUP_BUFFERING: False
PL_RESIZER_SETUP_GATE_CLONING: False
GRT_RESIZER_SETUP_BUFFERING: False
GRT_RESIZER_SETUP_GATE_CLONING: False
```

and in SDC:

```tcl
set_max_transition 8.0 [current_design]
```

These must be documented as flow workarounds, not final proof of timing quality.

### 14.4 `make librelane-nodrc` Is Not Full Signoff

The current run was launched as:

```bash
make librelane-nodrc
```

This skips DRC checks. Full signoff still needs real DRC/LVS/antenna/timing review.

---

## 15. Recommended Next Steps for AGY

1. **Do not edit immediately. First inspect current state.**
2. Read:
   - `librelane/config.yaml`
   - `librelane/chip_top.sdc`
   - `librelane/macros/macros_5v.yaml`
   - `src/chip_core.sv`
   - `src/Peripherals/RAM/Data_RAM.v`
   - latest task log `task-693.log`
   - latest `librelane/runs/RUN_*`
3. Confirm actual current:
   - `SLOT`
   - `CLOCK_PERIOD`
   - active macro count
   - macro coordinates after manual floorplan
   - current run status
4. If DRT already finished, collect:
   - routing DRC count
   - antenna status
   - post-route timing WNS/TNS
   - max slew/max cap violations
5. If DRT did not finish or run was interrupted:
   - start a fresh run only after saving current config and macro floorplan.
6. Generate a report:
   - `resume_status_after_agy_limit.md`
7. Before tapeout:
   - re-enable or run full DRC/LVS checks, not only nodrc.
   - decide instruction memory / boot strategy.
   - verify functional simulation with actual firmware.

---

## 16. Suggested Savepoint Commit

```bash
cd ~/Projects/riscv_librelane
git status

mkdir -p reports/agy_logs
cp ~/.gemini/antigravity-cli/brain/9fbe9960-da16-44e7-b814-50abb815f300/.system_generated/tasks/task-693.log \
   reports/agy_logs/task-693.log 2>/dev/null || true

git add src librelane firmware.hex Makefile README.md reports *.md
git commit -m "Save ASIC_BASE LibreLane progress after macro floorplan and AGY limit"
```

If `librelane/runs/` is too large, do not commit it. Archive the latest run separately:

```bash
RUN=$(ls -td librelane/runs/RUN_* | head -1)
mkdir -p backups
tar -czf backups/$(basename "$RUN")_backup_$(date +%Y%m%d_%H%M%S).tar.gz \
  -C librelane/runs "$(basename "$RUN")"
```

---

## 17. One-Line Current Status

ASIC_BASE has been reduced from FPGA-style full SoC to a smaller wafer.space-compatible RISC-V + UART/GPIO + Data_RAM SRAM design. The flow has passed synthesis/floorplan/placement/CTS/global route after disabling unstable pre-CTS repair, antenna repair completed iterations, and detailed routing had started before AGY hit limit. The user then manually improved macro floorplan; tomorrow AGY should re-read current files, inspect latest run/logs, and continue from DRT/signoff/timing verification.
