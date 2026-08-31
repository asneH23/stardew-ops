extends CharacterBody2D

@onready var sprite: Sprite2D = $Sprite2D
var is_walking = false
var path_queue: Array[Vector2] = []
var final_callback: Callable
var speed = 250.0

func _ready() -> void:
	sprite.texture = preload("res://assets/Character/Walk.png")
	sprite.hframes = 6
	sprite.vframes = 3
	sprite.scale = Vector2(2.5, 2.5)
	hide() # Börja gömd i huset

func _process(delta: float) -> void:
	if not is_walking and path_queue.size() > 0:
		is_walking = true
	
	if is_walking:
		var target = path_queue[0]
		var dir = (target - global_position).normalized()
		var distance = global_position.distance_to(target)
		
		var move_dist = speed * delta
		if move_dist >= distance:
			global_position = target
			path_queue.pop_front()
			if path_queue.size() == 0:
				is_walking = false
				sprite.frame = (sprite.frame / sprite.hframes) * sprite.hframes 
				if final_callback.is_valid():
					final_callback.call()
					final_callback = Callable()
		else:
			global_position += dir * move_dist
			update_animation(dir)

func update_animation(dir: Vector2) -> void:
	var facing_row = 2 # Nedåt
	sprite.flip_h = false
	
	if abs(dir.x) > abs(dir.y):
		facing_row = 0 # Höger
		if dir.x < 0:
			sprite.flip_h = true
	elif dir.y < 0:
		facing_row = 1 # Uppåt
		
	var frame_time = int(Time.get_ticks_msec() / 120.0) % sprite.hframes
	sprite.frame = (facing_row * sprite.hframes) + frame_time

func follow_path(points: Array, on_finished: Callable = Callable()) -> void:
	show()
	path_queue.clear()
	for p in points:
		path_queue.append(p)
	final_callback = on_finished
