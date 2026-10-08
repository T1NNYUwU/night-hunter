"""Night Hunter telemetry backend.

  POST /v1/nights          game servers send finished nights (X-Api-Key: GAME_API_KEY)
  GET  /v1/params/latest   game servers download the active OpponentModel at start-up
  POST /v1/train           fit a new model from stored nights (X-Api-Key: ADMIN_API_KEY)
  GET  /v1/stats           win rate per hunter condition with 95% CIs and z-tests vs "rule"
  GET  /                   a small dashboard of the same numbers
  GET  /healthz

Settings (environment): DATABASE_URL, GAME_API_KEY, ADMIN_API_KEY, MAX_BODY_BYTES.
Run:  uvicorn app.main:create_app --factory --port 8000
"""

from __future__ import annotations

import hmac
import html
import os
from collections import defaultdict

from fastapi import Depends, FastAPI, Header, HTTPException, Request
from fastapi.responses import HTMLResponse, JSONResponse
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from . import stats as st
from .db import ModelVersion, Night, make_sessionmaker
from .schemas import NightBatch
from .train import train as run_training

BASELINE = "rule"


def create_app(database_url: str | None = None, game_key: str | None = None, admin_key: str | None = None) -> FastAPI:
    database_url = database_url or os.environ.get("DATABASE_URL", "sqlite:///./nighthunter.db")
    game_key = game_key if game_key is not None else os.environ.get("GAME_API_KEY", "")
    admin_key = admin_key if admin_key is not None else os.environ.get("ADMIN_API_KEY", "")
    max_body = int(os.environ.get("MAX_BODY_BYTES", 2_000_000))
    Session = make_sessionmaker(database_url)

    app = FastAPI(title="Night Hunter backend", version="1.0")

    def get_session():
        with Session() as session:
            yield session

    def require(expected: str):
        def check(x_api_key: str | None = Header(default=None)):
            # An empty configured key means "locked", never "open".
            if not expected or not x_api_key or not hmac.compare_digest(x_api_key, expected):
                raise HTTPException(status_code=401, detail="bad or missing X-Api-Key")

        return check

    @app.middleware("http")
    async def limit_body(request: Request, call_next):
        length = request.headers.get("content-length")
        if length and length.isdigit() and int(length) > max_body:
            return JSONResponse({"detail": "body too large"}, status_code=413)
        return await call_next(request)

    @app.get("/healthz")
    def healthz():
        return {"ok": True}

    @app.post("/v1/nights", dependencies=[Depends(require(game_key))])
    def post_nights(batch: NightBatch, session=Depends(get_session)):
        stored, duplicates = 0, 0
        for record in batch.nights:
            row = Night(
                run_id=record.runId,
                night=record.night,
                started_at=record.startedAt,
                server=record.server,
                place_version=record.placeVersion,
                objective=record.objective,
                condition=record.condition,
                hunter_mode=record.hunterMode,
                outcome=record.outcome,
                won=record.won,
                duration_s=record.durationS,
                progress=record.progress,
                goal=record.goal,
                downs=record.downs,
                players=record.playersAtStart,
                avg_plan_ms=record.hunter.avgPlanMs,
                max_plan_ms=record.hunter.maxPlanMs,
                payload=record.model_dump(mode="json", by_alias=True),
            )
            session.add(row)
            try:
                session.commit()
                stored += 1
            except IntegrityError:
                # The game retries a batch after a timeout: the same night may arrive twice.
                session.rollback()
                duplicates += 1
        return {"stored": stored, "duplicates": duplicates}

    @app.get("/v1/params/latest")
    def params_latest(session=Depends(get_session)):
        row = session.scalar(select(ModelVersion).where(ModelVersion.active))
        if not row:
            raise HTTPException(status_code=404, detail="no model trained yet")
        return row.params

    @app.post("/v1/train", dependencies=[Depends(require(admin_key))])
    def post_train(session=Depends(get_session)):
        return run_training(session)

    def compute_stats(session) -> dict:
        nights = session.scalars(select(Night)).all()
        groups: dict[str, list[Night]] = defaultdict(list)
        for n in nights:
            groups[n.condition].append(n)
        conditions = {}
        for name, rows in sorted(groups.items()):
            wins = sum(r.won for r in rows)
            lo, hi = st.wilson(wins, len(rows))
            conditions[name] = {
                "nights": len(rows),
                "runs": len({r.run_id for r in rows}),
                "wins": wins,
                "winRate": wins / len(rows),
                "winRateCi95": [lo, hi],
                "downsPerNight": st.mean([r.downs for r in rows]),
                "avgDurationS": st.mean([r.duration_s for r in rows]),
                "avgPlanMs": st.mean([r.avg_plan_ms for r in rows if r.avg_plan_ms > 0]),
                "maxPlanMs": max((r.max_plan_ms for r in rows), default=0),
                "byNight": {
                    str(k): {"nights": len(v), "wins": sum(r.won for r in v)}
                    for k, v in sorted(_by(rows, lambda r: r.night).items())
                },
            }
        tests = {}
        base = conditions.get(BASELINE)
        if base:
            for name, c in conditions.items():
                if name != BASELINE:
                    z, p = st.two_proportion_z(c["wins"], c["nights"], base["wins"], base["nights"])
                    tests[f"{name} vs {BASELINE}"] = {"z": z, "p": p}
        active = session.scalar(select(ModelVersion).where(ModelVersion.active))
        return {
            "totalNights": len(nights),
            "conditions": conditions,
            "winRateTests": tests,
            "activeModel": {"version": active.version, "samples": active.samples, "metrics": active.metrics} if active else None,
        }

    @app.get("/v1/stats")
    def get_stats(session=Depends(get_session)):
        return compute_stats(session)

    @app.get("/", response_class=HTMLResponse)
    def dashboard(session=Depends(get_session)):
        s = compute_stats(session)
        rows = "".join(
            "<tr><td>{}</td><td>{}</td><td>{}</td><td>{:.0%} ({:.0%}–{:.0%})</td><td>{}</td><td>{}</td></tr>".format(
                html.escape(name),
                c["nights"],
                c["runs"],
                c["winRate"],
                *c["winRateCi95"],
                f"{c['downsPerNight']:.2f}" if c["downsPerNight"] is not None else "-",
                f"{c['avgPlanMs']:.2f}" if c["avgPlanMs"] is not None else "-",
            )
            for name, c in s["conditions"].items()
        )
        tests = "".join(
            f"<li>{html.escape(k)}: z = {v['z']:.2f}, p = {v['p']:.4f}</li>" for k, v in s["winRateTests"].items()
        )
        model = s["activeModel"]
        model_line = (
            f"{html.escape(model['version'])} — {model['samples']} steps" if model else "none yet (game uses its built-in model)"
        )
        return f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>Night Hunter Stats</title>
