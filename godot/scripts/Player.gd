extends CharacterBody2D

const SPEED = 150.0

@onready var sprite = $Sprite2D
var idle_texture = preload("res://assets/Character/Idle.png")
var walk_texture = preload("res://assets/Character/Walk.png")

var animation_timer = 0.0
var current_frame = 0

func _physics_process(delta: float) -> void:
	var direction_x = Input.get_axis("ui_left", "ui_right")
	var direction_y = Input.get_axis("ui_up", "ui_down")
	var direction = Vector2(direction_x, direction_y).normalized()
	
	if direction:
		velocity = direction * SPEED
		if sprite.texture != walk_texture:
			sprite.texture = walk_texture
			sprite.hframes = 6
			sprite.vframes = 3
			current_frame = 0
		
		# Vänd spelaren åt rätt håll
		if direction_x < 0:
			sprite.flip_h = true
		elif direction_x > 0:
			sprite.flip_h = false
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)
		if sprite.texture != idle_texture:
			sprite.texture = idle_texture
			sprite.hframes = 4
			sprite.vframes = 3
			current_frame = 0

	move_and_slide()
	
	# Manuell animations-loop!
	animation_timer += delta
	var frame_time = 0.12 if direction else 0.25
	if animation_timer >= frame_time:
		animation_timer = 0.0
		current_frame = (current_frame + 1) % sprite.hframes
		sprite.frame = current_frame
