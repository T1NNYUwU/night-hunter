"""Python port of src/shared/OpponentModel.luau (fit / prob / evaluate).

The game samples from the model; the backend only FITS and SCORES it, so only those parts are
ported. tests/test_opponent_model.py checks this port against weights fitted by the Luau code
(tests/fixtures/golden_fit.json), so the two cannot silently drift apart.

A trajectory is a list of (node, hunter_room) per 0.5 s tick for one player; node 0 = not in
play (downed, not joined yet, left).
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field

from .graph import HouseGraph

CATEGORIES = ("stay", "toward", "away", "side", "hide", "unhide")
BANDS = 4
PRIOR_STRENGTH = 20
MOVE_PROB_ROOM = 0.35
MOVE_PROB_HIDE = 0.08

Trajectory = list[tuple[int, int]]


def context_key(kind: str, hunter_dist: int) -> str:
    return f"{kind}{min(hunter_dist, BANDS - 1)}"


def all_context_keys() -> list[str]:
    return [f"{kind}{b}" for kind in ("room", "hide") for b in range(BANDS)]


def category(graph: HouseGraph, u: int, v: int, hunter_room: int) -> str | None:
    if u == v:
        return "stay"
    nu, nv = graph.nodes[u], graph.nodes[v]
    if nu.kind == "room" and nv.kind == "hide":
        return "hide"
    if nu.kind == "hide" and nv.kind == "room":
        return "unhide"
    if nu.kind == "room" and nv.kind == "room":
        du, dv = graph.dist[hunter_room][nu.room], graph.dist[hunter_room][nv.room]
        return "toward" if dv < du else "away" if dv > du else "side"
    return None


def prior_weights(kind: str) -> dict[str, float]:
    if kind == "hide":
        return {"stay": 1 - MOVE_PROB_HIDE, "unhide": MOVE_PROB_HIDE}
    each = MOVE_PROB_ROOM / 2.5
    return {"stay": 1 - MOVE_PROB_ROOM, "toward": each, "away": each, "side": each, "hide": each}


@dataclass
class Model:
    kind: str  # "uniform" | "learned"
    version: str
    samples: int = 0
    weights: dict[str, dict[str, float]] = field(default_factory=dict)

    def to_params(self) -> dict:
        """The JSON shape OpponentModel.fromParams (Luau) accepts."""
        return {"kind": self.kind, "version": self.version, "samples": self.samples, "weights": self.weights}


def uniform() -> Model:
    return Model(kind="uniform", version="uniform")


def _valid_step(graph: HouseGraph, u: int, v: int, h: int) -> bool:
    n = graph.node_count
    return 0 < u <= n and 0 < v <= n and 0 < h <= graph.room_count


def fit(graph: HouseGraph, trajectories: list[Trajectory], version: str = "local") -> Model:
    """Per context, weight[c] = (times c was chosen + a*prior) / (times c was possible + a)."""
    chosen = {k: {c: 0 for c in CATEGORIES} for k in all_context_keys()}
    avail = {k: {c: 0 for c in CATEGORIES} for k in all_context_keys()}
    samples = 0
    for traj in trajectories:
        for (u, h), (v, _) in zip(traj, traj[1:]):
            if not _valid_step(graph, u, v, h):
                continue
            c = category(graph, u, v, h)
            if c is None:
                continue
            nu = graph.nodes[u]
            key = context_key(nu.kind, graph.dist[h][nu.room])
            chosen[key][c] += 1
            avail[key]["stay"] += 1
            seen = {"stay"}
            for w in graph.neighbors[u]:
                cw = category(graph, u, w, h)
                if cw is not None and cw not in seen:
                    seen.add(cw)
                    avail[key][cw] += 1
            samples += 1

    weights: dict[str, dict[str, float]] = {}
    alpha = PRIOR_STRENGTH
    for key, counts in chosen.items():
        prior = prior_weights("hide" if key.startswith("hide") else "room")
        weights[key] = {
            c: (counts[c] + alpha * prior.get(c, 0)) / (avail[key][c] + alpha) for c in CATEGORIES
        }
    return Model(kind="learned", version=version, samples=samples, weights=weights)


def choices(model: Model, graph: HouseGraph, u: int, h: int) -> tuple[list[int], list[float]]:
    """Possible next nodes for a player at u (hunter in room h) and their probabilities."""
    nodes, probs = [u], []
    if model.kind == "uniform":
        options = graph.neighbors[u]
        move = MOVE_PROB_HIDE if graph.nodes[u].kind == "hide" else MOVE_PROB_ROOM
        probs.append(1 - move)
        for v in options:
            nodes.append(v)
            probs.append(move / len(options))
    else:
        nu = graph.nodes[u]
        w = model.weights[context_key(nu.kind, graph.dist[h][nu.room])]
        groups: dict[str, list[int]] = {}
        for v in graph.neighbors[u]:
            c = category(graph, u, v, h)
            if c is not None:
                groups.setdefault(c, []).append(v)
        total = w["stay"] + sum(w[c] for c in groups)
        probs.append(w["stay"] / total)
        for c, members in groups.items():
            for v in members:
                nodes.append(v)
                probs.append(w[c] / total / len(members))
    s = sum(probs)
    return nodes, [p / s for p in probs]


def prob(model: Model, graph: HouseGraph, u: int, v: int, h: int) -> float:
    nodes, probs = choices(model, graph, u, h)
    for node, p in zip(nodes, probs):
        if node == v:
            return p
    return 0.0


def evaluate(model: Model, graph: HouseGraph, trajectories: list[Trajectory]) -> dict:
    """Average log-likelihood per step (higher is better) and next-move accuracy over moves."""
    ll, steps, moves, hits = 0.0, 0, 0, 0
    for traj in trajectories:
        for (u, h), (v, _) in zip(traj, traj[1:]):
            if not _valid_step(graph, u, v, h) or category(graph, u, v, h) is None:
                continue
            ll += math.log(max(prob(model, graph, u, v, h), 1e-6))
            steps += 1
            if u != v:
                moves += 1
                nodes, probs = choices(model, graph, u, h)
                best = max(range(1, len(nodes)), key=lambda i: probs[i])
                hits += nodes[best] == v
    return {
        "logLikelihood": ll / steps if steps else 0.0,
        "moveAccuracy": hits / moves if moves else 0.0,
        "steps": steps,
        "moves": moves,
    }


def from_params(params: dict) -> Model | None:
    if not isinstance(params, dict) or params.get("kind") != "learned":
        return None
    weights = params.get("weights")
    if not isinstance(weights, dict):
        return None
    for key in all_context_keys():
        w = weights.get(key)
        if not isinstance(w, dict) or any(not isinstance(w.get(c), (int, float)) for c in CATEGORIES):
            return None
    return Model("learned", str(params.get("version", "remote")), int(params.get("samples", 0)), weights)
