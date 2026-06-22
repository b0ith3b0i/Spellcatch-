##TODO
#https://www.youtube.com/watch?v=JlgZtOFMdfc&t=255s (The old movement/camera tutorial i used)
## The 3 demo gadgets (Net is done, other 2 idk yet)
## Functional sprite movement and thinking
## Level design

## LESS IMPORTANT TODO:
## An actual design for the player and main villian
## Music for the 3 levels (Tutorial, one Fire area and one Water area)
## 3d models for the sprites and stuff
## Intro cutscene and voice acting
## Bart Bash

extends CharacterBody3D

# Defining the camera/mouse sensitivity
@export_group("Camera")
@export_range(0.0, 1.0) var mouse_sensitivity := 0.25

# la movemento
@export_group("Movement")
@export var move_speed := 8.5
@export var acceleration := 25.0
@export var rotation_speed := 10.0
@export var camera_auto_follow_speed := 1.5

@export_group("Juice / Jump")
@export var jump_impulse := 12.0 # Strength of first jump
@export var double_jump_impulse := 10.0 # Strength of second jump
@export var _gravity := -30.0 # Custom gravity acceleration

# Gadgets
enum GadgetType { NONE, CLUB, NET, SLINGSHOT } #placeholder names, change when come up with new items

@export_group("Gadgets")
@export var gadget_scenes: Array[PackedScene] = [] 
@export var current_gadget: GadgetType = GadgetType.NET # Swap the current gadget type
@export var right_stick_deadzone: float = 0.60 # Must push stick at least 60% out to swing
@export var gadget_active_slot: bool = true # Toggle via game logic if gadget is selected/equipped

# State Flags
var _is_snapping := false
var _target_camera_height := 2.5
var _has_double_jumped := false
var _is_gadget_swung := false 
var _is_playing_attack_animation := false

# Stores the camera motion
var _camera_input_direction := Vector2.ZERO
var _last_movement_direction := Vector3.BACK

# Direct node paths to prevent unique name database crashes
@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/Camera3D
@onready var _skin: SophiaSkin = %SophiaSkin as SophiaSkin

func _ready() -> void:
	if _camera != null:
		_camera.make_current()

# Capture the mouse into the project
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# Check to see if there's a mouse for the camera motion and if it's focused
func _unhandled_input(event: InputEvent) -> void:
	var is_camera_motion := (
		event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	)
	if is_camera_motion:
		_camera_input_direction = event.screen_relative * mouse_sensitivity

# Camera and player movement physics
func _physics_process(delta: float) -> void:
	var move_direction := Vector3.ZERO
	
	if Input.is_action_just_pressed("camera_snap"):
		_is_snapping = true
		
		# 1. Read Inputs
	var dpad_look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	
	if dpad_look.length() > 0.0:
		_camera_input_direction = dpad_look * (mouse_sensitivity * 10.0)
		_is_snapping = false
	else:
		# Clear camera when dpad is pressed
		_camera_input_direction = Vector2.ZERO 
		
	if _camera_input_direction.length() > 0.0:
		_is_snapping = false

	# 2. Right joystick for using Gadgets
	process_gadget_use()

	# 3. Camera Rotating
	var is_player_manually_looking := dpad_look.length() > 0.0 or _camera_input_direction.length() > 0.0
	if not _is_snapping and _camera_pivot != null:
		if is_player_manually_looking:
			_camera_pivot.rotation.x += _camera_input_direction.y * delta
			_camera_pivot.rotation.x = clamp(_camera_pivot.rotation.x, -PI / 6.0, PI / 3.0)
			_camera_pivot.rotation.y -= _camera_input_direction.x * delta
		else:
			# Camera auto-trackinator
			var horizontal_speed := Vector3(velocity.x, 0.0, velocity.z).length()
			if horizontal_speed > 0.5 and is_on_floor() and _skin != null:
				_camera_pivot.global_rotation.y = lerp_angle(_camera_pivot.global_rotation.y, _skin.global_rotation.y, camera_auto_follow_speed * delta)

	# 4. Camera snap
	if _is_snapping and _skin != null and _camera_pivot != null:
		_camera_pivot.global_rotation.y = lerp_angle(
			_camera_pivot.global_rotation.y,
			_skin.global_rotation.y,
			8.0 * delta
		)
		var target_pitch: float = -0.05
		_camera_pivot.rotation.x = lerp(_camera_pivot.rotation.x, target_pitch, 8.0 * delta)
		_camera_pivot.position.y = lerp(_camera_pivot.position.y, _target_camera_height, 8.0 * delta)
		
		var angle_diff := angle_difference(_camera_pivot.global_rotation.y, _skin.global_rotation.y)
		var pitch_diff := _camera_pivot.rotation.x - target_pitch
		if abs(angle_diff) < 0.08 and abs(pitch_diff) < 0.08:
			_is_snapping = false
			_camera_input_direction = Vector2.ZERO

	# 5. Movement
	var raw_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var input_tilt := raw_input.length()
	var forward := Vector3.FORWARD
	var right := Vector3.RIGHT
	
	if _camera != null:
		forward = _camera.global_basis.z
		right = _camera.global_basis.x
		
	move_direction = forward * raw_input.y + right * raw_input.x
	move_direction.y = 0.0
	
	if move_direction.length() > 0.0:
		move_direction = move_direction.normalized()

	# Ground Velocity
	var y_velocity := velocity.y
	velocity.y = 0.0
	
	# Scales velocity cleanly by the analog input_tilt
	var target_velocity := move_direction * (move_speed * input_tilt)
	velocity = velocity.move_toward(target_velocity, acceleration * delta)
	velocity.y = y_velocity + _gravity * delta
	
	if is_on_floor():
		_has_double_jumped = false

	# Jump Conditions Checking
	var is_starting_jump := Input.is_action_just_pressed("jump") and is_on_floor()
	var is_double_jump := Input.is_action_just_pressed("jump") and not is_on_floor() and not _has_double_jumped
	
	if is_starting_jump:
		velocity.y = jump_impulse
		if _skin != null:
			_skin.jump()
	elif is_double_jump:
		velocity.y = double_jump_impulse
		_has_double_jumped = true
		if _skin != null:
			_skin.jump()
			
	move_and_slide()
	
	if raw_input.length() > 0.05:
		_last_movement_direction = move_direction

	# 6. Animation and skin functions
	if _skin != null:
		if not _is_playing_attack_animation:
			var target_angle := Vector3.BACK.signed_angle_to(_last_movement_direction, Vector3.UP)
			_skin.rotation.y = lerp_angle(_skin.rotation.y, target_angle, rotation_speed * delta)
		
		if not is_on_floor():
			if velocity.y < 0.0:
				_skin.fall()
			else:
				_skin.jump()
		else:
			var ground_speed := Vector3(velocity.x, 0.0, velocity.z).length()
			if ground_speed > 0.1:
				_skin.move()
			else:
				_skin.idle()

