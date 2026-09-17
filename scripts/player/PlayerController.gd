## PlayerController.gd
## Handles 3D character movement, 3-lane horizontal snapping with tweens,
## vertical jump & gravity, slide mechanics, Character Abilities, and Phase 4 Fever States.
## Renders characters using pure direct rear-view (0° azimuth) AAA sprites with multi-frame run cycles.
## Includes boundary void fall death and procedural sound effects.
extends CharacterBody3D

const CharacterDataScript = preload("res://scripts/resources/CharacterData.gd")
const CollectibleScript = preload("res://scripts/world/Collectible.gd")

# --- Character Sprite Manifest (Pure Direct Rear View 0° Azimuth) ---
const CHARACTER_SPRITES = {
	"Chibi Leader": {
		"run1": preload("res://assets/sprites/characters/chibi_rear_run1.png"),
		"run2": preload("res://assets/sprites/characters/chibi_rear_run2.png"),
		"jump": preload("res://assets/sprites/characters/chibi_rear_jump.png"),
		"slide": preload("res://assets/sprites/characters/chibi_rear_slide.png"),
		"modulate": Color(1.0, 1.0, 1.0),
		"light_color": Color(1.0, 0.95, 0.88),
		"light_energy": 2.2,
		"light_range": 10.0,
		"light_offset": Vector3(0.0, 1.2, 0.1),
		"base_y": 0.80
	},
	"Julius Caesar": {
		"run1": preload("res://assets/sprites/characters/caesar_rear_run1.png"),
		"run2": preload("res://assets/sprites/characters/caesar_rear_run2.png"),
		"jump": preload("res://assets/sprites/characters/caesar_rear_jump.png"),
		"slide": preload("res://assets/sprites/characters/caesar_rear_slide.png"),
		"modulate": Color(1.0, 0.98, 0.95),
		"light_color": Color(1.0, 0.85, 0.4),
		"light_energy": 2.2,
		"light_range": 10.0,
		"light_offset": Vector3(0.0, 1.2, 0.1),
		"base_y": 0.84
	},
	"Joan of Arc": {
		"run1": preload("res://assets/sprites/characters/joan_rear_run1.png"),
		"run2": preload("res://assets/sprites/characters/joan_rear_run2.png"),
		"jump": preload("res://assets/sprites/characters/joan_rear_jump.png"),
		"slide": preload("res://assets/sprites/characters/joan_rear_slide.png"),
		"modulate": Color(0.96, 0.98, 1.0),
		"light_color": Color(0.75, 0.9, 1.0),
		"light_energy": 2.8,
		"light_range": 11.0,
		"light_offset": Vector3(0.0, 1.7, 0.0),
		"base_y": 0.84
	},
	"Harriet Tubman": {
		"run1": preload("res://assets/sprites/characters/harriet_rear_run1.png"),
		"run2": preload("res://assets/sprites/characters/harriet_rear_run2.png"),
		"jump": preload("res://assets/sprites/characters/harriet_rear_jump.png"),
		"slide": preload("res://assets/sprites/characters/harriet_rear_slide.png"),
		"modulate": Color(1.0, 0.95, 0.9),
		"light_color": Color(1.0, 0.78, 0.35),
		"light_energy": 3.8,
		"light_range": 16.0,
		"light_offset": Vector3(0.35, 0.85, -0.2),
		"base_y": 0.84
	}
}

# --- Constants & Configuration ---
const LANE_LEFT: float = -2.5
const LANE_CENTER: float = 0.0
const LANE_RIGHT: float = 2.5
const LANE_WIDTH: float = 2.5
const LANE_SWITCH_DURATION: float = 0.15

const JUMP_VELOCITY: float = 9.5
const GRAVITY_MULTIPLIER: float = 26.0

const SLIDE_DURATION: float = 0.8
const DEFAULT_HEIGHT: float = 1.8
const SLIDE_HEIGHT_RATIO: float = 0.5
const SWIPE_THRESHOLD: float = 30.0

# Magnetism constants
const MAGNET_RADIUS: float = 14.0
const MAGNET_PULL_SPEED: float = 22.0
const FEVER_MAGNET_RADIUS: float = 20.0
const FEVER_MAGNET_SPEED: float = 32.0

# --- State Variables ---
var current_lane: int = 0
var is_sliding: bool = false
var slide_timer: float = 0.0

var touch_start_pos: Vector2 = Vector2.ZERO
var is_touch_active: bool = false
var lane_tween: Tween = null

# Double-tap & swipe gesture tracking
var last_tap_time: float = -10.0
var last_tap_pos: Vector2 = Vector2.ZERO
const DOUBLE_TAP_TIME: float = 0.35

# Speed Boost Launch Ramp Tracking
var ramp_boost_timer: float = 0.0
var ramp_speed_bonus: float = 0.0

# Active Ability & Passive State
var is_invulnerable: bool = false
var is_ghost_mode: bool = false
var has_divine_aura: bool = false
var has_magnet_active: bool = false

# Phase 4 Fever State Tracking
var is_peasant_fever: bool = false
var is_divine_fever: bool = false
var artillery_timer: float = 0.0

# Phase 5 Relic State Tracking
var cleopatra_asp_used: bool = false
var tesla_magnet_timer: float = 0.0

