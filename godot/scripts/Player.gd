extends CharacterBody2D

const SPEED = 160.0

# Alex sprite sheets:
# Idle: 128x96  = 4 cols x 3 rows (right, up, down)
# Walk: 192x96  = 6 cols x 3 rows
# Run:  256x96  = 8 cols x 3 rows

@onready var sprite: Sprite2D = $Sprite2D

var idle_tex  = preload("res://assets/Character/Idle.png")
var walk_tex  = preload("res://assets/Character/Walk.png")

# Row indices in the sheet (row 0 = right/east, row 1 = up, row 2 = down)
const ROW_RIGHT = 0
const ROW_UP    = 1
const ROW_DOWN  = 2

var anim_timer  : float = 0.0
var cur_frame   : int   = 0
var facing_row  : int   = ROW_DOWN
var is_moving   : bool  = false

func _ready() -> void:
	sprite.hframes = 4
	sprite.vframes = 3
	sprite.texture = idle_tex
	sprite.scale   = Vector2(2, 2)
	sprite.frame   = 0

func _physics_process(delta: float) -> void:
	var dx = Input.get_axis("ui_left", "ui_right")
	var dy = Input.get_axis("ui_up",   "ui_down")
	var dir = Vector2(dx, dy).normalized()
	is_moving = dir.length() > 0.1

	# Work out facing direction
	if dx < -0.1:
		facing_row   = ROW_RIGHT
		sprite.flip_h = true
	elif dx > 0.1:
		facing_row   = ROW_RIGHT
		sprite.flip_h = false
	elif dy < -0.1:
		facing_row   = ROW_UP
		sprite.flip_h = false
	elif dy > 0.1:
		facing_row   = ROW_DOWN
		sprite.flip_h = false

	# Switch texture and column count
	if is_moving:
		if sprite.texture != walk_tex:
			sprite.texture = walk_tex
			sprite.hframes = 6
			cur_frame = 0
		velocity = dir * SPEED
	else:
		if sprite.texture != idle_tex:
			sprite.texture = idle_tex
			sprite.hframes = 4
			cur_frame = 0
		velocity = velocity.move_toward(Vector2.ZERO, SPEED * 4 * delta)

	move_and_slide()

	# Animate frame
	anim_timer += delta
	var frame_time = 0.1 if is_moving else 0.22
	if anim_timer >= frame_time:
		anim_timer = 0.0
		cur_frame  = (cur_frame + 1) % sprite.hframes
		# Frame index = row * hframes + col
		sprite.frame = facing_row * sprite.hframes + cur_frame