# Detect the right stick and spawn the Net hitbox
func process_gadget_use() -> void:
	if not gadget_active_slot:
		return
		
	# Read right joystick input axes
	var stick_x = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var stick_y = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	var stick_input = Vector2(stick_x, stick_y)
	
	if stick_input.length() >= right_stick_deadzone:
		if not _is_gadget_swung:
			_is_gadget_swung = true # Only swing ONCE per flick out (i forgot this for so long and it PISSED me off)
			use_gadget(stick_input.normalized())
	else:
		# Reset tracking only when the stick returns near deadzone center
		if stick_input.length() < (right_stick_deadzone - 0.15):
			_is_gadget_swung = false

func use_gadget(stick_direction: Vector2) -> void:
	var gadget_index = int(current_gadget) - 1
	# Check if i actually remembered to attach the damn hitbox scene
	if current_gadget == GadgetType.NONE:
		return
	if gadget_index < 0 or gadget_index >= gadget_scenes.size() or gadget_scenes[gadget_index] == null:
		print("you didnt put a hitbox dingus (current selected gadgetslot)")
		return
		
	# Turn on rotation lock so our model stays locked forward during strike frame windows
	_is_playing_attack_animation = true

	# Calculate camera-relative vector for the attack direction
	var cam_forward = -_camera_pivot.global_basis.z
	var cam_right = _camera_pivot.global_basis.x
	
	cam_forward.y = 0.0
	cam_right.y = 0.0
	cam_forward = cam_forward.normalized()
	cam_right = cam_right.normalized()
	
	var attack_direction_3d = (cam_right * -stick_direction.x) + (cam_forward * stick_direction.y)
	attack_direction_3d = attack_direction_3d.normalized()
	
	# Face the player's 3D skin model instantly toward the attack direction
	if _skin != null:
		var attack_angle = Vector3.BACK.signed_angle_to(attack_direction_3d, Vector3.UP)
		_skin.rotation.y = attack_angle
		
		# Update internal movement trajectory direction so it holds this rotation frame permanently
		_last_movement_direction = attack_direction_3d 
		
	# Instantiate the weapon scene out of our array configuration
	var new_hitbox = gadget_scenes[gadget_index].instantiate() as Node3D
	get_parent().add_child(new_hitbox)
	
	# Position it outward directly in front of where the skin is now looking
	var strike_offset_distance = 1.5
	new_hitbox.global_position = global_position + (attack_direction_3d * strike_offset_distance)
	
	# Orient the hitbox direction to look away from the player
	var look_target = new_hitbox.global_position + attack_direction_3d
	new_hitbox.look_at(look_target, Vector3.UP)
	
	# Pass explicit animation calls depending on what tool is used
	if _skin.has_method("attack"):
		match current_gadget:
			GadgetType.CLUB:
				_skin.attack("club_swing")
			GadgetType.NET:
				_skin.attack("net_swipe")
			GadgetType.SLINGSHOT:
				_skin.attack("slingshot_shoot")
		
	# Let the hitbox collision track targets for a short lifetime frame
	await get_tree().create_timer(0.25).timeout
	if is_instance_valid(new_hitbox):
		new_hitbox.queue_free()
		
	# Release the lock so standard analog runtime movement rotation functions again
	_is_playing_attack_animation = false

# call this to switch gadgets 
func switch_gadget(new_gadget_type: GadgetType) -> void:
	current_gadget = new_gadget_type
