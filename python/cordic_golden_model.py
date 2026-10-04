"""Textbook fixed-point CORDIC golden model for the inferred Flex-PE blocks.

Modes use the same encoding as the RTL: HR=0, LV=1, LR=2.  This file is an
independent numerical reference; it is not copied from the unpublished paper.
"""
from __future__ import annotations

import json
import math
from pathlib import Path
from typing import Iterable

import numpy as np

WIDTH = 32
FRAC = 13
SCALE = 1 << FRAC
HR, LV, LR = 0, 1, 2


def qround(x: float | np.ndarray) -> int | np.ndarray:
    return np.rint(np.asarray(x) * SCALE).astype(np.int64)


def qfloat(x: int | np.ndarray) -> float | np.ndarray:
    return np.asarray(x, dtype=np.float64) / SCALE


def arshift(x: int, i: int) -> int:
    return x >> i if i >= 0 else x << (-i)


def atanh_angle(i: int) -> int:
    return int(np.rint(np.arctanh(2.0 ** -i) * SCALE))


def hyperbolic_gain(stages: int) -> float:
    indices = [stage + 1 if stage < 4 else stage for stage in range(stages)]
    return float(np.prod([math.sqrt(1.0 - 2.0 ** (-2 * i)) for i in indices]))


def linear_angle(i: int) -> int:
    return int(np.rint((2.0 ** -i) * SCALE))


def hr_cordic(x0: int, y0: int, z0: int, stages: int = 10) -> tuple[int, int, int]:
    """Hyperbolic rotation with the mandatory repeated i=4 iteration."""
    x, y, z = int(x0), int(y0), int(z0)
    for stage in range(stages):
        i = stage + 1 if stage < 4 else stage
        d = 1 if z >= 0 else -1
        x, y, z = x + d * arshift(y, i), y + d * arshift(x, i), z - d * atanh_angle(i)
    return x, y, z


def lv_cordic(x0: int, y0: int, z0: int = 0, stages: int = 10) -> tuple[int, int, int]:
    """Linear vectoring; z accumulates the quotient y0/x0 for positive x0."""
    x, y, z = int(x0), int(y0), int(z0)
    for i in range(1, stages + 1):
        d = 1 if y >= 0 else -1
        x, y, z = x, y - d * arshift(x, i), z + d * linear_angle(i)
    return x, y, z


def lr_cordic(x0: int, y0: int, z0: int, stages: int = 10, range_ext_bits: int = 3) -> tuple[int, int, int]:
    """Linear rotation with i=-2,-1,0,... for range_ext_bits=3."""
    x, y, z = int(x0), int(y0), int(z0)
    for i in range(-(range_ext_bits - 1), stages - (range_ext_bits - 1)):
        d = 1 if z >= 0 else -1
        x, y, z = x, y + d * arshift(x, i), z - d * linear_angle(i)
    return x, y, z


def sigmoid(x: float | np.ndarray) -> float | np.ndarray:
    a = np.asarray(x, dtype=np.float64)
    return 1.0 / (1.0 + np.exp(-a))


def tanh(x: float | np.ndarray) -> float | np.ndarray:
    return np.tanh(np.asarray(x, dtype=np.float64))


def softmax(x: Iterable[float] | np.ndarray) -> np.ndarray:
    a = np.asarray(x, dtype=np.float64)
    e = np.exp(a - np.max(a, axis=-1, keepdims=True))
    return e / np.sum(e, axis=-1, keepdims=True)


def relu(x: float | np.ndarray) -> float | np.ndarray:
    return np.maximum(np.asarray(x, dtype=np.float64), 0.0)


