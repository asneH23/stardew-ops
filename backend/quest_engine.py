"""
quest_engine.py — Quest Board-logik
MVP: Hårdkodade quest-templates per kurs och svårighetsnivå.
Fas 2: Ersätt generate_quests() med LLM-anrop.
"""

import random
from datetime import datetime
from sqlmodel import Session, select
from models import Quest, QuestStatus

# ── Quest-templates ──────────────────────────────────────────────────────────
# Struktur: course_id → lista av (slot, title, description, xp_reward, bonus_xp)

QUEST_TEMPLATES: dict[str, list[tuple]] = {
    "python": [
        # (slot, title, description, xp_reward, bonus_xp)
        (1, "Listans Mästare", "Skriv ett script som läser en JSON-fil och skriver ut alla värden med list comprehension.", 30, 15),
        (1, "Dict-detektiven", "Skapa en funktion som slår samman två dicts utan att skriva över nycklar.", 25, 10),
        (1, "Fil-sheriffens runda", "Skriv ett CLI-script (argparse) som räknar ord i en textfil.", 35, 15),
        (2, "Klass-konstruktören", "Bygg en dataclass med @dataclass för ett student-objekt med metoder.", 80, 30),
        (2, "API-resenären", "Hämta data från ett öppet API (t.ex. wttr.in) och spara till JSON med requests.", 90, 35),
        (3, "Mini-CLI-verktyget", "Bygg ett komplett CLI med argparse: läser CSV, filtrerar rader, exporterar till JSON.", 200, 80),
    ],
    "linux": [
        (1, "Bash-bonden", "Skriv ett bash-script som skapar en katalogstruktur för ett nytt projekt automatiskt.", 30, 15),
        (1, "Process-jägaren", "Hitta och döda alla processer med ett givet namn via ett one-liner bash-kommando.", 25, 10),
        (2, "Cron-schemaläggaren", "Sätt upp ett cron-job som loggar systemets CPU- och RAM-användning var 5:e minut.", 80, 30),
        (3, "Serverns Väktare", "Konfigurera en systemd-tjänst som startar ett Python-script vid boot.", 200, 80),
    ],
    "db": [
        (1, "SQL-bonden", "Skriv SQL-queries för att skapa en tabell, infoga 5 rader och filtrera med WHERE.", 30, 15),
        (2, "Relations-smeden", "Designa ett ER-diagram med 3 tabeller och implementera det i SQLite med Python.", 90, 35),
        (3, "Migrations-maskinen", "Sätt upp Alembic för automatiska databas-migrationer i ett FastAPI-projekt.", 200, 80),
    ],
    "ml_models": [
        (1, "Data-skördaren", "Ladda Iris-datasetet med pandas och gör EDA: describe(), korrelation, histogram.", 35, 15),
        (2, "Klassificerarens Lärling", "Träna en RandomForest på Titanic-data. Evaluera med precision, recall, F1.", 100, 40),
        (3, "Pipelines Riddare", "Bygg en sklearn Pipeline med preprocessing + model, träna, evaluera och spara med joblib.", 220, 90),
    ],
    "ml_frameworks": [
        (1, "Tensor-bonden", "Skapa och manipulera tensors i PyTorch: shapes, dtypes, basic ops.", 35, 15),
        (2, "Nätverkets Smedja", "Bygg ett enkelt MLP i PyTorch för MNIST-klassifikation. Nå >95% accuracy.", 110, 45),
        (3, "Transfer-trollen", "Finjustera ett förtränat ResNet18 på en egen liten bildklassifikationsuppgift.", 250, 100),
    ],
    "mlops_cloud": [
        (1, "Container-bonden", "Dockerisera ett Python-script: skriv Dockerfile, bygg image, kör container.", 40, 20),
        (2, "Pipeline-piloten", "Sätt upp en GitHub Actions workflow som kör pytest vid varje push.", 100, 40),
        (3, "Deploy-draken", "Deploya en FastAPI-app till Railway/Render med automatisk deploy vid push till main.", 250, 100),
    ],
    "cicd": [
        (1, "Actions-bonden", "Skapa en GitHub Actions workflow med matrix-strategi för Python 3.10 och 3.11.", 40, 20),
        (2, "Test-tornet", "Lägg till pytest + coverage i CI-pipelinen. Kräv >80% kodtäckning.", 100, 40),
        (3, "Release-robotens Resa", "Bygg en CI/CD-pipeline: test → build docker → push till registry → deploy.", 250, 100),
    ],
}

# Fallback för kurser utan templates ännu
DEFAULT_TEMPLATES = {
    "python": QUEST_TEMPLATES["python"]
}


def get_templates_for_course(course_id: str) -> list[tuple]:
    return QUEST_TEMPLATES.get(course_id, QUEST_TEMPLATES.get("python", []))


def generate_quests(session: Session, course_id: str) -> list[Quest]:
    """
    Skapar 3 nya aktiva quests (slot 1, 2, 3) för given kurs.
    Markerar eventuella gamla aktiva quests som 'rerolled'.
    """
    # Markera gamla aktiva quests som rerolled
    old_quests = session.exec(
        select(Quest).where(Quest.status == QuestStatus.ACTIVE)
    ).all()
    for q in old_quests:
        q.status = QuestStatus.REROLLED
        session.add(q)

    templates = get_templates_for_course(course_id)

    # Välj slumpmässigt en template per slot (1, 2, 3)
    new_quests: list[Quest] = []
    for slot in [1, 2, 3]:
        slot_templates = [t for t in templates if t[0] == slot]
        if not slot_templates:
            # Skapa en generisk quest om ingen template finns
            slot_templates = [(slot, f"Slot {slot} Quest", f"Öva på {course_id}-relaterade uppgifter.", slot * 50, slot * 20)]

        chosen = random.choice(slot_templates)
        quest = Quest(
            slot=chosen[0],
            title=chosen[1],
            description=chosen[2],
            xp_reward=chosen[3],
            bonus_xp=chosen[4],
            course_id=course_id,
            status=QuestStatus.ACTIVE,
        )
        session.add(quest)
        new_quests.append(quest)

    session.commit()
    for q in new_quests:
        session.refresh(q)
    return new_quests


def check_quest_completion(session: Session, commit_message: str, course_id: str) -> Quest | None:
    """
    MVP: Enkel keyword-matching mot quest-titlar och beskrivningar.
    Returnerar den quest som verkar lösas av detta commit, annars None.
    """
    active_quests = session.exec(
        select(Quest).where(Quest.status == QuestStatus.ACTIVE)
    ).all()

    msg_lower = commit_message.lower()
    for quest in active_quests:
        keywords = quest.title.lower().split() + quest.description.lower().split()
        # Enkel heuristik: om 2+ nyckelord från quest finns i commit
        matches = sum(1 for kw in keywords if len(kw) > 4 and kw in msg_lower)
        if matches >= 2:
            return quest
    return None


def complete_quest(session: Session, quest: Quest) -> None:
    quest.status = QuestStatus.COMPLETED
    quest.completed_at = datetime.utcnow()
    session.add(quest)
    session.commit()
