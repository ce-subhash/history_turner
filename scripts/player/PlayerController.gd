## PlayerController.gd
## Handles 3D character movement, 3-lane horizontal snapping with tweens,
## vertical jump & gravity, slide mechanics, and dual keyboard/swipe input handling.
extends CharacterBody3D
class_name PlayerController

# --- Constants & Configuration ---
## Lane X positions: Left (-2.5), Center (0.0), Right (2.5)
const LANE_LEFT: float = -2.5
const LANE_CENTER: float = 0.0
const LANE_RIGHT: float = 2.5
const LANE_WIDTH: float = 2.5

## Lane transition speed (seconds)
const LANE_SWITCH_DURATION: float = 0.15

## Vertical Jump & Gravity constants
const JUMP_VELOCITY: float = 9.0
const GRAVITY_MULTIPLIER: float = 26.0

## Slide mechanics
const SLIDE_DURATION: float = 0.8
const DEFAULT_HEIGHT: float = 1.8
const SLIDE_HEIGHT_RATIO: float = 0.5

## Touch / Swipe detection threshold in pixels
const SWIPE_THRESHOLD: float = 40.0

# --- State Variables ---
## Current lane index: -1 = Left, 0 = Center, 1 = Right
var current_lane: int = 0

## Slide state tracking
var is_sliding: bool = false
var slide_timer: float = 0.0

## Mobile Touch tracking
var touch_start_pos: Vector2 = Vector2.ZERO
var is_touch_active: bool = false

## Tweens
var lane_tween: Tween = null

# --- Node References ---
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visual_model: Node3D = $VisualModel
@onready var camera: Camera3D = $Camera3D

# Internal cached values for shape restoration
var original_shape_height: float = DEFAULT_HEIGHT
var original_shape_y: float = 0.9


func _ready() -> void:
	# Ensure starting position is snapped to center lane
	position.x = LANE_CENTER
	current_lane = 0

	# Cache initial collision parameters
	_init_collision_cache()

	# Ensure Camera3D is positioned and oriented properly behind player
	_setup_camera()

	# Connect to GameManager signals if needed
	if GameManager:
		GameManager.game_over.connect(_on_game_over)


func _init_collision_cache() -> void:
	if collision_shape and collision_shape.shape:
		if collision_shape.shape is CapsuleShape3D:
			original_shape_height = (collision_shape.shape as CapsuleShape3D).height
		elif collision_shape.shape is BoxShape3D:
			original_shape_height = (collision_shape.shape as BoxShape3D).size.y
		original_shape_y = collision_shape.position.y
	else:
		original_shape_height = DEFAULT_HEIGHT
		original_shape_y = DEFAULT_HEIGHT * 0.5


func _setup_camera() -> void:
	if not camera:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		add_child(camera)

	# Camera3D child node positioned behind player: Vector3(0, 3, 5), rotated looking slightly down
	camera.position = Vector3(0.0, 3.0, 5.0)
	camera.rotation_degrees = Vector3(-16.0, 0.0, 0.0)
	camera.current = true


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_game_over:
		return

	# 1. Keyboard Input System: A/D or Left/Right for lanes; Space/Up for Jump; S/Down for Slide
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		match event.keycode:
			KEY_A, KEY_LEFT:
				switch_lane(-1)
			KEY_D, KEY_RIGHT:
				switch_lane(1)
			KEY_SPACE, KEY_UP, KEY_W:
				jump()
			KEY_S, KEY_DOWN:
				slide()

	# 2. Mobile Touch Input System: Screen touch / drag detection for Swipes
	if event is InputEventScreenTouch:
		if event.is_pressed():
			touch_start_pos = event.position
			is_touch_active = true
		else:
			is_touch_active = false

	elif event is InputEventScreenDrag and is_touch_active:
		var swipe_vec: Vector2 = event.position - touch_start_pos
		if swipe_vec.length() >= SWIPE_THRESHOLD:
			_process_swipe(swipe_vec)
			# Reset touch point so single continuous drag doesn't spam moves
			is_touch_active = false

	# Mouse fallback for desktop testing of touch swipe logic
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				touch_start_pos = event.position
				is_touch_active = true
			else:
				is_touch_active = false
	elif event is InputEventMouseMotion and is_touch_active:
		var swipe_vec: Vector2 = event.position - touch_start_pos
		if swipe_vec.length() >= SWIPE_THRESHOLD:
			_process_swipe(swipe_vec)
			is_touch_active = false


