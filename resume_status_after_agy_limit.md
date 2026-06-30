# LibreLane PnR Resume Status Report

This report summarizes the current status of the RISC-V GF180 LibreLane project after resuming from the savepoint.

## 1. Executive Summary

- **Latest Run:** `RUN_2026-06-30_03-34-34`
- **Detailed Routing & Manufacturability DRC:** Passed ✅
- **Antenna Rules Check:** Passed ✅
- **LVS (Layout vs Schematic):** Passed ✅ (Circuits match uniquely)
- **Hold Timing:** Passed ✅ (Worst Slack = 0.0572 ns, 0 violations)
- **Setup Timing:** Failed ❌ (Worst Slack = -79.9609 ns, 2131 violations)
- **SRAM Macro Floorplan:** Verified. All 8 physical 5V SRAM macros (`sram_b0_s0` through `sram_b1_s3`) are successfully placed at X-coordinate `979.12` and routed.

---

## 2. Configuration & Constraints Audit

### 2.1 Design & Slot Dimensions
- **Top Module:** `chip_top`
- **Slot Config:** `slot_0p5x1.yaml`
- **Die Area:** `[0, 0, 1936, 5122]` (Width = 1936 µm, Height = 5122 µm)
- **Core Area:** `[442, 442, 1494, 4680]` (Width = 1052 µm, Height = 4238 µm)

### 2.2 SRAM Macros
The 8 active 5V SRAM macros are configured in `librelane/macros/macros_5v.yaml` as follows:
- **Macro cell:** `gf180mcu_fd_ip_sram__sram512x8m8wm1`
- **Coordinates:**
  - `sram_b0_s0`: `[979.12, 472]`
  - `sram_b0_s1`: `[979.12, 923.86]`
  - `sram_b0_s2`: `[979.12, 1375.72]`
  - `sram_b0_s3`: `[979.12, 1827.58]`
  - `sram_b1_s0`: `[979.12, 2279.44]`
  - `sram_b1_s1`: `[979.12, 2731.3]`
  - `sram_b1_s2`: `[979.12, 3183.16]`
  - `sram_b1_s3`: `[979.12, 3635.02]`
- **Orientation:** `E` (East) for all macros.

### 2.3 Clock
- **Clock Port:** `clk_PAD`
- **Clock Period:** 40 ns (25 MHz)
- **Clock Net:** `clk_pad/Y`

---

## 3. Detailed Timing Analysis

The hold timing is completely clean, but setup timing fails heavily. The worst negative slack (WNS) is **-79.96 ns** (overall across all corners) and **-18.83 ns** in the nominal corner (`nom_tt_025C_5v00`).

### 3.1 Analysis of the Critical Path
From the nominal setup report (`max.rpt`):
- **Path start:** Register `_28561_/CLK`
- **Path end:** Register `_30053_/D`
- **Data arrival time:** `60.67 ns` (Target is `41.84 ns` required time, violating by `18.83 ns`)

The major bottleneck is several nets with huge fanout and capacitance that are not buffered. For example:
1. **Net `_08984_` (pin `_15040_/ZN` to `_15042_/A2`):**
   - **Fanout:** 57
   - **Capacitance:** 0.625 pF
   - **Slew:** 28.23 ns (extremely degraded!)
   - **Gate delay:** 16.17 ns
2. **Net `_09703_` (pin `_15917_/ZN` to `_24181_/A1`):**
   - **Fanout:** 53
   - **Capacitance:** 0.564 pF
   - **Slew:** 16.50 ns
   - **Gate delay:** 9.54 ns
3. **Net `_05687_` (pin `_24181_/ZN` to `_24345_/A1`):**
   - **Fanout:** 79
   - **Capacitance:** 0.703 pF
   - **Slew:** 20.55 ns
   - **Gate delay:** 16.68 ns

### 3.2 Root Cause
These huge unbuffered nets exist because setup timing repair was disabled in `librelane/config.yaml`:
```yaml
PL_RESIZER_SETUP_BUFFERING: False
PL_RESIZER_SETUP_GATE_CLONING: False
GRT_RESIZER_SETUP_BUFFERING: False
GRT_RESIZER_SETUP_GATE_CLONING: False
```
This was a development workaround to prevent the OpenROAD buffer explosion during global repair. However, because it prevents the resizer from adding buffers to high-fanout control signals, these signals experience massive transition times and timing failure.

---

## 4. Proposed Recommendations & Work Plan

To achieve timing closure, we need to balance buffer insertion without triggering buffer explosion. We propose the following steps:

1. **Re-evaluate Setup Buffering:** 
   Since ideal clock propagation before CTS is fixed (`unset_propagated_clock [all_clocks]` is run pre-CTS in SDC), the clock tree buffer explosion risk is minimized. We should try re-enabling setup buffering (`PL_RESIZER_SETUP_BUFFERING: True` and `GRT_RESIZER_SETUP_BUFFERING: True`) while keeping `RUN_POST_GPL_DESIGN_REPAIR: False` (which was the most unstable step).
   
2. **Tighten Max Slew / Max Transition Constraints:**
   The current SDC overrides max transition to a loose `8.0 ns`. We should gradually tighten this or allow the resizer to repair slews/caps more aggressively.
   
3. **Investigate RTL Pipeline Stages:**
   If timing remains highly negative even after buffering, the combinational paths in the CPU pipeline (especially related to Execute cycle / ALU / MDU) need pipeline registers to split the deep logic paths.