# Passive: Zealot's Faith tracker
var zealot_emergency_triggered: bool = false
var emergency_shield_timer: float = 0.0

# In-Run Power-Up State
var in_run_magnet_timer: float = 0.0
var has_chrono_shield: bool = false
var chariot_boost_timer: float = 0.0
var invulnerable_timer: float = 0.0
var was_on_floor_last_frame: bool = true

# Juice & Game Feel State
var camera_trauma: float = 0.0
var landing_dip_offset: float = 0.0
var close_call_history: Dictionary = {}

# Pure Rear-View 2.5D Character Sprite & Lighting
var character_sprite: Sprite3D = null
var character_light: OmniLight3D = null
var active_character_name: String = "Chibi Leader"
var run_anim_time: float = 0.0
var banking_tilt: float = 0.0
var dust_particles: CPUParticles3D = null


# --- Node References ---
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visual_model: Node3D = $VisualModel
@onready var camera: Camera3D = $Camera3D

var shield_mesh: MeshInstance3D
var original_shape_height: float = DEFAULT_HEIGHT
var original_shape_y: float = 0.9


func _ready() -> void:
	position.x = LANE_CENTER
	current_lane = 0
	_init_collision_cache()
	_setup_camera()
	_setup_ability_visuals()
	_setup_dust_particles()

	if GameManager:
		GameManager.game_over.connect(_on_game_over)
		GameManager.power_changed.connect(_on_power_changed)
		GameManager.fever_state_started.connect(_on_fever_started)
		GameManager.fever_state_ended.connect(_on_fever_ended)

	if CharacterManager:
		CharacterManager.ability_activated.connect(_on_ability_activated)
		CharacterManager.ability_deactivated.connect(_on_ability_deactivated)
		CharacterManager.character_selected.connect(_on_character_selected)
		if CharacterManager.active_character:
			_apply_character_visuals(CharacterManager.active_character)
		else:
			_apply_character_visuals(null)


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
	_set_collision_height(original_shape_height)


func _setup_camera() -> void:
	if not camera:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		add_child(camera)

	camera.position = Vector3(0.0, 3.8, 5.0)
	camera.rotation_degrees = Vector3(-16.5, 0.0, 0.0)
	camera.fov = 68.0
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.current = true


func _setup_dust_particles() -> void:
	dust_particles = CPUParticles3D.new()
	dust_particles.name = "RunnerDust"
	dust_particles.amount = 14
	dust_particles.lifetime = 0.40
	dust_particles.preprocess = 0.1
	dust_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	dust_particles.emission_sphere_radius = 0.22
	dust_particles.direction = Vector3(0.0, 0.5, 1.0)
	dust_particles.spread = 30.0
	dust_particles.gravity = Vector3(0.0, -1.5, 0.0)
	dust_particles.initial_velocity_min = 1.2
	dust_particles.initial_velocity_max = 3.2
	dust_particles.scale_amount_min = 0.06
	dust_particles.scale_amount_max = 0.16

	var dust_mat: StandardMaterial3D = StandardMaterial3D.new()
	dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_mat.albedo_color = Color(0.85, 0.78, 0.68, 0.40)
	dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_particles.material_override = dust_mat
	dust_particles.position = Vector3(0.0, 0.05, 0.35)
	add_child(dust_particles)


func _setup_ability_visuals() -> void:
	# Sleek horizontal ground aura ring instead of a giant obstructive sphere
	shield_mesh = MeshInstance3D.new()
	shield_mesh.name = "AbilityShield"
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.52
	ring.outer_radius = 0.70
	ring.rings = 24
	ring.ring_segments = 16
	shield_mesh.mesh = ring

	var aura_mat: StandardMaterial3D = StandardMaterial3D.new()
	aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_mat.albedo_color = Color(1.0, 0.85, 0.2, 0.65)
	aura_mat.emission_enabled = true
	aura_mat.emission = Color(1.0, 0.8, 0.2)
	aura_mat.emission_energy_multiplier = 2.0
	shield_mesh.material_override = aura_mat
	shield_mesh.position = Vector3(0.0, 0.04, 0.0)
	shield_mesh.visible = false
	add_child(shield_mesh)




func _input(event: InputEvent) -> void:
	if GameManager.is_game_over:
		return

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
			KEY_E, KEY_F:
				if CharacterManager:
					CharacterManager.trigger_active_ability()

	if event is InputEventScreenTouch:
		if event.is_pressed():
			var now: float = Time.get_ticks_msec() / 1000.0
			if now - last_tap_time < DOUBLE_TAP_TIME and (event.position - last_tap_pos).length() < 50.0:
				if CharacterManager:
					CharacterManager.trigger_active_ability()
			last_tap_time = now
			last_tap_pos = event.position
			touch_start_pos = event.position
			is_touch_active = true
		else:
			if is_touch_active:
				var swipe_vec: Vector2 = event.position - touch_start_pos
				if swipe_vec.length() >= SWIPE_THRESHOLD:
					_process_swipe(swipe_vec)
			is_touch_active = false

	elif event is InputEventScreenDrag and is_touch_active:
		var swipe_vec: Vector2 = event.position - touch_start_pos
		if swipe_vec.length() >= SWIPE_THRESHOLD:
			_process_swipe(swipe_vec)
			touch_start_pos = event.position

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				var now: float = Time.get_ticks_msec() / 1000.0
				if now - last_tap_time < DOUBLE_TAP_TIME and (event.position - last_tap_pos).length() < 50.0:
					if CharacterManager:
						CharacterManager.trigger_active_ability()
				last_tap_time = now
				last_tap_pos = event.position
				touch_start_pos = event.position
				is_touch_active = true
			else:
				if is_touch_active:
					var swipe_vec: Vector2 = event.position - touch_start_pos
					if swipe_vec.length() >= SWIPE_THRESHOLD:
						_process_swipe(swipe_vec)
				is_touch_active = false
	elif event is InputEventMouseMotion and is_touch_active:
		var swipe_vec: Vector2 = event.position - touch_start_pos
		if swipe_vec.length() >= SWIPE_THRESHOLD:
			_process_swipe(swipe_vec)
			touch_start_pos = event.position


