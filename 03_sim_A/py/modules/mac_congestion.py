# modules/mac_congestion.py
from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

import numpy as np


@dataclass(frozen=True)
class CongestionParams:
    """
    Ultra-light congestion proxy (Gate-D), upgraded to be closer to "busy channel" reality:

    Step-1) Count local contenders within carrier-sense radius r_cs_m.
    Step-2) Convert contenders + message rate + airtime into a channel busy ratio (CBR).
    Step-3) Use both n_cs and CBR to derive:
        - collision probability p_col
        - extra queue/backoff delay (deterministic + exponential tail)

    This remains a *proxy* (not a full 802.11p/NR-V2X MAC simulation), but it captures:
      - more neighbors => higher collision / longer delay
      - higher msg_rate / larger packets / lower PHY rate => higher busy ratio => worse tail
    """
    # contender counting
    r_cs_m: float = 250.0
    min_speed_mps: float = 0.0       # optional filter for contenders (0 => no filter)

    # collision / delay shaping
    alpha_col: float = 0.06          # collision intensity
    beta_delay_ms: float = 0.8       # deterministic extra delay per extra contender (scaled by CBR)
    exp_scale_ms: float = 0.6        # exponential tail scale per extra contender (scaled by CBR)

    # airtime / busy-ratio model
    pkt_bytes: int = 300             # typical CAM/BSM payload-ish (order of 200-400B)
    phy_rate_mbps: float = 6.0       # 802.11p often 3-12 Mbps; use 6 Mbps as a common baseline
    mac_efficiency: float = 0.55     # accounts for preamble, headers, inter-frame spaces, etc.
    phy_overhead_us: float = 300.0   # coarse constant overhead (microseconds) per packet

    # how strongly busy-ratio amplifies collisions / delay
    gamma_cbr_col: float = 1.5       # collision amplification
    gamma_cbr_delay: float = 2.0     # delay amplification

    # safety caps
    cbr_cap: float = 0.95            # cap busy ratio to avoid blow-ups


def compute_airtime_s(
    pkt_bytes: int,
    phy_rate_mbps: float,
    mac_efficiency: float = 0.55,
    phy_overhead_us: float = 300.0,
) -> float:
    """
    Very rough airtime (seconds) per packet.
    payload_bits / (phy_rate * efficiency) + fixed_overhead
    """
    b = max(1, int(pkt_bytes))
    r = max(0.1, float(phy_rate_mbps)) * 1e6  # bps
    eff = float(np.clip(float(mac_efficiency), 0.05, 0.95))
    payload_s = (b * 8.0) / (r * eff)
    overhead_s = max(0.0, float(phy_overhead_us)) * 1e-6
    return float(payload_s + overhead_s)


def compute_cbr(
    n_cs: int,
    msg_rate_hz: float,
    airtime_s: float,
    cbr_cap: float = 0.95,
) -> float:
    """
    Channel Busy Ratio proxy:
      busy ~= number_of_other_contenders * msg_rate * airtime
    """
    n = max(1, int(n_cs))
    n_others = max(0, n - 1)
    rate = max(0.0, float(msg_rate_hz))
    at = max(0.0, float(airtime_s))
    busy = float(n_others) * rate * at
    return float(np.clip(busy, 0.0, float(cbr_cap)))


def p_collision_from_ncs(
    n_cs: int,
    alpha_col: float,
    cbr: Optional[float] = None,
    gamma_cbr_col: float = 1.5,
) -> float:
    """
    Collision probability proxy.
    Base: 1-exp(-a*(n-1))
    Amplify with busy-ratio when provided:
      intensity *= (1 + gamma * cbr/(1-cbr))
    """
    n = max(1, int(n_cs))
    a = max(0.0, float(alpha_col))
    base_intensity = a * (n - 1)

    if cbr is None:
        p = 1.0 - float(np.exp(-base_intensity))
        return float(np.clip(p, 0.0, 0.99))

    c = float(np.clip(float(cbr), 0.0, 0.99))
    amp = 1.0 + max(0.0, float(gamma_cbr_col)) * (c / max(1e-6, (1.0 - c)))
    p = 1.0 - float(np.exp(-base_intensity * amp))
    return float(np.clip(p, 0.0, 0.99))


def congestion_extra_delay_ms(
    rng: np.random.Generator,
    n_cs: int,
    beta_delay_ms: float,
    exp_scale_ms: float,
    cbr: Optional[float] = None,
    gamma_cbr_delay: float = 2.0,
) -> float:
    """
    Extra delay (ms) due to queue/backoff under congestion.
    Base grows with (n-1). Busy-ratio increases both deterministic and tail components.
    """
    n = max(1, int(n_cs))
    if n <= 1:
        return 0.0

    beta = max(0.0, float(beta_delay_ms))
    scale = max(0.0, float(exp_scale_ms))

    amp = 1.0
    if cbr is not None:
        c = float(np.clip(float(cbr), 0.0, 0.99))
        amp = 1.0 + max(0.0, float(gamma_cbr_delay)) * (c / max(1e-6, (1.0 - c)))

    det = beta * (n - 1) * amp
    tail = float(rng.exponential(scale=scale * (n - 1) * amp)) if scale > 1e-9 else 0.0
    return float(det + tail)


def compute_ncs_from_distances(
    dist_all: np.ndarray,
    tx_index: int,
    r_cs_m: float,
    active_mask: Optional[np.ndarray] = None,
    speed_all: Optional[np.ndarray] = None,
    min_speed_mps: float = 0.0,
) -> int:
    """
    dist_all: distance from TX to every vehicle (shape V,)
    Returns n_cs including TX itself (>=1).
    """
    V = int(dist_all.shape[0])
    if active_mask is None:
        active_mask = np.isfinite(dist_all)

    within = (dist_all <= float(r_cs_m)) & active_mask

    # exclude tx itself when counting others
    others = within.copy()
    if 0 <= int(tx_index) < V:
        others[int(tx_index)] = False

    if speed_all is not None and float(min_speed_mps) > 0.0:
        others = others & (speed_all >= float(min_speed_mps))

    n_others = int(np.sum(others))
    return 1 + n_others