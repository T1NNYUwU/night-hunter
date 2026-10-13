"""The Python port must give the same numbers as the Luau OpponentModel the game uses."""

import json
from pathlib import Path

import pytest

from app import opponent_model as om
from app.graph import load

FIXTURES = Path(__file__).parent / "fixtures"


@pytest.fixture(scope="module")
def golden():
    data = json.loads((FIXTURES / "golden_fit.json").read_text())
    data["trajs"] = [list(zip(t["nodes"], t["hunterRooms"])) for t in data["trajectories"]]
    return data


def test_graph_matches_the_game():
    g = load()
    assert g.room_count == 17 and g.node_count == 41  # 17 rooms on three levels, 18 wardrobes, 6 cloth tables
    assert g.dist[1][7] == 1  # hall up the staircase to the landing
    assert g.dist[1][13] == 3  # hall, library, study, down to the boiler room
    assert g.dist[1][16] == 5  # the crypt under the hall is a long way round
    assert g.dist[6][15] == 1  # kitchen down to cold storage
    assert g.nodes[18].kind == "hide" and g.nodes[18].room == 1
    assert g.nodes[41].kind == "hide" and g.nodes[41].room == 15  # the butcher's slab


def test_fit_matches_luau(golden):
    model = om.fit(load(), golden["trajs"], "golden")
    assert model.samples == golden["samples"]
    for key, weights in golden["weights"].items():
        for c in om.CATEGORIES:
            assert model.weights[key][c] == pytest.approx(weights[c], abs=1e-12), (key, c)


def test_log_likelihood_matches_luau(golden):
    g = load()
    learned = om.evaluate(om.fit(g, golden["trajs"]), g, golden["trajs"])
    uniform = om.evaluate(om.uniform(), g, golden["trajs"])
    assert learned["steps"] == golden["steps"]
    assert learned["logLikelihood"] == pytest.approx(golden["learnedLogLikelihood"], abs=1e-9)
    assert uniform["logLikelihood"] == pytest.approx(golden["uniformLogLikelihood"], abs=1e-9)


def test_probabilities_sum_to_one(golden):
    g = load()
    model = om.fit(g, golden["trajs"])
    for u in range(1, g.node_count + 1):
        for h in (1, 6, 16):
            _, probs = om.choices(model, g, u, h)
            assert sum(probs) == pytest.approx(1.0)


def test_params_round_trip(golden):
    model = om.fit(load(), golden["trajs"], "v-test")
    again = om.from_params(json.loads(json.dumps(model.to_params())))
    assert again is not None and again.weights == model.weights and again.version == "v-test"
    assert om.from_params({"kind": "learned", "weights": {}}) is None
