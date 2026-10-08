"""Fit a new OpponentModel from every stored night and decide whether the game should use it.

Runs from the API (POST /v1/train) or as a daily job:  python -m app.train
Runs are split 80/20 by a hash of their run id (so all nights of one run land on the same
side). The new model is fitted on the 80% and scored on the 20% it never saw; it becomes the
ACTIVE model (the one Roblox servers download) only if it predicts the held-out players better
than the model in use now (or the uniform walk if there is none).
"""

from __future__ import annotations

import hashlib
import os
from datetime import datetime, timezone

from sqlalchemy import func, select, update
from sqlalchemy.orm import Session

from . import opponent_model as om
from .db import ModelVersion, Night, make_sessionmaker
from .graph import load as load_graph

HOLDOUT_SHARE = 0.2
MIN_STEPS = 200


def trajectories_of(payload: dict) -> list[om.Trajectory]:
    rooms = payload.get("hunterRooms") or []
    trajectories = payload.get("trajectories") or {}
    if not isinstance(trajectories, dict):
        return []
    return [list(zip(nodes, rooms)) for nodes in trajectories.values()]


def is_holdout(run_id: str) -> bool:
    return hashlib.sha256(run_id.encode()).digest()[0] < 256 * HOLDOUT_SHARE


def train(session: Session, min_steps: int = MIN_STEPS) -> dict:
    graph = load_graph()
    train_set: list[om.Trajectory] = []
    holdout_set: list[om.Trajectory] = []
    nights = session.scalars(select(Night)).all()
    for night in nights:
        (holdout_set if is_holdout(night.run_id) else train_set).extend(trajectories_of(night.payload))

    count = session.scalar(select(func.count()).select_from(ModelVersion)) or 0
    version = f"v{count + 1}-{datetime.now(timezone.utc):%Y%m%d-%H%M}"
    model = om.fit(graph, train_set, version)
    if model.samples < min_steps:
        return {"trained": False, "reason": f"only {model.samples} steps (need {min_steps})", "nights": len(nights)}

    active_row = session.scalar(select(ModelVersion).where(ModelVersion.active))
    baseline = om.from_params(active_row.params) if active_row else om.uniform()
    scored_on = "holdout" if holdout_set else "train"
    eval_set = holdout_set or train_set
    new_metrics = om.evaluate(model, graph, eval_set)
    base_metrics = om.evaluate(baseline, graph, eval_set)
    uniform_metrics = om.evaluate(om.uniform(), graph, eval_set)

    better = new_metrics["logLikelihood"] > base_metrics["logLikelihood"]
    activate = better if (holdout_set or active_row) else True
    metrics = {
        "nights": len(nights),
        "trainSteps": model.samples,
        "scoredOn": scored_on,
        "new": new_metrics,
        "baseline": {"version": baseline.version, **base_metrics},
        "uniform": uniform_metrics,
        "activated": activate,
    }
    row = ModelVersion(version=version, samples=model.samples, params=model.to_params(), metrics=metrics, active=False)
    session.add(row)
    session.flush()
    if activate:
        session.execute(update(ModelVersion).where(ModelVersion.id != row.id).values(active=False))
        row.active = True
    session.commit()
    return {"trained": True, "version": version, **metrics}


def main() -> None:
    url = os.environ.get("DATABASE_URL", "sqlite:///./nighthunter.db")
    with make_sessionmaker(url)() as session:
        result = train(session)
    print(result)


if __name__ == "__main__":
    main()
