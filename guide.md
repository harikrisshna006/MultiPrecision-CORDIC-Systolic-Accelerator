# Flex-PE RTL Beginner Guide

This folder contains a Verilog implementation of the Flex-PE paper baseline.
It is the reference design that will later be compared with the new dual-lane
floating-point proposal. The baseline uses CORDIC fixed-point arithmetic, not
IEEE floating point.

The normal path is simple:

1. Install or open the ModelSim / Questa command prompt.
2. Open PowerShell in this folder.
3. If the project arrived by Gmail, rename `run_baseline.txt` to `run_baseline.ps1`.
4. Run `powershell -ExecutionPolicy Bypass -File .\run_baseline.ps1`.
5. Read the final line. Success is `BASELINE VERIFICATION PASSED: 9 testbenches.`

Do not run a `tb_*.v` file by double-clicking it. A testbench is Verilog code
that must be compiled and simulated by ModelSim.

## 1. What this project does

The completed baseline supports the following paper-derived functions:

| Function | Meaning |
| --- | --- |
| FxP4 / FxP8 / FxP16 / FxP32 | Signed fixed-point numbers with 4, 8, 16, or 32 bits. |
| SIMD | One instruction performs many independent lanes at once. A 64-bit word holds 16 FxP4 lanes, 8 FxP8 lanes, 4 FxP16 lanes, or 1 FxP32 lane. |
| MAC | Multiply-and-accumulate. This is the main calculation used in neural-network matrix multiplication. |
| CORDIC | A shift-and-add method that approximates multiplication, division, exponential, Tanh, and related operations without a conventional multiplier/divider. |
| ReLU / Sigmoid / Tanh / SoftMax | Activation functions used by neural networks. |
| Iterative PE | Reuses CORDIC hardware over several clocks. Smaller area, more latency. |
| Pipelined PE | Places CORDIC stages in a pipeline. Higher throughput, more registers/area. |
| 3x3 systolic array | Nine PEs arranged in three rows and three columns. Features travel right; weights travel down; each PE keeps its own output accumulator. |

The code is a clean-room implementation from the paper description. The paper
does not publish the authors' original RTL, FPGA project, timing constraints,
or trained-model checkpoints. Therefore this project must not claim to be a
bit-for-bit copy of unpublished author code.

## 2. Important words before running anything

| Word | Plain-language meaning |
| --- | --- |
| RTL | Verilog source describing the hardware circuit. RTL files do not execute directly. |
| Module | One reusable hardware block, similar to a component. |
| Testbench | A simulation-only Verilog module that supplies inputs and checks outputs. Testbench filenames start with `tb_`. |
| Compile | ModelSim reads Verilog files and checks their syntax and module connections. |
| Simulate | ModelSim advances clock cycles and runs a testbench. |
| Library | A temporary folder created by ModelSim containing compiled simulation data. It is safe to delete and recreate. |
| PASS / FAIL | The testbench's own check result. `FAIL=0` is required. |
| Warning | A message that did not stop the simulation. The Starter Edition may warn about large designs; this is not a functional failure. |

## 3. The recommended command

Open PowerShell, then enter these commands exactly:

```powershell
Set-Location C:\Users\shash\Downloads\NPU
Rename-Item .\run_baseline.txt run_baseline.ps1
powershell -ExecutionPolicy Bypass -File .\run_baseline.ps1
```

Gmail blocks the `.ps1` extension because it can execute PowerShell code. The
project therefore contains `run_baseline.txt`, which is safe to attach. Rename
it only after downloading the project and only when you intend to run this
project's verification. If Windows asks whether to change the extension, choose
**Yes**.

The script does four safe things:

1. Deletes only `build_modelsim_baseline`, a temporary compiled library.
2. Creates a new clean ModelSim library.
3. Compiles all retained design RTL plus the nine baseline testbenches.
4. Runs all nine testbenches and stops with an error if a test reports a nonzero FAIL count.

Expected successful verdicts are:

