"""
Derive harsh braking / acceleration counts and a simple driving score from OBD-style samples.
Assumes rows are ordered by time ascending.
"""

from __future__ import annotations

from collections.abc import Sequence

from app import models


def analyze_samples(samples: Sequence[models.VehicleData]) -> tuple[int, int, int]:
    if len(samples) < 2:
        return 100, 0, 0

    harsh_brake = 0
    harsh_accel = 0
    ordered = sorted(samples, key=lambda r: r.timestamp)

    for prev, cur in zip(ordered, ordered[1:], strict=False):
        dt = (cur.timestamp - prev.timestamp).total_seconds()
        if dt <= 0:
            continue
        dv = cur.speed - prev.speed
        rate = dv / dt
        if rate <= -8:
            harsh_brake += 1
        elif rate >= 6:
            harsh_accel += 1

    penalty = min(60, harsh_brake * 8 + harsh_accel * 5)
    score = max(40, 100 - penalty)
    return score, harsh_brake, harsh_accel
