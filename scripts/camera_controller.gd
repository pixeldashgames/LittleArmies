extends Camera3D

@export var camera_speed: float
@export var camera_damping: float

var limits: Rect2

var current_speed: Vector2

var can_move := true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if not can_move:
		return

	var movement := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")) * camera_speed
	
	if camera_damping == 0:
		current_speed = movement
	else:
		current_speed = current_speed.move_toward(movement, camera_speed * delta / camera_damping)

	position += Vector3(current_speed.x, 0, current_speed.y) * delta

	position.x = clamp(position.x, limits.position.x, limits.position.x + limits.size.x)
	position.z = clamp(position.z, limits.position.y, limits.position.y + limits.size.y)