func _process_swipe(swipe_vec: Vector2) -> void:
	if abs(swipe_vec.x) > abs(swipe_vec.y):
		if swipe_vec.x < 0.0:
			switch_lane(-1)
		else:
			switch_lane(1)
	else:
		if swipe_vec.y < 0.0:
			jump()
		else:
			slide()


func switch_lane(direction: int) -> void:
	var target_lane: int = clampi(current_lane + direction, -1, 1)
	if target_lane == current_lane:
		return

	current_lane = target_lane
	var target_x: float = current_lane * LANE_WIDTH

	# Bank sprite smoothly into lane turn
	banking_tilt = -float(direction) * 0.22

	# Sound effect
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx_lane_switch(direction)

	if lane_tween and lane_tween.is_running():
		lane_tween.kill()

	lane_tween = create_tween()
	lane_tween.set_trans(Tween.TRANS_QUAD)
	lane_tween.set_ease(Tween.EASE_OUT)
	lane_tween.tween_property(self, "position:x", target_x, LANE_SWITCH_DURATION)


func jump() -> void:
	if is_peasant_fever:
		return
	if is_on_floor() or position.y < 0.15:
		if is_sliding:
			_end_slide()
		velocity.y = JUMP_VELOCITY
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx_jump()


func slide() -> void:
	if is_peasant_fever:
		return

	# Fast-fall: If sliding while airborne, quickly dive down to the road
	if not is_on_floor():
		velocity.y = -JUMP_VELOCITY * 1.5

	if not is_sliding:
		is_sliding = true
		slide_timer = SLIDE_DURATION
		_set_collision_height(original_shape_height * SLIDE_HEIGHT_RATIO)
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx_slide()
	else:
		slide_timer = SLIDE_DURATION


func _end_slide() -> void:
	if not is_sliding:
		return

	is_sliding = false
	slide_timer = 0.0
	_set_collision_height(original_shape_height)


## Interactive speed ramp boost: launches upward and grants speed boost
func apply_ramp_boost(vertical_launch: float = 13.5, bonus_speed: float = 6.5, duration: float = 2.5) -> void:
	if is_sliding:
		_end_slide()
	velocity.y = vertical_launch
	ramp_boost_timer = duration
	ramp_speed_bonus = bonus_speed
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx_ability()
	if camera:
		camera.fov = minf(camera.fov + 10.0, 95.0)


func _set_collision_height(new_height: float) -> void:
	if not collision_shape or not collision_shape.shape:
		return

	if collision_shape.shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = collision_shape.shape
		capsule.height = new_height
	elif collision_shape.shape is BoxShape3D:
		var box: BoxShape3D = collision_shape.shape
		box.size.y = new_height

	collision_shape.position.y = new_height * 0.5
	if abs(position.x) <= 5.5 and position.y < -0.10:
		position.y = 0.0


