"""What the game is allowed to send. Anything else is rejected with 422 before it reaches the DB."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

MAX_TICKS = 1000  # a 180 s night is 360 ticks at 0.5 s
MAX_NODE = 64
MAX_ROOM = 64


class HunterStats(BaseModel):
    brain: str = Field(max_length=32)
    modelVersion: str | None = Field(default=None, max_length=64)
    decisions: int = Field(default=0, ge=0)
    avgDecisionMs: float = Field(default=0, ge=0)
    plans: int = Field(default=0, ge=0)
    avgPlanMs: float = Field(default=0, ge=0)
    maxPlanMs: float = Field(default=0, ge=0)


class Event(BaseModel):
    model_config = ConfigDict(extra="allow")

    t: float = Field(ge=0)
    tick: int = Field(ge=0)
    kind: Literal["down", "revive", "objective", "item", "escape"]
    player: str | None = Field(default=None, pattern=r"^p\d{1,2}$")

    @model_validator(mode="after")
    def small_extras(self):
        extra = self.model_extra or {}
        if len(extra) > 4 or any(not isinstance(v, (int, float, str)) or (isinstance(v, str) and len(v) > 32) for v in extra.values()):
            raise ValueError("event extras must be a few short numbers or strings")
        return self


class NightRecord(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    schema_version: Literal[1] = Field(alias="schema")
    runId: str = Field(min_length=8, max_length=64)
    server: str = Field(max_length=64)
    placeVersion: int = Field(ge=0)
    startedAt: int = Field(ge=0)
    night: int = Field(ge=1, le=7)
    objective: Literal["supplies", "power", "escape"]
    goal: int = Field(ge=0, le=50)
    condition: str = Field(min_length=1, max_length=32)
    hunterMode: Literal["story", "experiment"]
    playersAtStart: int = Field(ge=0, le=8)
    playersAtEnd: int = Field(default=0, ge=0, le=8)
    tickSeconds: float = Field(gt=0, le=5)
    events: list[Event] = Field(default_factory=list, max_length=500)
    hunterRooms: list[int] = Field(default_factory=list, max_length=MAX_TICKS)
    trajectories: dict[str, list[int]] = Field(default_factory=dict)
    outcome: Literal["Win", "Fail", "Complete"]
    durationS: float = Field(ge=0, le=3600)
    progress: int = Field(ge=0, le=50)
    downs: int = Field(default=0, ge=0, le=100)
    hunter: HunterStats

    @field_validator("trajectories", mode="before")
    @classmethod
    def empty_list_is_empty_dict(cls, value):
        # Roblox's JSONEncode turns an empty table into [] — that means "no players tracked".
        return {} if value == [] else value

    @field_validator("hunterRooms")
    @classmethod
    def rooms_in_range(cls, rooms: list[int]) -> list[int]:
        if any(r < 0 or r > MAX_ROOM for r in rooms):
            raise ValueError("hunter room out of range")
        return rooms

    @model_validator(mode="after")
    def trajectories_match_ticks(self):
        if len(self.trajectories) > 8:
            raise ValueError("at most 8 players per night")
        ticks = len(self.hunterRooms)
        for slot, nodes in self.trajectories.items():
            if not slot.startswith("p") or not slot[1:].isdigit() or len(slot) > 3:
                raise ValueError(f"bad player slot {slot!r}")
            if len(nodes) != ticks:
                raise ValueError(f"trajectory {slot} has {len(nodes)} ticks, expected {ticks}")
            if any(n < 0 or n > MAX_NODE for n in nodes):
                raise ValueError(f"trajectory {slot} has a node out of range")
        return self

    @property
    def won(self) -> bool:
        return self.outcome in ("Win", "Complete")


class NightBatch(BaseModel):
    nights: list[NightRecord] = Field(min_length=1, max_length=50)
