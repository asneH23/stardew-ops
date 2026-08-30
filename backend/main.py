"""
main.py — FastAPI-applikationens hjärna (Stardew-Ops Backend)

Endpoints:
  GET  /          — healthcheck
  GET  /state     — Godot pollar detta (XP, level, quests)
  POST /webhook/github  — GitHub push-events
  POST /dev/fake-commit — Testa utan GitHub
  POST /quests/reroll   — Generera 3 nya quests
"""

import sys
import os

# Lägg till backend/-mappen i Python-sökvägen så att imports fungerar
# oavsett var uvicorn startas ifrån (lokalt eller på Railway).
sys.path.insert(0, os.path.dirname(__file__))

import json
from contextlib import asynccontextmanager
from datetime import datetime

from fastapi import Depends, FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from sqlmodel import Session, select

from courses import COURSE_BY_ID, COURSES
from database import create_db_and_tables, get_session, engine
from models import (
    CommitEvent, FakeCommitRequest, PlayerState,
    Quest, QuestStatus, StateResponse, WebhookResponse,
)
from quest_engine import check_quest_completion, complete_quest, generate_quests
from webhook_handler import parse_push_event, verify_github_signature
from xp_calculator import calculate_course_xp_earned, classify_commit


# ── App startup ──────────────────────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Körs en gång vid app-start: skapar DB-tabeller och seed-data."""
    create_db_and_tables()
    _seed_initial_data()
    yield


def _seed_initial_data() -> None:
    """Skapar PlayerState och första Quest Board om databasen är tom."""
    with Session(engine) as session:
        state = session.get(PlayerState, 1)
        if state is None:
            state = PlayerState(id=1, total_xp=0, current_course_id="python")
            session.add(state)
            session.commit()
            print("🌱 Ny spelare skapad! Välkommen till Stardew-Ops.")

        # Skapa quests om inga aktiva finns
        active = session.exec(
            select(Quest).where(Quest.status == QuestStatus.ACTIVE)
        ).all()
        if not active:
            generate_quests(session, "python")
            print("📋 Quest Board initierad med 3 uppdrag!")