func _physics_process(delta: float) -> void:
	if GameManager.is_game_over:
		velocity = Vector3.ZERO
		return

	if is_sliding:
		slide_timer -= delta
		if slide_timer <= 0.0:
			_end_slide()

	if emergency_shield_timer > 0.0:
		emergency_shield_timer -= delta
		if emergency_shield_timer <= 0.0:
			is_invulnerable = false

	if invulnerable_timer > 0.0:
		invulnerable_timer -= delta
		if invulnerable_timer <= 0.0 and emergency_shield_timer <= 0.0 and chariot_boost_timer <= 0.0:
			is_invulnerable = false

	# Power-Up Countdown Timers
	var chariot_speed_boost: float = 0.0
	if chariot_boost_timer > 0.0:
		chariot_boost_timer -= delta
		chariot_speed_boost = 8.0
		is_invulnerable = true

	if in_run_magnet_timer > 0.0:
		in_run_magnet_timer -= delta

	# Forward Speed with momentary Ramp Boost & Chariot Boost
	var speed_modifier: float = 1.0
	if CharacterManager and CharacterManager.active_character:
		speed_modifier = CharacterManager.active_character.base_speed_modifier

	var boost: float = 0.0
	if ramp_boost_timer > 0.0:
		boost = ramp_speed_bonus * (ramp_boost_timer / 2.5)
		ramp_boost_timer = maxf(0.0, ramp_boost_timer - delta)

	# Lateral movement is strictly lane-based; physics collisions must NEVER add lateral velocity
	velocity.x = 0.0
	velocity.z = -(GameManager.current_speed * speed_modifier + boost + chariot_speed_boost)

	# Peasant Revolution Flight Mode: Glide smoothly at Y = 2.4m
	if is_peasant_fever:
		position.y = lerpf(position.y, 2.4, 8.0 * delta)
		velocity.y = 0.0
	else:
		if not is_on_floor():
			velocity.y -= GRAVITY_MULTIPLIER * delta
		elif velocity.y < 0:
				velocity.y = 0.0

	move_and_slide()

	# Zero out any lateral velocity resulting from collision deflection
	velocity.x = 0.0

	# Void Fall Detection: If player falls off the track
	if position.y < -4.0 and not GameManager.is_game_over:
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx_void_fall()
		GameManager.trigger_game_over("Fell into the Temporal Void!")
		return

	# Strict Lateral Track Bounds Locking (Never allows player to get knocked off the road)
	if absf(position.x) <= 4.0:
		if lane_tween and lane_tween.is_running():
			position.x = clampf(position.x, -LANE_WIDTH, LANE_WIDTH)
		elif not GameManager.is_game_over:
			position.x = current_lane * LANE_WIDTH

		# Road surface floor & ceiling clamp
		if position.y < 0.0:
			position.y = 0.0
			if velocity.y < 0.0:
				velocity.y = 0.0
		elif position.y > 4.2:
			position.y = 4.2
			if velocity.y > 0.0:
				velocity.y = 0.0

	# Landing Impact Juice
	var on_floor: bool = is_on_floor() or position.y <= 0.04
	if on_floor and not was_on_floor_last_frame and not is_sliding:
		landing_dip_offset = -0.06
		camera_trauma = minf(camera_trauma + 0.16, 0.45)
		if dust_particles:
			dust_particles.restart()
	was_on_floor_last_frame = on_floor


	# Proactive hazard clearing ahead of runner during Chariot Boost / Peasant Fever
	if chariot_boost_timer > 0.0 or is_peasant_fever:
		for node in get_tree().root.find_children("Obstacle_*", "StaticBody3D", true, false):
			var dz: float = node.global_position.z - global_position.z
			if dz < 0.5 and dz > -3.5 and absf(node.global_position.x - position.x) < 2.0:
				_smash_obstacle(node as Node3D)
				_spawn_floating_text("💥 SMASH! +50", Color(1.0, 0.85, 0.2))

	_update_procedural_animations(delta)
	_update_dynamic_camera(delta)
	_check_close_calls(delta)


	# Divine Right Artillery Barrage: Clears upcoming hazards
	if is_divine_fever:
		artillery_timer -= delta
		if artillery_timer <= 0.0:
			artillery_timer = 0.6
			_execute_artillery_strike()

	# Process Active Magnetism (Harriet, Fever, Tesla Watch, or In-Run Magnet)
	if has_magnet_active or is_peasant_fever or is_divine_fever or tesla_magnet_timer > 0.0 or in_run_magnet_timer > 0.0:
		if tesla_magnet_timer > 0.0:
			tesla_magnet_timer -= delta
		_process_magnetism(delta)

	_check_collisions()



## Activates Tesla's Pocket Watch 3.0s magnetism burst.
func activate_tesla_magnet(duration: float = 3.0) -> void:
	tesla_magnet_timer = duration
	print("[Relic: Tesla's Pocket Watch] Activated %.1fs magnetism burst!" % duration)


## Pulls relevant collectibles toward player based on active state.
func _process_magnetism(delta: float) -> void:
	var radius: float = FEVER_MAGNET_RADIUS if (is_peasant_fever or is_divine_fever or tesla_magnet_timer > 0.0) else MAGNET_RADIUS
	var speed: float = FEVER_MAGNET_SPEED if (is_peasant_fever or is_divine_fever or tesla_magnet_timer > 0.0) else MAGNET_PULL_SPEED

	for node in get_tree().root.find_children("*", "Area3D", true, false):
		if node is CollectibleScript and not node.is_collected:
			if tesla_magnet_timer <= 0.0:
				if is_peasant_fever and node.get("type") != CollectibleScript.CollectibleType.PEOPLE_FIST:
					continue
				if is_divine_fever and node.get("type") != CollectibleScript.CollectibleType.GOVT_CROWN:
					continue

			var dist: float = global_position.distance_to(node.global_position)
			if dist <= radius:
				var pull_dir: Vector3 = (global_position + Vector3(0, 0.5, 0) - node.global_position).normalized()
				node.global_position += pull_dir * speed * delta


## Divine Right: Royal artillery clears hazards ahead of the player across all 3 lanes.
func _execute_artillery_strike() -> void:
	for node in get_tree().root.find_children("Obstacle_*", "StaticBody3D", true, false):
		var dz: float = node.global_position.z - global_position.z
		if dz < -5.0 and dz > -35.0:
			_transmute_obstacle(node as Node3D)


