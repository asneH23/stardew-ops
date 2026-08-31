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
var shipping_box_pos = Vector2(100, -200)

var camera: Camera2D
var target_zoom: Vector2 = Vector2(1.2, 1.2)
const MIN_ZOOM = Vector2(0.5, 0.5)
const MAX_ZOOM = Vector2(3.0, 3.0)

func _ready() -> void:
	_setup_camera()
	place_world_objects()
	
	api_client.state_updated.connect(_on_state_updated)
	api_client.connection_error.connect(_on_connection_error)

func _process(delta: float) -> void:
	if camera:
		camera.zoom = camera.zoom.lerp(target_zoom, 8.0 * delta)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom += Vector2(0.15, 0.15)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom -= Vector2(0.15, 0.15)
	elif event is InputEventPanGesture:
		# För Mac-trackpads!
		target_zoom -= Vector2(event.delta.y, event.delta.y) * 0.05
	elif event is InputEventKey and event.is_pressed():
		# Keyboard fallback (Q/E eller +/-)
		if event.keycode == KEY_E or event.keycode == KEY_PLUS or event.keycode == KEY_EQUAL:
			target_zoom += Vector2(0.2, 0.2)
		elif event.keycode == KEY_Q or event.keycode == KEY_MINUS:
			target_zoom -= Vector2(0.2, 0.2)
			
	target_zoom = target_zoom.clamp(MIN_ZOOM, MAX_ZOOM)
		
func _setup_camera() -> void:
	camera = player.get_node_or_null("Camera2D")
	if camera:
		player.remove_child(camera)
		add_child(camera)
		camera.position = Vector2(0, 0)
		camera.zoom = target_zoom
		camera.make_current()

func _on_state_updated(state: Dictionary) -> void:
	var total_xp = int(state.get("total_xp", 0))
	var level = int(state.get("level", 1))
	var xp_for_next = int(state.get("xp_for_next_level", 100))
	var course_id = str(state.get("last_course_id", "stardew"))
	
	xp_label.text = "XP: %d" % total_xp
	level_label.text = "Level %d" % level
	course_label.text = "Senaste: " + course_id.capitalize()
	progress_bar.max_value = xp_for_next
	progress_bar.value = total_xp % xp_for_next

	if last_known_xp == -1:
		last_known_xp = total_xp
		_instantly_plant_history(total_xp)
	elif total_xp > last_known_xp:
		var gained_xp = total_xp - last_known_xp
		_spawn_floating_text("+%d XP!" % gained_xp, house_door + Vector2(0, -60), Color(0.2, 1.0, 0.4))
		
		var new_crops = (total_xp / 50) - (last_known_xp / 50)
		for i in range(new_crops):
			# Vi lägger till grödor i kön om vi passerat en 50-gräns
			var xp_val = (last_known_xp / 50 + i + 1) * 50
			planting_queue.append(xp_val)
		last_known_xp = total_xp
		process_planting_queue()

func _spawn_floating_text(text: String, pos: Vector2, color: Color) -> void:
	var label = Label.new()
	label.text = text
	label.position = pos
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 5)
	
	# Gör texten stor och fet om möjligt
	label.scale = Vector2(1.5, 1.5)
	crops_node.add_child(label)
	
	var tween = get_tree().create_tween().set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(0, -50), 2.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(label, "modulate:a", 0.0, 2.0).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(label.queue_free)

func _on_connection_error(message: String) -> void:
	status_label.text = "❌ " + message

func _instantly_plant_history(total_xp: int) -> void:
	var total_crops = total_xp / 50
	for i in range(total_crops):
		var xp_val = (i * 50) # Use 0-indexed for history placement
		var hub_index = i % 3
		var crops_at_hub = i / 3
		var slot = crops_at_hub % 9
		
		# Bara spawna om vi är i den "aktuella" cykeln
		var current_cycle = (total_crops / 3) / 9
		var this_crop_cycle = crops_at_hub / 9
		
		if this_crop_cycle == current_cycle:
			_spawn_crop(i, hubs[hub_index])
		elif this_crop_cycle == current_cycle - 1 and (total_crops / 3) % 9 == 0:
			# If exactly wrapped, show the full previous cycle until the 10th arrives
			_spawn_crop(i, hubs[hub_index])

