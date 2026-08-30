"""
database.py — Databas-setup med SQLModel
Stöder både SQLite (lokal dev) och PostgreSQL (Railway produktion).
Railway sätter DATABASE_URL automatiskt när du lägger till PostgreSQL-tjänsten.
"""

import os
from sqlmodel import SQLModel, Session, create_engine

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./stardew_ops.db")

# Railway sätter postgres:// men SQLAlchemy kräver postgresql://
if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)

# connect_args behövs bara för SQLite
connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}

engine = create_engine(DATABASE_URL, connect_args=connect_args, echo=False)


def create_db_and_tables() -> None:
    SQLModel.metadata.create_all(engine)


def get_session():
    with Session(engine) as session:
        yield session
