"""Small, dependency-free statistics for comparing hunter conditions."""

from __future__ import annotations

import math


def wilson(k: int, n: int, z: float = 1.96) -> tuple[float, float]:
    """95% Wilson score interval for a proportion k/n (well-behaved for small n and 0%/100%)."""
    if n == 0:
        return (0.0, 1.0)
    p = k / n
    denom = 1 + z * z / n
    centre = (p + z * z / (2 * n)) / denom
    half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / denom
    return (max(0.0, centre - half), min(1.0, centre + half))


def two_proportion_z(k1: int, n1: int, k2: int, n2: int) -> tuple[float, float]:
    """Two-sided z-test for p1 == p2 (pooled). Returns (z, p-value)."""
    if n1 == 0 or n2 == 0:
        return (0.0, 1.0)
    pooled = (k1 + k2) / (n1 + n2)
    se = math.sqrt(pooled * (1 - pooled) * (1 / n1 + 1 / n2))
    if se == 0:
        return (0.0, 1.0)
    z = (k1 / n1 - k2 / n2) / se
    return (z, math.erfc(abs(z) / math.sqrt(2)))


def mean(values: list[float]) -> float | None:
    return sum(values) / len(values) if values else None