<style>
:root{{--bg:#111014;--fg:#e8e4de;--muted:#9a948c;--line:#2c2a30;--accent:#c83232}}
body{{background:var(--bg);color:var(--fg);font:15px/1.5 system-ui,sans-serif;margin:0;padding:24px 16px;max-width:900px;margin:auto}}
h1{{color:var(--accent);font-size:24px}} table{{border-collapse:collapse;width:100%}}
td,th{{border-bottom:1px solid var(--line);padding:6px 8px;text-align:left}} th{{color:var(--muted);font-weight:600}}
.wrap{{overflow-x:auto}} small{{color:var(--muted)}}
</style></head><body>
<h1>7 Nights Hunter — playtest stats</h1>
<p><small>{s['totalNights']} nights recorded · player win rate per hunter condition (95% Wilson CI)</small></p>
<div class="wrap"><table><tr><th>Hunter</th><th>Nights</th><th>Runs</th><th>Players win</th><th>Downs / night</th><th>Plan ms</th></tr>{rows}</table></div>
<h2>Tests vs {BASELINE}</h2><ul>{tests or '<li>needs nights from the rule condition</li>'}</ul>
<h2>Opponent model</h2><p>{model_line}</p>
</body></html>"""

    return app


def _by(rows, key):
    out = defaultdict(list)
    for r in rows:
        out[key(r)].append(r)
    return out