def run_cross_checks(seed: int = 7, samples: int = 128) -> dict[str, bool]:
    rng = np.random.default_rng(seed)
    hr_err, lv_err, lr_err = [], [], []
    for _ in range(samples):
        # HR's textbook convergence domain is kept inside the 10-stage table.
        z = float(rng.uniform(-0.45, 0.45))
        x, y, _ = hr_cordic(int(round((1.0 / hyperbolic_gain(10)) * SCALE)), 0, int(round(z * SCALE)), 10)
        hr_err.append(max(abs(qfloat(x) - math.cosh(z)), abs(qfloat(y) - math.sinh(z))))
        den = float(rng.uniform(0.25, 1.0)); num = float(rng.uniform(-den, den))
        _, _, q = lv_cordic(int(round(den * SCALE)), int(round(num * SCALE)), stages=12)
        lv_err.append(abs(float(qfloat(q)) - num / den))
        x0 = float(rng.uniform(-0.75, 0.75)); z0 = float(rng.uniform(-7.5, 7.5)); y0 = float(rng.uniform(-0.25, 0.25))
        _, y, _ = lr_cordic(int(round(x0*SCALE)), int(round(y0*SCALE)), int(round(z0*SCALE)), 16, 3)
        lr_err.append(abs(float(qfloat(y)) - (y0 + x0*z0)))
    checks = {
        "HR vs cosh/sinh": max(hr_err) < 0.08,
        "LV vs direct division": max(lv_err) < 0.02,
        "LR vs direct multiply-add": max(lr_err) < 0.08,
        "derived activations": bool(np.allclose(softmax([0.2, -0.1, 0.7]).sum(), 1.0) and sigmoid(0) == 0.5 and tanh(0) == 0 and relu(-1) == 0),
    }
    for name, ok in checks.items(): print(f"CHECK {name}: {'PASS' if ok else 'FAIL'}")
    print(f"MAX_ERR HR={max(hr_err):.6g} LV={max(lv_err):.6g} LR={max(lr_err):.6g}")
    return checks


def generate_test_vectors(out_dir: str | Path = "rtl", count: int = 64, seed: int = 11) -> None:
    """Emit hex vectors consumed by the six CORDIC verification testbenches."""
    out = Path(out_dir); out.mkdir(parents=True, exist_ok=True); rng = np.random.default_rng(seed)
    def write(name: str, rows: list[str]): (out / name).write_text("\n".join(rows) + "\n", encoding="ascii")
    hr_rows=[]; lv_rows=[]; lr_rows=[]; wrap_rows=[]; pipe_rows=[]
    for _ in range(count):
        z=int(rng.integers(-3500,3501)); x=int(SCALE); y=0; hx,hy,hz=hr_cordic(x,y,z,1)
        hr_rows.append(f"{x & 0xffffffff:08x}{y & 0xffffffff:08x}{z & 0xffffffff:08x}{1:02x}{hx & 0xffffffff:08x}{hy & 0xffffffff:08x}{hz & 0xffffffff:08x}")
        den=int(rng.integers(2048,8193)); num=int(rng.integers(-den,den+1)); lx,ly,lz=lv_cordic(den,num,0,1)
        lv_rows.append(f"{den & 0xffffffff:08x}{num & 0xffffffff:08x}{0:08x}{1:02x}{lx & 0xffffffff:08x}{ly & 0xffffffff:08x}{lz & 0xffffffff:08x}")
        x=int(rng.integers(-6144,6145)); y=int(rng.integers(-2048,2049)); z=int(rng.integers(-61440,61441)); rx,ry,rz=lr_cordic(x,y,z,1,3)
        lr_rows.append(f"{x & 0xffffffff:08x}{y & 0xffffffff:08x}{z & 0xffffffff:08x}{((-2)&255):02x}{rx & 0xffffffff:08x}{ry & 0xffffffff:08x}{rz & 0xffffffff:08x}")
        for mode in (HR, LV, LR):
            a=int(rng.integers(-2048,2049)); b=int(rng.integers(-2048,2049)); c=int(rng.integers(-24000,24001))
            if mode==HR: a,b=SCALE,0; ox,oy,oz=hr_cordic(a,b,c,10)
            elif mode==LV: a=max(1024,abs(a)); c=0; ox,oy,oz=lv_cordic(a,b,c,10)
            else: ox,oy,oz=lr_cordic(a,b,c,10,3)
            row=f"{mode:01x}{a & 0xffffffff:08x}{b & 0xffffffff:08x}{c & 0xffffffff:08x}{ox & 0xffffffff:08x}{oy & 0xffffffff:08x}{oz & 0xffffffff:08x}"
            wrap_rows.append(row); pipe_rows.append(row)
    write("cordic_hr_stage_vectors.mem", hr_rows); write("cordic_lv_stage_vectors.mem", lv_rows); write("cordic_lr_stage_vectors.mem", lr_rows)
    lut=[]
    for mode in range(3):
        for i in range(1,13): lut.append(f"{mode:01x}{i:02x}{(atanh_angle(i) if mode==0 else linear_angle(i)) & 0xffffffff:08x}")
    write("angle_lut_vectors.mem",lut); write("cordic_iterative_vectors.mem",wrap_rows); write("cordic_pipeline_vectors.mem",pipe_rows)
    print(f"GENERATED vectors: HR/LV/LR={count} each, LUT={len(lut)} -> {out}")


if __name__ == "__main__":
    results = run_cross_checks()
    generate_test_vectors()
    raise SystemExit(0 if all(results.values()) else 1)