| Testbench | Expected final result |
| --- | --- |
| `tb_control_fsm` | `CONTROL FSM: PASS=9 FAIL=0` |
| `tb_cordic_stage_iterative` | `CORDIC ITERATIVE: PASS=192 FAIL=0` |
| `tb_cordic_stage_pipeline` | `CORDIC PIPELINE: PASS=192 FAIL=0` |
| `tb_flex_pe_iterative_top` | `ITERATIVE TOP MIXED: PASS=6 FAIL=0` |
| `tb_flex_pe_pipelined_top` | `PIPELINED TOP MIXED: PASS=6 FAIL=0` |
| `tb_flex_pe_config_fsm` | `CONFIG AF FSM: PASS=5 FAIL=0` |
| `tb_flex_pe_simd64_iterative` | `SIMD64 ITERATIVE: PASS=8 FAIL=0` |
| `tb_flex_pe_simd64_pipelined` | `SIMD64 PIPELINED: PASS=3 FAIL=0` |
| `tb_flex_pe_simd64_array_3x3` | `SIMD64 3x3 ARRAY: PASS=12 FAIL=0` |

The two larger SIMD tests can report a ModelSim Starter Edition design-size
warning. It is acceptable only when the test still ends with `FAIL=0` and
`Errors: 0`.

## 4. Run one test manually

Run the full script once first. It creates `build_modelsim_baseline`.
Afterwards, this command runs only the 3x3 array test:

```powershell
vsim -c -quiet -lib build_modelsim_baseline tb_flex_pe_simd64_array_3x3 -do "run -all; quit -f"
```

Replace `tb_flex_pe_simd64_array_3x3` with any test name from the expected
results table to run one different test.

If ModelSim says `Instantiation ... failed` or `Error loading design`, rerun
the recommended script. It compiles all dependencies in the correct order.

## 5. Which files are the real baseline RTL

The following are retained source RTL files. They are hardware descriptions,
not tests.

| File | What it means |
| --- | --- |
| `rtl/af_precision_ctrl.v` | Two-register host configuration block. Address 0 selects fixed-point precision; address 1 selects the activation. |
| `rtl/angle_lut_rom.v` | CORDIC angle lookup table used by the individual CORDIC stages. |
| `rtl/cordic_hr_stage.v` | One hyperbolic-rotation CORDIC step, used for exponential-related functions. |
| `rtl/cordic_lv_stage.v` | One linear-vectoring CORDIC step, used for division. |
| `rtl/cordic_lr_stage.v` | One linear-rotation CORDIC step, used for MAC. |
| `rtl/cordic_stage_iterative.v` | Reuses one set of CORDIC stages over multiple clocks. Includes the hyperbolic repeated iteration required at shift index 4. |
| `rtl/cordic_stage_pipeline.v` | Pipelined CORDIC engine. Carries each operation mode alongside its data. |
| `rtl/input_normalizer.v` | Clips inputs to the convergence range required by each CORDIC mode. |
| `rtl/relu_mux.v` | ReLU: negative input becomes zero; nonnegative input is forwarded. |
| `rtl/flex_pe_config_fsm.v` | Main paper-derived operation controller. It latches operands, runs MAC directly, and runs HR then LV for Sigmoid/Tanh. Scalar SoftMax is rejected because SoftMax needs a shared SIMD denominator. |
| `rtl/cordic_exp_pipeline.v` | One pipelined exponential lane used before vector SoftMax division. |
| `rtl/flex_pe_iterative_top.v` | One scalar iterative PE supporting all four widths. |
| `rtl/flex_pe_pipelined_top.v` | One scalar pipelined PE supporting all four interface widths. |
| `rtl/flex_pe_simd64_iterative.v` | Main 64-bit iterative SIMD PE: 16 FxP4, 8 FxP8, 4 FxP16, or 1 FxP32 lane. |
| `rtl/flex_pe_simd64_softmax.v` | Vector-wide SoftMax controller: exponentiate all lanes, form a shared denominator, then divide every lane. |
| `rtl/flex_pe_simd64_pipelined.v` | Main 64-bit pipelined SIMD PE. Paper-supported pipelined widths are FxP8/FxP16/FxP32; FxP4 is rejected visibly. |
| `rtl/flex_pe_simd64_array_3x3.v` | Main 3x3 iterative SIMD systolic array. It uses registered links and staggered input injection, so inputs move one PE per clock. |
| `rtl/exp_accumulator.v` | Legacy combinational block that reconstructs exponential as Cosh + Sinh. |
| `rtl/fifo_exp_store.v` | Legacy FIFO storage block for exponent values. |
| `rtl/sigmoid_softmax_selector.v` | Legacy divisor-selection helper. |
| `rtl/control_fsm.v` | Earlier scalar controller retained for legacy verification. The baseline PE uses `flex_pe_config_fsm.v` instead. |
| `rtl/pe_array_8x8.v` | Earlier 8x8 CORDIC array retained as historical/reference code. The current baseline array is the 3x3 registered SIMD implementation. |

