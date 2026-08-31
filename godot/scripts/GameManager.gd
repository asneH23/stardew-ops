extends Node2D

@onready var api_client: Node = $ApiClient
@onready var xp_label: Label = $UI/XPLabel
@onready var level_label: Label = $UI/LevelLabel
@onready var course_label: Label = $UI/CourseLabel
@onready var progress_bar: ProgressBar = $UI/ProgressBar
@onready var progress_label: Label = $UI/ProgressLabel
@onready var commits_label: Label = $UI/CommitsLabel
@onready var status_label: Label = $StatusLabel
@onready var player: CharacterBody2D = $Player
@onready var crops_node: Node2D = $Crops

@onready var quest1_label: Label = $UI/Quest1Label
@onready var quest2_label: Label = $UI/Quest2Label
@onready var quest3_label: Label = $UI/Quest3Label

@onready var btn_reroll_1: Button = $UI/BtnReroll1
@onready var btn_reroll_2: Button = $UI/BtnReroll2
@onready var btn_reroll_3: Button = $UI/BtnReroll3

@onready var player_sprite: Label = $UI/Map/PlayerSprite
@onready var map_panel: Panel = $UI/Map

var last_known_xp: int = -1

func _ready() -> void:
	draw_pixel_grass()
	api_client.state_updated.connect(_on_state_updated)
	api_client.connection_error.connect(_on_connection_error)
	
	btn_reroll_1.pressed.connect(func(): _on_reroll_pressed(1, btn_reroll_1))
	btn_reroll_2.pressed.connect(func(): _on_reroll_pressed(2, btn_reroll_2))
	btn_reroll_3.pressed.connect(func(): _on_reroll_pressed(3, btn_reroll_3))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		$UI.visible = not $UI.visible

func _on_reroll_pressed(slot: int, btn: Button) -> void:
	btn.text = "⏳"
	btn.disabled = true
	api_client.reroll_quest(slot)


func _on_state_updated(state: Dictionary) -> void:
	status_label.text = "✅ Ansluten  |  Uppdateras var 2:a sekund"

	var total_xp: int = state.get("total_xp", 0)
	var level: int = state.get("level", 1)
	
	if last_known_xp != -1 and total_xp > last_known_xp:
		var gained = total_xp - last_known_xp
		spawn_floating_xp(gained)
		plant_crop(total_xp)
		
		# SPELA UPP ETT LJUD DIREKT I MAC OS
		var audio_output = []
		var audio_code = OS.execute("/usr/bin/afplay", ["/System/Library/Sounds/Ping.aiff"], audio_output)
		print("[Ljud] Exit code: ", audio_code, " Output: ", audio_output)
		
		# NATIVE MAC OS NOTIFICATION
		var output = []

		var apple_script = 'display notification "Du fick +%d XP!" with title "Stardew-Ops 🤖" subtitle "Gemini har analyserat din kod!"' % gained
		var exit_code = OS.execute("/usr/bin/osascript", ["-e", apple_script], output)
		
	last_known_xp = total_xp

	xp_label.text = "⭐ Total XP: %d" % total_xp
	level_label.text = "Lvl %d MLOps Engineer" % level

	var course_name: String = state.get("current_course_name", "Okänd kurs")
	course_label.text = "📚 Kurs: %s" % course_name

	var xp_earned: int = state.get("current_course_xp_earned", 0)
	var xp_total: int = state.get("current_course_xp_total", 1)
	
	progress_bar.min_value = 0
	progress_bar.max_value = xp_total
	
	var tween = get_tree().create_tween()
	tween.tween_property(progress_bar, "value", float(xp_earned), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	progress_label.text = "%d / %d XP" % [xp_earned, xp_total]
	commits_label.text = "🔨 Commits: %d" % state.get("commits_total", 0)

	var quests: Array = state.get("quests", [])
	var slot_names = ["🌾 Daily Chore", "⚙️ Weekly Contract", "🏆 Epic Project"]
	var labels = [quest1_label, quest2_label, quest3_label]
	var buttons = [btn_reroll_1, btn_reroll_2, btn_reroll_3]

	for i in range(3):
		if i < quests.size():
			var q: Dictionary = quests[i]
			labels[i].text = "%s — %s\n    %s\n    (+%d XP, +%d bonus)" % [
				slot_names[i],
				q.get("title", "?"),
				q.get("description", ""),
				q.get("xp_reward", 0),
				q.get("bonus_xp", 0),
			]
		else:
			labels[i].text = "%s: Ingen aktiv quest" % slot_names[i]
			
		buttons[i].text = "🎲"
		buttons[i].disabled = false

	# UPPDATERA KARTAN (Flytta gubben baserat på level)
	update_map(level)


func update_map(level: int) -> void:
	# Kartan är 400px bred. Max level vi visar är t.ex. 10.
	# Varje level flyttar gubben 40 pixlar åt höger.
	var target_x = min((level - 1) * 40, 360) 
	var tween = get_tree().create_tween()
	tween.tween_property(player_sprite, "position:x", float(target_x), 1.0).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func spawn_floating_xp(amount: int) -> void:
	var label = Label.new()
	label.text = "+%d XP!" % amount
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 8)
	
	label.position = Vector2(400, 180)
	$UI.add_child(label)
	
	var tween = get_tree().create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 200, 4.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 4.0).set_trans(Tween.TRANS_LINEAR)
	tween.chain().tween_callback(label.queue_free)

