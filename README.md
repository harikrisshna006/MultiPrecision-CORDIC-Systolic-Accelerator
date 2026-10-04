# FlexNPU: Mixed-Precision 3×3 Systolic Tensor Accelerator with Unified CORDIC Activation Engine

[![Verilog HDL](https://img.shields.io/badge/Language-Verilog_2001-blue.svg)](https://en.wikipedia.org/wiki/Verilog)
[![Precision](https://img.shields.io/badge/Precision-FxP4%20%7C%20FxP8%20%7C%20FxP16%20%7C%20FxP32-orange.svg)]()
[![Interconnect](https://img.shields.io/badge/Interconnect-AXI4--Lite-green.svg)]()
[![Architecture](https://img.shields.io/badge/Compute-3x3_Systolic_Wavefront-red.svg)]()

FlexNPU is an energy-efficient, reconfigurable hardware inference accelerator designed for low-power edge neural network workloads. It integrates a 3×3 2D systolic compute grid, dynamic multi-precision SIMD execution, a shared CORDIC engine for both linear and transcendental non-linear activations, and a dedicated multi-lane scratchpad memory subsystem.

## ?? Key Architectural Highlights

- **3×3 Output-Stationary Wavefront Systolic Array:** Staggered diagonal compute schedule optimizing feature and weight data reuse across processing elements.
- **Dynamic Mixed-Precision SIMD Core:** 64-bit SIMD datapath dynamically reconfigurable via runtime register control into **16×FxP4, 8×FxP8, 4×FxP16, or 1×FxP32** lanes.
- **Unified CORDIC Activation & Transcendental Unit:**
  - **Linear Rotation (LR):** Multi-lane Dot-Products / MAC operations.
  - **Hyperbolic & Linear Vectoring (HR + LV):** Hardware-efficient evaluation of ^x$, Sigmoid ($\sigma(x)$), and $\tanh(x)$ without expensive DSP multipliers.
  - **Vector Reduction Engine:** Dedicated cross-lane parallel exponentiation and division datapath for high-accuracy **SoftMax** execution.
- **Multi-Lane Wavefront Output SRAM Subsystem:**
  - Hardware-generated 
o_of_OPSram_lane_active handshaking matching systolic wavefront graduation (1, 3, or 5 results written per clock cycle).
  - Eliminates pipeline stalls and structural memory bank hazards.
- **System-Level SoC Integration:** AXI4-Lite slave control register interface (f_precision_ctrl) coupled with DMA-assisted double-buffered scratchpad memory streaming.
