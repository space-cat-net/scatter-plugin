extends CharacterBody3D


@export var walk_speed: float = 5.0
@export_range(0, 1, 0.001, 'or_greater') var mouse_sensivity: float = 1.0
@export var invert_mouse: bool = false



func _physics_process(delta: float) -> void:
	if not Input.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Get the input direction and handle the movement/deceleration.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * walk_speed
		velocity.z = direction.z * walk_speed
	else:
		velocity.x = move_toward(velocity.x, 0, walk_speed)
		velocity.z = move_toward(velocity.z, 0, walk_speed)
	
	move_and_slide()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var turn = event.relative * mouse_sensivity * deg_to_rad(0.2)
		if not invert_mouse:
			turn *= -1
		rotation.y += turn.x
		$Camera.rotation.x = clamp($Camera.rotation.x + turn.y, PI * -0.5, PI * 0.5)
