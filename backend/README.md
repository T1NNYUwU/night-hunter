# Night Hunter backend

Receives one record per night from the Roblox game, fits the hunter's **opponent model** (how
real players move) from the recorded trajectories, serves the model back to game servers, and
reports win rates per hunter condition for the playtest.

```
Roblox server ──POST /v1/nights──▶ FastAPI ──▶ DB (SQLite / PostgreSQL)
      ▲                               │
      └──GET /v1/params/latest────────┘◀── POST /v1/train (daily job or admin)
```

## Run locally

```bash
uv sync --group dev
uv run pytest
GAME_API_KEY=dev-game ADMIN_API_KEY=dev-admin uv run uvicorn app.main:create_app --factory --port 8000
```

With PostgreSQL: `GAME_API_KEY=... ADMIN_API_KEY=... docker compose up --build`.

## Endpoints

| Method | Path | Who | What |
|---|---|---|---|
| POST | `/v1/nights` | game (`X-Api-Key: GAME_API_KEY`) | store up to 50 nights; duplicates (same run/night/start) are ignored |
| GET | `/v1/params/latest` | game | the active opponent model (404 = none yet; the game keeps its built-in one) |
| POST | `/v1/train` | admin (`X-Api-Key: ADMIN_API_KEY`) | fit on 80% of runs, score on the other 20%, activate only if better |
| GET | `/v1/stats` | anyone | player win rate per condition, 95% Wilson CI, z-test vs `rule` |
| GET | `/` | anyone | the same as a small dashboard |

Daily training job (cron, Render cron, GitHub Action…): `uv run python -m app.train`.

## Connect the game

1. Deploy this somewhere with HTTPS (Roblox servers cannot reach `localhost`).
2. In Studio: Game Settings → Security → **Allow HTTP Requests**.
3. Add a secret `nighthunter_api_key` = your `GAME_API_KEY` (Game Settings → Security → Secrets).
   For Studio-only testing you can instead set the ServerStorage attribute `TelemetryKey`.
4. Set the ServerStorage attribute `TelemetryUrl` to the deployed URL.
5. Optional: ServerStorage attribute `HunterMode = "experiment"` for the A/B playtest.

## Data and privacy

No Roblox user ids or names are sent. Players are `p1`..`p4` inside one run; a run id is a
random GUID. Each night holds the graph node of every player every 0.5 s (41 possible nodes),
the hunter's room, and a few events (down, revive, objective, item, escape).

## Checks that keep the game and the backend in sync

`tests/test_opponent_model.py` compares the Python fit with weights fitted by the Luau code in
Roblox (`tests/fixtures/golden_fit.json`), and `app/house_graph.json` is exported from
`HouseGraph.luau`. If the house layout changes, export both again.
