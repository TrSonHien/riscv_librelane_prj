# Resume & Savepoint Status: RISC-V GF180 LibreLane Timing Closure

This document serves as the savepoint/resume summary for the next session.

---

## 1. Project Context & Status

- **Design:** `chip_top` (RISC-V SoC with 8 active 5V SRAM macros).
- **Physical Design Config:** Manual macro floorplan in [macros_5v.yaml](file:///home/hien/Projects/riscv_librelane/librelane/macros/macros_5v.yaml), slot size `slot_0p5x1.yaml`.
- **Timing Target:** 40 ns (25 MHz) clock period.
- **Git Repo:** `git@github.com:TrSonHien/riscv_librelane_prj.git` (Branch `main`).

---

## 2. Summary of timing closure experiments (June 30, 2026)

We prepared two configuration variants to evaluate physical-design-only timing closure:

### Variant A (Stable Baseline)
- **Settings:** `RUN_POST_GPL_DESIGN_REPAIR: False`, `RUN_POST_GRT_RESIZER_TIMING: True`, `SYNTH_STRATEGY: "DELAY 1"`, and setup buffering/gate cloning enabled.
- **Results:** PnR completed successfully without buffer explosion (2,331 buffers added).
- **Timing:**
  - `nom_tt_025C_5v00`: **`+0.8047 ns`** (Timing met! TNS = `0.0000`)
  - `max_ss_125C_4v50`: **`-41.5407 ns`** (TNS = `-11784.00`)
- **Key Bottleneck:** Stall/Hazard control logic combinational path:
  `Decode RS1_D_r -> Stall/Hazard logic -> PCPlus4D pipeline registers`

### Variant B (Pre-CTS Global Design Repair)
- **Settings:** `RUN_POST_GPL_DESIGN_REPAIR: True`
- **Results:** **FAILED** at `OpenROAD.RepairDesignPostGPL` with `[DPL-0036] Detailed placement failed` (over-congestion of buffers). This variant has been **abandoned**.

---

## 3. Current Configuration (Pending Server Run)

To further optimize timing, we configured the latest code on `main` to try Yosys strategy `DELAY 2`:
- **Current Commit:** `62e64fffab296a18638905892f26654febebe0bb` (remote `main`).
- **Active configuration in `config.yaml`:**
  - `RUN_POST_GPL_DESIGN_REPAIR: False`
  - `RUN_POST_GRT_RESIZER_TIMING: True`
  - `SYNTH_STRATEGY: "DELAY 2"` (for timing comparison against `DELAY 1`)
  - Setup buffering & gate cloning enabled.
  - Manual SRAM floorplan intact.

---

## 4. Instructions for Next Session (When Resuming)

1. **Verify if the server run has completed:**
   Check if the user has completed the LibreLane PnR run on the server using `DELAY 2` and `scp`-ed the run folders back to this machine.
2. **Analyze the DELAY 2 run outputs:**
   - Locate the new run directory inside `librelane/runs/`.
   - Inspect `summary.rpt` and `max.rpt` in the post-PnR STA folder (`54-openroad-stapostpnr/`).
   - Extract:
     - WNS / TNS in nominal and worst corner.
     - Buffer count inserted (compare with the 2,331 baseline of Variant A).
     - Top 10 worst setup paths (verify if they still go through Hazard/Stall logic).
3. **Compare DELAY 2 vs. DELAY 1 (Variant A):**
   Evaluate if changing synthesis strategy from `DELAY 1` to `DELAY 2` improved the worst corner slack (baseline `-41.54 ns`).
4. **Determine Timing Closure Route:**
   - If timing is closed or very close (< 2-3 ns slack), continue physical design tuning.
   - If worst-corner timing is still heavily violated (~30–40 ns), proceed to **targeted RTL optimization of the Hazard/Stall control path** as the next step, rather than modifying the MDU (which is not a bottleneck).
