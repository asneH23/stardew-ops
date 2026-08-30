"""
xp_calculator.py — Regel-baserad kurs-klassifikation + XP-beräkning
MVP: Analyserar commit-meddelande och branch-namn, ingen LLM behövs.

Commit-format som ger bäst klassifikation:
  feat(python): beskrivning
  fix(linux): beskrivning
  chore(docker): beskrivning

XP per commit baseras på conventional commit-typ:
  feat    → 50 XP (ny funktion/lösning)
  fix     → 25 XP (buggfix)
  docs    → 10 XP (dokumentation)
  test    → 35 XP (tester är viktigt i MLOps)
  chore   → 15 XP (underhåll)
  refactor→ 30 XP
  default → 20 XP
"""
import os
import json
import google.generativeai as genai


import re
from courses import PREFIX_TO_COURSE, COURSE_BY_ID, COURSES

# XP per commit-typ (conventional commits)
COMMIT_TYPE_XP: dict[str, int] = {
    "feat":     50,
    "feature":  50,
    "fix":      25,
    "bugfix":   25,
    "docs":     10,
    "doc":      10,
    "test":     35,
    "tests":    35,
    "chore":    15,
    "refactor": 30,
    "perf":     40,
    "ci":       30,
}
DEFAULT_XP = 20

# Setup Gemini
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)
    # Använder den moderna 3.5-modellen
    model = genai.GenerativeModel('gemini-3.5-flash')
else:
    model = None

# Regex: matchar "type(scope): message"
CONVENTIONAL_COMMIT_RE = re.compile(
    r"^(?P<type>\w+)(?:\((?P<scope>[^)]+)\))?(?:!)?:\s+(?P<desc>.+)$",
    re.IGNORECASE,
)


def classify_commit(commit_message: str, branch_name: str = "main") -> tuple[str, int]:
    """
    Använder Gemini (om API-nyckeln finns) för att agera Tech Lead och bedöma
    vilken kurs din commit hör till och hur mycket XP den är värd (10-100).
    Returnerar (course_id, xp).
    """
    if not model:
        print("⚠️ Ingen GEMINI_API_KEY hittades. Använder fallback-logik.")
        return _fallback_classification(commit_message, branch_name)

    valid_courses = [course["id"] for course in COURSES]
    
    prompt = f"""
    Du är en peppande och generös Tech Lead för en student som läser en utbildning till MLOps Engineer.
    Studenten har precis gjort en git commit i sin studiekod.
    Din uppgift är att bedöma:
    1. Vilken kurs committen troligen tillhör.
    2. Hur mycket XP den är värd (mellan 40 och 100 XP).
       (Mindre kodändringar: 40-50 XP. Större features/maskininlärnings-kod: 60-80 XP. Bygga från scratch eller svåra koncept: 90-100 XP).
    
    Giltiga kurs-IDn att välja bland: {', '.join(valid_courses)}
    
    Commit-meddelande: "{commit_message}"
    Branch: "{branch_name}"
    
    Returnera ENDAST ett giltigt JSON-objekt utan markdown-taggar. Format:
    {{
        "course_id": "valt_kurs_id",
        "xp": 50,
        "reasoning": "Kort motivering på svenska till varför (max 1-2 meningar)."
    }}
    
    Om du är osäker, fallback på "python" med 20 XP.
    """
    
    try:
        response = model.generate_content(prompt)
        text = response.text.strip()
        
        # Rensa eventuella markdown code blocks (```json ... ```)
        if text.startswith("```"):
            lines = text.split("\n")
            text = "\n".join(lines[1:-1])
            
        data = json.loads(text)
        course_id = data.get("course_id", "python")
        xp = data.get("xp", 30)
        reasoning = data.get("reasoning", "")
        
        print(f"🤖 Gemini analys: {reasoning} -> {course_id} (+{xp} XP)")
        
        if course_id not in COURSE_BY_ID:
            course_id = "python"
            
        return course_id, xp
        
    except Exception as e:
        print(f"❌ Gemini error: {e}")
        return _fallback_classification(commit_message, branch_name)


def _fallback_classification(message: str, branch: str) -> tuple[str, int]:
    """
    Returnerar (course_id, xp_awarded).
    Försöker matcha i denna ordning:
    1. Conventional commit scope → t.ex. feat(python) → "python"
    2. Branch-namn               → t.ex. feature/linux-week3 → "linux"
    3. Nyckelord i meddelandet   → sök alla kurs-prefix
    4. Fallback                  → aktuell kurs (hämtas från DB i main.py)
    """
    course_id = None
    xp = DEFAULT_XP

    match = CONVENTIONAL_COMMIT_RE.match(message.strip())
    if match:
        commit_type = match.group("type").lower()
        scope = (match.group("scope") or "").lower()
        xp = COMMIT_TYPE_XP.get(commit_type, DEFAULT_XP)

        # 1. Scope-match
        if scope:
            course_id = _find_course_in_text(scope)

    # 2. Branch-match
    if course_id is None:
        course_id = _find_course_in_text(branch.lower())

    # 3. Nyckelord i hela meddelandet
    if course_id is None:
        course_id = _find_course_in_text(message.lower())

    return course_id, xp


def _find_course_in_text(text: str) -> str | None:
    """Söker igenom PREFIX_TO_COURSE och returnerar första match."""
    for prefix, course_id in PREFIX_TO_COURSE.items():
        if prefix in text:
            return course_id
    return None


def calculate_course_xp_earned(total_xp: int, course_id: str) -> int:
    """
    Räknar ut hur mycket XP spelaren tjänat IN I den aktuella kursen,
    givet total_xp och kursordningen (linjär progression).
    """
    earned_so_far = 0
    for course in COURSES:
        course_xp = course["xp_total"]
        if course["id"] == course_id:
            # Hur mycket är kvar att fördela till denna kurs
            remaining = total_xp - earned_so_far
            return max(0, min(remaining, course_xp))
        earned_so_far += course_xp
        if earned_so_far > total_xp:
            return 0
    return 0
