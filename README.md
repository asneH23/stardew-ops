# 🌾 Stardew-Ops

> MLOps-utbildningen som ett Stardew Valley-inspirerat RPG.  
> Pusha kod → tjäna XP → lås upp zoner på din gård.

## Arkitektur

```
[GitHub Push] → [FastAPI Backend @ Railway] → [SQLite DB]
                                            ↓
                              [Godot Desktop-spel] (polling /state)
```

## Kom igång

### 1. Backend (lokalt för utveckling)

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

cp ../.env.example ../.env
# Redigera .env med dina värden

uvicorn main:app --reload
# Öppna http://localhost:8000/docs för Swagger UI
```

### 2. Testa pipeline utan GitHub

```bash
curl -X POST http://localhost:8000/dev/fake-commit \
  -H "Content-Type: application/json" \
  -d '{"message": "feat(python): add list comprehension to parser"}'

curl http://localhost:8000/state
```

### 3. Godot-setup

1. Ladda ner [Godot Engine 4.x](https://godotengine.org/download)
2. Öppna `godot/` som projekt i Godot Editor
3. Skapa scen-hierarkin enligt kommentarerna i `scenes/Main.tscn`
4. Koppla scripts: `GameManager.gd` → Main-noden, `ApiClient.gd` → ApiClient-noden
5. Tryck F5 för att köra — kontrollera Output-panelen

### 4. Deploy till Railway

1. Skapa konto på [railway.app](https://railway.app)
2. "New Project" → "Deploy from GitHub repo" → välj detta repo
3. Lägg till miljövariabler i Railway dashboard:
   - `GITHUB_WEBHOOK_SECRET` → generera med `python -c "import secrets; print(secrets.token_hex(32))"`
4. Kopiera din Railway-URL (t.ex. `https://stardew-ops.up.railway.app`)
5. Uppdatera `backend_url` i Godot-editorn (ApiClient-noden)

### 5. GitHub Webhook

1. Gå till ditt studiekod-repo → Settings → Webhooks → Add webhook
2. Payload URL: `https://YOUR-RAILWAY-URL/webhook/github`
3. Content type: `application/json`
4. Secret: samma som `GITHUB_WEBHOOK_SECRET`
5. Events: Välj "Just the push event"

## Commit-format för XP

Använd [Conventional Commits](https://www.conventionalcommits.org/) med kursens ID som scope:

```
feat(python): lägg till list comprehension      → 50 XP (Pythonprogrammering)
fix(linux): fixa bash-script för cron           → 25 XP (Linuxadministration)
test(ml): lägg till pytest för sklearn-pipeline → 35 XP (ML-modeller)
docs(docker): dokumentera Dockerfile            → 10 XP (MLOps & moln)
```

### Kurs-IDs

| Scope | Kurs |
|-------|------|
| `python`, `py` | Pythonprogrammering |
| `linux`, `bash`, `shell` | Linuxadministration |
| `db`, `sql`, `sqlite` | Databashantering |
| `ml`, `model`, `sklearn` | ML-modeller & algoritmer |
| `torch`, `tensorflow`, `keras` | ML-ramverk |
| `mlops`, `cloud`, `docker` | MLOps & moln |
| `ci`, `cicd`, `actions` | CI/CD |

Se `backend/courses.py` för alla kurs-IDs och prefix.

## Quest Board

3 aktiva slots genereras automatiskt vid start:
- **Slot 1 — Daily Chore**: Snabb win, låg XP
- **Slot 2 — Weekly Contract**: Medium utmaning
- **Slot 3 — Epic Project**: Stort mini-projekt

```bash
# Reroll alla quests
curl -X POST http://localhost:8000/quests/reroll

# Se quest-historik
curl http://localhost:8000/quests/history
```