func _check_collisions() -> void:
	for i in range(get_slide_collision_count()):
		var collision: KinematicCollision3D = get_slide_collision(i)
		var collider: Object = collision.get_collider()

		if collider and (collider.is_in_group("obstacles") or collider.name.begins_with("Obstacle")):
			# If sliding, glide safely underneath high arch obstacles
			if is_sliding and (collider.name.begins_with("Obstacle_HighArch") or "HighArch" in collider.name):
				continue

			# In-Run Chariot Boost or Peasant Fever: Smash right through!
			if chariot_boost_timer > 0.0 or is_peasant_fever:
				_smash_obstacle(collider as Node3D)
				_spawn_floating_text("💥 SMASH! +50", Color(1.0, 0.85, 0.2))
				continue

			if is_invulnerable:
				_pulse_shield_impact()
				continue

			if is_ghost_mode:
				continue

			if has_divine_aura:
				_transmute_obstacle(collider as Node3D)
				continue

			# In-Run Chrono-Shield Protection: Absorbs hit and saves the run!
			if has_chrono_shield:
				has_chrono_shield = false
				_trigger_shield_break(collider as Node3D)
				continue

			# Relic Perk: Cleopatra's Asp
			if has_node("/root/SaveManager"):
				var sm = get_node("/root/SaveManager")
				if sm.is_relic_equipped("cleopatra_asp") and not cleopatra_asp_used:
					cleopatra_asp_used = true
					_trigger_cleopatra_asp()
					continue

			var reason: String = "Crashed into %s" % collider.name
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").play_sfx_crash()
			GameManager.trigger_game_over(reason)
			break



## Cleopatra's Asp: Emergency revival resetting meters to 50/50 with 3.5s invulnerability.
func _trigger_cleopatra_asp() -> void:
	GameManager.people_power = 50.0
	GameManager.govt_power = 50.0
	GameManager.power_changed.emit(50.0, 50.0)
	emergency_shield_timer = 3.5
	is_invulnerable = true
	shield_mesh.visible = true
	shield_mesh.material_override.albedo_color = Color(0.2, 0.95, 0.45, 0.6)
	shield_mesh.material_override.emission = Color(0.2, 0.9, 0.4)
	if GameManager:
		GameManager.decision_notification.emit("🐍 CLEOPATRA'S ASP: Fatal collapse averted! Meters stabilized at 50%!")


func _smash_obstacle(obstacle: Node3D) -> void:
	if not obstacle:
		return
	# Immediately disable collision on all shapes to prevent physical snagging / lateral push
	for col in obstacle.find_children("*", "CollisionShape3D", true, false):
		col.set_deferred("disabled", true)
	if obstacle is CollisionObject3D:
		obstacle.set_deferred("collision_layer", 0)
		obstacle.set_deferred("collision_mask", 0)
	GameManager.add_people_power(3.0)
	var tween: Tween = create_tween()
	tween.tween_property(obstacle, "scale", Vector3(1.3, 0.2, 1.3), 0.1)
	tween.tween_callback(obstacle.queue_free)


func _transmute_obstacle(obstacle: Node3D) -> void:
	if not obstacle:
		return
	for col in obstacle.find_children("*", "CollisionShape3D", true, false):
		col.set_deferred("disabled", true)
	if obstacle is CollisionObject3D:
		obstacle.set_deferred("collision_layer", 0)
		obstacle.set_deferred("collision_mask", 0)
	GameManager.add_people_power(4.0)
	GameManager.add_govt_power(4.0)
	var tween: Tween = create_tween()
	tween.tween_property(obstacle, "scale", Vector3.ZERO, 0.2)
	tween.tween_callback(obstacle.queue_free)



func _pulse_shield_impact() -> void:
	if not shield_mesh:
		return
	var tween: Tween = create_tween()
	tween.tween_property(shield_mesh, "scale", Vector3(1.2, 1.2, 1.2), 0.08)
	tween.tween_property(shield_mesh, "scale", Vector3.ONE, 0.08)


# --- Phase 4 Fever State Callbacks ---

func _on_fever_started(fever_type: String, _duration: float) -> void:
	shield_mesh.visible = true
	if fever_type == "peasant_revolution":
		is_peasant_fever = true
		shield_mesh.material_override.albedo_color = Color(1.0, 0.2, 0.2, 0.6)
		shield_mesh.material_override.emission = Color(1.0, 0.15, 0.2)
	else:
		is_divine_fever = true
		shield_mesh.material_override.albedo_color = Color(0.2, 0.6, 1.0, 0.6)
		shield_mesh.material_override.emission = Color(0.2, 0.5, 1.0)


func _on_fever_ended(_fever_type: String) -> void:
	is_peasant_fever = false
	is_divine_fever = false
	if not is_invulnerable and not is_ghost_mode:
		shield_mesh.visible = false


# --- Ability & Perk Event Handlers ---

func _on_ability_activated(character: Resource, _duration: float) -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx_ability()

	match character.get("character_name"):
		"Julius Caesar":
			is_invulnerable = true
			shield_mesh.visible = true
			shield_mesh.material_override.albedo_color = Color(1.0, 0.8, 0.2, 0.45)
			shield_mesh.material_override.emission = Color(1.0, 0.75, 0.2)

		"Joan of Arc":
			has_divine_aura = true
			shield_mesh.visible = true
			shield_mesh.material_override.albedo_color = Color(0.9, 0.95, 1.0, 0.5)
			shield_mesh.material_override.emission = Color(0.95, 0.9, 0.4)

		"Harriet Tubman":
			is_ghost_mode = true
			has_magnet_active = true
			shield_mesh.visible = true
			shield_mesh.material_override.albedo_color = Color(0.2, 0.9, 0.6, 0.35)
			shield_mesh.material_override.emission = Color(0.2, 0.85, 0.5)

			if character_sprite:
				character_sprite.modulate = Color(1, 1, 1, 0.4)


