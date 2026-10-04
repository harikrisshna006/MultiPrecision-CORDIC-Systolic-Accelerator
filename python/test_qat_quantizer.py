"""Functional checks for qat_quantizer.py.

Expected quantized values are computed with independent NumPy arithmetic.
The test reports dependency-blocked rather than claiming a pass when PyTorch
is unavailable.
"""
import sys
import numpy as np

try:
    import torch
    from qat_quantizer import PACTActivation, quantize_tensor
except ModuleNotFoundError as exc:
    print(f"QAT FUNCTIONAL TEST: UNAVAILABLE - missing dependency: {exc}")
    sys.exit(2)


def check(name, got, expected, atol=1e-6):
    got_np = got.detach().cpu().numpy() if hasattr(got, "detach") else np.asarray(got)
    ok = np.allclose(got_np, expected, atol=atol, rtol=0.0)
    print(f"{name}: {'PASS' if ok else 'FAIL'} got={got_np} expected={expected}")
    return ok


def main():
    passed = failed = 0

    # Independent uniform quantization reference: 2-bit [0,1] has levels
    # 0, 1/3, 2/3, 1. The final value explicitly exercises saturation.
    values = np.array([0.5, 1.0 / 3.0, 1.5], dtype=np.float32)
    expected = np.rint(np.clip(values, 0.0, 1.0) * 3.0) / 3.0
    got = quantize_tensor(torch.tensor(values), bits=2, lower=0.0, upper=1.0)
    if check("uniform mid/boundary/saturation", got, expected): passed += 1
    else: failed += 1

    pact = PACTActivation(init_a=1.0)
    with torch.no_grad():
        a = float(pact.a.item())
    x = np.array([-2.0, 0.0, 0.5, 2.0], dtype=np.float32)
    expected_pact = 0.5 * (np.abs(x) - np.abs(x - a) + a)
    got_pact = pact(torch.tensor(x))
    if check("PACT negative/inside/clip", got_pact, expected_pact): passed += 1
    else: failed += 1

    print(f"QAT FUNCTIONAL TEST: PASS={passed} FAIL={failed}")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
