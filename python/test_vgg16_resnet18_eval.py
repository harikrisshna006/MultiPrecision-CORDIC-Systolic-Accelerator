"""Small functional smoke test for vgg16_resnet18_eval.py.

This avoids downloading CIFAR-100 and uses known logits to check the
CORDIC-softmax substitution's output shape, dtype, and normalization.
"""
import sys
import numpy as np

try:
    import torch
    from vgg16_resnet18_eval import cordic_softmax
except ModuleNotFoundError as exc:
    print(f"VGG/RESNET FUNCTIONAL TEST: UNAVAILABLE - missing dependency: {exc}")
    sys.exit(2)


def main():
    logits = torch.tensor([[0.0, 1.0, -1.0], [4.0, 4.0, 0.0]], dtype=torch.float32)
    output = cordic_softmax(logits)
    shape_ok = tuple(output.shape) == (2, 3)
    dtype_ok = output.dtype == logits.dtype
    sums = output.sum(dim=1).detach().cpu().numpy()
    normalized_ok = np.allclose(sums, np.ones(2), atol=1e-5, rtol=0.0)
    finite_ok = bool(torch.isfinite(output).all().item())
    print(f"shape: {'PASS' if shape_ok else 'FAIL'} got={tuple(output.shape)} expected=(2, 3)")
    print(f"dtype: {'PASS' if dtype_ok else 'FAIL'} got={output.dtype} expected={logits.dtype}")
    print(f"row sums: {'PASS' if normalized_ok else 'FAIL'} got={sums}")
    print(f"finite: {'PASS' if finite_ok else 'FAIL'} output={output.detach().cpu().numpy()}")
    passed = sum((shape_ok, dtype_ok, normalized_ok, finite_ok))
    failed = 4 - passed
    print(f"VGG/RESNET FUNCTIONAL TEST: PASS={passed} FAIL={failed}")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