func process_planting_queue() -> void:
	if is_player_busy or planting_queue.size() == 0:
		return
		
	is_player_busy = true
	var xp_val = planting_queue.pop_front()
	var crop_index = (xp_val / 50) - 1 # 0-indexed
	var hub_index = crop_index % 3
	var crops_at_hub = crop_index / 3
	var slot = crops_at_hub % 9
	var target_hub = hubs[hub_index]
	
	var path = [house_door]
	if hub_index == 0 or hub_index == 1:
		path.append(Vector2(0, target_hub.y))
		path.append(target_hub)
	else:
		path.append(target_hub)
		
	player.global_position = house_door
	
	# Om vi precis wrappade (slot 0 och crops_at_hub > 0), rensa hubben först!
	if slot == 0 and crops_at_hub > 0:
		player.follow_path(path, func(): _harvest_and_plant(crop_index, target_hub, path))
	else:
		player.follow_path(path, func(): _on_arrived_at_hub(crop_index, target_hub, path))

func _harvest_and_plant(crop_index: int, target_hub: Vector2, path_taken: Array) -> void:
	# Skörde-animation
	for child in crops_node.get_children():
		if child is Sprite2D and child.position.distance_to(target_hub) < 80:
			# Sväva upp och försvinn
			var tween = get_tree().create_tween().set_parallel(true)
			tween.tween_property(child, "position", child.position + Vector2(0, -50), 0.5)
			tween.tween_property(child, "modulate:a", 0.0, 0.5)
			tween.chain().tween_callback(child.queue_free)
			
	# Extra dopamin-text
	var label = Label.new()
	label.text = "HARVEST! +BONUS"
	label.position = target_hub + Vector2(-40, -40)
	label.add_theme_color_override("font_color", Color(1, 0.5, 0.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	crops_node.add_child(label)
	var label_tween = get_tree().create_tween().set_parallel(true)
	label_tween.tween_property(label, "position", label.position + Vector2(0, -60), 2.0)
	label_tween.tween_property(label, "modulate:a", 0.0, 2.0)
	label_tween.chain().tween_callback(label.queue_free)
	
	await get_tree().create_timer(1.0).timeout
	_on_arrived_at_hub(crop_index, target_hub, path_taken)

func _on_arrived_at_hub(crop_index: int, target_hub: Vector2, path_taken: Array) -> void:
	_spawn_crop(crop_index, target_hub, true)
	
	await get_tree().create_timer(1.0).timeout
	var return_path = path_taken.duplicate()
	return_path.reverse()
	
	player.follow_path(return_path, func():
		player.hide()
		is_player_busy = false
		process_planting_queue()
	)

func _spawn_crop(crop_index: int, hub_pos: Vector2, animate: bool = false) -> void:
	var crops_at_hub = crop_index / 3
	var slot = crops_at_hub % 9
	var slot_x = (slot % 3) - 1
	var slot_y = (slot / 3) - 1
	var final_pos = hub_pos + Vector2(slot_x * 32, slot_y * 32)
	
	var crop = Sprite2D.new()
	crop.texture = preload("res://assets/Objects/Spring Crops.png")
	crop.region_enabled = true
	
	var crop_rects = [
		Rect2(64, 0, 16, 16),
		Rect2(80, 16, 16, 16),
		Rect2(64, 32, 16, 16),
		Rect2(80, 48, 16, 16),
		Rect2(64, 64, 16, 16)
	]
	crop.region_rect = crop_rects[crop_index % crop_rects.size()]
	crop.scale = Vector2(2.5, 2.5)
	crop.position = final_pos
	crop.z_index = -5
	crops_node.add_child(crop)
	
	if animate:
		crop.scale = Vector2.ZERO
		var tween = get_tree().create_tween()
		tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(crop, "scale", Vector2(2.5, 2.5), 0.8)
		
		var label = Label.new()
		label.text = "+50 XP"
		label.position = final_pos + Vector2(-20, -20)
		label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		label.add_theme_constant_override("outline_size", 4)
		crops_node.add_child(label)
		
		var label_tween = get_tree().create_tween().set_parallel(true)
		label_tween.tween_property(label, "position", label.position + Vector2(0, -40), 1.5)
		label_tween.tween_property(label, "modulate:a", 0.0, 1.5)
		label_tween.chain().tween_callback(label.queue_free)

func _add_fence_row(start: Vector2, count: int, step: Vector2) -> void:
	var fence_tex = preload("res://assets/Objects/Fence Wood.png")
	for i in range(count):
		var f = Sprite2D.new()
		f.texture = fence_tex
		f.region_enabled = true
		f.region_rect = Rect2(0, 0, 16, 32) # Vertikal träplanka
		f.scale = Vector2(2, 2)
		f.position = start + step * i
		f.z_index = 2
		world_bg.add_child(f)

func _add_sprite(tex_path: String, region: Rect2, pos: Vector2, sc: Vector2, z: int) -> void:
	var s = Sprite2D.new()
	s.texture = load(tex_path)
	s.region_enabled = true
	s.region_rect = region
	s.scale = sc
	s.position = pos
	s.z_index = z
	world_bg.add_child(s)

func place_world_objects() -> void:
	# === BAKGRUND ===
	# Rikt, levande grönt gräs
	var base = ColorRect.new()
	base.color = Color(0.38, 0.65, 0.29, 1)
	base.position = Vector2(-1200, -1200)
	base.size = Vector2(2400, 2400)
	base.z_index = -20
	world_bg.add_child(base)
	
	# Lite mörkare gräsfläckar för djup och textur
	for i in range(80):
		var patch = ColorRect.new()
		patch.color = Color(0.32, 0.57, 0.24, randf_range(0.4, 0.7))
		var pw = randf_range(30, 90)
		var ph = randf_range(20, 60)
		patch.position = Vector2(randf_range(-700, 700), randf_range(-500, 500))
		patch.size = Vector2(pw, ph)
		patch.z_index = -19
		world_bg.add_child(patch)

	# === GRUSGÅNGARNA (Dirt paths - varma och organiska) ===
	# Vertikal gång (från huset ner)
	var path_col = Color(0.71, 0.54, 0.35, 1)
	var path_shadow = Color(0.55, 0.40, 0.25, 1)
	var pv = ColorRect.new()
	pv.color = path_shadow
	pv.position = Vector2(-22, -115)
	pv.size = Vector2(44, 392)
	pv.z_index = -15
	world_bg.add_child(pv)
	var pv2 = ColorRect.new()
	pv2.color = path_col
	pv2.position = Vector2(-17, -112)
	pv2.size = Vector2(34, 386)
	pv2.z_index = -14
	world_bg.add_child(pv2)
	
	# Horisontell gång (tvärsgatan)
	var ph_r = ColorRect.new()
	ph_r.color = path_shadow
	ph_r.position = Vector2(-256, 80)
	ph_r.size = Vector2(512, 44)
	ph_r.z_index = -15
	world_bg.add_child(ph_r)
	var ph_r2 = ColorRect.new()
	ph_r2.color = path_col
	ph_r2.position = Vector2(-252, 84)
	ph_r2.size = Vector2(504, 36)
	ph_r2.z_index = -14
	world_bg.add_child(ph_r2)

	# === STÄNGSEL runt gårdarna ===
	# Runt vänster hub
	_add_fence_row(Vector2(-340, 40), 6, Vector2(32, 0))
	_add_fence_row(Vector2(-340, 164), 6, Vector2(32, 0))
	_add_fence_row(Vector2(-340, 40), 4, Vector2(0, 32))
	_add_fence_row(Vector2(-175, 40), 4, Vector2(0, 32))
	# Runt höger hub
	_add_fence_row(Vector2(175, 40), 6, Vector2(32, 0))
	_add_fence_row(Vector2(175, 164), 6, Vector2(32, 0))
	_add_fence_row(Vector2(175, 40), 4, Vector2(0, 32))
	_add_fence_row(Vector2(338, 40), 4, Vector2(0, 32))
	# Runt nedre hub
	_add_fence_row(Vector2(-90, 196), 6, Vector2(32, 0))
	_add_fence_row(Vector2(-90, 320), 6, Vector2(32, 0))
	_add_fence_row(Vector2(-90, 196), 4, Vector2(0, 32))
	_add_fence_row(Vector2(75, 196), 4, Vector2(0, 32))

	# === ODLINGSLÅDOR ===
	var soil_tex = preload("res://assets/Tileset/Tilled Soil.png")
	for hub in hubs:
		var plot_border = ColorRect.new()
		plot_border.color = Color(0.42, 0.27, 0.15, 1)
		plot_border.position = hub + Vector2(-52, -52)
		plot_border.size = Vector2(104, 104)
		plot_border.z_index = -11
		world_bg.add_child(plot_border)
		for x in [-1, 0, 1]:
			for y in [-1, 0, 1]:
				var soil = Sprite2D.new()
				soil.texture = soil_tex
				soil.region_enabled = true
				soil.region_rect = Rect2(64, 0, 16, 16)
				soil.scale = Vector2(2, 2)
				soil.position = hub + Vector2(x * 32, y * 32)
				soil.z_index = -10
				world_bg.add_child(soil)

	# === DEKORATION ===
	# Huset (CPU / Farmhouse)
	_add_sprite("res://assets/Objects/House.png", Rect2(144, 0, 80, 112), Vector2(0, -230), Vector2(3, 3), -5)
	
	# Shipping Box
	_add_sprite("res://assets/Objects/shipping box.png", Rect2(0, 0, 48, 64), shipping_box_pos, Vector2(2, 2), -5)
	
	# Brevlåda (nära huset)
	_add_sprite("res://assets/Objects/Mailbox.png", Rect2(0, 0, 16, 16), Vector2(90, -180), Vector2(3, 3), 2)
	
	# Hö-balar (vid sidan av gårdarna)
	_add_sprite("res://assets/Objects/Hay Bales.png", Rect2(0, 0, 16, 16), Vector2(-430, 200), Vector2(3, 3), 2)
	_add_sprite("res://assets/Objects/Hay Bales.png", Rect2(0, 0, 16, 16), Vector2(380, 200), Vector2(3, 3), 2)
	_add_sprite("res://assets/Objects/Hay Bales.png", Rect2(16, 0, 16, 16), Vector2(-430, 232), Vector2(3, 3), 2)
	
	# Fågelskrämma (vid varje odlingsplats)
	_add_sprite("res://assets/Objects/Scarescrow.png", Rect2(0, 0, 16, 32), Vector2(-340, 50), Vector2(2.5, 2.5), 3)
	_add_sprite("res://assets/Objects/Scarescrow.png", Rect2(0, 0, 16, 32), Vector2(310, 50), Vector2(2.5, 2.5), 3)
	
	# Brunn (dekorationspunkt söder om huset)
	_add_sprite("res://assets/Objects/Well.png", Rect2(0, 0, 32, 48), Vector2(-130, -200), Vector2(2.5, 2.5), -5)
	
	# Kyckling (wandrar runt i gårdsplanen)
	_add_sprite("res://assets/Objects/Chicken White.png", Rect2(0, 0, 16, 16), Vector2(-200, 50), Vector2(2.5, 2.5), 3)
	_add_sprite("res://assets/Objects/Chicken White.png", Rect2(0, 0, 16, 16), Vector2(200, 40), Vector2(2.5, 2.5), 3)
	
	# Får (lite längre ut)
	_add_sprite("res://assets/Objects/Sheep Female.png", Rect2(0, 0, 32, 48), Vector2(-550, 300), Vector2(2.5, 2.5), 3)
	_add_sprite("res://assets/Objects/Sheep Female.png", Rect2(0, 0, 32, 48), Vector2(510, 280), Vector2(2.5, 2.5), 3)

	# === TRÄD (organisk ram med blandade träd) ===
	var tree_defs = [
		["res://assets/Objects/Maple Tree.png", Rect2(96, 0, 32, 48), Vector2(3.5, 3.5)],
		["res://assets/Objects/Maple Tree.png", Rect2(64, 0, 32, 48), Vector2(3.5, 3.5)],
	]
	var tree_positions = [
		Vector2(-650, -420), Vector2(-480, -440), Vector2(-300, -460), Vector2(-120, -450),
		Vector2(120, -450), Vector2(300, -460), Vector2(480, -440), Vector2(650, -420),
		Vector2(-700, -280), Vector2(700, -280), Vector2(-720, -120), Vector2(720, -120),
		Vector2(-710, 60), Vector2(710, 60), Vector2(-700, 240), Vector2(700, 240),
		Vector2(-690, 420), Vector2(690, 420),
		Vector2(-550, 500), Vector2(-380, 520), Vector2(-200, 510), Vector2(0, 520),
		Vector2(200, 510), Vector2(380, 520), Vector2(550, 500),
		# Extra inre träd för att fylla tomrum
		Vector2(-600, -100), Vector2(600, -100), Vector2(-620, 150), Vector2(620, 150),
	]
	for i in range(tree_positions.size()):
		var def = tree_defs[i % tree_defs.size()]
		_add_sprite(def[0], def[1], tree_positions[i], def[2], 5)