## 6. Arithmetic and generic support RTL

| File | What it means |
| --- | --- |
| `rtl/barrel_shifter_stage.v` | One arithmetic right-shift stage. |
| `rtl/simd_add_sub.v` | Generic packed SIMD add/sub reference implementation. |
| `rtl/simd_add_sub_4b.v` | One signed 4-bit add/sub lane. |
| `rtl/simd_add_sub_8b.v` | One signed 8-bit add/sub lane. |
| `rtl/simd_add_sub_16b.v` | One signed 16-bit add/sub lane. |
| `rtl/simd_add_sub_32b.v` | One signed 32-bit add/sub lane. |
| `rtl/simd_lane_mux.v` | Selects the correct 4/8/16/32-bit packed add/sub result. |
| `rtl/simd_barrel_shifter.v` | Packed SIMD arithmetic right shifter. |
| `rtl/simd_barrel_shifter_top.v` | Structural five-stage packed barrel-shifter version. |
| `rtl/address_mapper.v` | Maps a host address to local memory-bank address/control signals. |
| `rtl/axi_signal_interface.v` | Project-scoped AXI-Lite style host interface. |
| `rtl/dma_scheduler.v` | Simple DMA scheduling control. |
| `rtl/status_control_reg.v` | Status/control register storage. |
| `rtl/if_bank_mem.v` | Input-feature memory bank model. |
| `rtl/wt_bank_mem.v` | Weight memory bank model. |
| `rtl/of_bank_mem.v` | Output-feature memory bank model. |

## 7. Testbench files

Every file beginning with `tb_` is for simulation only. Do not use it as
synthesizable FPGA hardware.

| Testbench | It checks |
| --- | --- |
| `tb_address_mapper.v` | Address mapper. |
| `tb_af_combinational.v` | Legacy ReLU, exponential accumulator, and divisor helper. |
| `tb_af_precision_ctrl.v` | Host precision/activation configuration registers. |
| `tb_angle_lut_rom.v` | CORDIC angle lookup values. |
| `tb_axi_signal_interface.v` | Project-scoped AXI-Lite interface behavior. |
| `tb_control_fsm.v` | Earlier control FSM state transitions. |
| `tb_cordic_hr_stage.v` | One hyperbolic CORDIC stage. |
| `tb_cordic_lv_stage.v` | One linear-vectoring CORDIC stage. |
| `tb_cordic_lr_stage.v` | One linear-rotation CORDIC stage. |
| `tb_cordic_stage_iterative.v` | Complete iterative CORDIC engine against generated vectors. |
| `tb_cordic_stage_pipeline.v` | Complete pipelined CORDIC engine against generated vectors. |
| `tb_dma_scheduler.v` | DMA scheduler. |
| `tb_fifo_exp_store.v` | Legacy exponent FIFO. |
| `tb_flex_pe_iterative_top.v` | Scalar iterative Flex-PE smoke test. |
| `tb_flex_pe_pipelined_top.v` | Scalar pipelined Flex-PE smoke test. |
| `tb_flex_pe_config_fsm.v` | Main activation controller: ReLU, Tanh(0), Sigmoid(0), scalar-SoftMax rejection, and MAC. |
| `tb_flex_pe_simd64_iterative.v` | Main iterative SIMD test: lane packing and paper stage counts. |
| `tb_flex_pe_simd64_pipelined.v` | Main pipelined SIMD test: vector SoftMax and pipelined FxP4 rejection. |
| `tb_flex_pe_simd64_array_3x3.v` | Main 3x3 array test: registered systolic wave, ReLU, and MAC. |
| `tb_if_bank_mem.v` | Input-feature memory bank. |
| `tb_wt_bank_mem.v` | Weight memory bank. |
| `tb_of_bank_mem.v` | Output-feature memory bank. |
| `tb_input_normalizer.v` | CORDIC range clipping. |
| `tb_pe_array_8x8.v` | Earlier 8x8 array smoke test. |
| `tb_pe_array_8x8_error_debug.v` | Diagnostic-only legacy array test. It prints internal values; it has no PASS/FAIL verdict. |
| `tb_pe_array_8x8_error_sweep.v` | Legacy CORDIC array error-characterization sweep. FxP8/FxP16/FxP32 use tolerances. |
| `tb_pe_array_8x8_extended.v` | Historical exact-match test. Do not use it as a baseline acceptance test because CORDIC is approximate. |
| `tb_simd_add_sub.v` | Generic packed SIMD addition/subtraction. |
| `tb_simd_barrel_shifter.v` | Generic packed barrel shifter. |
| `tb_simd_barrel_shifter_top.v` | Structural packed barrel shifter. |
| `tb_simd_lane_mux.v` | SIMD precision selection mux. |
| `tb_status_control_reg.v` | Status/control register. |

