"""PyTorch QAT helpers for Flex-PE fixed-point deployment.

The repository's original golden-model files were not present in this checkout;
these utilities therefore keep their public-facing functionality self-contained.
"""
from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Iterable, Optional

import torch
from torch import Tensor, nn


def quantize_tensor(x: Tensor, bits: int, lower: Tensor | float, upper: Tensor | float) -> Tensor:
    """Symmetric-free uniform fake quantization with learned/fitted bounds."""
    lo, hi = torch.as_tensor(lower, device=x.device, dtype=x.dtype), torch.as_tensor(upper, device=x.device, dtype=x.dtype)
    levels = float((1 << bits) - 1)
    scale = (hi - lo).clamp_min(torch.finfo(x.dtype).eps) / levels
    clipped = x.clamp(lo, hi)
    return torch.round((clipped - lo) / scale) * scale + lo


def fit_entropy_clipping(weights: Tensor, bits: int = 8, grid: int = 41) -> tuple[float, float]:
    """Fit non-fixed saturation bounds by minimizing quantized-value entropy.

    A small saturation penalty prevents the entropy objective from selecting a
    tiny interval that discards most of the distribution.
    """
    flat = weights.detach().float().flatten()
    if flat.numel() == 0:
        return -1.0, 1.0
    qs = torch.linspace(0.001, 0.10, grid, device=flat.device)
    best = (float("inf"), float(flat.min()), float(flat.max()))
    for q in qs:
        lo = torch.quantile(flat, q).item()
        hi = torch.quantile(flat, 1.0 - q).item()
        if hi <= lo:
            continue
        qv = quantize_tensor(flat, bits, lo, hi)
        _, counts = torch.unique(qv, return_counts=True)
        p = counts.float() / flat.numel()
        entropy = float(-(p * torch.log2(p)).sum())
        clipped_fraction = float(((flat < lo) | (flat > hi)).float().mean())
        score = entropy + 8.0 * clipped_fraction
        if score < best[0]:
            best = (score, lo, hi)
    return best[1], best[2]


def layer_sensitivity(model: nn.Module, gradients: Optional[dict[str, Tensor]] = None, bits: int = 8) -> dict[str, float]:
    """Return quantization distance weighted by each layer's gradient norm."""
    out: dict[str, float] = {}
    for name, parameter in model.named_parameters():
        if parameter.ndim == 0 or not parameter.requires_grad:
            continue
        lo, hi = fit_entropy_clipping(parameter.detach(), bits)
        q = quantize_tensor(parameter.detach(), bits, lo, hi)
        distance = torch.linalg.vector_norm(q - parameter.detach())
        grad = gradients.get(name) if gradients else parameter.grad
        grad_norm = torch.linalg.vector_norm(grad.detach()) if grad is not None else torch.tensor(1.0, device=parameter.device)
        out[name] = float((distance * grad_norm).item())
    return out


class PACTActivation(nn.Module):
    """PACT activation with trainable positive clipping threshold ``a``."""
    def __init__(self, init_a: float = 6.0):
        super().__init__()
        self.alpha = nn.Parameter(torch.tensor(math.log(math.expm1(init_a))))

    @property
    def a(self) -> Tensor:
        return torch.nn.functional.softplus(self.alpha)

    def forward(self, x: Tensor) -> Tensor:
        a = self.a
        return 0.5 * (x.abs() - (x - a).abs() + a)


@dataclass
class QuantizedLayerBounds:
    name: str
    lower: float
    upper: float
    sensitivity: float


def collect_qat_bounds(model: nn.Module, bits: int = 8) -> list[QuantizedLayerBounds]:
    sensitivity = layer_sensitivity(model, bits=bits)
    bounds = []
    for name, p in model.named_parameters():
        if p.requires_grad and p.ndim > 0:
            lo, hi = fit_entropy_clipping(p.detach(), bits)
            bounds.append(QuantizedLayerBounds(name, lo, hi, sensitivity.get(name, 0.0)))
    return sorted(bounds, key=lambda x: x.sensitivity, reverse=True)


if __name__ == "__main__":
    torch.manual_seed(0)
    demo = nn.Sequential(nn.Linear(8, 16), PACTActivation(), nn.Linear(16, 4))
    x = torch.randn(32, 8)
    demo(x).sum().backward()
    for item in collect_qat_bounds(demo)[:3]:
        print(item)
