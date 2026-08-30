"""
courses.py — Kursplan & XP-konstanter
1 YHP = 100 XP. Progressionen är strikt linjär.
commit_prefixes: använd dessa i dina commit-meddelanden för auto-klassifikation.
  Exempel: "feat(python): la till list comprehension"
"""

from typing import TypedDict


class Course(TypedDict):
    id: str
    name: str
    yhp: int
    xp_total: int
    zone: str
    year: int
    commit_prefixes: list[str]


COURSES: list[Course] = [
    # ── År 1 ──────────────────────────────────────────────────────────────
    {
        "id": "python",
        "name": "Pythonprogrammering",
        "yhp": 40,
        "xp_total": 4000,
        "zone": "Startfältet",
        "year": 1,
        "commit_prefixes": ["python", "py"],
    },
    {
        "id": "linux",
        "name": "Linuxadministration",
        "yhp": 15,
        "xp_total": 1500,
        "zone": "Serverhallsladan",
        "year": 1,
        "commit_prefixes": ["linux", "bash", "shell"],
    },
    {
        "id": "db",
        "name": "Databashantering",
        "yhp": 25,
        "xp_total": 2500,
        "zone": "Silos & Förråd",
        "year": 1,
        "commit_prefixes": ["db", "database", "sql", "postgres", "sqlite"],
    },
    {
        "id": "ml_models",
        "name": "Maskininlärningsmodeller & algoritmer",
        "yhp": 30,
        "xp_total": 3000,
        "zone": "Växthuset",
        "year": 1,
        "commit_prefixes": ["ml", "model", "sklearn", "algorithm", "algo"],
    },
    {
        "id": "ml_frameworks",
        "name": "Maskininlärningsramverk",
        "yhp": 30,
        "xp_total": 3000,
        "zone": "Traktorer",
        "year": 1,
        "commit_prefixes": ["torch", "tensorflow", "keras", "framework", "huggingface", "hf"],
    },
    {
        "id": "ai_strategy",
        "name": "AI-förstärkt kunskapsstrategi",
        "yhp": 20,
        "xp_total": 2000,
        "zone": "Forskningslabbet",
        "year": 1,
        "commit_prefixes": ["ai", "strategy", "prompt", "rag", "llm"],
    },
    {
        "id": "mlops_cloud",
        "name": "MLOps och molnplattformar",
        "yhp": 30,
        "xp_total": 3000,
        "zone": "Molnbevattning",
        "year": 1,
        "commit_prefixes": ["mlops", "cloud", "gcp", "aws", "azure", "vertex"],
    },
    # ── År 2 ──────────────────────────────────────────────────────────────
    {
        "id": "edge",
        "name": "Edge computing",
        "yhp": 30,
        "xp_total": 3000,
        "zone": "Fältsensorer",
        "year": 2,
        "commit_prefixes": ["edge", "iot", "embedded", "tflite", "onnx"],
    },
    {
        "id": "cicd",
        "name": "Kontinuerlig integration & leverans",
        "yhp": 30,
        "xp_total": 3000,
        "zone": "Transportband",
        "year": 2,
        "commit_prefixes": ["ci", "cd", "cicd", "actions", "github", "pipeline", "docker"],
    },
    {
        "id": "architecture",
        "name": "Systemarkitektur & teknikstackar",
        "yhp": 15,
        "xp_total": 1500,
        "zone": "Huvudkontor",
        "year": 2,
        "commit_prefixes": ["arch", "architecture", "design", "api", "microservice"],
    },
    {
        "id": "security",
        "name": "Säkerhet & integritet",
        "yhp": 25,
        "xp_total": 2500,
        "zone": "Säkerhetsstängsel",
        "year": 2,
        "commit_prefixes": ["security", "auth", "encrypt", "gdpr", "privacy"],
    },
    {
        "id": "monitoring",
        "name": "Övervakning & felhantering",
        "yhp": 25,
        "xp_total": 2500,
        "zone": "Kontrolltornet",
        "year": 2,
        "commit_prefixes": ["monitor", "logging", "alert", "observ", "grafana", "prometheus"],
    },
    {
        "id": "lia1",
        "name": "LIA 1",
        "yhp": 75,
        "xp_total": 7500,
        "zone": "Exportmarknad",
        "year": 2,
        "commit_prefixes": ["lia1", "lia-1", "internship1"],
    },
    # ── År 3 ──────────────────────────────────────────────────────────────
    {
        "id": "lia2",
        "name": "LIA 2",
        "yhp": 75,
        "xp_total": 7500,
        "zone": "Kooperativet",
        "year": 3,
        "commit_prefixes": ["lia2", "lia-2", "internship2"],
    },
    {
        "id": "thesis",
        "name": "Examensarbete",
        "yhp": 25,
        "xp_total": 2500,
        "zone": "Mastermonumentet",
        "year": 3,
        "commit_prefixes": ["thesis", "exam", "exjobb"],
    },
]

# Snabb lookup-dict: prefix → course_id
PREFIX_TO_COURSE: dict[str, str] = {}
for course in COURSES:
    for prefix in course["commit_prefixes"]:
        PREFIX_TO_COURSE[prefix.lower()] = course["id"]

COURSE_BY_ID: dict[str, Course] = {c["id"]: c for c in COURSES}

TOTAL_XP = sum(c["xp_total"] for c in COURSES)  # 50 000 XP