## 8. Generated CORDIC vector files

These text files provide known input/output values to the CORDIC testbenches.
They are generated from the Python golden model and should be retained.

| File | Used by |
| --- | --- |
| `rtl/angle_lut_vectors.mem` | Angle LUT test. |
| `rtl/cordic_hr_stage_vectors.mem` | Hyperbolic-stage test. |
| `rtl/cordic_lr_stage_vectors.mem` | Linear-rotation-stage test. |
| `rtl/cordic_lv_stage_vectors.mem` | Linear-vectoring-stage test. |
| `rtl/cordic_iterative_vectors.mem` | Iterative CORDIC test. |
| `rtl/cordic_pipeline_vectors.mem` | Pipelined CORDIC test. |

To regenerate all vectors after changing CORDIC arithmetic:

```powershell
$env:PYTHONPATH = 'python'
python python\cordic_golden_model.py
```

Then run `run_baseline.ps1` again. Never change the RTL and forget to
regenerate its golden vectors.

## 9. Python files

| File | What it does |
| --- | --- |
| `python/cordic_golden_model.py` | Independent fixed-point CORDIC model. Runs internal mathematical checks and writes the `.mem` test vectors. |
| `python/monte_carlo_error_eval.py` | Evaluates CORDIC error at different stage counts. Useful when making paper plots. |
| `python/qat_quantizer.py` | Quantization-aware-training helper functions. |
| `python/test_qat_quantizer.py` | Functional tests for the quantization helper. |
| `python/vgg16_resnet18_eval.py` | Neural-network evaluation utility. A full dataset/model run is separate from RTL simulation. |
| `python/test_vgg16_resnet18_eval.py` | No-download smoke test for the evaluation utility. |

## 10. Other folders and files

| Item | Keep it? | Reason |
| --- | --- | --- |
| `rtl/` | Yes | All Verilog source, testbenches, and CORDIC vectors. |
| `python/` | Yes | Golden model, quantization utilities, and evaluation helpers. |
| `run_baseline.txt` | Yes | Gmail-safe copy of the verification runner. Rename it to `run_baseline.ps1` only when you want to execute it. |
| `guide.md` | Yes | This document. |

All generated ModelSim libraries, simulation logs, audit folders, temporary PDF
extractions, generated report files, and the empty data folder were permanently
removed. The runner recreates its temporary compiled library automatically when
you run it.

## 11. How to decide that verification succeeded

Verification succeeds only when all are true:

1. The compile command ends without `** Error`.
2. Every selected testbench prints `FAIL=0`.
3. ModelSim ends with `Errors: 0`.
4. The final script line says `BASELINE VERIFICATION PASSED: 9 testbenches.`

A simulation that merely reaches `$finish` is not automatically successful.
Always check the PASS/FAIL line first.

## 12. Common beginner mistakes

| Symptom | Cause | Fix |
| --- | --- | --- |
| `vlog is not recognized` | ModelSim is not installed or its command folder is not on PATH. | Open the Intel FPGA / ModelSim command prompt, then run the script again. |
| `Error loading design` | The design was simulated before every dependency was compiled. | Rename `run_baseline.txt` to `run_baseline.ps1`, then run it; it compiles everything first. |
| `FAIL=1` or more | A real check failed. | Copy the complete terminal output before changing RTL. |
| ModelSim design-size warning | Starter Edition recommends a smaller design. | Treat it as acceptable only if the test ends in `FAIL=0` and `Errors: 0`. |
| A result changed after editing CORDIC | Golden vectors are stale. | Regenerate vectors with `python\\cordic_golden_model.py`, then rerun the baseline. |
| SoftMax fails in scalar mode | SoftMax needs a vector denominator. | Use `flex_pe_simd64_pipelined.v`, not a scalar Flex-PE. |

## 13. What happens next

Do not modify this baseline casually. It is the comparison point for the
research contribution. The next design will be added separately and will
contain the exact floating-point lane, approximate floating-point lane,
frequency-control hooks, voltage-profile request, pipelining, and a second
3x3 array. Both designs will then use the same test vectors, FPGA target, and
measurement method.
