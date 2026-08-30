extends CharacterBody2D

const SPEED = 300.0

func _physics_process(delta: float) -> void:
	# Läs input från piltangenter (eller standard WASD om konfigurerat)
	var direction_x = Input.get_axis("ui_left", "ui_right")
	var direction_y = Input.get_axis("ui_up", "ui_down")
	
	# Normalisera så vi inte springer snabbare diagonalt
	var direction = Vector2(direction_x, direction_y).normalized()
	
	if direction:
		velocity = direction * SPEED
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)

	move_and_slide()
