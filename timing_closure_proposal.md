# Timing Closure & Tuning Proposal for RISC-V LibreLane

This document outlines the proposed optimizations across RTL, Synthesis, and Physical Design to achieve timing closure on the RISC-V SoC design. 

---

## Option 1: Physical Design & Tooling Optimizations (Low Risk, Config Only)

These changes do not touch the RTL code and can be implemented purely through configuration.

### 1.1 Yosys Synthesis Strategy Tuning
- **Current State:** Inherits default `SYNTH_STRATEGY: "AREA 0"`, which instructs Yosys to minimize standard cell area, completely ignoring delay optimization.
- **Proposal:** Set `SYNTH_STRATEGY: "DELAY 1"` or `"DELAY 2"` in [config.yaml](file:///home/hien/Projects/riscv_librelane/librelane/config.yaml).
- **Timing Impact:** Highly Significant. Yosys will prioritize delay over area, selecting faster logic gates and restructuring deep Boolean networks to reduce logic depth.
- **Risk:** Minor area increase (perfectly fine since the die density target is 35%).

### 1.2 Enable Post-Global Route Resizer
- **Current State:** `RUN_POST_GRT_RESIZER_TIMING` is set to `False` by default.
- **Proposal:** Set `RUN_POST_GRT_RESIZER_TIMING: True` in [config.yaml](file:///home/hien/Projects/riscv_librelane/librelane/config.yaml).
- **Timing Impact:** Moderate. This runs another timing repair pass in OpenROAD after global routing (GRT) using actual estimated routing parasitics, ensuring critical paths are buffered based on physical layout load.
- **Risk:** Increases PnR runtime slightly.

### 1.3 Tighten Max Transition Constraints in SDC
- **Current State:** [chip_top.sdc](file:///home/hien/Projects/riscv_librelane/librelane/chip_top.sdc#L78) overrides max transition to `8.0 ns`.
- **Proposal:** Change the override to `4.0 ns` or remove it entirely to fall back on the SCL library default (~3.0 ns).
- **Timing Impact:** High. A loose transition target of 8.0 ns allows the resizer to ignore slow slews, leading to massive propagation delays. Tightening this constraint forces the resizer to insert buffers earlier on slow control paths.
- **Risk:** None.

---

## Option 2: ASIC-Oriented RTL Optimizations (Moderate Risk, Code Changes)

These changes modify the SystemVerilog/Verilog source code to resolve physical design bottlenecks.

### 2.1 Multi-Cycle Pipelined Multiplier (MDU)
- **Current State:** The $33 \times 33$ signed/unsigned multiplier in [MDU.v](file:///home/hien/Projects/riscv_librelane/src/IP_CORE/MDU.v#L70) is fully combinational. On ASIC standard cells (GF180mcu), this compiles into a massive cascade of adders with 15–25 ns of delay.
- **Proposal:** 
  1. Pipeline the multiplier by adding a pipeline register stage in [MDU.v](file:///home/hien/Projects/riscv_librelane/src/IP_CORE/MDU.v) to capture the partial products or inputs.
  2. Modify the MDU state machine so that multiplication (`is_mul`) takes 2 clock cycles instead of 1.
  3. Assert the `Busy` output for 1 cycle when multiplication is triggered, which automatically stalls the pipeline (the CPU's Hazard Unit already stalls the pipeline when `Busy` is asserted).
- **Timing Impact:** Extremely High. Cuts the multiplier delay in half, which is the absolute worst-case logic path in the CPU execution unit.
- **Risk:** Moderate. Needs careful RTL verification and simulation via cocotb to ensure state machine and stalling functionality remain correct.

### 2.2 Register Hazard Detection Outputs
- **Current State:** The Hazard/Stall logic in [Hazard_Unit.v](file:///home/hien/Projects/riscv_librelane/src/IP_CORE/Hazard_Unit.v) compares destination/source registers across all active stages (`Decode`, `Execute`, `Memory`) and combinationaly generates `StallD` and `FlushD`, which feed back to the D-inputs of the Fetch/Decode pipeline registers. This creates a stage-crossing combinational feedback path.
- **Proposal:** Break the feedback loop by registering the stall/flush decisions at the boundary of the Hazard Unit or structure the hazard checks to execute one clock cycle earlier (though this may require adding bubbles/wait-states).
- **Timing Impact:** Moderate to High.
- **Risk:** High. Changing pipeline control/hazard state behavior is highly error-prone and can introduce CPU bugs.

---

## Option 3: General RTL Pipelining of CPU Execute Stage
- **Current State:** The Execute cycle contains the ALU, MDU, and Address generation. The outputs are multiplexed and forwarded.
- **Proposal:** Insert pipeline registers between the execution results and the memory stage write ports, ensuring that deep ALU/MDU operations are isolated.
- **Timing Impact:** High.
- **Risk:** High (major rewrite of the CPU pipeline).
