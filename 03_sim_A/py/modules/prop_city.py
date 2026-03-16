# modules/prop_city.py
from __future__ import annotations

from typing import Iterable, Protocol, Tuple
import numpy as np


class RectLike(Protocol):
    x_min: float
    x_max: float
    y_min: float
    y_max: float


def clamp01(x: float) -> float:
    return float(np.clip(float(x), 0.0, 1.0))


def segment_intersects_rect(ax, ay, bx, by, rect: RectLike) -> bool:
    ax, ay, bx, by = map(float, [ax, ay, bx, by])
    rx0, rx1 = float(rect.x_min), float(rect.x_max)
    ry0, ry1 = float(rect.y_min), float(rect.y_max)

    seg_xmin, seg_xmax = (ax, bx) if ax <= bx else (bx, ax)
    seg_ymin, seg_ymax = (ay, by) if ay <= by else (by, ay)
    if seg_xmax < rx0 or seg_xmin > rx1 or seg_ymax < ry0 or seg_ymin > ry1:
        return False

    # endpoint inside rect
    if (rx0 <= ax <= rx1 and ry0 <= ay <= ry1) or (rx0 <= bx <= rx1 and ry0 <= by <= ry1):
        return True

    def ccw(x1, y1, x2, y2, x3, y3):
        return (y3 - y1) * (x2 - x1) > (y2 - y1) * (x3 - x1)

    def intersect(x1, y1, x2, y2, x3, y3, x4, y4):
        return ccw(x1, y1, x3, y3, x4, y4) != ccw(x2, y2, x3, y3, x4, y4) and \
               ccw(x1, y1, x2, y2, x3, y3) != ccw(x1, y1, x2, y2, x4, y4)

    edges = [
        (rx0, ry0, rx1, ry0),
        (rx1, ry0, rx1, ry1),
        (rx1, ry1, rx0, ry1),
        (rx0, ry1, rx0, ry0),
    ]
    for (x3, y3, x4, y4) in edges:
        if intersect(ax, ay, bx, by, x3, y3, x4, y4):
            return True
    return False


def segment_to_rect_min_distance(ax, ay, bx, by, rect: RectLike) -> float:
    ax, ay, bx, by = map(float, [ax, ay, bx, by])
    rx0, rx1 = float(rect.x_min), float(rect.x_max)
    ry0, ry1 = float(rect.y_min), float(rect.y_max)

    if segment_intersects_rect(ax, ay, bx, by, rect):
        return 0.0

    def point_segment_dist(px, py, x1, y1, x2, y2) -> float:
        vx, vy = x2 - x1, y2 - y1
        wx, wy = px - x1, py - y1
        c1 = vx * wx + vy * wy
        if c1 <= 0:
            return float(np.hypot(px - x1, py - y1))
        c2 = vx * vx + vy * vy
        if c2 <= c1:
            return float(np.hypot(px - x2, py - y2))
        t = c1 / c2
        projx, projy = x1 + t * vx, y1 + t * vy
        return float(np.hypot(px - projx, py - projy))

    def point_rect_dist(px, py) -> float:
        dx = 0.0
        if px < rx0:
            dx = rx0 - px
        elif px > rx1:
            dx = px - rx1
        dy = 0.0
        if py < ry0:
            dy = ry0 - py
        elif py > ry1:
            dy = py - ry1
        return float(np.hypot(dx, dy))

    corners = [(rx0, ry0), (rx0, ry1), (rx1, ry0), (rx1, ry1)]
    d = min(point_rect_dist(ax, ay), point_rect_dist(bx, by))
    for (cx, cy) in corners:
        d = min(d, point_segment_dist(cx, cy, ax, ay, bx, by))
    return float(d)


def blockage_strength_with_dmin(
    ax: float,
    ay: float,
    bx: float,
    by: float,
    buildings: Iterable[RectLike],
    transition_m: float,
) -> Tuple[float, float]:
    blds = list(buildings) if buildings is not None else []
    if not blds:
        return 0.0, float("inf")

    d_min = float("inf")
    for rect in blds:
        d = segment_to_rect_min_distance(ax, ay, bx, by, rect)
        if d < d_min:
            d_min = d
            if d_min == 0.0:
                break

    t = float(transition_m)
    if t <= 1e-6:
        b = 1.0 if d_min == 0.0 else 0.0
        return clamp01(b), float(d_min)

    b = float(np.exp(- (d_min / t) ** 2))
    return clamp01(b), float(d_min)


def p_success_los(distance_m: float) -> float:
    d0 = 60.0
    slope = 0.045
    p = 1.0 / (1.0 + np.exp(slope * (float(distance_m) - d0)))
    return float(np.clip(p, 0.001, 0.999))


def p_success_nlos(distance_m: float) -> float:
    d0 = 40.0
    slope = 0.055
    p = 1.0 / (1.0 + np.exp(slope * (float(distance_m) - d0)))
    p *= 0.75
    return float(np.clip(p, 0.001, 0.999))


def refl_gain_db(d_min_m: float, b: float, gmax_db: float, d0_m: float) -> float:
    if (not np.isfinite(d_min_m)) or float(d0_m) <= 1e-9 or float(gmax_db) <= 1e-9:
        return 0.0
    return float(float(gmax_db) * np.exp(-float(d_min_m) / float(d0_m)) * float(b))