app = FastAPI(
    title="Stardew-Ops Backend",
    description="MLOps-utbildningsspåret som ett RPG",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Tillåter Godot-klienten oavsett origin
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Helpers ──────────────────────────────────────────────────────────────────

def get_or_create_state(session: Session) -> PlayerState:
    state = session.get(PlayerState, 1)
    if state is None:
        state = PlayerState(id=1, total_xp=0, current_course_id="python")
        session.add(state)
        session.commit()
        session.refresh(state)
    return state


def determine_current_course(total_xp: int) -> str:
    """Räknar ut vilken kurs spelaren är i baserat på total XP (linjär progression)."""
    xp_remaining = total_xp
    for course in COURSES:
        if xp_remaining < course["xp_total"]:
            return course["id"]
        xp_remaining -= course["xp_total"]
    return COURSES[-1]["id"]  # Examensarbete — klar!


def process_commit(session: Session, sha: str, message: str, branch: str, repo: str) -> WebhookResponse:
    """Kärn-logiken: klassificera commit → ge XP → kolla quests."""
    state = get_or_create_state(session)

    # Kolla om detta commit redan är processat (idempotent)
    existing = session.exec(select(CommitEvent).where(CommitEvent.sha == sha)).first()
    if existing:
        course = COURSE_BY_ID.get(existing.course_id or "python", COURSES[0])
        return WebhookResponse(
            xp_awarded=0,
            course_id=existing.course_id or "python",
            course_name=course["name"],
            message=f"Commit {sha[:7]} redan processat. Ingen ny XP.",
        )

    # Klassificera commit → kurs + XP
    course_id, xp = classify_commit(message, branch)
    if course_id is None:
        course_id = state.current_course_id  # Fallback: aktuell kurs

    course = COURSE_BY_ID.get(course_id, COURSES[0])

    # Kolla om commit löser en aktiv quest
    completed_quest = check_quest_completion(session, message, course_id)
    quest_bonus = 0
    quest_name = None
    if completed_quest:
        quest_bonus = completed_quest.bonus_xp
        quest_name = completed_quest.title
        complete_quest(session, completed_quest)

    total_xp_gained = xp + quest_bonus

    # Uppdatera state
    state.total_xp += total_xp_gained
    state.commits_total += 1
    state.current_course_id = determine_current_course(state.total_xp)
    state.last_updated = datetime.utcnow()

    # Logga commit
    event = CommitEvent(
        sha=sha,
        repo=repo,
        branch=branch,
        message=message,
        course_id=course_id,
        xp_awarded=total_xp_gained,
        quest_completed_id=completed_quest.id if completed_quest else None,
    )
    session.add(state)
    session.add(event)
    session.commit()

    msg = f"+{total_xp_gained} XP för {course['name']}"
    if quest_name:
        msg += f" | 🎉 Quest klar: '{quest_name}' (+{quest_bonus} bonus XP)"

    print(f"✅ {msg}")
    return WebhookResponse(
        xp_awarded=total_xp_gained,
        course_id=course_id,
        course_name=course["name"],
        message=msg,
        quest_completed=quest_name,
    )


# ── Endpoints ────────────────────────────────────────────────────────────────

@app.get("/", tags=["Health"])
def healthcheck():
    return {"status": "ok", "app": "Stardew-Ops Backend v0.1.0"}


@app.get("/state", response_model=StateResponse, tags=["Game"])
def get_state(session: Session = Depends(get_session)):
    """Godot pollar detta endpoint var X:e sekund för att uppdatera UI."""
    state = get_or_create_state(session)
    course = COURSE_BY_ID.get(state.current_course_id, COURSES[0])
    course_xp_earned = calculate_course_xp_earned(state.total_xp, state.current_course_id)

    active_quests = session.exec(
        select(Quest).where(Quest.status == QuestStatus.ACTIVE).order_by(Quest.slot)
    ).all()

    quests_data = [
        {
            "id": q.id,
            "slot": q.slot,
            "title": q.title,
            "description": q.description,
            "xp_reward": q.xp_reward,
            "bonus_xp": q.bonus_xp,
        }
        for q in active_quests
    ]

    return StateResponse(
        total_xp=state.total_xp,
        current_course_id=state.current_course_id,
        current_course_name=course["name"],
        current_course_xp_total=course["xp_total"],
        current_course_xp_earned=course_xp_earned,
        commits_total=state.commits_total,
        quests=quests_data,
    )


@app.post("/webhook/github", response_model=WebhookResponse, tags=["GitHub"])
async def github_webhook(request: Request, session: Session = Depends(get_session)):
    """Tar emot GitHub push-events. Verifiera HMAC → ge XP."""
    body = await verify_github_signature(request)
    event_type = request.headers.get("X-GitHub-Event", "unknown")

    if event_type == "ping":
        return WebhookResponse(
            xp_awarded=0, course_id="", course_name="",
            message="Webhook ping mottagen! GitHub är ansluten. 🎉"
        )

    if event_type != "push":
        return WebhookResponse(
            xp_awarded=0, course_id="", course_name="",
            message=f"Event '{event_type}' ignorerat (bara push ger XP)."
        )

    payload = json.loads(body)
    commit_data = parse_push_event(payload)
    if not commit_data:
        return WebhookResponse(
            xp_awarded=0, course_id="", course_name="",
            message="Push utan commits — ingen XP."
        )

    return process_commit(
        session=session,
        sha=commit_data["sha"],
        message=commit_data["message"],
        branch=commit_data["branch"],
        repo=commit_data["repo"],
    )


@app.post("/dev/fake-commit", response_model=WebhookResponse, tags=["Dev"])
def fake_commit(body: FakeCommitRequest, session: Session = Depends(get_session)):
    """
    Testar XP-pipelinen utan att behöva pusha till GitHub.
    Användning: curl -X POST /dev/fake-commit -d '{"message": "feat(python): hello world"}'
    """
    import hashlib, time
    unique_sha = hashlib.md5(f"{body.message}{time.time()}".encode()).hexdigest()[:10]
    return process_commit(
        session=session,
        sha=unique_sha,
        message=body.message,
        branch=body.branch,
        repo=body.repo,
    )


@app.post("/quests/reroll", tags=["Game"])
def reroll_quests(session: Session = Depends(get_session)):
    """Genererar 3 nya quests. Gamla markeras som 'rerolled'."""
    state = get_or_create_state(session)
    new_quests = generate_quests(session, state.current_course_id)
    return {
        "message": "Quest Board uppdaterad! 🎲",
        "quests": [
            {"slot": q.slot, "title": q.title, "xp_reward": q.xp_reward}
            for q in new_quests
        ],
    }


@app.get("/quests/history", tags=["Game"])
def quest_history(session: Session = Depends(get_session)):
    """Listar alla avklarade quests."""
    completed = session.exec(
        select(Quest).where(Quest.status == QuestStatus.COMPLETED).order_by(Quest.completed_at.desc())
    ).all()
    return {"completed_count": len(completed), "quests": completed}

@app.get("/debug-env", tags=["Dev"])
def debug_env():
    import os
    key = os.getenv("GEMINI_API_KEY")
    return {
        "key_exists": bool(key),
        "key_length": len(key) if key else 0,
        "starts_with_AIza": key.startswith("AIza") if key else False
    }

@app.get("/debug-db", tags=["Dev"])
def debug_db():
    import os
    db_url = os.getenv("DATABASE_URL")
    return {
        "db_url_exists": bool(db_url),
        "db_type": "postgres" if db_url and "postgres" in db_url else "sqlite (temporary!)"
    }

@app.get("/debug-ai", tags=["Dev"])
def debug_ai():
    import os
    import google.generativeai as genai
    key = os.getenv("GEMINI_API_KEY")
    if not key:
        return {"error": "Ingen nyckel hittades"}
    
    try:
        genai.configure(api_key=key)
        model = genai.GenerativeModel('gemini-1.5-flash')
        resp = model.generate_content("Säg hej kort!")
        return {"success": True, "response": resp.text.strip(), "key_start": key[:4]}
    except Exception as e:
        return {"error": str(e), "key_start": key[:4]}
