"""Reproducible stage-count error sweep using cordic_golden_model."""
from __future__ import annotations
import numpy as np
from cordic_golden_model import SCALE, hr_cordic, lv_cordic, lr_cordic, qfloat, hyperbolic_gain


def main(samples: int = 1000, seed: int = 1234) -> None:
    rng = np.random.default_rng(seed)
    hr = rng.uniform(-0.45, 0.45, samples)
    den = rng.uniform(0.25, 1.0, samples); num = rng.uniform(-1.0, 1.0, samples) * den
    lr_x = rng.uniform(-0.75, 0.75, samples); lr_z = rng.uniform(-7.5, 7.5, samples); lr_y = rng.uniform(-0.25,0.25,samples)
    print(f"Monte Carlo seed={seed} samples={samples}")
    print("stages | HR_MAE HR_MSE | LV_MAE LV_MSE | LR_MAE LR_MSE")
    for stages in range(4, 17):
        hr_e=[];lv_e=[];lr_e=[]
        for a,b,c in zip(hr,den,num):
            x0=int(round((1.0/hyperbolic_gain(stages))*SCALE)); x,y,_=hr_cordic(x0,0,int(round(a*SCALE)),stages)
            hr_e.append(max(abs(float(qfloat(x))-np.cosh(a)),abs(float(qfloat(y))-np.sinh(a))))
        for a,b,c in zip(hr,den,num):
            _,_,q=lv_cordic(int(round(b*SCALE)),int(round(c*SCALE)),stages=stages);lv_e.append(float(qfloat(q))-c/b)
        for a,b,c in zip(lr_x,lr_y,lr_z):
            _,q,_=lr_cordic(int(round(a*SCALE)),int(round(b*SCALE)),int(round(c*SCALE)),stages,3);lr_e.append(float(qfloat(q))-(b+a*c))
        print(f"{stages:6d} | {np.mean(np.abs(hr_e)):.6g} {np.mean(np.square(hr_e)):.6g} | {np.mean(np.abs(lv_e)):.6g} {np.mean(np.square(lv_e)):.6g} | {np.mean(np.abs(lr_e)):.6g} {np.mean(np.square(lr_e)):.6g}")


if __name__ == "__main__":
    main()
