import pytest

from app.stats import two_proportion_z, wilson


def test_wilson_known_values():
    lo, hi = wilson(81, 100)
    assert lo == pytest.approx(0.722, abs=1e-3) and hi == pytest.approx(0.875, abs=1e-3)
    assert wilson(0, 10)[0] == 0.0 and wilson(10, 10)[1] == 1.0
    assert wilson(0, 0) == (0.0, 1.0)


def test_two_proportion_z():
    # Sim result: POMCP catches 163/200 hiders, belief 101/200.
    z, p = two_proportion_z(163, 200, 101, 200)
    assert z == pytest.approx(6.54, abs=0.02) and p < 1e-9
    z, p = two_proportion_z(50, 100, 50, 100)
    assert z == 0 and p == pytest.approx(1.0)


def test_database_url_normalized_for_psycopg():
    from app.db import normalize_url

    assert normalize_url("postgres://u:p@h/db") == "postgresql+psycopg://u:p@h/db"
    assert normalize_url("postgresql://u:p@h/db?sslmode=require") == "postgresql+psycopg://u:p@h/db?sslmode=require"
    assert normalize_url("sqlite:///x.db") == "sqlite:///x.db"