func _on_connection_error(message: String) -> void:
	status_label.text = "❌ " + message

func draw_pixel_grass() -> void:
	# Tileset Grass Spring.png = 384x640, 16x16 tiles
	# The top-left 16x16 block is pure green grass — confirmed from image
	var grass_tex = preload("res://assets/Tileset/Tileset Grass Spring.png")
	var soil_tex  = preload("res://assets/Tileset/Tilled Soil.png")
	var world_bg  = $WorldBackground

	# Draw 40x30 grass tiles (each 32px scaled = 1280x960 world area)
	for x in range(-20, 22):
		for y in range(-16, 18):
			var tile      = Sprite2D.new()
			tile.texture  = grass_tex
			tile.region_enabled = true
			# Row 0, col 0 in the 16x16 grid = 0,0 → pure grass tile
			tile.region_rect = Rect2(16, 0, 16, 16)
			tile.scale    = Vector2(2, 2)
			tile.position = Vector2(x * 32, y * 32)
			tile.z_index  = -10
			world_bg.add_child(tile)

	# Draw a tilled-soil field in the centre (where crops will grow)
	for fx in range(-6, 7):
		for fy in range(2, 9):
			var soil      = Sprite2D.new()
			soil.texture  = soil_tex
			soil.region_enabled = true
			# Tilled Soil.png = 384x128; dry tilled soil tile = col 0, row 0 = Rect2(0,0,16,16)
			soil.region_rect = Rect2(0, 0, 16, 16)
			soil.scale    = Vector2(2, 2)
			soil.position = Vector2(fx * 32, fy * 32)
			soil.z_index  = -9
			world_bg.add_child(soil)

	# Place the house sprite (top-left of farm)
	var house_tex  = preload("res://assets/Objects/House.png")
	var house      = Sprite2D.new()
	house.texture  = house_tex
	# House.png: take only the main house (left part, roughly 80x64 px)
	house.region_enabled = true
	house.region_rect = Rect2(0, 0, 80, 64)
	house.scale    = Vector2(3, 3)
	house.position = Vector2(-300, -200)
	house.z_index  = 0
	world_bg.add_child(house)

	# Place maple trees around the edges
	var tree_tex = preload("res://assets/Objects/Maple Tree.png")
	# Maple Tree.png: large tree is roughly 32x48 in the sheet
	var tree_positions = [
		Vector2(-360, -300), Vector2(-360, -100), Vector2(-360, 100),
		Vector2( 340, -300), Vector2( 340, -100), Vector2( 340, 100),
		Vector2(-200, -300), Vector2(   0, -300), Vector2( 200, -300),
	]
	for pos in tree_positions:
		var tree      = Sprite2D.new()
		tree.texture  = tree_tex
		tree.region_enabled = true
		tree.region_rect = Rect2(32, 0, 32, 48)  # the full-grown tree frame
		tree.scale    = Vector2(3, 3)
		tree.position = pos
		tree.z_index  = 1
		world_bg.add_child(tree)

func plant_crop(total_xp: int) -> void:
	# All Crops.png = 416x288, individual crop sprites are 16x16
	# Row 0 = strawberry stages, row 1 = tomato, row 2 = carrot, etc.
	# Last column (col ~9-11) in each row = the fully ripe harvest sprite
	var crop_tex = preload("res://assets/Objects/All Crops.png")
	var crop      = Sprite2D.new()
	crop.texture  = crop_tex
	crop.region_enabled = true

	# Pick which crop type based on XP (cycles every 50 XP)
	var crop_row  = (total_xp / 50) % 9      # which crop type
	var ripe_col  = 9                          # column ~9 = ripe fruit icon
	crop.region_rect = Rect2(ripe_col * 16, crop_row * 16, 16, 16)
	crop.scale    = Vector2(3, 3)  # 16*3 = 48px — clearly visible

	# Snap to tilled-soil grid so crops look planted neatly
	var grid_pos  = (player.global_position / 32.0).floor() * 32.0
	crop.position = grid_pos + Vector2(0, 8)
	crops_node.add_child(crop)

	# Pop-in animation: grow from seed
	crop.scale = Vector2.ZERO
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(crop, "scale", Vector2(3, 3), 0.8)