## Interprets gesture direction into lane switch, jump, or slide.
func _process_swipe(swipe_vec: Vector2) -> void:
	if abs(swipe_vec.x) > abs(swipe_vec.y):
		# Horizontal swipe
		if swipe_vec.x < 0.0:
			switch_lane(-1) # Swipe Left
		else:
			switch_lane(1)  # Swipe Right
	else:
		# Vertical swipe
		if swipe_vec.y < 0.0:
			jump()          # Swipe Up
		else:
			slide()         # Swipe Down


## Switches between -1 (Left), 0 (Center), 1 (Right) lanes with smooth tweening.
func switch_lane(direction: int) -> void:
	var target_lane: int = clampi(current_lane + direction, -1, 1)
	if target_lane == current_lane:
		return

	current_lane = target_lane
	var target_x: float = current_lane * LANE_WIDTH

	# Cancel existing tween to maintain instantaneous responsiveness
	if lane_tween and lane_tween.is_running():
		lane_tween.kill()

	lane_tween = create_tween()
	lane_tween.set_trans(Tween.TRANS_QUAD)
	lane_tween.set_ease(Tween.EASE_OUT)
	lane_tween.tween_property(self, "position:x", target_x, LANE_SWITCH_DURATION)


## Applies upward velocity for jump.
func jump() -> void:
	if is_on_floor():
		if is_sliding:
			_end_slide() # Interrupt slide with jump
		velocity.y = JUMP_VELOCITY


## Initiates temporary slide crouching mechanic for 0.8s, shrinking collision height by 50%.
func slide() -> void:
	if not is_sliding:
		is_sliding = true
		slide_timer = SLIDE_DURATION

		# Shrink collision height by 50%
		_set_collision_height(original_shape_height * SLIDE_HEIGHT_RATIO)

		# Visual squash feedback
		if visual_model:
			var visual_tween = create_tween()
			visual_tween.tween_property(visual_model, "scale", Vector3(1.1, SLIDE_HEIGHT_RATIO, 1.1), 0.1)
			visual_tween.parallel().tween_property(visual_model, "position:y", 0.45, 0.1)
	else:
		# Refresh slide duration if already sliding
		slide_timer = SLIDE_DURATION


## Ends the slide and restores collision height.
func _end_slide() -> void:
	if not is_sliding:
		return

	is_sliding = false
	slide_timer = 0.0

	# Restore collision shape height
	_set_collision_height(original_shape_height)

	# Restore visual model transform
	if visual_model:
		var visual_tween = create_tween()
		visual_tween.tween_property(visual_model, "scale", Vector3.ONE, 0.1)
		visual_tween.parallel().tween_property(visual_model, "position:y", original_shape_y, 0.1)


## Adjusts collision shape dimension and vertical offset cleanly.
func _set_collision_height(new_height: float) -> void:
	if not collision_shape or not collision_shape.shape:
		return

	if collision_shape.shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = collision_shape.shape
		capsule.height = new_height
	elif collision_shape.shape is BoxShape3D:
		var box: BoxShape3D = collision_shape.shape
		box.size.y = new_height

	# Center collision box at half-height above floor
	collision_shape.position.y = new_height * 0.5


func _physics_process(delta: float) -> void:
	if GameManager.is_game_over:
		velocity = Vector3.ZERO
		return

	# Handle Slide timer countdown
	if is_sliding:
		slide_timer -= delta
		if slide_timer <= 0.0:
			_end_slide()

	# Constant forward velocity along -Z axis driven by GameManager
	velocity.z = -GameManager.current_speed

	# Apply Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY_MULTIPLIER * delta
	elif velocity.y < 0:
		velocity.y = 0.0

	# Move the character body
	move_and_slide()

	# Check for obstacle collisions
	_check_collisions()


## Detects collision with obstacles tagged or grouped in the environment.
func _check_collisions() -> void:
	for i in range(get_slide_collision_count()):
		var collision: KinematicCollision3D = get_slide_collision(i)
		var collider: Object = collision.get_collider()

		if collider and (collider.is_in_group("obstacles") or collider.name.begins_with("Obstacle")):
			var reason: String = "Crashed into %s" % collider.name
			GameManager.trigger_game_over(reason)
			break


func _on_game_over(_reason: String) -> void:
	# Stop any running tweens
	if lane_tween and lane_tween.is_running():
		lane_tween.kill()
