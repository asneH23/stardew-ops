# GameManager.gd
# Huvud-controller för Stardew-Ops spelet.
# Lyssnar på ApiClient's signal och uppdaterar all UI.
#
# Nodstruktur som förväntas i Main.tscn:
#   Main (Node2D)
#   ├── ApiClient (Node)          ← kör ApiClient.gd
#   ├── UI (CanvasLayer)
#   │   ├── XPLabel (Label)       ← "Total XP: 150"
#   │   ├── CourseLabel (Label)   ← "Kurs: Pythonprogrammering"
#   │   ├── ProgressBar (ProgressBar)
#   │   ├── CommitsLabel (Label)  ← "Commits: 12"
#   │   └── QuestBoard (VBoxContainer)
#   │       ├── Quest1Label (Label)
#   │       ├── Quest2Label (Label)
#   │       └── Quest3Label (Label)
#   └── StatusLabel (Label)       ← "Ansluten / Ansluter..."

extends Node2D

# Hämtar referenser till UI-noder med $-syntaxen
# $UI/XPLabel är samma som get_node("UI/XPLabel")
@onready var api_client: Node = $ApiClient
@onready var xp_label: Label = $UI/XPLabel
@onready var course_label: Label = $UI/CourseLabel
@onready var progress_bar: ProgressBar = $UI/ProgressBar
@onready var commits_label: Label = $UI/CommitsLabel
@onready var status_label: Label = $StatusLabel
@onready var quest1_label: Label = $UI/QuestBoard/Quest1Label
@onready var quest2_label: Label = $UI/QuestBoard/Quest2Label
@onready var quest3_label: Label = $UI/QuestBoard/Quest3Label


func _ready() -> void:
	# Koppla ihop signaler från ApiClient med våra handler-funktioner
	# .connect() = Godots sätt att "subscriba" på en signal
	api_client.state_updated.connect(_on_state_updated)
	api_client.connection_error.connect(_on_connection_error)

	status_label.text = "⏳ Ansluter till backend..."
	print("[GameManager] Stardew-Ops startar!")


func _on_state_updated(state: Dictionary) -> void:
	"""Kallas av ApiClient när backend svarat med ny state."""
	status_label.text = "✅ Ansluten"

	# Uppdatera XP
	var total_xp: int = state.get("total_xp", 0)
	xp_label.text = "Total XP: %d" % total_xp

	# Uppdatera kurs
	var course_name: String = state.get("current_course_name", "Okänd kurs")
	course_label.text = "Kurs: %s" % course_name

	# Uppdatera progress bar
	var xp_earned: int = state.get("current_course_xp_earned", 0)
	var xp_total: int = state.get("current_course_xp_total", 1)
	progress_bar.min_value = 0
	progress_bar.max_value = xp_total
	progress_bar.value = xp_earned

	# Uppdatera commits
	commits_label.text = "Commits: %d" % state.get("commits_total", 0)

	# Uppdatera Quest Board
	var quests: Array = state.get("quests", [])
	_update_quest_label(quest1_label, quests, 0, "Daily Chore")
	_update_quest_label(quest2_label, quests, 1, "Weekly Contract")
	_update_quest_label(quest3_label, quests, 2, "Epic Project")


func _update_quest_label(label: Label, quests: Array, index: int, slot_name: String) -> void:
	"""Hjälpfunktion för att uppdatera en quest-label."""
	if index < quests.size():
		var q: Dictionary = quests[index]
		label.text = "[%s] %s (+%d XP)" % [slot_name, q.get("title", "?"), q.get("xp_reward", 0)]
	else:
		label.text = "[%s] Ingen aktiv quest" % slot_name


func _on_connection_error(message: String) -> void:
	"""Kallas när backend inte är nåbar."""
	status_label.text = "❌ " + message
	print("[GameManager] Anslutningsfel: ", message)
