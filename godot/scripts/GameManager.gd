extends Node

@onready var api_client = $ApiClient
@onready var status_label = $StatusLabel
@onready var world_bg = $WorldBackground
@onready var crops_node = $Crops
@onready var player = $Player
@onready var ui = $UI

@onready var xp_label = $UI/XPLabel
@onready var level_label = $UI/LevelLabel
@onready var progress_bar = $UI/ProgressBar
@onready var commits_label = $UI/CommitsLabel
@onready var course_label = $UI/CourseLabel

var last_known_xp: int = -1
var planting_queue: Array[int] = []
var is_player_busy: bool = false

var hubs = [
	Vector2(-250, 100),
	Vector2(250, 100),
	Vector2(0, 250)
]
var house_door = Vector2(0, -110)

func _ready() -> void:
	_setup_camera()
	place_world_objects()
	
	api_client.state_updated.connect(_on_state_updated)
	api_client.connection_error.connect(_on_connection_error)
	
func _setup_camera() -> void:
	# Flytta kameran från Player till Main för statisk vy
	var cam = player.get_node_or_null("Camera2D")
	if cam:
		player.remove_child(cam)
		add_child(cam)
		cam.position = Vector2(0, 0)
		cam.zoom = Vector2(1.2, 1.2)

func _on_state_updated(state: Dictionary) -> void:
	var total_xp = state.get("total_xp", 0)
	var level = state.get("level", 1)
	var xp_for_next = state.get("xp_for_next_level", 100)
	var course_id = state.get("last_course_id", "stardew")
	
	xp_label.text = "XP: %d" % total_xp
	level_label.text = "Level %d" % level
	course_label.text = "Senaste: " + course_id.capitalize()
	progress_bar.max_value = xp_for_next
	progress_bar.value = total_xp % xp_for_next

	if last_known_xp == -1:
		last_known_xp = total_xp
		_instantly_plant_history(total_xp)
	elif total_xp > last_known_xp:
		var new_crops = (total_xp / 50) - (last_known_xp / 50)
		for i in range(new_crops):
			var xp_val = last_known_xp + ((i + 1) * 50)
			planting_queue.append(xp_val)
		last_known_xp = total_xp
		process_planting_queue()

func _on_connection_error(message: String) -> void:
	status_label.text = "❌ " + message

func _instantly_plant_history(total_xp: int) -> void:
	var total_crops = total_xp / 50
	for i in range(total_crops):
		var xp_val = (i + 1) * 50
		var hub_index = (xp_val / 50) % 3
		_spawn_crop(xp_val, hubs[hub_index])

func process_planting_queue() -> void:
	if is_player_busy or planting_queue.size() == 0:
		return
		
	is_player_busy = true
	var xp_val = planting_queue.pop_front()
	var hub_index = (xp_val / 50) % 3
	var target_hub = hubs[hub_index]
	
	var path = [house_door]
	if hub_index == 0 or hub_index == 1:
		path.append(Vector2(0, target_hub.y))
		path.append(target_hub)
	else:
		path.append(target_hub)
		
	player.global_position = house_door
	player.follow_path(path, func(): _on_arrived_at_hub(xp_val, target_hub, path))

func _on_arrived_at_hub(xp_val: int, target_hub: Vector2, path_taken: Array) -> void:
	_spawn_crop(xp_val, target_hub, true)
	
	# Vänta lite, gå sen hem
	await get_tree().create_timer(1.0).timeout
	var return_path = path_taken.duplicate()
	return_path.reverse()
	
	player.follow_path(return_path, func():
		player.hide()
		is_player_busy = false
		process_planting_queue()
	)

func _spawn_crop(xp_val: int, hub_pos: Vector2, animate: bool = false) -> void:
	var crop = Sprite2D.new()
	crop.texture = preload("res://assets/Objects/All Crops.png")
	crop.region_enabled = true
	
	var crop_rects = [
		Rect2(96, 32, 16, 16),    # Jordgubbe
		Rect2(224, 64, 16, 16),   # Tomat
		Rect2(96, 112, 16, 16),   # Morot
		Rect2(96, 48, 16, 16),    # Potatis
		Rect2(96, 176, 16, 16),   # Broccoli
	]
	crop.region_rect = crop_rects[(xp_val / 50) % crop_rects.size()]
	crop.scale = Vector2(2.5, 2.5)
	
	# Placera i 3x3 rutnät vid hubben
	var crop_count_at_this_hub = (xp_val / 50) / 3
	var slot = crop_count_at_this_hub % 9
	var slot_x = (slot % 3) - 1
	var slot_y = (slot / 3) - 1
	crop.position = hub_pos + Vector2(slot_x * 32, slot_y * 32)
	
	crops_node.add_child(crop)
	
	if animate:
		crop.scale = Vector2.ZERO
		var tween = get_tree().create_tween()
		tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(crop, "scale", Vector2(2.5, 2.5), 0.8)

func place_world_objects() -> void:
	# 1. Grön Kretskort-bakgrund
	var base = ColorRect.new()
	base.color = Color(0.42, 0.69, 0.37, 1)
	base.position = Vector2(-1200, -1200)
	base.size = Vector2(2400, 2400)
	base.z_index = -20
	world_bg.add_child(base)
	
	# 2. Databussar (Grusgångar/Traces)
	var bus_v = ColorRect.new()
	bus_v.color = Color(0.63, 0.45, 0.28, 1) # Jordbrun
	bus_v.position = Vector2(-20, -110)
	bus_v.size = Vector2(40, 380)
	bus_v.z_index = -15
	world_bg.add_child(bus_v)
	
	var bus_h = ColorRect.new()
	bus_h.color = Color(0.63, 0.45, 0.28, 1)
	bus_h.position = Vector2(-270, 80)
	bus_h.size = Vector2(540, 40)
	bus_h.z_index = -15
	world_bg.add_child(bus_h)
	
	# 3. Noder (Odlingslådor) vid hubbarna
	var soil_tex = preload("res://assets/Tileset/Tilled Soil.png")
	for hub in hubs:
		for x in range(-1, 2):
			for y in range(-1, 2):
				var soil = Sprite2D.new()
				soil.texture = soil_tex
				soil.region_enabled = true
				soil.region_rect = Rect2(64, 0, 16, 16)
				soil.scale = Vector2(2, 2)
				soil.position = hub + Vector2(x * 32, y * 32)
				soil.z_index = -10
				world_bg.add_child(soil)

	# 4. Huset (CPU)
	var house = Sprite2D.new()
	house.texture = preload("res://assets/Objects/House.png")
	house.region_enabled = true
	house.region_rect = Rect2(144, 0, 80, 112)
	house.scale = Vector2(3, 3)
	house.position = Vector2(0, -220)
	house.z_index = -5
	world_bg.add_child(house)
	
	# 5. Träd (Ram)
	var tree_tex = preload("res://assets/Objects/Maple Tree.png")
	var t_pos = [
		Vector2(-450, -300), Vector2(450, -300), Vector2(-450, 300), Vector2(450, 300),
		Vector2(-450, 0), Vector2(450, 0), Vector2(-200, -350), Vector2(200, -350)
	]
	for p in t_pos:
		var tree = Sprite2D.new()
		tree.texture = tree_tex
		tree.region_enabled = true
		tree.region_rect = Rect2(96, 0, 32, 48)
		tree.scale = Vector2(3.5, 3.5)
		tree.position = p
		tree.z_index = 5
		world_bg.add_child(tree)