func _on_ability_deactivated(_character: Resource) -> void:
	is_invulnerable = false
	has_divine_aura = false
	is_ghost_mode = false
	has_magnet_active = false
	if not is_peasant_fever and not is_divine_fever:
		if is_instance_valid(shield_mesh):
			shield_mesh.visible = false


	if character_sprite:
		var char_data = CHARACTER_SPRITES.get(active_character_name, CHARACTER_SPRITES["Julius Caesar"])
		character_sprite.modulate = char_data["modulate"]


func _on_power_changed(people: float, govt: float) -> void:
	if not CharacterManager or not CharacterManager.active_character:
		return

	if CharacterManager.active_character.get("passive_perk_type") == "zealots_faith":
		if (people < 15.0 or govt < 15.0) and not zealot_emergency_triggered:
			zealot_emergency_triggered = true
			emergency_shield_timer = 4.0
			is_invulnerable = true
			invulnerable_timer = 4.0
			if GameManager:
				GameManager.decision_notification.emit("⚔️ ZEALOT'S FAITH: Emergency 4s Invincibility!")
		elif people >= 25.0 and govt >= 25.0:
			zealot_emergency_triggered = false



func _on_character_selected(character: Resource) -> void:
	_apply_character_visuals(character)


## Initializes pure direct rear-view 2.5D Sprite3D and real-time lighting for active ruler.
func _apply_character_visuals(character: Resource) -> void:
	if not visual_model:
		return

	# Clean up previous visuals
	for child in visual_model.get_children():
		visual_model.remove_child(child)
		child.queue_free()

	active_character_name = character.get("character_name") if character else "Chibi Leader"
	if not CHARACTER_SPRITES.has(active_character_name):
		active_character_name = "Chibi Leader"

	var char_data = CHARACTER_SPRITES[active_character_name]
	var run1_texture: Texture2D = char_data["run1"]

	# Create Sprite3D with clean alpha discard
	character_sprite = Sprite3D.new()
	character_sprite.name = "CharacterSprite3D"
	character_sprite.texture = run1_texture
	character_sprite.centered = true
	character_sprite.offset = Vector2.ZERO
	character_sprite.alpha_cut = Sprite3D.ALPHA_CUT_DISABLED
	character_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	character_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	character_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED

	# Match sprite height exactly to 1.8m collision capsule
	var tex_h: float = float(run1_texture.get_height()) if run1_texture else 1024.0
	character_sprite.pixel_size = DEFAULT_HEIGHT / tex_h
	var base_y: float = char_data.get("base_y", 0.84)
	character_sprite.position = Vector3(0.0, base_y, 0.0)
	character_sprite.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
	character_sprite.modulate = char_data["modulate"]
	visual_model.add_child(character_sprite)

	# Dynamic character illumination (Freedom Lantern, Saint Halo, Imperial Radiance)
	character_light = OmniLight3D.new()
	character_light.name = "CharacterDynamicLight"
	character_light.light_color = char_data["light_color"]
	character_light.light_energy = char_data["light_energy"]
	character_light.omni_range = char_data["light_range"]
	character_light.omni_attenuation = 1.2
	character_light.position = char_data["light_offset"]
	character_light.shadow_enabled = false
	character_sprite.add_child(character_light)

	# Subtle, small ground contact shadow (0.18 radius, 0.18 opacity)
	var shadow_inst: MeshInstance3D = MeshInstance3D.new()
	shadow_inst.name = "ContactShadow"
	var shadow_mesh: CylinderMesh = CylinderMesh.new()
	shadow_mesh.top_radius = 0.18
	shadow_mesh.bottom_radius = 0.18
	shadow_mesh.height = 0.01
	var shadow_mat: StandardMaterial3D = StandardMaterial3D.new()
	shadow_mat.albedo_color = Color(0.04, 0.04, 0.06, 0.18)
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.roughness = 1.0
	shadow_inst.mesh = shadow_mesh
	shadow_inst.material_override = shadow_mat
	shadow_inst.position = Vector3(0.0, 0.02, 0.05)
	visual_model.add_child(shadow_inst)



