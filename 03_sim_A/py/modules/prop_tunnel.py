# modules/prop_tunnel.py
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Tuple

import numpy as np
import pandas as pd


def clamp01(x: float) -> float:
    return float(np.clip(float(x), 0.0, 1.0))


@dataclass(frozen=True)
class TunnelConfig:
    """
    Tunnel impairment model parameters.

    Bell-shaped impairment inside tunnel (sin^2), optionally sharpened by gamma,
    then a Gaussian fade at entrances/exits.

    Output impairment b in [0,1] can drive:
      - success probability degradation
      - extra mean delay and exponential tail
    """
    x0_m: float = 1000.0
    x1_m: float = 2600.0
    transition_m: float = 200.0

    severity: float = 1.0
    b_floor: float = 0.35
    b_peak: float = 0.45
    bell_gamma: float = 1.6

    delay_extra_ms: float = 0.8
    delay_exp_scale_ms: float = 1.0

    shape: str = "sin2_gamma"

    @staticmethod
    def from_csv(path: Path) -> "TunnelConfig":
        df = pd.read_csv(path)
        if len(df) < 1:
            raise ValueError(f"Empty tunnel config: {path}")
        r = df.iloc[0]
        return TunnelConfig(
            x0_m=float(r["x0_m"]),
            x1_m=float(r["x1_m"]),
            transition_m=float(r.get("transition_m", 200.0)),
            severity=float(r.get("severity", 1.0)),
            b_floor=float(r.get("b_floor", 0.35)),
            b_peak=float(r.get("b_peak", 0.45)),
            bell_gamma=float(r.get("bell_gamma", 1.6)),
            delay_extra_ms=float(r.get("delay_extra_ms", 0.8)),
            delay_exp_scale_ms=float(r.get("delay_exp_scale_ms", 1.0)),
            shape=str(r.get("shape", "sin2_gamma")),
        )

    def to_record(self) -> dict:
        return {
            "x0_m": float(self.x0_m),
            "x1_m": float(self.x1_m),
            "transition_m": float(self.transition_m),
            "severity": float(self.severity),
            "b_floor": float(self.b_floor),
            "b_peak": float(self.b_peak),
            "bell_gamma": float(self.bell_gamma),
            "delay_extra_ms": float(self.delay_extra_ms),
            "delay_exp_scale_ms": float(self.delay_exp_scale_ms),
            "shape": str(self.shape),
        }


def tunnel_impairment_b(tx_x: float, rx_x: float, cfg: TunnelConfig) -> Tuple[float, float]:
    """
    Compute tunnel impairment b and normalized position u using mid-point x.
    Aligned with your current sim_v2x_A.py implementation.
    """
    mid_x = 0.5 * (float(tx_x) + float(rx_x))
    x0, x1 = float(cfg.x0_m), float(cfg.x1_m)
    L = max(1e-6, x1 - x0)

    u = (mid_x - x0) / L
    u_clip = float(np.clip(u, 0.0, 1.0))

    bell = float(np.sin(np.pi * u_clip) ** 2)
    if float(cfg.bell_gamma) > 1e-6:
        bell = float(bell ** float(cfg.bell_gamma))

    b_inside = float(cfg.severity) * (float(cfg.b_floor) + float(cfg.b_peak) * bell)

    if u < 0.0:
        d_to = x0 - mid_x
    elif u > 1.0:
        d_to = mid_x - x1
    else:
        d_to = 0.0

    t = float(cfg.transition_m)
    if t <= 1e-6:
        fade = 1.0 if d_to <= 0.0 else 0.0
    else:
        if d_to > 4.0 * t:
            fade = 0.0
        else:
            fade = float(np.exp(- (d_to / t) ** 2))

    b = clamp01(float(b_inside) * fade)
    return b, float(u)