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

# Regex: matchar "type(scope): message"
CONVENTIONAL_COMMIT_RE = re.compile(
    r"^(?P<type>\w+)(?:\((?P<scope>[^)]+)\))?(?:!)?:\s+(?P<desc>.+)$",
    re.IGNORECASE,
)


def classify_commit(message: str, branch: str = "main") -> tuple[str, int]:
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