## Procedurally animates 2.5D sprite bobbing, multi-frame run cycle, banking, and state textures.
func _update_procedural_animations(delta: float) -> void:
	if not character_sprite:
		return

	if not CHARACTER_SPRITES.has(active_character_name):
		return

	var char_data = CHARACTER_SPRITES[active_character_name]
	var base_y: float = char_data.get("base_y", 0.84)

	# Banking recovery
	banking_tilt = lerpf(banking_tilt, 0.0, 8.0 * delta)
	character_sprite.rotation.z = banking_tilt

	# Dynamic Contact Shadow: Only visible when grounded (height <= 0.15m) and not sliding
	var contact_shadow = visual_model.get_node_or_null("ContactShadow")
	if contact_shadow:
		var is_grounded: bool = position.y <= 0.15 and not is_sliding and not GameManager.is_game_over
		contact_shadow.visible = is_grounded
		if is_grounded:
			var s: float = 1.0 + sin(run_anim_time * 2.0) * 0.06
			contact_shadow.scale = Vector3(s, 1.0, s)

	# Rotate Ground Halo Ring
	if is_instance_valid(shield_mesh) and shield_mesh.visible:
		shield_mesh.rotate_y(delta * 4.0)

	# Invulnerability sprite flicker
	if invulnerable_timer > 0.0 and character_sprite:
		character_sprite.modulate.a = 0.35 if fmod(Time.get_ticks_msec() * 0.015, 2.0) < 1.0 else 1.0

	if GameManager.is_game_over:
		character_sprite.rotation_degrees.x = lerpf(character_sprite.rotation_degrees.x, -25.0, 6.0 * delta)
		return


	# State 1: Peasant Revolution Fever Flight
	if is_peasant_fever:
		character_sprite.texture = char_data["jump"]
		var flight_tex_h: float = float(char_data["jump"].get_height())
		character_sprite.pixel_size = DEFAULT_HEIGHT / flight_tex_h
		run_anim_time += delta * 4.0
		character_sprite.position.y = base_y + sin(run_anim_time) * 0.08
		character_sprite.rotation_degrees.x = -15.0
		return

	# State 2: Low Ground Slide
	if is_sliding:
		character_sprite.texture = char_data["slide"]
		var slide_tex_h: float = float(char_data["slide"].get_height())
		character_sprite.pixel_size = 1.28 / slide_tex_h
		character_sprite.position.y = 0.61
		character_sprite.position.x = 0.0
		character_sprite.rotation_degrees.x = -16.0
		return

	# State 3: Airborne Jump Leap (Only when genuinely in the air or launching)
	var is_airborne: bool = (not is_on_floor() and position.y > 0.18) or velocity.y > 1.2
	if is_airborne:
		character_sprite.texture = char_data["jump"]
		var jump_tex_h: float = float(char_data["jump"].get_height())
		character_sprite.pixel_size = DEFAULT_HEIGHT / jump_tex_h
		character_sprite.position.y = base_y + 0.10
		character_sprite.position.x = 0.0
		character_sprite.rotation_degrees.x = -12.0
		return

	# State 4: Multi-Frame Ground Running Stride Cycle (Pure Rear View)
	var run_freq: float = 11.0 * (GameManager.current_speed / 12.0)
	run_anim_time += delta * run_freq

	# Alternate between right stride (run1) and left stride (run2) based on stride cycle
	var is_stride_right: bool = fmod(run_anim_time, 2.0 * PI) < PI
	var current_run_tex: Texture2D = char_data["run1"] if is_stride_right else char_data["run2"]
	character_sprite.texture = current_run_tex

	var run_tex_h: float = float(current_run_tex.get_height()) if current_run_tex else 1024.0
	character_sprite.pixel_size = DEFAULT_HEIGHT / run_tex_h

	# Athletic running bounce & hip sway
	var vertical_bounce: float = abs(sin(run_anim_time)) * 0.05
	character_sprite.position.y = base_y + vertical_bounce
	character_sprite.position.x = sin(run_anim_time * 0.5) * 0.03
	character_sprite.rotation_degrees.x = -8.0




func _on_game_over(_reason: String) -> void:
	if lane_tween and lane_tween.is_running():
		lane_tween.kill()
	is_invulnerable = false
	is_ghost_mode = false
	has_divine_aura = false
	has_magnet_active = false
	is_peasant_fever = false
	if shield_mesh:
		shield_mesh.visible = false


## Dynamically updates camera FOV, banking roll, footstep micro-bobbing, trauma shake, and dust.
func _update_dynamic_camera(delta: float) -> void:
	if not camera:
		return

	# 1. Dynamic Speed FOV: widen FOV from 68° to 80° (up to 84° during Chariot Boost)
	var speed_ratio: float = clampf((GameManager.current_speed - 12.0) / 16.0, 0.0, 1.0)
	var target_fov: float = lerpf(68.0, 80.0, speed_ratio)
	if chariot_boost_timer > 0.0:
		target_fov += 5.0
	camera.fov = lerpf(camera.fov, target_fov, 3.5 * delta)

	# 2. Footstep micro-bobbing synchronized with running stride and landing dip
	var base_cam_y: float = 3.8 + landing_dip_offset
	landing_dip_offset = lerpf(landing_dip_offset, 0.0, 8.0 * delta)

	if (is_on_floor() or position.y < 0.15) and not is_sliding and not GameManager.is_game_over:
		camera.position.y = base_cam_y + sin(run_anim_time * 2.0) * 0.025
	else:
		camera.position.y = lerpf(camera.position.y, base_cam_y, 6.0 * delta)

	# 3. Dynamic banking roll when switching lanes
	camera.rotation.z = lerpf(camera.rotation.z, banking_tilt * 0.45, 8.0 * delta)

	# 4. Camera Trauma Shake (Close calls, collisions, boosts)
	if camera_trauma > 0.0:
		var shake_amount = camera_trauma * camera_trauma
		camera.h_offset = (randf() * 2.0 - 1.0) * shake_amount * 0.14
		camera.v_offset = (randf() * 2.0 - 1.0) * shake_amount * 0.14
		camera_trauma = maxf(0.0, camera_trauma - delta * 2.2)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0

	# 5. Dust particles emission
	if dust_particles:
		dust_particles.emitting = (is_on_floor() or position.y < 0.15) and not is_peasant_fever and not GameManager.is_game_over


