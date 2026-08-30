# GameManager.gd — Stardew-Ops huvud-controller
extends Node2D

@onready var api_client: Node = $ApiClient
@onready var xp_label: Label = $UI/XPLabel
@onready var course_label: Label = $UI/CourseLabel
@onready var progress_bar: ProgressBar = $UI/ProgressBar
@onready var commits_label: Label = $UI/CommitsLabel
@onready var status_label: Label = $StatusLabel
@onready var quest1_label: Label = $UI/Quest1Label
@onready var quest2_label: Label = $UI/Quest2Label
@onready var quest3_label: Label = $UI/Quest3Label


func _ready() -> void:
	api_client.state_updated.connect(_on_state_updated)
	api_client.connection_error.connect(_on_connection_error)
	print("[GameManager] Stardew-Ops startar!")


func _on_state_updated(state: Dictionary) -> void:
	status_label.text = "✅ Ansluten till backend"

	# XP
	var total_xp: int = state.get("total_xp", 0)
	xp_label.text = "⭐ Total XP: %d" % total_xp

	# Kurs
	var course_name: String = state.get("current_course_name", "Okänd kurs")
	course_label.text = "📚 Kurs: %s" % course_name

	# Progress bar
	var xp_earned: int = state.get("current_course_xp_earned", 0)
	var xp_total: int = state.get("current_course_xp_total", 1)
	progress_bar.min_value = 0
	progress_bar.max_value = xp_total
	progress_bar.value = xp_earned
	progress_bar.tooltip_text = "%d / %d XP" % [xp_earned, xp_total]

	# Commits
	commits_label.text = "🔨 Commits: %d" % state.get("commits_total", 0)

	# Quests
	var quests: Array = state.get("quests", [])
	var slot_names = ["🌾 Daily Chore", "⚙️ Weekly Contract", "🏆 Epic Project"]
	var labels = [quest1_label, quest2_label, quest3_label]

	for i in range(3):
		if i < quests.size():
			var q: Dictionary = quests[i]
			labels[i].text = "%s: %s\n   → %s\n   (+%d XP, +%d bonus vid commit)" % [
				slot_names[i],
				q.get("title", "?"),
				q.get("description", ""),
				q.get("xp_reward", 0),
				q.get("bonus_xp", 0),
			]
		else:
			labels[i].text = "%s: Ingen aktiv quest" % slot_names[i]


func _on_connection_error(message: String) -> void:
	status_label.text = "❌ " + message
	print("[GameManager] Fel: ", message)
