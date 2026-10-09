"""Database tables. SQLite by default (one file, nothing to install); set DATABASE_URL to use
PostgreSQL in production, e.g. postgresql+psycopg://user:pass@host/nighthunter."""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import JSON, Boolean, DateTime, Float, Integer, String, UniqueConstraint, create_engine
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, sessionmaker


class Base(DeclarativeBase):
    pass


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Night(Base):
    """One night played in Roblox. The columns are what the stats need; `payload` keeps the
    whole record (trajectories, events) for training and for later analyses."""

    __tablename__ = "nights"
    __table_args__ = (UniqueConstraint("run_id", "night", "started_at", name="uq_night"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    run_id: Mapped[str] = mapped_column(String(64), index=True)
    night: Mapped[int] = mapped_column(Integer, index=True)
    started_at: Mapped[int] = mapped_column(Integer)
    server: Mapped[str] = mapped_column(String(64))
    place_version: Mapped[int] = mapped_column(Integer)
    objective: Mapped[str] = mapped_column(String(16))
    condition: Mapped[str] = mapped_column(String(32), index=True)
    hunter_mode: Mapped[str] = mapped_column(String(16), index=True)
    outcome: Mapped[str] = mapped_column(String(16))
    won: Mapped[bool] = mapped_column(Boolean)
    duration_s: Mapped[float] = mapped_column(Float)
    progress: Mapped[int] = mapped_column(Integer)
    goal: Mapped[int] = mapped_column(Integer)
    downs: Mapped[int] = mapped_column(Integer)
    players: Mapped[int] = mapped_column(Integer)
    avg_plan_ms: Mapped[float] = mapped_column(Float)
    max_plan_ms: Mapped[float] = mapped_column(Float)
    received_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    payload: Mapped[dict] = mapped_column(JSON)


class ModelVersion(Base):
    """An OpponentModel fitted from stored trajectories. Exactly one is active at a time:
    the one Roblox servers download at start-up."""

    __tablename__ = "model_versions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    version: Mapped[str] = mapped_column(String(64), unique=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    samples: Mapped[int] = mapped_column(Integer)
    params: Mapped[dict] = mapped_column(JSON)
    metrics: Mapped[dict] = mapped_column(JSON)
    active: Mapped[bool] = mapped_column(Boolean, default=False, index=True)


def normalize_url(url: str) -> str:
    """Neon / Render hand out postgres:// or postgresql:// URLs; SQLAlchemy needs the driver."""
    for prefix in ("postgres://", "postgresql://"):
        if url.startswith(prefix):
            return "postgresql+psycopg://" + url[len(prefix) :]
    return url


def make_sessionmaker(database_url: str):
    database_url = normalize_url(database_url)
    connect_args = {"check_same_thread": False} if database_url.startswith("sqlite") else {}
    # pool_pre_ping: Neon closes idle connections when it scales to zero.
    engine = create_engine(database_url, connect_args=connect_args, pool_pre_ping=True)
    Base.metadata.create_all(engine)
    return sessionmaker(bind=engine, expire_on_commit=False)