# ==============================================================================
# --- In-Run Power-Up Handlers & Juice Mechanics ---
# ==============================================================================

## Activates In-Run Royal Magnet (attracts tokens from all 3 lanes for 2.5s).
func activate_in_run_magnet(duration: float = 2.5) -> void:
	in_run_magnet_timer = duration
	_spawn_floating_text("🧲 MAGNET ON!", Color(0.2, 0.8, 1.0))
	if GameManager:
		GameManager.decision_notification.emit("🧲 ROYAL MAGNET: Vacuums All Coins Across All Lanes!")
	if shield_mesh:
		shield_mesh.visible = true
		shield_mesh.material_override.albedo_color = Color(0.2, 0.8, 1.0, 0.7)
		shield_mesh.material_override.emission = Color(0.2, 0.85, 1.0)


## Activates Chrono-Shield (absorbs 1 collision).
func activate_chrono_shield() -> void:
	has_chrono_shield = true
	_spawn_floating_text("🛡️ AEGIS READY!", Color(0.3, 1.0, 0.6))
	if GameManager:
		GameManager.decision_notification.emit("🛡️ AEGIS SHIELD: Absorbs 1 Fatal Crash!")
	if shield_mesh:
		shield_mesh.visible = true
		shield_mesh.material_override.albedo_color = Color(0.25, 1.0, 0.5, 0.7)
		shield_mesh.material_override.emission = Color(0.25, 1.0, 0.45)


## Activates Imperial Dash / Chariot Boost (+8 m/s hyper-speed rush for 2.0s).
func activate_chariot_boost(duration: float = 2.0) -> void:
	chariot_boost_timer = duration
	camera_trauma = 0.35
	_spawn_floating_text("⚡ SPEED DASH!", Color(1.0, 0.85, 0.2))
	if GameManager:
		GameManager.decision_notification.emit("⚡ IMPERIAL DASH: Invincible Speed & Smashes Obstacles!")
	if shield_mesh:
		shield_mesh.visible = true
		shield_mesh.material_override.albedo_color = Color(1.0, 0.85, 0.2, 0.85)
		shield_mesh.material_override.emission = Color(1.0, 0.85, 0.3)


## Smashes an obstacle safely when shield absorbs impact.
func _trigger_shield_break(obstacle: Node3D) -> void:
	has_chrono_shield = false
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx_shield_break()

	_smash_obstacle(obstacle)
	is_invulnerable = true
	invulnerable_timer = 1.0
	camera_trauma = 0.35

	_spawn_floating_text("🛡️ AEGIS CRASH ABSORPTION!", Color(0.3, 1.0, 0.6))
	if GameManager:
		GameManager.decision_notification.emit("🛡️ AEGIS SHIELD: Collision absorbed safely!")
	if shield_mesh and not (in_run_magnet_timer > 0.0 or chariot_boost_timer > 0.0):
		shield_mesh.visible = false


## Evaluates close-call / near-miss brush with obstacles along the road.
func _check_close_calls(_delta: float) -> void:
	if GameManager.is_game_over:
		return

	for node in get_tree().root.find_children("Obstacle_*", "StaticBody3D", true, false):
		var obs = node as StaticBody3D
		if not obs or not is_instance_valid(obs):
			continue

		var obs_id: int = obs.get_instance_id()
		if close_call_history.has(obs_id):
			continue

		var dz: float = obs.global_position.z - global_position.z
		if dz >= -1.0 and dz <= 1.2:
			var dx: float = absf(obs.global_position.x - global_position.x)
			var dy: float = global_position.y - obs.global_position.y

			var is_close: bool = false
			if dx >= 1.3 and dx <= 2.4 and absf(dy) < 0.9:
				is_close = true
			elif dx < 1.0 and not is_on_floor() and dy >= 0.70 and dy <= 1.6:
				is_close = true

			if is_close:
				close_call_history[obs_id] = true
				_trigger_close_call()


func _trigger_close_call() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx_close_call()
	camera_trauma = minf(camera_trauma + 0.22, 0.55)
	GameManager.add_people_power(1.5)
	GameManager.add_govt_power(1.5)
	_spawn_floating_text("⚡ CLOSE CALL! +50", Color(1.0, 0.9, 0.2))


func trigger_combo_popup(combo: int) -> void:
	camera_trauma = minf(camera_trauma + 0.15, 0.4)
	_spawn_floating_text("🔥 %dx STREAK!" % combo, Color(1.0, 0.45, 0.1))


## Procedurally pops a floating 3D text label above the player.
func _spawn_floating_text(text: String, col: Color) -> void:
	var label = Label3D.new()
	label.text = text
	label.font_size = 28
	label.outline_size = 6
	label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	label.modulate = col
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 14
	label.position = Vector3(randf_range(-0.25, 0.25), 1.9, 0.0)
	add_child(label)

	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y + 1.2, 0.45)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.45)
	tween.tween_callback(label.queue_free)
