import copy
import json
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.main import create_app

FIXTURES = Path(__file__).parent / "fixtures"
GAME = {"X-Api-Key": "game-key"}
ADMIN = {"X-Api-Key": "admin-key"}


@pytest.fixture
def client(tmp_path):
    app = create_app(f"sqlite:///{tmp_path / 'test.db'}", game_key="game-key", admin_key="admin-key")
    return TestClient(app)


@pytest.fixture
def record():
    # A real night recorded in Roblox Studio (POMCP hunter, night 3).
    return json.loads((FIXTURES / "night_record.json").read_text())


def golden_nights(count_per_traj: int = 1):
    """Nights built from the simulator trajectories of the golden fixture (enough to train)."""
    data = json.loads((FIXTURES / "golden_fit.json").read_text())
    nights = []
    for i, t in enumerate(data["trajectories"] * count_per_traj):
        nights.append(
            {
                "schema": 1,
                "runId": f"run-{i:04d}-abcdef",
                "server": "test",
                "placeVersion": 1,
                "startedAt": 1_700_000_000 + i,
                "night": 1 + i % 7,
                "objective": "supplies",
                "goal": 3,
                "condition": ["rule", "pomcp"][i % 2],
                "hunterMode": "experiment",
                "playersAtStart": 1,
                "tickSeconds": 0.5,
                "events": [],
                "hunterRooms": t["hunterRooms"],
                "trajectories": {"p1": t["nodes"]},
                "outcome": ["Win", "Fail"][i % 3 == 0],
                "durationS": len(t["nodes"]) / 2,
                "progress": 1,
                "downs": i % 2,
                "hunter": {"brain": "pomcp", "avgPlanMs": 4.5, "maxPlanMs": 6.0, "plans": 3, "decisions": 20},
            }
        )
    return nights


def test_health(client):
    assert client.get("/healthz").json() == {"ok": True}


def test_store_real_record_and_ignore_duplicates(client, record):
    r = client.post("/v1/nights", json={"nights": [record]}, headers=GAME)
    assert r.status_code == 200 and r.json() == {"stored": 1, "duplicates": 0}
    r = client.post("/v1/nights", json={"nights": [record]}, headers=GAME)
    assert r.json() == {"stored": 0, "duplicates": 1}


def test_requires_game_key(client, record):
    assert client.post("/v1/nights", json={"nights": [record]}).status_code == 401
    assert client.post("/v1/nights", json={"nights": [record]}, headers={"X-Api-Key": "wrong"}).status_code == 401
    assert client.post("/v1/train", headers=GAME).status_code == 401  # game key is not admin


def test_empty_key_config_locks_endpoint(tmp_path, record):
    app = create_app(f"sqlite:///{tmp_path / 'x.db'}", game_key="", admin_key="")
    c = TestClient(app)
    assert c.post("/v1/nights", json={"nights": [record]}, headers={"X-Api-Key": ""}).status_code == 401


@pytest.mark.parametrize(
    "mutate",
    [
        lambda r: r.update(night=9),
        lambda r: r.update(outcome="Draw"),
        lambda r: r["trajectories"]["p1"].pop(),  # length no longer matches hunterRooms
        lambda r: r["trajectories"].update({"bob": r["trajectories"]["p1"]}),  # names are not allowed
        lambda r: r["trajectories"]["p1"].__setitem__(0, 999),
        lambda r: r["events"].append({"t": 1, "tick": 1, "kind": "hack", "player": "p1"}),
    ],
)
def test_rejects_bad_records(client, record, mutate):
    bad = copy.deepcopy(record)
    mutate(bad)
    assert client.post("/v1/nights", json={"nights": [bad]}, headers=GAME).status_code == 422


def test_empty_trajectories_from_roblox_are_accepted(client, record):
    # Roblox encodes an empty table as [] — a night where nobody was tracked.
    record["trajectories"] = []
    record["hunterRooms"] = []
    assert client.post("/v1/nights", json={"nights": [record]}, headers=GAME).status_code == 200


def test_rejects_huge_body(client):
    r = client.post("/v1/nights", content=b"x" * 2_100_000, headers={**GAME, "Content-Type": "application/json"})
    assert r.status_code == 413


def test_train_then_serve_model(client):
    assert client.get("/v1/params/latest").status_code == 404
    nights = golden_nights(count_per_traj=4)
    for i in range(0, len(nights), 50):
        assert client.post("/v1/nights", json={"nights": nights[i : i + 50]}, headers=GAME).status_code == 200

    result = client.post("/v1/train", headers=ADMIN).json()
    assert result["trained"] is True
    assert result["activated"] is True  # beats the uniform walk
    assert result["new"]["logLikelihood"] > result["uniform"]["logLikelihood"]

    params = client.get("/v1/params/latest").json()
    assert params["kind"] == "learned" and params["version"] == result["version"]
    assert set(params["weights"]) == {f"{k}{b}" for k in ("room", "hide") for b in range(4)}

    # Same data again: the new model is no better than the active one, so it is not activated.
    again = client.post("/v1/train", headers=ADMIN).json()
    assert again["trained"] is True
    assert client.get("/v1/params/latest").json()["version"] in (result["version"], again["version"])


def test_train_needs_enough_data(client, record):
    client.post("/v1/nights", json={"nights": [record]}, headers=GAME)
    result = client.post("/v1/train", headers=ADMIN).json()
    assert result["trained"] is False


def test_stats_and_dashboard(client):
    client.post("/v1/nights", json={"nights": golden_nights()}, headers=GAME)
    s = client.get("/v1/stats").json()
    assert s["totalNights"] == 12
    assert set(s["conditions"]) == {"rule", "pomcp"}
    pomcp = s["conditions"]["pomcp"]
    assert 0 <= pomcp["winRateCi95"][0] <= pomcp["winRate"] <= pomcp["winRateCi95"][1] <= 1
    assert "pomcp vs rule" in s["winRateTests"]
    page = client.get("/")
    assert page.status_code == 200 and "Night Hunter" in page.text
