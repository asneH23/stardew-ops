"""
database.py — SQLite-setup med SQLModel
Filen stardew_ops.db skapas automatiskt vid första start.
"""

import os
from sqlmodel import SQLModel, Session, create_engine

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./stardew_ops.db")

# connect_args behövs för SQLite + FastAPI (threading)
engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False},
    echo=False,
)


def create_db_and_tables() -> None:
    """Skapar alla tabeller om de inte finns. Körs vid app-start."""
    SQLModel.metadata.create_all(engine)


def get_session():
    """FastAPI dependency — yield:ar en DB-session per request."""
    with Session(engine) as session:
        yield session
