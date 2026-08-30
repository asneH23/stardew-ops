"""
models.py — SQLModel-scheman (databas + API)
SQLModel kombinerar SQLAlchemy (ORM) och Pydantic (validering) i ett.
"""

from datetime import datetime
from enum import Enum
from typing import Optional

from sqlmodel import Field, SQLModel


class QuestSlot(int, Enum):
    DAILY = 1    # Daily Chore     — låg XP
    WEEKLY = 2   # Weekly Contract — medium XP
    EPIC = 3     # Epic Project    — hög XP


class QuestStatus(str, Enum):
    ACTIVE = "active"
    COMPLETED = "completed"
    REROLLED = "rerolled"


# ── Databas-tabeller ────────────────────────────────────────────────────────

class PlayerState(SQLModel, table=True):
    """En enda rad i databasen — din spel-karaktärs state."""
    id: int = Field(default=1, primary_key=True)
    total_xp: int = Field(default=0)
    current_course_id: str = Field(default="python")
    commits_total: int = Field(default=0)
    last_updated: datetime = Field(default_factory=datetime.utcnow)


class Quest(SQLModel, table=True):
    """En aktiv eller historisk quest på Quest Board."""
    id: Optional[int] = Field(default=None, primary_key=True)
    slot: int  # 1=Daily, 2=Weekly, 3=Epic
    title: str
    description: str
    xp_reward: int
    bonus_xp: int = Field(default=0)
    course_id: str
    status: str = Field(default=QuestStatus.ACTIVE)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    completed_at: Optional[datetime] = Field(default=None)


class CommitEvent(SQLModel, table=True):
    """Logg över alla GitHub-commits som gett XP."""
    id: Optional[int] = Field(default=None, primary_key=True)
    sha: str = Field(index=True)
    repo: str
    branch: str
    message: str
    course_id: Optional[str] = Field(default=None)
    xp_awarded: int = Field(default=0)
    quest_completed_id: Optional[int] = Field(default=None)
    received_at: datetime = Field(default_factory=datetime.utcnow)


# ── API request/response-scheman (ej lagrade i DB) ──────────────────────────

class FakeCommitRequest(SQLModel):
    """Body för POST /dev/fake-commit"""
    message: str
    branch: str = "main"
    repo: str = "stardew-ops-study"
    sha: str = "deadbeef00"


class StateResponse(SQLModel):
    """Vad Godot pollar från GET /state"""
    total_xp: int
    current_course_id: str
    current_course_name: str
    current_course_xp_total: int
    current_course_xp_earned: int
    commits_total: int
    quests: list[dict]


class WebhookResponse(SQLModel):
    xp_awarded: int
    course_id: str
    course_name: str
    message: str
    quest_completed: Optional[str] = None
